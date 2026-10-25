#!/usr/bin/env bash
#
# toolkit.sh — caja de herramientas personal de sysadmin.
#
# Uso:
#   toolkit.sh doctor                   reporta el estado del entorno (Semana 01)
#   toolkit.sh doctor --tipos           ademas distingue builtins de externos
#   toolkit.sh inventory [ruta]         cuenta archivos/directorios/enlaces (Semana 02)
#   toolkit.sh inventory [ruta] --ext E filtra ademas por extension E
#
# Este es el unico entrypoint del proyecto: cada semana nueva agrega un
# subcomando aca, nunca un script aparte. doctor ya viene completo de la
# Semana 01 — esta semana completas inventory.

set -euo pipefail

: "${HOME:?HOME no esta definido}"

cmd_doctor() {
  local mostrar_tipos=false
  if [[ "${1:-}" == "--tipos" ]]; then
    mostrar_tipos=true
  fi

  echo "== toolkit doctor =="
  echo "bash: $BASH_VERSION"

  local distro
  distro=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
  echo "distro: $distro"

  if [[ "$mostrar_tipos" == true ]]; then
    for c in cd ls; do
      echo "$c: $(type -t "$c")"
    done
  fi
}

cmd_inventory() {
  # shellcheck disable=SC2034  # los TODO 1-5 de abajo los usan
  local objetivo="." extension=""

  # TODO 1: recorre "$@" con un while/case. Si ves el flag --ext, el
  # siguiente argumento es la extension (guardala y avanza dos posiciones
  # con "shift 2"). Cualquier otro argumento es la ruta objetivo (guardala
  # y avanza una posicion con "shift"). Pista: mismo patron que viste en
  # 3-proyecto/README.md de esta semana, seccion "Que anade esta capa".

  # TODO 2: si "$objetivo" no es un directorio (test -d), imprime un error
  # a stderr con el nombre del comando y la ruta, y termina con exit 1.

  # TODO 3: resuelve "$objetivo" a su ruta absoluta. Pista: "cd ... && pwd"
  # dentro de una sub-shell $(...) es mas confiable que concatenar strings
  # a mano (ver 1-teoria/01, seccion "Rutas relativas dentro de un script").
  local absoluta="TODO"

  echo "== toolkit inventory =="
  echo "ruta: $absoluta"

  # TODO 4: cuenta archivos regulares, directorios (sin contar el propio
  # "$absoluta") y enlaces simbolicos dentro de "$absoluta", SIN recursion
  # (un solo nivel). Pista: "find "$absoluta" -maxdepth 1 -type f | wc -l"
  # y variantes con -type d (agregando -mindepth 1) y -type l.
  echo "archivos regulares: TODO"
  echo "directorios: TODO"
  echo "enlaces simbolicos: TODO"

  # TODO 5: si "$extension" no esta vacia, arma un array con
  # "shopt -s nullglob" + "$absoluta"/*."$extension" (no te olvides
  # "shopt -u nullglob" despues), imprime cuantas coincidencias hay y
  # despues cada nombre con "basename".
}

main() {
  local subcomando="${1:-}"
  shift || true

  case "$subcomando" in
    doctor)
      cmd_doctor "$@"
      ;;
    inventory)
      cmd_inventory "$@"
      ;;
    "")
      echo "Uso: toolkit.sh <subcomando>" >&2
      echo "Subcomandos disponibles: doctor, inventory" >&2
      exit 1
      ;;
    *)
      echo "toolkit.sh: subcomando desconocido: $subcomando" >&2
      exit 1
      ;;
  esac
}

main "$@"
