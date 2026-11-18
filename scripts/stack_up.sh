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

# TODO [Rol 1]: Crear la red bridge 'ha-net' si no existe (docker network create)

# TODO [Rol 2]: Construir la imagen 'so-ha-app:1.0' desde ${ROOT_DIR}/app si no existe o si se pasa --build

# TODO [Rol 1]: Preparar archivos estaticos de prueba (incluyendo un payload de varios MB para evidenciar Page Cache)
# y levantar 'nginx-assets' con docker run aplicando:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=200
#   y montando ${ROOT_DIR}/config/nginx/nginx_assets.conf

# TODO [Rol 2]: Levantar N replicas ('app-1' .. "app-${REPLICAS}") con docker run aplicando:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=0
#   variables de entorno: APP_WORKERS, UV_THREADPOOL_SIZE, REDIS_SENTINELS, MYSQL_PRIMARY_HOST, MYSQL_REPLICA_HOST

# TODO [Rol 1]: Generar configuracion upstream para N replicas (sin ensuciar el repo si usas /tmp)
# y levantar 'nginx-lb' en puerto 8080:8080 aplicando:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=-700

# TODO [Rol 1 y 2]: Esperar y verificar que http://127.0.0.1:8080/health devuelva HTTP 200 OK
echo "[stack_up] TODO: completar implementacion de Rol 1 y Rol 2."
