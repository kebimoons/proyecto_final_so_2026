# Convención de Evidencias (`evidencias/`)

Todas las capturas PNG subidas por el equipo deben obtenerse directamente desde la VM Linux ejecutando los comandos reales del sistema operativo y mostrando el **prompt `PS1` personalizado**.

## 1. Configuración del Prompt (`PS1`)

Antes de capturar cualquier terminal, ejecuta en tu VM (sustituyendo `<N>` y `<tu_nombre>`):

```bash
export PS1="grupo1sf134-rol<N>-<tu_nombre>@so-ha-prod:\w\$ "
```

## 2. Convención de Nombres de Capturas PNG

| Experimento | Nomenclatura Sugerida | Rol Responsable |
| :--- | :--- | :--- |
| **5.1 Baseline — Procesos/Hilos** | `rol1_exp51_nginx_workers_pagecache.png`<br>`rol2_exp51_node_cluster_threads.png`<br>`rol3_exp51_redis_threads.png`<br>`rol4_exp51_mysql_threads_disco_io.png` | Roles 1, 2, 3, 4 |
| **5.2 Escalamiento (1 vs 3 Réplicas)** | `rol2_exp52_1rep_vs_3rep_top_h.png`<br>`rol5_exp52_load_3reps_cgroups.png` | Roles 2 y 5 |
| **5.3 Memoria (`high` vs `max`/OOM)** | `rol3_exp53_memory_high_psi.png`<br>`rol3_exp53_memory_max_oom_dmesg.png` | Rol 3 |
| **5.4 Failover HA en Vivo (MTTR)** | `rol6_exp54_failover_app.png`<br>`rol6_exp54_failover_redis_sentinel.png`<br>`rol6_exp54_failover_mysql_gtid.png` | Rol 6 |

> **Regla:** Asegúrate de que el texto en cada captura sea legible, sin líneas cortadas y muestre tanto el comando ejecutado como su salida real completa.
