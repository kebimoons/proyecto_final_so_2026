# Guía Individual — Rol 1: Arquitecto de Entrada, Balanceo y Page Cache

## 1. Archivos de los que eres Dueño
- `scripts/stack_up.sh` (red `ha-net`, `nginx-assets` y `nginx-lb`)
- `config/nginx/nginx_lb.conf`
- `config/nginx/nginx_assets.conf`

## 2. Flujo de Trabajo en tu Rama Git
```bash
git checkout dev && git pull origin dev
git checkout feat/rol-1-nginx-lb-assets

# 1. En tu VM Linux, prepara el entorno si aun no lo hiciste:
./scripts/setup_env.sh --rol 1 --nombre tu_alias

# 2. Completa los TODO [Rol 1] en:
#    - config/nginx/nginx_lb.conf (least_conn, max_fails=1 fail_timeout=3s, proxy_next_upstream)
#    - config/nginx/nginx_assets.conf (sendfile on, open_file_cache, Cache-Control)
#    - scripts/stack_up.sh (red ha-net, docker run para nginx-assets y nginx-lb con limites cgroups v2 y oom_score_adj)

# 3. Guarda tus cambios con commits atomicos:
git add config/nginx/ scripts/stack_up.sh evidencias/
git commit -m "feat(rol-1): configurar nginx-lb, nginx-assets y evidencia Page Cache"
```

## 3. Comandos del Kernel a Ejecutar y Capturar (con tu `PS1`)
Activa tu prompt antes de capturar:
```bash
export PS1="grupo1il143-rol1-tu_nombre@so-ha-prod:\w\$ "
```

* **Módulo I (`worker_processes` fijos vs vCPUs):**
  ```bash
  nproc
  PID_LB=$(docker inspect -f '{{.State.Pid}}' nginx-lb)
  ps -L -p "$PID_LB" -o pid,tid,psr,comm
  docker exec nginx-lb ps -o pid,ppid,comm
  ```
* **Módulo II (`cgroups v2` y `--oom-score-adj`):**
  ```bash
  CID_LB=$(docker inspect -f '{{.Id}}' nginx-lb)
  CG_LB=$(find /sys/fs/cgroup -name "*${CID_LB}*" -type d | head -n 1)
  cat "${CG_LB}/cpu.max" "${CG_LB}/memory.max" "${CG_LB}/pids.max"
  cat "/proc/${PID_LB}/oom_score_adj"   # Debe ser -700 en nginx-lb y +200 en nginx-assets
  ```
* **Módulo III (Page Cache y `sendfile`):**
  ```bash
  grep -E 'MemTotal|MemFree|Buffers|Cached' /proc/meminfo
  hey -n 40 -c 5 http://127.0.0.1:8080/assets/payload.bin >/dev/null
  free -h
  ```
Guarda tu captura en `evidencias/rol1_exp51_nginx_workers_pagecache.png`.

## 4. Las 3 Preguntas Más Probables en Sustentación
1. **¿Por qué `nginx-lb` mantiene exactamente `worker_processes` fijos aunque entren cientos de peticiones simultáneas?**
   Porque Nginx utiliza un bucle de eventos asíncronos no bloqueantes (`epoll` en Linux) donde cada proceso worker multiplexa miles de descriptores de socket en un único hilo, evitando el costo de crear hilos por conexión y reduciendo cambios de contexto.
2. **¿Cómo garantiza `nginx-lb` que el cliente reciba 0 errores cuando se cae `app-1` en medio del tráfico?**
   Combinando healthchecks pasivos (`max_fails=1 fail_timeout=3s`) con `proxy_connect_timeout 500ms` y `proxy_next_upstream error timeout http_502 http_503 http_504;`. Si una réplica falla o corta la conexión, Nginx reintenta la petición en otra réplica sana antes de responder al cliente.
3. **¿Cómo interactúa `sendfile on` con la Page Cache del sistema operativo en `nginx-assets`?**
   `sendfile()` permite que el kernel transfiera bloques directamente desde la Page Cache (`Cached` en `/proc/meminfo`) hacia el buffer del socket de red sin copiar los datos al espacio de usuario, eliminando copias redundantes en RAM y lecturas repetidas a disco.
