#!/usr/bin/env bash
# ==============================================================================
# load.sh - [ESQUELETO: Rol 5 (Ingeniero de Carga y Cuellos de Botella)]
# Ejecuta pruebas de carga con >=3 repeticiones, calcula promedios y p99,
# y recolecta metricas de cgroups v2 e iostat en logs/.
# Uso previsto: ./scripts/load.sh <escenario> [URL] [CONCURRENCIA] [PETICIONES] [REPS]
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGS_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOGS_DIR"

SCENARIO="${1:-baseline}"
URL="${2:-http://127.0.0.1:8080/api/datos?id=1}"
CONCURRENCY="${3:-40}"
REQUESTS="${4:-1500}"
REPS="${5:-3}"

if [ "$REPS" -lt 3 ]; then
  echo "[load] Error: se exigen al menos 3 repeticiones (REPS=$REPS)." >&2
  exit 1
fi

echo "[load] Escenario=${SCENARIO} | URL=${URL} | c=${CONCURRENCY} | n=${REQUESTS} | reps=${REPS}"

# TODO [Rol 5]: Implementar bucle de >=3 repeticiones usando 'hey' (o 'wrk')
# y exportar resultados por repeticion a ${LOGS_DIR}/load_${SCENARIO}.csv

# TODO [Rol 5]: Durante cada repeticion, capturar en paralelo:
#   - iostat -dx (para medir await y %util del disco)
#   - lecturas de cgroups v2 (/sys/fs/cgroup/...): cpu.stat (nr_throttled), memory.current, pids.current

# TODO [Rol 5]: Calcular promedio de RPS, latencia promedio, p99 promedio/maximo y errores totales con awk/bc

# TODO [Rol 5]: Ejecutar tambien 'redis-benchmark' (>=3 repeticiones) para perfilar la capa de cache
echo "[load] TODO: completar implementacion de Rol 5."
