#!/usr/bin/env bash
# ==============================================================================
# cache_up.sh - [ESQUELETO: Rol 3 (Especialista en Cache HA y Memoria)]
# Despliega Redis Primario, Redis Replica y 3 instancias de Redis Sentinel.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NET_NAME="ha-net"

HOST_CPUS="$(nproc)"
HOST_MEM_MB="$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
echo "[cache_up] VM detectada: ${HOST_CPUS} vCPUs | ${HOST_MEM_MB} MB RAM"

# TODO [Rol 3]: Crear red 'ha-net' y volumenes persistentes 'redis_master_data' y 'redis_replica_data'

# TODO [Rol 3]: Levantar 'redis-master' (imagen redis:7-alpine) con flags explicitos:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=400
#   montando ${ROOT_DIR}/config/redis/redis_master.conf y redis_master_data:/data

# TODO [Rol 3]: Levantar 'redis-replica' con replicacion hacia redis-master,
#   mismos limites cgroups v2, --oom-score-adj=400 y redis_replica_data:/data

# TODO [Rol 3]: Copiar ${ROOT_DIR}/config/redis/sentinel.conf a un directorio escribible por instancia
# (ej. /tmp/ha_sentinel_1..3) para que Sentinel pueda reescribir su estado sin EBUSY,
# y levantar 'redis-sentinel-1', 'redis-sentinel-2' y 'redis-sentinel-3' con quorum=2.

# TODO [Rol 3]: Verificar con 'redis-cli INFO replication' y 'SENTINEL master mymaster'
echo "[cache_up] TODO: completar implementacion de Rol 3."
