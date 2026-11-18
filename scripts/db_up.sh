#!/usr/bin/env bash
# ==============================================================================
# db_up.sh - [ESQUELETO: Rol 4 (Administrador de Datos, Almacenamiento y E/S)]
# Despliega MySQL Primario, MySQL Replica (GTID) y carga datos iniciales.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NET_NAME="ha-net"

HOST_CPUS="$(nproc)"
HOST_MEM_MB="$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
echo "[db_up] VM detectada: ${HOST_CPUS} vCPUs | ${HOST_MEM_MB} MB RAM"

# TODO [Rol 4]: Crear red 'ha-net' y volumenes persistentes 'mysql_master_data' y 'mysql_replica_data'

# TODO [Rol 4]: Levantar 'mysql-master' (mysql:8.0) con flags de kernel:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=-800
#   montando config/mysql/my_master.cnf (permisos 644) y mysql_master_data:/var/lib/mysql

# TODO [Rol 4]: Levantar 'mysql-replica' (mysql:8.0) con:
#   --cpus, --memory, --memory-reservation, --pids-limit, --oom-score-adj=-500
#   montando config/mysql/my_replica.cnf (permisos 644) y mysql_replica_data:/var/lib/mysql
#   Nota: aplicar read_only/super_read_only despues de inicializar el volumen para no bloquear el entrypoint.

# TODO [Rol 4]: Esperar mysqladmin ping en ambos nodos, crear usuario de replicacion 'repl',
# esquema 'ha_db' con tabla 'registros' y poblar datos iniciales de prueba.

# TODO [Rol 4]: Configurar replicacion GTID (CHANGE REPLICATION SOURCE TO ... SOURCE_AUTO_POSITION=1)
# en mysql-replica y validar Replica_IO_Running=Yes y Replica_SQL_Running=Yes.
echo "[db_up] TODO: completar implementacion de Rol 4."
