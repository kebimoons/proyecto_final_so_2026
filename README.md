# Proyecto Semestral — Servicios en Producción con Alta Disponibilidad (HA)

- **Curso:** Sistemas Operativos (0689)
- **Grupo:** 1IL143
- **Docente:** Isacio Manuel Tamayo Rodríguez
- **Fecha límite de entrega:** 5 de diciembre de 2026 (23:59)
- **Repositorio:** `https://github.com/kebimoons/proyecto_final_so_2026.git`

> **Alcance técnico obligatorio:** Todo el despliegue, presupuestos del kernel (`cgroups v2`, `oom_score_adj`), pruebas de carga y pruebas de caos deben implementarse exclusivamente mediante **Bash**, **Docker** (`docker run` con flags explícitos), `systemd` y utilidades estándar de Linux. Está prohibido usar herramientas de IaC (Terraform, Vagrant, Ansible) y programas en C.

---

## 1. Arquitectura del Sistema (5 Capas)

```text
                    [ Cliente / hey / wrk / sondeo.sh ]
                                    │ :8080
                                    ▼
                        ┌───────────────────────┐
                        │   nginx-lb (Rol 1)    │  oom_score_adj: -700
                        │   least_conn + retry  │  worker_processes fijos
                        └─────┬───────────┬─────┘
             /assets/*        │           │        /api/* , /health
        ┌─────────────────────┘           └─────────────────────┐
        ▼                                                       ▼
┌───────────────┐                               ┌──────────────────────────────┐
│ nginx-assets  │ oom_score_adj: +200           │   app-1 .. app-N (Rol 2)     │
│ sendfile on   │ Page Cache del Kernel         │   Node cluster + UV_THREADPOOL│
└───────────────┘                               │   oom_score_adj: 0           │
                                                └───────┬──────────────┬───────┘
                                                        │              │
                        ┌───────────────────────────────┘              └───────────────────────┐
                        ▼ Cache-Aside (Sentinel)                                               ▼ Failover GTID
        ┌───────────────────────────────┐                                      ┌───────────────────────────────┐
        │ redis-master + replica (Rol 3)│ oom: +400                            │ mysql-master + replica (Rol 4)│
        │ io-threads + bio_* (fijos)    │ Volúmenes /data                      │ GTID + max_connections=200    │
        │ + 3x redis-sentinel (quorum2) │                                      │ oom: -800 / -500 | Volúmenes  │
        └───────────────────────────────┘                                      └───────────────────────────────┘
```

---

## 2. Preparación de la VM Linux de cada Integrante

No se suben imágenes `.vdi`/`.vmdk` al repositorio. Cada integrante crea o usa su propia **VM Linux** (Ubuntu 22.04/24.04 o Debian 12/13 en VirtualBox, VMware o WSL2 con `systemd`), clona el repositorio y ejecuta una única vez `scripts/setup_env.sh`:

```bash
git clone https://github.com/kebimoons/proyecto_final_so_2026.git
cd proyecto_final_so_2026
chmod +x scripts/*.sh

# Instala docker.io, sysstat, hey, wrk, redis-tools, default-mysql-client, jq, bc
# Verifica cgroups v2 y muestra hardware (nproc, free -h, lsblk)
./scripts/setup_env.sh --rol <1..6> --nombre <tu_alias>
```

Antes de tomar capturas de pantalla en `evidencias/`, activa el prompt personalizado:

```bash
export PS1="grupo1il143-rol<N>-<tu_nombre>@so-ha-prod:\w\$ "
```

---

## 3. Tabla de los 6 Roles (Sorteo 1 al 6)

| Rol | Integrante | Responsabilidad Técnica | Archivos Asignados | Rama Git |
| :---: | :--- | :--- | :--- | :--- |
| **1** | `[Nombre Integrante 1]` | **Arquitecto de Entrada, Balanceo y Page Cache** | `scripts/stack_up.sh` (Nginx), `config/nginx/nginx_lb.conf`, `config/nginx/nginx_assets.conf` | `feat/rol-1-nginx-lb-assets` |
| **2** | `[Nombre Integrante 2]` | **Desarrollador de App y Escalabilidad Horizontal** | `app/server.js`, `app/Dockerfile`, `app/package.json`, `scripts/stack_up.sh` (réplicas App) | `feat/rol-2-app-escalabilidad` |
| **3** | `[Nombre Integrante 3]` | **Especialista en Caché HA y Gestión de Memoria** | `scripts/cache_up.sh`, `config/redis/redis_master.conf`, `redis_replica.conf`, `sentinel.conf` | `feat/rol-3-redis-memoria-oom` |
| **4** | `[Nombre Integrante 4]` | **Administrador de Datos, Almacenamiento y E/S** | `scripts/db_up.sh`, `config/mysql/my_master.cnf`, `config/mysql/my_replica.cnf` | `feat/rol-4-mysql-almacenamiento-io` |
| **5** | `[Nombre Integrante 5]` | **Ingeniero de Carga y Cuellos de Botella** | `scripts/load.sh`, resultados CSV en `logs/` (`>=3` reps, `p99`, `cgroups`) | `feat/rol-5-carga-metricas` |
| **6** | `[Nombre Integrante 6]` | **Ingeniero de Caos, Failover HA y Documentación** | `scripts/falla.sh`, `scripts/sondeo.sh`, `docs/GUIA_SUSTENTACION_GRUPAL.md`, `informe/plantilla.docx` | `feat/rol-6-failover-ha-informe` |

> **Guías individuales:** Revisa `docs/GUIAS_ROLES/ROL_<N>_*.md` según el número que te toque en el sorteo.

---

## 4. Flujo de Trabajo en Git

1. Sincroniza `dev` y cámbiate a tu rama asignada:
   ```bash
   git checkout dev && git pull origin dev
   git checkout feat/rol-<N>-...
   ```
2. Completa los `TODO [Rol N]` de tus scripts/configuraciones y prueba en tu VM.
3. Sube tus capturas PNG con `PS1` personalizado a `evidencias/` (siguiendo `evidencias/README.md`).
4. Haz commits atómicos, abre un Pull Request hacia `dev` verificando `.github/pull_request_template.md`, y una vez integrado todo el equipo en `dev`, se consolidará `main` para la entrega final.

---

## 5. Cronograma de Hitos (18 de noviembre – 5 de diciembre de 2026)

| Hito | Fechas | Actividades y Entregables | Responsables |
| :--- | :--- | :--- | :--- |
| **H1: Entorno y Sorteo** | 18 nov – 22 nov 2026 | VM Linux por integrante, ejecución de `setup_env.sh`, verificación de `cgroups v2` y sorteo de roles 1–6. | Todo el equipo |
| **H2: Implementación por Capas** | 23 nov – 27 nov 2026 | Completar `db_up.sh` (Rol 4), `cache_up.sh` (Rol 3), `app/server.js` (Rol 2) y `nginx_*.conf` + `stack_up.sh` (Rol 1). Merge inicial a `dev`. | Roles 1, 2, 3 y 4 |
| **H3: Carga, OOM y Failover** | 28 nov – 02 dic 2026 | Ejecutar Exp. 5.1–5.4 (`>=3` reps, `p99`, `memory.high` vs `memory.max`, failover y `MTTR`) y subir capturas a `evidencias/`. | Roles 5 y 6 (apoyo 2–4) |
| **H4: Informe y Sustentación** | 03 dic – 05 dic 2026 (23:59) | Ensamblar `Grupo_1IL143_Proyecto_HA.pdf` (12–20 págs. desde `informe/plantilla.docx`), ensayar preguntas con `GUIA_SUSTENTACION_GRUPAL.md` y entregar `main`. | Todo el equipo |
