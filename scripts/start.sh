#!/usr/bin/env bash
#
# start.sh — levanta el laboratorio multi-distro del bootcamp.
#
# Uso:
#   ./scripts/start.sh
#
# Deja cuatro contenedores corriendo (ubuntu-lab, debian-lab, rhel-lab,
# arch-lab). Solo ubuntu-lab es graded; los otros tres son de exploracion.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

rojo()  { printf '\033[0;31m%s\033[0m\n' "$*"; }
verde() { printf '\033[0;32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[0;90m%s\033[0m\n' "$*"; }

if ! command -v docker >/dev/null 2>&1; then
  rojo "Falta docker. Instalalo antes de seguir: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  rojo "Falta el plugin 'docker compose' (v2). 'docker-compose' v1 no sirve."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  rojo "El demonio de Docker no responde. Arrancalo y vuelve a intentarlo."
  exit 1
fi

echo "Levantando el laboratorio..."
docker compose up -d

echo -n "Esperando a que ubuntu-lab responda"
transcurrido=0
espera_maxima=30
while true; do
  if docker exec ubuntu-lab true 2>/dev/null; then
    echo
    break
  fi
  if (( transcurrido >= espera_maxima )); then
    echo
    rojo "ubuntu-lab no respondio en ${espera_maxima}s."
    gris "Mira que paso con: docker compose logs ubuntu-lab"
    exit 1
  fi
  echo -n "."
  sleep 2
  transcurrido=$(( transcurrido + 2 ))
done

cat <<RESUMEN

$(verde "Laboratorio listo.")

  ubuntu-lab   canonico, graded       docker exec -it ubuntu-lab bash
  debian-lab   exploracion            docker exec -it debian-lab bash
  rhel-lab     exploracion (dnf)      docker exec -it rhel-lab bash
  arch-lab     exploracion (pacman)   docker exec -it arch-lab bash

Pruebalo:

  docker exec -it ubuntu-lab cat /etc/os-release | grep VERSION_ID
  # VERSION_ID="24.04"

Para pararlo:  ./scripts/stop.sh
RESUMEN
