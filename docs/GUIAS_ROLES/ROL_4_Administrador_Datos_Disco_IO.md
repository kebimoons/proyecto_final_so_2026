# Guía Individual — Rol 4: Administrador de Datos, Almacenamiento y E/S

## 1. Archivos de los que eres Dueño
- `scripts/db_up.sh`
- `config/mysql/my_master.cnf`
- `config/mysql/my_replica.cnf`

## 2. Flujo de Trabajo en tu Rama Git
```bash
git checkout dev && git pull origin dev
git checkout feat/rol-4-mysql-almacenamiento-io

./scripts/setup_env.sh --rol 4 --nombre tu_alias

# 1. Completa los TODO [Rol 4] en config/mysql/*.cnf y scripts/db_up.sh:
#    - Replicacion GTID (gtid_mode=ON, enforce_gtid_consistency=ON, SOURCE_AUTO_POSITION=1)
#    - Durabilidad (sync_binlog=1, innodb_flush_log_at_trx_commit=1, O_DIRECT)
#    - Volumenes persistentes mysql_master_data y mysql_replica_data en /var/lib/mysql
#    - Proteccion OOM: --oom-score-adj=-800 (primario) y -500 (replica)

git add config/mysql/ scripts/db_up.sh evidencias/
git commit -m "feat(rol-4): configurar MySQL GTID, volumenes persistentes y perfilado E/S"
```

## 3. Comandos del Kernel a Ejecutar y Capturar (con tu `PS1`)
```bash
export PS1="grupo1sf134-rol4-tu_nombre@so-ha-prod:\w\$ "
```

* **Módulo I (Hilos dinámicos por conexión + hilos InnoDB):**
  ```bash
  PID_DB=$(docker inspect -f '{{.State.Pid}}' mysql-master)
  ls /proc/${PID_DB}/task | wc -l
  ps -L -p "$PID_DB" -o pid,tid,psr,comm | head -n 15
  ```
* **Módulo II (Máxima protección OOM):**
  ```bash
  cat "/proc/${PID_DB}/oom_score_adj"   # Debe ser -800
  ```
* **Módulo III (OverlayFS vs Volúmenes persistentes, inodos y perfil de E/S):**
  ```bash
  docker exec mysql-master df -hT / /var/lib/mysql
  df -i /
  cat /sys/block/*/queue/scheduler
  iostat -dx 1 4
  pidstat -d 1 4
  ```
Guarda tu captura en `evidencias/rol4_exp51_mysql_threads_disco_io.png`.

## 4. Las 3 Preguntas Más Probables en Sustentación
1. **¿Qué hilos son fijos y cuáles son dinámicos en MySQL 8.0?**
   Los hilos de fondo de InnoDB (`ib_io_rd-*`, `ib_io_wr-*`, purge, log) son fijos al arranque, mientras que los hilos de atención a clientes crecen dinámicamente con la concurrencia según el modelo *thread-per-connection* hasta `max_connections`.
2. **¿Por qué `/var/lib/mysql` debe residir en un volumen Docker y no en la capa raíz OverlayFS del contenedor?**
   OverlayFS usa *copy-on-write* efímero ligado al contenedor: al borrar el contenedor se pierden los datos y las escrituras intensivas sufren penalización de capa. Un volumen Docker escribe directo sobre el sistema de archivos del host (`ext4`), garantizando persistencia y mejor rendimiento de E/S.
3. **¿Qué indican `await` y `%util` en `iostat -dx` y qué hace `innodb_flush_method = O_DIRECT`?**
   `await` es el tiempo promedio (ms) de espera + servicio por operación en bloque y `%util` el porcentaje de tiempo que el dispositivo estuvo ocupado. `O_DIRECT` evita la doble caché entre el InnoDB Buffer Pool y la Page Cache del kernel Linux.
