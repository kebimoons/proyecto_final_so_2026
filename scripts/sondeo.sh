#!/usr/bin/env bash
# ==============================================================================
# sondeo.sh - [ESQUELETO: Rol 6 (Ingeniero de Caos, Failover HA y Documentacion)]
# Monitoreo continuo HTTP/BD cada 100ms durante failover y calculo exacto de MTTR.
# Uso previsto: ./scripts/sondeo.sh <escenario> [DURACION_SEG] [URL]
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGS_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOGS_DIR"

SCENARIO="${1:-failover}"
DURATION="${2:-20}"
URL="${3:-http://127.0.0.1:8080/api/datos?id=1}"

echo "[sondeo] Escenario=${SCENARIO} | Duracion=${DURATION}s | URL=${URL}"

# TODO [Rol 6]: Implementar bucle cada 100ms (sleep 0.1) usando 'curl' con timeout corto
# registrando en ${LOGS_DIR}/sondeo_${SCENARIO}.csv:
#   timestamp_ms, elapsed_ms, http_code, latencia_ms, contenedor, origen (redis/mysql)

# TODO [Rol 6]: Al finalizar la ventana, calcular con awk:
#   - Total de sondas, respuestas HTTP 200, errores (!=200) y % disponibilidad
#   - MTTR maximo observado (ms desde el primer fallo hasta recuperacion sostenida HTTP 200)
#   y guardar resumen en ${LOGS_DIR}/mttr_${SCENARIO}.txt
echo "[sondeo] TODO: completar implementacion de Rol 6."
