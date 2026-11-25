#!/usr/bin/env bash
# ==============================================================================
# load.sh - Rol 5 (Ingeniero de Carga y Cuellos de Botella)
# Ejecuta pruebas de carga con >=3 repeticiones, calcula promedio y p50/p95/p99
# con awk, y recolecta en paralelo metricas de cgroups v2 e iostat -dx.
#
# Uso:
#   ./scripts/load.sh <escenario> [URL] [CONCURRENCIA] [PETICIONES] [REPS]
#   ./scripts/load.sh --ficha            # ficha de la VM para la Tabla 3.1
#
# Ejemplos (Exp. 5.2):
#   ./scripts/stack_up.sh 1
#   ./scripts/load.sh exp52_1rep "http://127.0.0.1:8080/api/datos?id=1&work=12000" 40 1200 3
#   ./scripts/stack_up.sh 3
#   ./scripts/load.sh exp52_3rep "http://127.0.0.1:8080/api/datos?id=1&work=12000" 40 1200 3
#
# Variables opcionales:
#   CONTAINERS="app-1 nginx-lb"  contenedores a medir (por defecto: app-*, nginx-lb,
#                                nginx-assets, redis-master, mysql-master que esten corriendo)
#   DISK=sda                     disco para iostat (por defecto: el disco de /)
#   COOLDOWN=5                   segundos de pausa entre repeticiones
#   REDIS_BENCH=auto|1|0         redis-benchmark (auto: solo si redis-master esta corriendo)
#   REDIS_N=50000 REDIS_C=50     peticiones y clientes de redis-benchmark
#
# Salidas en logs/ (los .csv y .txt se versionan; los .log crudos no):
#   load_<esc>.csv        una fila por repeticion: RPS, latencia prom., p50, p95, p99, errores
#   cgroups_<esc>.csv     por repeticion y contenedor: deltas de cpu.stat y maximos de memoria/pids
#   cg_samples_<esc>.csv  muestreo cada 1 s de memory.current y pids.current
#   iostat_<esc>.csv      por repeticion: r_await, w_await y %util del disco (de /proc/diskstats)
#   redis_bench_<esc>.csv redis-benchmark por repeticion (si aplica)
#   resumen_<esc>.txt     promedios listos para las Tablas 5.3 y 5.4 del informe
# ==============================================================================
set -euo pipefail
# Numeros con punto decimal en awk/printf aunque Ubuntu este en espanol (es_* usa coma)
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGS_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOGS_DIR"

log() { echo "[load] $*"; }
die() { echo "[load] Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Disco donde vive / (sda, nvme0n1, vda...)
# ------------------------------------------------------------------------------
root_disk() {
  local src pk
  src="$(findmnt -no SOURCE / 2>/dev/null || true)"
  pk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)"
  if [ -n "$pk" ]; then echo "$pk"; else lsblk -dno NAME 2>/dev/null | grep -v '^loop' | head -n1; fi
}

# ==============================================================================
# Modo --ficha: datos de la VM para la Tabla 3.1
# ==============================================================================
if [ "${1:-}" = "--ficha" ]; then
  OUT="${LOGS_DIR}/ficha_vm_$(hostname)_$(date +%Y%m%d).txt"
  D="$(root_disk)"
  {
    echo "# Ficha de la VM de medicion - $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "## Hipervisor y distribucion"
    echo "hipervisor: $(systemd-detect-virt 2>/dev/null || echo desconocido)"
    (lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release) | sed 's/^/distro: /'
    echo "## Kernel (uname -r)"
    uname -r
    echo "## vCPU (nproc) y modelo"
    echo "nproc: $(nproc)"
    lscpu | grep -E '^(Model name|Nombre del modelo|Thread|Hilo|Hypervisor|Fabricante del hipervisor)' || true
    echo "## RAM y swap (free -h)"
    free -h
    swapon --show 2>/dev/null || true
    echo "## Disco y planificador"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,ROTA,MOUNTPOINT
    echo "disco de /: ${D}"
    echo "planificador: $(cat /sys/block/${D}/queue/scheduler 2>/dev/null || echo n/d)"
    echo "rotacional (0 = SSD): $(cat /sys/block/${D}/queue/rotational 2>/dev/null || echo n/d)"
    df -hT /
    df -i /
    echo "## cgroups (stat -fc %T /sys/fs/cgroup)"
    stat -fc %T /sys/fs/cgroup
    echo "## Docker y herramientas"
    docker version --format 'docker server {{.Server.Version}}' 2>/dev/null || echo "docker: no disponible"
    docker info 2>/dev/null | grep -E 'Cgroup Driver|Cgroup Version|Storage Driver' || true
    command -v hey >/dev/null && echo "hey: $(dpkg-query -W -f='${Version}' hey 2>/dev/null || echo instalado)"
    command -v wrk >/dev/null && echo "wrk: $(wrk -v 2>&1 | head -n1)"
    command -v iostat >/dev/null && echo "sysstat: $(iostat -V 2>&1 | head -n1)"
    command -v redis-benchmark >/dev/null && echo "redis-benchmark: $(redis-benchmark --version 2>/dev/null || echo instalado)"
    echo "## Commit de dev usado"
    git -C "$ROOT_DIR" log -1 --format='%h %s (%ci)' 2>/dev/null || echo "n/d"
  } | tee "$OUT"
  log "Ficha guardada en ${OUT}"
  exit 0
fi

# ==============================================================================
# Parametros
# ==============================================================================
SCENARIO="${1:-baseline}"
URL="${2:-http://127.0.0.1:8080/api/datos?id=1}"
CONCURRENCY="${3:-40}"
REQUESTS="${4:-1500}"
REPS="${5:-3}"
COOLDOWN="${COOLDOWN:-5}"
REDIS_BENCH="${REDIS_BENCH:-auto}"
REDIS_N="${REDIS_N:-50000}"
REDIS_C="${REDIS_C:-50}"
DISK="${DISK:-$(root_disk)}"

[[ "$SCENARIO" =~ ^[A-Za-z0-9_.-]+$ ]] || die "nombre de escenario invalido: '$SCENARIO' (usa letras, numeros, _ . -)"
[[ "$REPS" =~ ^[0-9]+$ ]] || die "REPS debe ser un numero"
[ "$REPS" -ge 3 ] || die "se exigen al menos 3 repeticiones (REPS=$REPS)."
command -v hey >/dev/null 2>&1 || die "'hey' no esta instalado (corre ./scripts/setup_env.sh)."
command -v awk >/dev/null 2>&1 || die "falta awk."

HAVE_IOSTAT=1; command -v iostat >/dev/null 2>&1 || { HAVE_IOSTAT=0; log "AVISO: iostat no esta instalado (paquete sysstat); se omite E/S."; }
HAVE_DOCKER=1; docker info >/dev/null 2>&1 || { HAVE_DOCKER=0; log "AVISO: sin acceso a Docker; se omiten cgroups."; }

CSV_LOAD="${LOGS_DIR}/load_${SCENARIO}.csv"
CSV_CG="${LOGS_DIR}/cgroups_${SCENARIO}.csv"
CSV_SAMPLES="${LOGS_DIR}/cg_samples_${SCENARIO}.csv"
CSV_IO="${LOGS_DIR}/iostat_${SCENARIO}.csv"
CSV_REDIS="${LOGS_DIR}/redis_bench_${SCENARIO}.csv"
RESUMEN="${LOGS_DIR}/resumen_${SCENARIO}.txt"
TMP_DIR="$(mktemp -d)"
SAMPLER_PID=""; IOSTAT_PID=""

cleanup_bg() {
  [ -n "$SAMPLER_PID" ] && kill "$SAMPLER_PID" 2>/dev/null || true
  [ -n "$IOSTAT_PID" ] && kill "$IOSTAT_PID" 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup_bg EXIT

# Cada corrida del mismo escenario reemplaza la anterior (un escenario = una corrida)
echo "escenario,rep,inicio,url,concurrencia,peticiones,ok_2xx,errores,duracion_s,rps,lat_prom_ms,p50_ms,p95_ms,p99_ms,lat_max_ms" > "$CSV_LOAD"
echo "escenario,rep,contenedor,nr_periods,nr_throttled,throttled_usec,usage_usec,memory_current_max,memory_current_fin,pids_current_max,cpu_max" > "$CSV_CG"
echo "escenario,rep,epoch_ms,contenedor,memory_current,pids_current" > "$CSV_SAMPLES"
echo "escenario,rep,disco,duracion_s,r_ios,w_ios,r_await_ms,w_await_ms,util_pct,iostat_muestras,iostat_util_max_pct" > "$CSV_IO"

log "Escenario=${SCENARIO} | URL=${URL} | c=${CONCURRENCY} | n=${REQUESTS} | reps=${REPS} | disco=${DISK}"
log "Commit: $(git -C "$ROOT_DIR" log -1 --format=%h 2>/dev/null || echo n/d) | Host: $(hostname) | Kernel: $(uname -r)"

# ------------------------------------------------------------------------------
# Comprobacion previa del endpoint
# ------------------------------------------------------------------------------
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" || true)"
[ "$code" = "200" ] || log "AVISO: ${URL} respondio HTTP '${code:-sin respuesta}'. ¿Corriste stack_up.sh?"

# ------------------------------------------------------------------------------
# Contenedores y su cgroup v2
# ------------------------------------------------------------------------------
declare -A CG_PATH=()
if [ "$HAVE_DOCKER" -eq 1 ]; then
  if [ -n "${CONTAINERS:-}" ]; then
    read -r -a CLIST <<< "$CONTAINERS"
  else
    mapfile -t CLIST < <(docker ps --format '{{.Names}}' | grep -E '^(app-[0-9]+|nginx-lb|nginx-assets|redis-master|mysql-master)$' | sort -V || true)
  fi
  for c in "${CLIST[@]}"; do
    cid="$(docker inspect -f '{{.Id}}' "$c" 2>/dev/null || true)"
    [ -n "$cid" ] || { log "AVISO: contenedor '$c' no existe; se omite."; continue; }
    p=""
    for cand in "/sys/fs/cgroup/system.slice/docker-${cid}.scope" "/sys/fs/cgroup/docker/${cid}"; do
      [ -f "${cand}/cpu.stat" ] && { p="$cand"; break; }
    done
    [ -n "$p" ] || p="$(find /sys/fs/cgroup -maxdepth 4 -type d -name "*${cid}*" 2>/dev/null | head -n1)"
    if [ -n "$p" ]; then CG_PATH["$c"]="$p"; else log "AVISO: no se encontro el cgroup de '$c'."; fi
  done
  log "Contenedores medidos: ${#CG_PATH[@]} (${!CG_PATH[*]})"
fi

# Contadores del disco en /proc/diskstats (los mismos que usa iostat):
# rd_ios rd_ticks wr_ios wr_ticks io_ticks (ticks en ms)
disk_snap() { awk -v d="$DISK" '$3==d {print $4, $7, $8, $11, $13; f=1} END {if(!f) print "0 0 0 0 0"}' /proc/diskstats; }

cpu_field() { awk -v k="$2" '$1==k {print $2; f=1} END {if(!f) print 0}' "$1/cpu.stat" 2>/dev/null || echo 0; }
read_or_na() { cat "$1" 2>/dev/null || echo "n/d"; }

snapshot_cpu() {  # $1 = before|after
  local c p
  for c in "${!CG_PATH[@]}"; do
    p="${CG_PATH[$c]}"
    echo "$c $(cpu_field "$p" nr_periods) $(cpu_field "$p" nr_throttled) $(cpu_field "$p" throttled_usec) $(cpu_field "$p" usage_usec)"
  done > "${TMP_DIR}/cpu_$1"
}

sampler() {  # $1 = rep ; muestrea memory.current y pids.current cada 1 s
  local rep="$1" c p now
  while :; do
    now="$(date +%s%3N)"
    for c in "${!CG_PATH[@]}"; do
      p="${CG_PATH[$c]}"
      echo "${SCENARIO},${rep},${now},${c},$(read_or_na "$p/memory.current"),$(read_or_na "$p/pids.current")"
    done >> "$CSV_SAMPLES"
    sleep 1
  done
}

# ------------------------------------------------------------------------------
# Repeticiones
# ------------------------------------------------------------------------------
for rep in $(seq 1 "$REPS"); do
  log "---- Repeticion ${rep}/${REPS} ----"
  RAW="${LOGS_DIR}/hey_${SCENARIO}_r${rep}.log"
  IORAW="${LOGS_DIR}/iostat_${SCENARIO}_r${rep}.log"
  START_ISO="$(date '+%Y-%m-%dT%H:%M:%S%z')"

  snapshot_cpu before
  if [ "${#CG_PATH[@]}" -gt 0 ]; then sampler "$rep" & SAMPLER_PID=$!; fi
  if [ "$HAVE_IOSTAT" -eq 1 ]; then
    # stdbuf -oL: sin esto iostat guarda su salida en buffer y se pierde al matarlo
    stdbuf -oL iostat -dx -y "$DISK" 1 > "$IORAW" 2>&1 & IOSTAT_PID=$!
  fi

  DS0="$(disk_snap)"
  t0="$(date +%s%N)"
  hey -n "$REQUESTS" -c "$CONCURRENCY" -t 20 -o csv "$URL" > "$RAW" 2>"${TMP_DIR}/hey_err" || log "AVISO: hey termino con error (ver ${TMP_DIR}/hey_err)"
  t1="$(date +%s%N)"
  DS1="$(disk_snap)"

  [ -n "$IOSTAT_PID" ] && { kill "$IOSTAT_PID" 2>/dev/null || true; wait "$IOSTAT_PID" 2>/dev/null || true; IOSTAT_PID=""; }
  [ -n "$SAMPLER_PID" ] && { kill "$SAMPLER_PID" 2>/dev/null || true; wait "$SAMPLER_PID" 2>/dev/null || true; SAMPLER_PID=""; }
  snapshot_cpu after

  # --- Latencias: hey -o csv da una fila por peticion completada (response-time en s, status-code).
  #     Las peticiones que fallaron por conexion/timeout no aparecen: se cuentan como errores.
  DUR_S="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f",(b-a)/1e9}')"
  awk -F, 'NR>1 && $1+0>0 {print $1*1000, $7}' "$RAW" | sort -n -k1,1 > "${TMP_DIR}/lat"
  ROW="$(awk -v n_req="$REQUESTS" -v dur="$DUR_S" '
    function pct(p,  i){ i=int(p*n); if (i<p*n) i++; if (i<1) i=1; return lat[i] }
    { n++; lat[n]=$1; sum+=$1; if ($2>=200 && $2<300) ok++ }
    END {
      if (n==0) { printf "0,%d,%s,0,0,0,0,0,0", n_req, dur; exit }
      err = n_req - ok
      printf "%d,%d,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f", ok, err, dur, n/dur, sum/n, pct(0.50), pct(0.95), pct(0.99), lat[n]
    }' "${TMP_DIR}/lat")"
  echo "${SCENARIO},${rep},${START_ISO},\"${URL}\",${CONCURRENCY},${REQUESTS},${ROW}" >> "$CSV_LOAD"
  IFS=, read -r _ err _ rps avg p50 p95 p99 _ <<< "$ROW"
  log "rep ${rep}: ${rps} req/s | prom ${avg} ms | p50 ${p50} | p95 ${p95} | p99 ${p99} ms | errores ${err}/${REQUESTS}"

  # --- cgroups: delta de cpu.stat y maximos del muestreo
  for c in "${!CG_PATH[@]}"; do
    read -r _ a_per a_thr a_tus a_use < <(grep "^${c} " "${TMP_DIR}/cpu_before")
    read -r _ b_per b_thr b_tus b_use < <(grep "^${c} " "${TMP_DIR}/cpu_after")
    p="${CG_PATH[$c]}"
    memmax="$(awk -F, -v c="$c" -v r="$rep" '$2==r && $4==c && $5+0>m {m=$5+0} END{print m+0}' "$CSV_SAMPLES")"
    pidmax="$(awk -F, -v c="$c" -v r="$rep" '$2==r && $4==c && $6+0>m {m=$6+0} END{print m+0}' "$CSV_SAMPLES")"
    echo "${SCENARIO},${rep},${c},$((b_per-a_per)),$((b_thr-a_thr)),$((b_tus-a_tus)),$((b_use-a_use)),${memmax},$(read_or_na "$p/memory.current"),${pidmax},\"$(read_or_na "$p/cpu.max")\"" >> "$CSV_CG"
  done

  # --- Disco: deltas de /proc/diskstats durante la repeticion (r_await, w_await y %util
  #     igual que iostat -dx, pero sobre toda la ventana, aunque dure menos de 1 s).
  #     El log crudo de iostat queda en logs/iostat_<esc>_r<N>.log como respaldo.
  ios_n="0"; ios_umax="n/d"
  if [ "$HAVE_IOSTAT" -eq 1 ] && [ -f "$IORAW" ]; then
    read -r ios_n ios_umax < <(awk -v d="$DISK" '
      /^Device/ { for (i=1;i<=NF;i++) { h=$i; sub(":","",h); col[h]=i } next }
      $1==d && ("%util" in col) { n++; u=$(col["%util"]); if (u>mu) mu=u }
      END { if (n) printf "%d %.2f\n", n, mu; else print "0 n/d" }' "$IORAW")
  fi
  awk -v s="$SCENARIO" -v r="$rep" -v d="$DISK" -v dur="$DUR_S" -v a="$DS0" -v b="$DS1" -v n="$ios_n" -v um="$ios_umax" 'BEGIN {
      split(a, x, " "); split(b, y, " ")
      rio=y[1]-x[1]; rt=y[2]-x[2]; wio=y[3]-x[3]; wt=y[4]-x[4]; busy=y[5]-x[5]
      ra = rio>0 ? rt/rio : 0; wa = wio>0 ? wt/wio : 0
      ut = dur>0 ? 100*busy/(dur*1000) : 0; if (ut>100) ut=100
      printf "%s,%s,%s,%s,%d,%d,%.2f,%.2f,%.2f,%s,%s\n", s, r, d, dur, rio, wio, ra, wa, ut, n, um }' >> "$CSV_IO"

  [ "$rep" -lt "$REPS" ] && sleep "$COOLDOWN"
done

# ------------------------------------------------------------------------------
# redis-benchmark (>=3 repeticiones) contra redis-master, desde el host
# ------------------------------------------------------------------------------
if [ "$REDIS_BENCH" != "0" ] && [ "$HAVE_DOCKER" -eq 1 ] && command -v redis-benchmark >/dev/null 2>&1 \
   && docker ps --format '{{.Names}}' | grep -qx redis-master; then
  RIP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' redis-master | awk '{print $1}')"
  log "redis-benchmark contra redis-master (${RIP}:6379), n=${REDIS_N}, c=${REDIS_C}"
  echo "escenario,rep,test,rps,avg_latency_ms,min_latency_ms,p50_latency_ms,p95_latency_ms,p99_latency_ms,max_latency_ms" > "$CSV_REDIS"
  for rep in $(seq 1 "$REPS"); do
    redis-benchmark -h "$RIP" -p 6379 -t set,get -n "$REDIS_N" -c "$REDIS_C" --csv 2>/dev/null \
      | tr -d '"' | awk -F, -v s="$SCENARIO" -v r="$rep" 'NR>1 && NF>=8 {print s","r","$0}' >> "$CSV_REDIS"
    sleep 2
  done
elif [ "$REDIS_BENCH" = "1" ]; then
  log "AVISO: REDIS_BENCH=1 pero redis-master no esta corriendo o falta redis-benchmark."
fi

# ------------------------------------------------------------------------------
# Resumen para el informe (Tablas 5.3 y 5.4)
# ------------------------------------------------------------------------------
{
  echo "# Resumen ${SCENARIO} - $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "host=$(hostname) kernel=$(uname -r) commit=$(git -C "$ROOT_DIR" log -1 --format=%h 2>/dev/null || echo n/d)"
  echo "url=${URL} c=${CONCURRENCY} n=${REQUESTS} reps=${REPS}"
  echo ""
  echo "## Tabla 5.3 - carga HTTP (hey)"
  printf "%-10s %10s %12s %10s %10s %10s %8s\n" "rep" "req/s" "prom_ms" "p50_ms" "p95_ms" "p99_ms" "errores"
  awk -F, 'NR>1 {
      printf "%-10s %10s %12s %10s %10s %10s %8s\n", $2, $10, $11, $12, $13, $14, $8
      n++; rps+=$10; avg+=$11; p50+=$12; p95+=$13; p99+=$14; err+=$8; if ($14>mx) mx=$14
    }
    END { if (n) {
      printf "%-10s %10.2f %12.2f %10.2f %10.2f %10.2f %8d\n", "Promedio", rps/n, avg/n, p50/n, p95/n, p99/n, err
      printf "p99 maximo entre repeticiones: %.2f ms | errores totales: %d\n", mx, err } }' \
    <(sed 's/"[^"]*"/URL/' "$CSV_LOAD")
  if [ "$(wc -l < "$CSV_CG")" -gt 1 ]; then
    echo ""
    echo "## Tabla 5.4 - cgroups v2 (suma de deltas en las ${REPS} reps; memoria y pids = maximo observado)"
    printf "%-14s %12s %16s %14s %10s %s\n" "contenedor" "nr_throttled" "throttled_usec" "memory_max_MiB" "pids_max" "cpu.max"
    awk -F, 'NR>1 { c=$3; thr[c]+=$5; tus[c]+=$6; if ($8>mem[c]) mem[c]=$8; if ($10>pid[c]) pid[c]=$10; cm[c]=$11 }
      END { for (c in thr) printf "%-14s %12d %16d %14.1f %10d %s\n", c, thr[c], tus[c], mem[c]/1048576, pid[c], cm[c] }' "$CSV_CG" | sort -V
  fi
  echo ""
  echo "## Disco ${DISK} (deltas de /proc/diskstats por rep, como iostat -dx)"
  printf "%-10s %8s %8s %12s %12s %8s\n" "rep" "r_ios" "w_ios" "r_await_ms" "w_await_ms" "%util"
  awk -F, 'NR>1 { printf "%-10s %8d %8d %12.2f %12.2f %8.2f\n", $2, $5, $6, $7, $8, $9
                  n++; ra+=$7; wa+=$8; u+=$9; if ($9>mu) mu=$9 }
    END { if (n) printf "%-10s %8s %8s %12.2f %12.2f %8.2f  (%%util max %.2f)\n", "Promedio", "", "", ra/n, wa/n, u/n, mu }' "$CSV_IO"
  if [ -f "$CSV_REDIS" ] && [ "$(wc -l < "$CSV_REDIS")" -gt 1 ]; then
    echo ""
    echo "## redis-benchmark (promedio de las reps)"
    awk -F, 'NR>1 { t=$3; n[t]++; r[t]+=$4; p[t]+=$9 }
      END { for (t in n) printf "%-6s %12.0f req/s   p99=%.3f ms\n", t, r[t]/n[t], p[t]/n[t] }' "$CSV_REDIS"
  fi
} | tee "$RESUMEN"

log "Listo. CSV en logs/: $(basename "$CSV_LOAD"), $(basename "$CSV_CG"), $(basename "$CSV_IO"), $(basename "$RESUMEN")"
