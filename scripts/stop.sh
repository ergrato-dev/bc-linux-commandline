#!/usr/bin/env bash
#
# stop.sh — para el laboratorio del bootcamp.
#
# Uso:
#   ./scripts/stop.sh              para los contenedores, conserva los volumenes
#   ./scripts/stop.sh --limpiar    ademas borra los volumenes

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

LIMPIAR=false
case "${1:-}" in
  --limpiar) LIMPIAR=true ;;
  "")        ;;
  *)         echo "Uso: $0 [--limpiar]" >&2; exit 1 ;;
esac

if [[ "$LIMPIAR" == true ]]; then
  printf '\033[1;33m%s\033[0m\n' "Esto borra los volumenes del laboratorio (todo lo instalado a mano dentro)."
  printf '%s' "Continuar? [s/N] "
  read -r respuesta
  if [[ "${respuesta,,}" != "s" ]]; then
    echo "Cancelado."
    exit 0
  fi
  docker compose down -v
  printf '\033[0;32m%s\033[0m\n' "Laboratorio parado y limpiado."
else
  docker compose down
  printf '\033[0;32m%s\033[0m\n' "Laboratorio parado. Los volumenes siguen ahi."
fi
