# Guía de Ensamblaje del Informe Final (`informe/plantilla.docx`)

- **Archivo base:** `informe/plantilla.docx` (conservar portada institucional, fuentes Arial, encabezados `#0F4761`, márgenes y estilo de tablas/figuras).
- **Extensión obligatoria:** **12 a 20 páginas** compiladas en PDF (`Grupo_1IL143_Proyecto_HA.pdf`).
- **Fecha límite:** **5 de diciembre de 2026 a las 23:59**.

---

## Estructura de Secciones y Responsables

| Sección del Informe | Contenido Obligatorio | Responsable(s) |
| :--- | :--- | :--- |
| **Portada Institucional** | Replicar `plantilla.docx`: Curso 0689, Grupo 1IL143, Docente Isacio Manuel Tamayo Rodríguez, tabla de los 6 integrantes con su rol sorteado y fecha 5 de diciembre de 2026. | **Rol 6** (consolida) |
| **1. Arquitectura del Sistema HA** | Diagrama de arquitectura (5 capas), flujo de peticiones HTTP/Cache-Aside/GTID y red `ha-net`. | **Rol 1 y Rol 6** |
| **2. Marco Teórico Aplicado al Kernel** | Explicación práctica de Módulos I (procesos/hilos fijos vs dinámicos), II (`cgroups v2`, PSI, `oom_score_adj`) y III (OverlayFS vs volúmenes, Page Cache, `sendfile`, planificadores E/S) respaldada con salidas reales. | **Roles 1, 2, 3, 4** (cada uno su capa) |
| **3. Hipótesis y Diseño Experimental** | Especificaciones de hardware detectadas en la VM (`nproc`, `free -h`, `lsblk`) y tabla de presupuestos (`--cpus`, `--memory`, `--memory-reservation`, `--pids-limit`, `--oom-score-adj`). | **Rol 5 y Rol 6** |
| **4. Desarrollo por Servicio** | Detalle técnico de configuración de Nginx LB/Assets (Rol 1), App Node.js (Rol 2), Redis/Sentinel (Rol 3) y MySQL GTID (Rol 4). | **Roles 1, 2, 3, 4** |
| **5. Resultados Experimentales** | Tablas con **>=3 repeticiones**, promedios y **p99** + análisis de `evidencias/*.png`:<br>- **5.1** Baseline<br>- **5.2** 1 vs 3 réplicas y cuello de botella<br>- **5.3** `memory.high` + PSI vs `memory.max` + OOM Killer<br>- **5.4** Failover HA en vivo y **MTTR** | **Rol 5** (5.1, 5.2)<br>**Rol 3** (5.3)<br>**Rol 6** (5.4) |
| **6. Comparativa con la Industria** | Análisis crítico frente a AWS ALB/AutoScaling, ElastiCache y RDS Multi-AZ / ProxySQL (RTO, RPO, split-brain y operación). | **Rol 6** |
| **7. Conclusiones y Cronograma** | Síntesis de aprendizajes del kernel (Módulos I–III) y cumplimiento del cronograma (18 nov – 5 dic 2026). | **Todo el equipo** |
