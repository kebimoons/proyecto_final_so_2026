## Checklist Obligatorio antes de hacer Merge a `dev`

- [ ] Trabajé únicamente sobre mi rama asignada (`feat/rol-X-...`) sin modificar archivos de otros roles sin coordinación.
- [ ] Verifiqué en mi VM Linux que **cgroups v2** está activo (`/sys/fs/cgroup/cgroup.controllers`).
- [ ] Todos los contenedores en mis scripts usan `docker run` con límites explícitos (`--cpus`, `--memory`, `--memory-reservation`, `--pids-limit`, `--oom-score-adj`) — sin IaC ni código en C.
- [ ] Todos los scripts `.sh` tienen formato LF y permisos de ejecución (`chmod +x scripts/*.sh`).
- [ ] Las capturas en `evidencias/` muestran el prompt `PS1` personalizado con mi rol y salidas reales del kernel.
- [ ] Si aplica a mi rol, las pruebas de carga (`load.sh`) incluyen **>= 3 repeticiones** con cálculo de promedio y **p99**.
- [ ] Probé `./scripts/cleanup.sh` y mi servicio levanta de forma no interactiva desde cero.
