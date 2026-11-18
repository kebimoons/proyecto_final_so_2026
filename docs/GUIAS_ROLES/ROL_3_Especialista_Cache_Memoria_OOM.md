# Guía Individual — Rol 3: Especialista en Caché HA y Gestión de Memoria

## 1. Archivos de los que eres Dueño
- `scripts/cache_up.sh`
- `config/redis/redis_master.conf`
- `config/redis/redis_replica.conf`
- `config/redis/sentinel.conf`

## 2. Flujo de Trabajo en tu Rama Git
```bash
git checkout dev && git pull origin dev
git checkout feat/rol-3-redis-memoria-oom

./scripts/setup_env.sh --rol 3 --nombre tu_alias

# 1. Completa los TODO [Rol 3] en config/redis/*.conf y scripts/cache_up.sh:
#    - redis-master y redis-replica con --oom-score-adj=400 y volumenes /data
#    - 3 nodos redis-sentinel con directorios escribibles, resolve-hostnames yes y quorum=2
# 2. Coordina con Rol 6 las pruebas de memory.high + PSI vs memory.max + OOM Killer (Exp. 5.3).

git add config/redis/ scripts/cache_up.sh evidencias/
git commit -m "feat(rol-3): configurar Redis HA con 3 Sentinels y pruebas OOM/PSI"
```

## 3. Comandos del Kernel a Ejecutar y Capturar (con tu `PS1`)
```bash
export PS1="grupo1sf134-rol3-tu_nombre@so-ha-prod:\w\$ "
```

* **Módulo I (Hilos fijos de Redis: `--io-threads` + `bio_*`):**
  ```bash
  PID_RED=$(docker inspect -f '{{.State.Pid}}' redis-master)
  ps -L -p "$PID_RED" -o pid,tid,comm
  ls /proc/${PID_RED}/task
  ```
* **Módulo II / Experimento 5.3 (`memory.high` + PSI vs `memory.max` + OOM Killer):**
  ```bash
  cat "/proc/${PID_RED}/oom_score_adj"   # Debe mostrar 400
  # Degradacion controlada (memory.high):
  ./scripts/falla.sh oom_high
  cat /proc/pressure/memory

  # Muerte por limite duro (memory.max):
  ./scripts/falla.sh oom_max
  docker inspect -f 'Running={{.State.Running}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}}' redis-master
  dmesg -T | grep -i -E 'oom|killed' | tail -n 15
  ```
Guarda tus capturas en `evidencias/rol3_exp51_redis_threads.png`, `evidencias/rol3_exp53_memory_high_psi.png` y `evidencias/rol3_exp53_memory_max_oom_dmesg.png`.

## 4. Las 3 Preguntas Más Probables en Sustentación
1. **¿Qué diferencia hay en cgroups v2 entre superar `memory.high` y superar `memory.max`?**
   `memory.high` aplica estrangulamiento (*throttling*) y reclamo directo de memoria (*direct reclaim*), elevando las métricas PSI (`/proc/pressure/memory`) y la latencia `p99`, pero el proceso sobrevive. `memory.max` es un techo estricto: si no hay memoria liberable ni swap disponible, el kernel invoca al OOM Killer (`SIGKILL`, código de salida 137).
2. **¿Por qué Redis tiene `oom_score_adj = +400` y MySQL tiene `-800`?**
   En caso de escasez global de memoria en el host, el OOM Killer prioriza matar al proceso con mayor puntaje. Como Redis es caché volátil reconstruible desde la BD y MySQL guarda el estado persistente, sacrificamos antes a Redis (`+400`) para proteger a MySQL (`-800`).
3. **¿Por qué desplegar 3 instancias de Redis Sentinel con `quorum = 2` en vez de 1 o 2?**
   Un único Sentinel es un punto único de fallo; 2 Sentinels no pueden desempatar si se parte la red. Con 3 Sentinels y `quorum 2` se requiere mayoría real (2 de 3) para declarar un primario caído (`ODOWN`) y evitar *split-brain*.
