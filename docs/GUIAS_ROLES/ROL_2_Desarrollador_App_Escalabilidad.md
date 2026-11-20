# Guía Individual — Rol 2: Desarrollador de App y Escalabilidad Horizontal

## 1. Archivos de los que eres Dueño
- `app/server.js`
- `app/Dockerfile`
- `app/package.json`
- `scripts/stack_up.sh` (despliegue y escalado `app-1` .. `app-N`)

## 2. Flujo de Trabajo en tu Rama Git
```bash
git checkout dev && git pull origin dev
git checkout feat/rol-2-app-escalabilidad

./scripts/setup_env.sh --rol 2 --nombre tu_alias

# 1. Completa los TODO [Rol 2] en app/server.js:
#    - cluster.fork() con APP_WORKERS y reinicio ante salida de worker
#    - UV_THREADPOOL_SIZE=4 + crypto.pbkdf2 para carga CPU controlada (?work=N)
#    - Cache-Aside con ioredis (3 Sentinels) y degradacion elegante a MySQL
#    - Failover automatico entre mysql-master y mysql-replica en lectura/escritura
# 2. Completa la seccion de replicas App en scripts/stack_up.sh (--cpus, --memory, --pids-limit, --oom-score-adj=0).

git add app/ scripts/stack_up.sh evidencias/
git commit -m "feat(rol-2): implementar API clusterizada y escalamiento horizontal"
```

## 3. Comandos del Kernel a Ejecutar y Capturar (con tu `PS1`)
```bash
export PS1="grupo1il143-rol2-tu_nombre@so-ha-prod:\w\$ "
```

* **Módulo I (`cluster` + hilos `libuv` en `/proc/<PID>/task` y `top -H`):**
  ```bash
  PID_APP=$(docker inspect -f '{{.State.Pid}}' app-1)
  docker exec app-1 ps -o pid,ppid,comm
  ls /proc/${PID_APP}/task
  top -H -b -n 1 -p "$PID_APP"
  ```
* **Experimento 5.2 (Crecimiento Horizontal: 1 vs 3 Réplicas):**
  ```bash
  ./scripts/stack_up.sh 1 --build
  ./scripts/load.sh escala_1rep "http://127.0.0.1:8080/api/datos?id=1&work=12000" 40 1200 3
  ./scripts/stack_up.sh 3
  ./scripts/load.sh escala_3rep "http://127.0.0.1:8080/api/datos?id=1&work=12000" 40 1200 3
  ```
Guarda tus capturas en `evidencias/rol2_exp51_node_cluster_threads.png` y `evidencias/rol2_exp52_1rep_vs_3rep_top_h.png`.

## 4. Las 3 Preguntas Más Probables en Sustentación
1. **¿Qué diferencia existe entre `cluster.fork()` y `UV_THREADPOOL_SIZE` en Node.js?**
   `cluster.fork()` crea procesos independientes del kernel (cada uno con su PID, su memoria y su propio Event Loop V8) para escalar en múltiples núcleos. `UV_THREADPOOL_SIZE` define el número fijo de hilos POSIX (`pthreads`) dentro de cada proceso usados por `libuv` para operaciones bloqueantes (como `crypto.pbkdf2`, E/S de archivos o `dns.lookup`).
2. **¿Por qué al pasar de 1 a 3 réplicas cae drásticamente la latencia `p99`?**
   Con 1 réplica limitada a `--cpus=1.0`, la carga en CPU satura la cuota CFS (`nr_throttled` sube en `cpu.stat`) y las peticiones se encolan. Con 3 réplicas, el balanceador reparte la concurrencia entre 3 cgroups independientes de CPU, reduciendo el encolamiento y el `p99`.
3. **¿Cómo evita `server.js` devolver HTTP 500 mientras Redis Sentinel promueve una réplica?**
   Configurando `enableOfflineQueue: false` y `commandTimeout` corto en `ioredis`, y capturando la excepción en `try/catch` para consultar directamente a MySQL durante los segundos que dura la promoción (degradación elegante del patrón Cache-Aside).
