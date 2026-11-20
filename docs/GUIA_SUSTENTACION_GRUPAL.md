# Guía Integral de Sustentación Grupal — Proyecto HA (Grupo 1IL143)

**Curso:** Sistemas Operativos (0689) · **Docente:** Isacio Manuel Tamayo Rodríguez · **Entrega:** 5 de diciembre de 2026

> **Dinámica de defensa:** Cada integrante debe dominar su rol y comprender el sistema completo. El docente podrá realizar **1 pregunta aleatoria de cada módulo (Módulos I, II y III)** sobre el comportamiento real en Linux.

---

## 1. Flujo Extremo a Extremo de los 5 Servicios

1. **Entrada y Balanceo (`nginx-lb` — Rol 1):** Recibe tráfico en `:8080`.
   - `/assets/*` se delega a `nginx-assets`, que responde mediante `sendfile on` directamente desde la **Page Cache** del kernel.
   - `/api/*` y `/health` se reparten entre `app-1..app-N` con `least_conn`. Si una réplica falla, `max_fails=1 fail_timeout=3s` y `proxy_next_upstream` reenvían la petición a otra réplica sana sin error para el cliente.
2. **Aplicación (`app-1..N` — Rol 2):** API Node.js con `cluster` (procesos worker) y `UV_THREADPOOL_SIZE` (hilos `libuv`). Implementa **Cache-Aside**: consulta primero a Redis Sentinel; si hay *hit*, responde de inmediato; si hay *miss* o Redis está en failover, consulta MySQL (`mysql-master` con fallback a `mysql-replica`).
3. **Caché HA (`redis-master`, `redis-replica`, `3x redis-sentinel` — Rol 3):** Replicación asíncrona de caché y monitoreo por quórum (`quorum 2`). Si `redis-master` cae, Sentinel promueve automáticamente a `redis-replica`.
4. **Persistencia Transaccional (`mysql-master`, `mysql-replica` — Rol 4):** Replicación basada en **GTID** sobre volúmenes Docker persistentes (`ext4`), con durabilidad estricta (`sync_binlog=1`, `innodb_flush_log_at_trx_commit=1`, `O_DIRECT`).
5. **Control del Kernel (`cgroups v2` y `oom_score_adj`):** Todos los contenedores ejecutan `docker run` con cuotas explícitas (`--cpus`, `--memory`, `--memory-reservation`, `--pids-limit`) y jerarquía OOM (`MySQL Primario -800` < `Nginx LB -700` < `MySQL Réplica -500` < `App 0` < `Assets +200` < `Redis +400`).

---

## 2. Banco de Preguntas y Respuestas (Módulos I, II y III)

### Módulo I — Procesos, Hilos y Planificación (CFS)

1. **¿Qué servicios mantienen hilos/procesos fijos y cuáles crecen dinámicamente con la carga?**
   - **Fijos:** `nginx-lb` y `nginx-assets` (`1` maestro + `worker_processes` fijos con `epoll`); `app` (`cluster` + `UV_THREADPOOL_SIZE` hilos `libuv`); `redis` (`1` event loop + `io-threads` + hilos `bio_*`).
   - **Dinámicos:** `mysql` mantiene hilos fijos de fondo InnoDB (`ib_io_rd`, `ib_io_wr`), pero crea un hilo por cada nueva conexión cliente (*thread-per-connection*) hasta `max_connections`.
2. **¿Cómo verifican en Linux si un servicio usa procesos independientes o hilos (`LWP`)?**
   - Mediante `ps -L -p <PID> -o pid,tid,psr,comm`, `top -H` y listando `/proc/<PID>/task`. Los hilos POSIX comparten el mismo `PID` (TGID) con distintos `TID` dentro de `/proc/<PID>/task`; los procesos worker tienen distinto `PID`.
3. **¿Qué ocurre en el kernel cuando un contenedor alcanza su límite `--cpus`?**
   - Docker traduce `--cpus` al archivo `cpu.max` de `cgroups v2` (cuota/período CFS). Al agotarse la cuota antes de terminar el período de 100 ms, el planificador suspende los hilos del cgroup hasta el siguiente período e incrementa `nr_throttled` y `throttled_usec` en `cpu.stat`.

---

### Módulo II — Gestión de Memoria, cgroups v2, PSI y OOM Killer

4. **¿Cuál es la diferencia entre `memory.high` y `memory.max` en `cgroups v2`?**
   - `memory.high` es un límite blando que dispara *throttling* y reclamo directo (*direct reclaim*), aumentando la presión de memoria en `/proc/pressure/memory` (**PSI**) y la latencia `p99`, pero **sin matar** al proceso.
   - `memory.max` es un techo duro: si no hay memoria liberable ni swap disponible, el kernel invoca al **OOM Killer** (`SIGKILL`, salida `137`) y lo registra en `dmesg`.
5. **¿Por qué asignamos `oom_score_adj = -800` a `mysql-master` y `+400` a `redis`?**
   - En una crisis de memoria global, el OOM Killer suma `oom_score_adj` al puntaje de cada proceso para elegir a la víctima. Con `+400`, Redis (caché reconstruible) es sacrificado antes que MySQL (`-800`), resguardando los datos transaccionales.
6. **¿Qué indican `some` y `full` en `/proc/pressure/memory` (PSI)?**
   - `some` mide el porcentaje de tiempo en que **al menos una** tarea ejecutable estuvo bloqueada esperando memoria; `full` mide el tiempo en que **todas** las tareas ejecutables estuvieron estancadas por falta de memoria.

---

### Módulo III — Almacenamiento, Sistemas de Archivos, Page Cache y E/S

7. **¿Por qué los datos de MySQL y Redis usan volúmenes Docker mientras la raíz usa OverlayFS?**
   - OverlayFS apila capas *copy-on-write* efímeras ligadas al ciclo de vida del contenedor y penaliza escrituras aleatorias intensivas. Los volúmenes Docker montan directorios nativos del sistema de archivos del host (`ext4`), preservando los datos tras fallos o recreaciones.
8. **¿Qué diferencia verifican entre `df -hT` y `df -i`?**
   - `df -hT` muestra el tipo de filesystem y espacio en bloques; `df -i` muestra el uso de **inodos**. Un volumen con espacio libre en GB puede fallar al crear archivos si agota sus inodos.
9. **¿Por qué `nginx-assets` aprovecha la Page Cache (`sendfile on`) mientras MySQL usa `O_DIRECT`?**
   - `nginx-assets` sirve archivos estáticos de solo lectura donde la Page Cache (`Cached` en `/proc/meminfo`) acelera entregas *zero-copy*. MySQL administra su propio `innodb_buffer_pool_size` y con `O_DIRECT` evita duplicar páginas en la Page Cache del kernel.
10. **¿Cómo se interpreta `iostat -dx` (`await`, `%util`) y `/sys/block/*/queue/scheduler`?**
    - `await` es la latencia media total por petición de E/S (cola + dispositivo) y `%util` el porcentaje de saturación temporal del disco. `/sys/block/*/queue/scheduler` muestra el planificador `blk-mq` activo (`none`, `mq-deadline`, `kyber`) que ordena las colas de lectura/escritura.
