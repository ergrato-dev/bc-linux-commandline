#!/usr/bin/env bash
#
# toolkit.sh — caja de herramientas personal de sysadmin.
#
# Uso:
#   toolkit.sh doctor             reporta el estado del entorno
#   toolkit.sh doctor --tipos     ademas distingue builtins de externos
#
# Este es el unico entrypoint del proyecto: cada semana nueva agrega un
# subcomando aca, nunca un script aparte.

set -euo pipefail

# TODO 1: valida que $HOME este definido antes de seguir. Si no lo esta,
# imprime un error a stderr y termina con un codigo de salida distinto de 0.
# Pista: la expansion ${HOME:?mensaje} hace exactamente esto en una linea.

cmd_doctor() {
  local mostrar_tipos=false
  if [[ "${1:-}" == "--tipos" ]]; then
    mostrar_tipos=true
  fi

  echo "== toolkit doctor =="

  # TODO 2: imprime la version de bash en uso. Pista: la variable
  # BASH_VERSION ya trae ese dato, no hace falta parsear "bash --version".
  echo "bash: TODO"

  # TODO 3: imprime el nombre de la distro, leyendo PRETTY_NAME de
  # /etc/os-release. Pista: ese archivo tiene formato CLAVE="valor", una
  # linea por variable — se puede leer con 'source' o con grep + cut.
  echo "distro: TODO"

  if [[ "$mostrar_tipos" == true ]]; then
    # TODO 4: imprime, para 'cd' y para 'ls', si cada uno es builtin o
    # externo. Formato esperado por el autograding: una linea que contenga
    # "cd" seguido en algun punto de la palabra "builtin".
    # Pista: 'type -t comando' devuelve justamente eso ("builtin", "file",
    # "alias"...) en una sola palabra, facil de usar en un condicional.
    echo "TODO: tipos de comando"
  fi
}

main() {
  local subcomando="${1:-}"
  shift || true

  case "$subcomando" in
    doctor)
      cmd_doctor "$@"
      ;;
    "")
      echo "Uso: toolkit.sh <subcomando>" >&2
      echo "Subcomandos disponibles: doctor" >&2
      exit 1
      ;;
    *)
      echo "toolkit.sh: subcomando desconocido: $subcomando" >&2
      exit 1
      ;;
  esac
}

main "$@"
