# Guía Individual — Rol 6: Ingeniero de Caos, Failover HA y Documentación

## 1. Archivos de los que eres Dueño
- `scripts/falla.sh`
- `scripts/sondeo.sh`
- `docs/GUIA_SUSTENTACION_GRUPAL.md`
- `informe/plantilla.docx` y compilación de `Grupo_1SF134_Proyecto_HA.pdf`

## 2. Flujo de Trabajo en tu Rama Git
```bash
git checkout dev && git pull origin dev
git checkout feat/rol-6-failover-ha-informe

./scripts/setup_env.sh --rol 6 --nombre tu_alias

# 1. Completa los TODO [Rol 6] en scripts/falla.sh y scripts/sondeo.sh.
# 2. Ejecuta los escenarios del Experimento 5.4 bajo sondeo continuo cada 100ms.
# 3. Consolida el informe grupal (12-20 paginas) a partir de informe/plantilla.docx
#    siguiendo informe/GUIA_ENSAMBLAJE_INFORME.md.

git add scripts/falla.sh scripts/sondeo.sh evidencias/ logs/ informe/ docs/
git commit -m "feat(rol-6): failover HA en vivo, calculo MTTR e informe final"
```

## 3. Comandos del Kernel a Ejecutar y Capturar (con tu `PS1`)
```bash
export PS1="grupo1sf134-rol6-tu_nombre@so-ha-prod:\w\$ "

# Escenario A: Caida de replica app-1
./scripts/sondeo.sh failover_app 15 &
sleep 3 && ./scripts/falla.sh app
wait

# Escenario B: Caida de redis-master (Sentinel promueve replica)
./scripts/sondeo.sh failover_redis 20 &
sleep 3 && ./scripts/falla.sh redis
wait

# Escenario C: Caida de mysql-master (conmutacion GTID a replica)
./scripts/sondeo.sh failover_mysql 20 "http://127.0.0.1:8080/api/datos?id=1&nocache=1" &
sleep 3 && ./scripts/falla.sh mysql
wait

# Verificar MTTR calculado y restaurar stack
cat logs/mttr_failover_*.txt
./scripts/falla.sh restore
```
Guarda tus capturas en `evidencias/rol6_exp54_failover_app.png`, `evidencias/rol6_exp54_failover_redis_sentinel.png` y `evidencias/rol6_exp54_failover_mysql_gtid.png`.

## 4. Las 3 Preguntas Más Probables en Sustentación
1. **¿Cómo calculas el MTTR real en `sondeo.sh` durante el experimento 5.4?**
   Midiendo con `date +%s%3N` cada 100 ms el intervalo exacto desde la primera respuesta HTTP distinta de `200` hasta la recuperación sostenida de respuestas `200 OK`, reportando además el total de sondas, errores y porcentaje de disponibilidad.
2. **¿Cómo se verifica que el failover de MySQL tuvo 0 pérdida de datos?**
   Insertando un registro canario único vía API (`POST /api/datos`) inmediatamente antes de matar `mysql-master`, contabilizando filas totales y verificando tras la promoción de `mysql-replica` (`STOP REPLICA; SET GLOBAL read_only=OFF;`) que el registro canario y el conteo total permanecen intactos gracias a GTID y `sync_binlog=1`.
3. **¿Qué diferencias críticas tiene este stack frente a soluciones HA gestionadas como AWS ALB, ElastiCache y RDS Multi-AZ?**
   En la nube, ALB + Auto Scaling reemplaza instancias muertas automáticamente (en lugar de solo retirarlas); ElastiCache abstrae el mantenimiento del quórum Sentinel; y RDS Multi-AZ emplea replicación síncrona a nivel de almacenamiento EBS con conmutación DNS automática (`RPO = 0`), a diferencia de GTID asíncrono que requiere promoción explícita o ProxySQL/Orchestrator.
