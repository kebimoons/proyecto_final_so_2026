#!/usr/bin/env bash
# ==============================================================================
# falla.sh - [ESQUELETO: Rol 6 (Ingeniero de Caos, Failover HA y Documentacion)]
# Inyeccion controlada de fallos y pruebas de memoria cgroups v2.
# Uso previsto: ./scripts/falla.sh <app|redis|mysql|oom_high|oom_max|restore>
# ==============================================================================
set -euo pipefail

MODE="${1:-}"
if [ -z "$MODE" ]; then
  echo "Uso: $0 <app|redis|mysql|oom_high|oom_max|restore>" >&2
  exit 1
fi

case "$MODE" in
  app)
    # TODO [Rol 6]: Detener/matar una replica de aplicacion (ej. docker kill app-1) bajo trafico
    echo "[falla:app] TODO: implementar caida de app-1."
    ;;
  redis)
    # TODO [Rol 6]: Matar redis-master y verificar promocion automatica de redis-replica via Redis Sentinel
    echo "[falla:redis] TODO: implementar caida de redis-master y verificacion Sentinel."
    ;;
  mysql)
    # TODO [Rol 6]: Insertar registro canario previo, matar mysql-master, promover mysql-replica
    # (STOP REPLICA; SET GLOBAL super_read_only=OFF; read_only=OFF;) y verificar 0 perdida de datos
    echo "[falla:mysql] TODO: implementar failover GTID de mysql-master."
    ;;
  oom_high)
    # TODO [Rol 3 / Rol 6]: Reducir memory.high en /sys/fs/cgroup/... de redis-master bajo carga
    # y registrar degradacion p99 + /proc/pressure/memory (PSI) sin muerte del proceso
    echo "[falla:oom_high] TODO: implementar prueba de degradacion memory.high + PSI."
    ;;
  oom_max)
    # TODO [Rol 3 / Rol 6]: Fijar memory.max (y swap.max=0) en redis-master, superar el limite
    # y capturar la intervencion del OOM Killer en 'dmesg -T | grep -i -E "oom|killed"'
    echo "[falla:oom_max] TODO: implementar prueba de muerte OOM Killer."
    ;;
  restore)
    # TODO [Rol 6]: Restaurar todo el stack llamando a db_up.sh, cache_up.sh y stack_up.sh
    echo "[falla:restore] TODO: implementar restauracion del stack."
    ;;
  *)
    echo "Modo invalido: $MODE. Use: app|redis|mysql|oom_high|oom_max|restore" >&2
    exit 1
    ;;
esac
