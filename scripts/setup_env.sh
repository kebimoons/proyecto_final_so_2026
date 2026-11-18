#!/usr/bin/env bash
# ==============================================================================
# setup_env.sh - Preparacion del Entorno Linux (Ubuntu 22.04/24.04 o Debian 12/13)
# Ejecutar una vez en la VM Linux tras clonar el repositorio:
#   ./scripts/setup_env.sh [--rol N] [--nombre alias]
# ==============================================================================
set -euo pipefail

ROL_NUM="${ROL_NUM:-X}"
MEMBER_NAME="${MEMBER_NAME:-integrante}"

while [ $# -gt 0 ]; do
  case "$1" in
    --rol)    ROL_NUM="${2:-X}"; shift 2 ;;
    --nombre) MEMBER_NAME="${2:-integrante}"; shift 2 ;;
    -h|--help)
      echo "Uso: $0 [--rol 1..6] [--nombre tu_nombre]"
      exit 0
      ;;
    *) echo "Opcion desconocida: $1" >&2; exit 1 ;;
  esac
done

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "[ERROR] Ejecuta como root o instala sudo." >&2
    exit 1
  fi
fi

echo "======================================================================"
echo " 1. Verificacion de Kernel y cgroups v2"
echo "======================================================================"
uname -a
if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
  echo "[ERROR] cgroups v2 NO esta activo en /sys/fs/cgroup/cgroup.controllers." >&2
  echo "Habilitalo en GRUB agregando 'systemd.unified_cgroup_hierarchy=1' en /etc/default/grub," >&2
  echo "ejecuta 'sudo update-grub && sudo reboot' y vuelve a correr este script." >&2
  exit 1
fi
echo "[OK] cgroups v2 activo. Controladores disponibles:"
cat /sys/fs/cgroup/cgroup.controllers

echo ""
echo "======================================================================"
echo " 2. Inventario de Hardware de la VM (para calcular presupuestos)"
echo "======================================================================"
echo "vCPUs (nproc): $(nproc)"
echo "--- Memoria RAM y Swap ---"
free -h
echo "--- Discos y Planificadores de E/S ---"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
head -n 1 /sys/block/*/queue/scheduler 2>/dev/null || true

echo ""
echo "======================================================================"
echo " 3. Instalacion de Dependencias Permitidas (sin IaC ni compiladores C)"
echo "======================================================================"
if ! command -v apt-get >/dev/null 2>&1; then
  echo "[ERROR] Este script soporta distribuciones basadas en Debian/Ubuntu (apt-get)." >&2
  exit 1
fi

PKGS=(
  docker.io
  sysstat
  hey
  wrk
  redis-tools
  default-mysql-client
  jq
  bc
  procps
  curl
)

MISSING=()
for pkg in "${PKGS[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING+=("$pkg")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "[setup_env] Instalando paquetes faltantes: ${MISSING[*]}"
  $SUDO apt-get update
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING[@]}"
else
  echo "[OK] Todos los paquetes requeridos ya estan instalados."
fi

echo ""
echo "======================================================================"
echo " 4. Activacion de Docker Engine y Permisos"
echo "======================================================================"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  $SUDO systemctl enable --now docke
else
  $SUDO service docker start || true
fi

TARGET_USER="${SUDO_USER:-$USER}"
if [ "$TARGET_USER" != "root" ] && id "$TARGET_USER" >/dev/null 2>&1; then
  if ! id -nG "$TARGET_USER" | grep -qw docker; then
    $SUDO usermod -aG docker "$TARGET_USER"
    echo "[AVISO] Usuario '$TARGET_USER' agregado al grupo 'docker'. Cierra sesion y vuelve a entrar (o ejecuta 'newgrp docker')."
  fi
fi

$SUDO docker info 2>/dev/null | grep -E "Server Version|Cgroup Driver|Cgroup Version|Storage Driver|CPUs|Total Memory" || true

echo ""
echo "======================================================================"
echo " 5. Configuracion de Prompt PS1 Personalizado para Evidencias"
echo "======================================================================"
PS1_CMD="export PS1=\"grupo1sf134-rol${ROL_NUM}-${MEMBER_NAME}@so-ha-prod:\\w\\$ \""
TARGET_HOME="$(eval echo "~${TARGET_USER}")"
BASHRC="${TARGET_HOME}/.bashrc"

if [ -f "$BASHRC" ] && ! grep -q "grupo1sf134-rol" "$BASHRC"; then
  {
    echo ""
    echo "# Prompt personalizado Proyecto HA - SO 0689 (Grupo 1SF134)"
    echo "alias ps1-ha='${PS1_CMD}'"
  } >> "$BASHRC"
  echo "[OK] Alias 'ps1-ha' agregado a ${BASHRC}."
fi

echo "Ejecuta en tu terminal actual antes de tomar capturas:"
echo "  ${PS1_CMD}"
echo ""
echo "[LISTO] Entorno de VM verificado y listo para trabajar en tu rol."
