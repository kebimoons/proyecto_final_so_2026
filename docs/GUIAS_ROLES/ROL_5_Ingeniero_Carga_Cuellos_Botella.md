# Guía Individual — Rol 5: Ingeniero de Carga y Análisis de Cuellos de Botella

## 1. Archivos de los que eres Dueño
- `scripts/load.sh`
- Archivos CSV y métricas crudas generadas en `logs/`

## 2. Flujo de Trabajo en tu Rama Git
```bash
git checkout dev && git pull origin dev
git checkout feat/rol-5-carga-metricas

./scripts/setup_env.sh --rol 5 --nombre tu_alias

# 1. Completa los TODO [Rol 5] en scripts/load.sh:
#    - Ejecutar >=3 repeticiones por escenario con 'hey' (o 'wrk') y 'redis-benchmark'
#    - Parsear RPS, latencia promedio, p50, p95, p99 y errores HTTP
#    - Capturar snapshots de cgroups v2 (cpu.stat, memory.current, pids.current) e iostat -dx

git add scripts/load.sh logs/ evidencias/
git commit -m "feat(rol-5): pruebas de carga (>=3 reps), calculo p99 y analisis de cuellos de botella"
```

## 3. Comandos del Kernel a Ejecutar y Capturar (con tu `PS1`)
```bash
export PS1="grupo1il143-rol5-tu_nombre@so-ha-prod:\w\$ "

# Comparar 1 vs 3 replicas (minimo 3 repeticiones cada uno):
./scripts/stack_up.sh 1
./scripts/load.sh exp52_1rep "http://127.0.0.1:8080/api/datos?id=1&work=12000" 40 1200 3

./scripts/stack_up.sh 3
./scripts/load.sh exp52_3rep "http://127.0.0.1:8080/api/datos?id=1&work=12000" 40 1200 3

# Inspeccionar throttling CFS y memoria en cgroups v2:
for c in app-1 app-2 app-3 nginx-lb mysql-master; do
  cid=$(docker inspect -f '{{.Id}}' "$c" 2>/dev/null)
  cg=$(find /sys/fs/cgroup -name "*${cid}*" -type d | head -n 1)
  echo "=== $c ==="
  cat "${cg}/cpu.stat" "${cg}/memory.current" "${cg}/pids.current"
done
```
Guarda tu captura en `evidencias/rol5_exp52_load_3reps_cgroups.png`.

## 4. Las 3 Preguntas Más Probables en Sustentación
1. **¿Por qué no basta con reportar el promedio de latencia y se exige el percentil `p99` en `>=3` repeticiones?**
   El promedio enmascara los picos extremos sufridos por el 1 % de peticiones más lentas (*tail latency*), provocados por colas de CPU, throttling o flushes de disco. Ejecutar al menos 3 repeticiones garantiza validez estadística y descarta efectos transitorios de caché fría.
2. **¿Cómo determinas a partir de `cpu.stat` e `iostat -dx` si el cuello de botella es CPU o disco?**
   Si `nr_throttled` y `throttled_usec` en `cpu.stat` crecen rápidamente mientras `iostat -dx` mantiene `await` y `%util` bajos, el cuello es la cuota de CPU del cgroup. Si `%util` ronda el 100 % y `await` se dispara mientras la CPU espera en estado `D`, el cuello es la E/S de disco.
3. **¿Qué significa `nr_throttled` en `/sys/fs/cgroup/.../cpu.stat`?**
   Es el número de períodos del planificador CFS en los que el contenedor consumió el 100 % de su cuota (`cpu.max`) antes de concluir el período y fue pausado por el kernel hasta el siguiente intervalo.
