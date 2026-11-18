#!/usr/bin/env bash
# ==============================================================================
# cleanup.sh - Limpieza completa de contenedores, red y volumenes de prueba
# Uso: ./scripts/cleanup.sh [--volumes]
# ==============================================================================
set -euo pipefail

REMOVE_VOLS="${1:-}"

CONTAINERS="$(docker ps -a --format '{{.Names}}' | grep -E '^(nginx-lb|nginx-assets|app-[0-9]+|redis-master|redis-replica|redis-sentinel-[0-9]+|mysql-master|mysql-replica)$' || true)"
if [ -n "$CONTAINERS" ]; then
  echo "[cleanup] Deteniendo y eliminando contenedores: $CONTAINERS"
  docker rm -f $CONTAINERS >/dev/null 2>&1 || true
else
  echo "[cleanup] No hay contenedores del proyecto activos."
fi

if docker network inspect ha-net >/dev/null 2>&1; then
  echo "[cleanup] Eliminando red Docker ha-net..."
  docker network rm ha-net >/dev/null 2>&1 || true
fi

if [ "$REMOVE_VOLS" = "--volumes" ]; then
  echo "[cleanup] Eliminando volumenes persistentes..."
  docker volume rm mysql_master_data mysql_replica_data redis_master_data redis_replica_data >/dev/null 2>&1 || true
fi

rm -rf /tmp/ha_assets /tmp/ha_nginx_lb.conf /tmp/ha_sentinel_* /tmp/ha_my_*.cnf
echo "[cleanup] Limpieza finalizada."
