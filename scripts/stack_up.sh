#!/usr/bin/env bash
# ==============================================================================
# stack_up.sh - [ESQUELETO: Rol 1 (Entrada/Nginx) y Rol 2 (App Escalabilidad)]
# Uso previsto: ./scripts/stack_up.sh [NUM_REPLICAS] [--build]
# ==============================================================================
set -euo pipefail

REPLICAS="${1:-3}"
BUILD_FLAG="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NET_NAME="ha-net"

# Deteccion basica de hardware disponible en la VM
HOST_CPUS="$(nproc)"
HOST_MEM_MB="$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
echo "[stack_up] VM detectada: ${HOST_CPUS} vCPUs | ${HOST_MEM_MB} MB RAM | Replicas solicitadas: ${REPLICAS}"

# [Rol 1] Red bridge compartida por todos los contenedores
docker network inspect "${NET_NAME}" >/dev/null 2>&1 || docker network create "${NET_NAME}"

# TODO [Rol 2]: Construir la imagen 'so-ha-app:1.0' desde ${ROOT_DIR}/app si no existe o si se pasa --build

# [Rol 1] Archivos estaticos de prueba (payload de 20 MB para evidenciar Page Cache)
ASSETS_DIR="/tmp/ha-assets/assets"
mkdir -p "${ASSETS_DIR}"
echo "<h1>nginx-assets OK</h1>" > "${ASSETS_DIR}/index.html"
[ -f "${ASSETS_DIR}/payload.bin" ] || \
  dd if=/dev/urandom of="${ASSETS_DIR}/payload.bin" bs=1M count=20 status=none

# [Rol 1] nginx-assets
docker rm -f nginx-assets >/dev/null 2>&1 || true
docker run -d --name nginx-assets --network "${NET_NAME}" \
  --cpus 0.5 --memory 128m --memory-reservation 64m --pids-limit 100 \
  --oom-score-adj=200 --restart unless-stopped \
  -v "${ROOT_DIR}/config/nginx/nginx_assets.conf:/etc/nginx/nginx.conf:ro" \
  -v "${ASSETS_DIR}:/usr/share/nginx/html/assets:ro" \
  nginx:alpine >/dev/null
echo "[stack_up] nginx-assets listo"

# TODO [Rol 2]: Levantar N replicas ('app-1' .. "app-${REPLICAS}") con docker run aplicando:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=0
#   variables de entorno: APP_WORKERS, UV_THREADPOOL_SIZE, REDIS_SENTINELS, MYSQL_PRIMARY_HOST, MYSQL_REPLICA_HOST

# [Rol 1] Config del LB en /tmp: upstream para N replicas + worker_processes = vCPUs
GEN_DIR="/tmp/ha-nginx"
mkdir -p "${GEN_DIR}"
: > "${GEN_DIR}/upstream_app.conf"
for i in $(seq 1 "${REPLICAS}"); do
  # nginx no arranca si un host del upstream no existe: solo agrega apps ya creadas
  if docker inspect "app-${i}" >/dev/null 2>&1; then
    echo "server app-${i}:3000 max_fails=1 fail_timeout=3s;" >> "${GEN_DIR}/upstream_app.conf"
  else
    echo "[stack_up] AVISO: app-${i} no existe todavia (Rol 2), no se agrega al upstream"
  fi
done
# Si no hay ninguna app aun, un placeholder deja arrancar el LB (devolvera 502)
[ -s "${GEN_DIR}/upstream_app.conf" ] || \
  echo "server 127.0.0.1:3000 max_fails=1 fail_timeout=3s;" > "${GEN_DIR}/upstream_app.conf"
sed "s/^worker_processes .*/worker_processes ${HOST_CPUS};/" \
  "${ROOT_DIR}/config/nginx/nginx_lb.conf" > "${GEN_DIR}/nginx.conf"

# [Rol 1] nginx-lb
docker rm -f nginx-lb >/dev/null 2>&1 || true
docker run -d --name nginx-lb --network "${NET_NAME}" -p 8080:8080 \
  --cpus 1 --memory 256m --memory-reservation 128m --pids-limit 200 \
  --oom-score-adj=-700 --restart unless-stopped \
  -v "${GEN_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "${GEN_DIR}/upstream_app.conf:/etc/nginx/upstream_app.conf:ro" \
  nginx:alpine >/dev/null
echo "[stack_up] nginx-lb listo en :8080"

# [Rol 1 y 2] Verificar que /health responda 200 (requiere las apps del Rol 2)
for _ in $(seq 1 30); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/health || true)"
  if [ "${CODE}" = "200" ]; then
    echo "[stack_up] OK: /health = 200"
    exit 0
  fi
  sleep 1
done
echo "[stack_up] ERROR: /health no devolvio 200 (se necesitan app-1..N del Rol 2 corriendo)" >&2
exit 1