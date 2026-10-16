#!/usr/bin/env bash
#
# verificar-semana.sh — autograding declarativo del bootcamp.
#
# Uso:
#   ./scripts/verificar-semana.sh 04        comprueba la Semana 04
#   ./scripts/verificar-semana.sh --doctor  comprueba tu entorno
#
# Este script no sabe nada de ninguna semana en concreto: lee las
# comprobaciones de bootcamp/week-NN-*/checks.json y las ejecuta dentro de
# ubuntu-lab. Si necesitas logica especifica de una semana, el sitio es el
# checks.json, nunca este archivo. Contrato completo: docs/autograding.md.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

CONTENEDOR="ubuntu-lab"

rojo()  { printf '\033[0;31m%s\033[0m\n' "$*"; }
verde() { printf '\033[0;32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[0;90m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# --doctor: comprueba las dependencias antes de culpar al material
# ---------------------------------------------------------------------------
doctor() {
  local fallos=0

  comprobar() {
    local etiqueta="$1" resultado="$2" detalle="${3:-}"
    if [[ "$resultado" == ok ]]; then
      printf '  \033[0;32m✅\033[0m %-24s %s\n' "$etiqueta" "$detalle"
    else
      printf '  \033[0;31m❌\033[0m %-24s %s\n' "$etiqueta" "$detalle"
      fallos=$(( fallos + 1 ))
    fi
  }

  echo "Entorno:"

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    comprobar "docker" ok "demonio activo"
  else
    comprobar "docker" no "no disponible — el laboratorio no puede arrancar"
  fi

  if command -v jq >/dev/null 2>&1; then
    comprobar "jq" ok "$(jq --version)"
  else
    comprobar "jq" no "no instalado — es obligatorio para leer checks.json"
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    comprobar "shellcheck" ok "$(shellcheck --version | awk '/^version:/{print $2}')"
  else
    comprobar "shellcheck" no "no instalado — algunas comprobaciones lo usan"
  fi

  echo
  echo "Laboratorio:"

  if docker exec "$CONTENEDOR" true 2>/dev/null; then
    comprobar "$CONTENEDOR" ok "corriendo"
  else
    comprobar "$CONTENEDOR" no "no responde — ./scripts/start.sh"
  fi

  echo
  if (( fallos == 0 )); then
    verde "Todo listo."
    return 0
  fi
  rojo "$fallos comprobacion(es) del entorno fallaron."
  return 1
}

# ---------------------------------------------------------------------------
# Evaluacion de una asercion
#   exit0        el comando sale con 0
#   exit!=0      el comando sale distinto de 0
#   exit=N       el comando sale exactamente con N
#   stdout~RE    la salida casa con la expresion regular extendida RE
#   stdout!~RE   la salida NO casa con RE
# ---------------------------------------------------------------------------
evaluar() {
  local asercion="$1" codigo="$2" salida="$3"

  case "$asercion" in
    exit0)      [[ "$codigo" -eq 0 ]] ;;
    "exit!=0")  [[ "$codigo" -ne 0 ]] ;;
    exit=*)     [[ "$codigo" -eq "${asercion#exit=}" ]] ;;
    "stdout!~"*) ! grep -qE "${asercion#stdout!~}" <<<"$salida" ;;
    stdout~*)   grep -qE "${asercion#stdout~}" <<<"$salida" ;;
    *)
      rojo "ASERCION DESCONOCIDA: '$asercion'"
      gris "Validas: exit0, exit!=0, exit=N, stdout~RE, stdout!~RE"
      return 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Ejecucion de una semana
# ---------------------------------------------------------------------------
verificar_semana() {
  local semana="$1"

  if ! [[ "$semana" =~ ^[0-9]{2}$ ]]; then
    rojo "La semana se indica con dos digitos: 01, 02 ... 20"
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    rojo "Falta jq. Es obligatorio para leer checks.json."
    exit 1
  fi

  if ! docker exec "$CONTENEDOR" true 2>/dev/null; then
    rojo "$CONTENEDOR no responde. ./scripts/start.sh primero."
    exit 1
  fi

  local dir
  dir=$(find bootcamp -maxdepth 1 -type d -name "week-${semana}-*" | head -1)
  if [[ -z "$dir" ]]; then
    rojo "No existe la carpeta de la Semana $semana."
    exit 1
  fi

  local archivo="$dir/checks.json"
  if [[ ! -f "$archivo" ]]; then
    rojo "La Semana $semana todavia no tiene checks.json."
    gris "Se escribe antes que el contenido: ver docs/autograding.md"
    exit 1
  fi

  if ! jq -e . "$archivo" >/dev/null 2>&1; then
    rojo "checks.json invalido: $archivo"
    exit 1
  fi

  echo "Semana $semana — $(jq -r '.titulo' "$archivo")"
  echo

  local total=0 pasados=0
  local descripcion cmd asercion pista codigo salida

  # El primer campo (id) se descarta con "_": es el identificador estable
  # de checks.json, pero este script solo reporta por descripcion.
  while IFS=$'\t' read -r _ descripcion cmd asercion pista; do
    total=$(( total + 1 ))

    # `if` alrededor: con `set -e`, capturar el codigo de un comando que falla
    # a proposito requiere que la ejecucion este en un contexto condicional.
    if salida=$(docker exec "$CONTENEDOR" bash -c "$cmd" 2>/dev/null); then
      codigo=0
    else
      codigo=$?
    fi

    if evaluar "$asercion" "$codigo" "$salida"; then
      printf '  \033[0;32m✅\033[0m %s\n' "$descripcion"
      pasados=$(( pasados + 1 ))
    else
      printf '  \033[0;31m❌\033[0m %s\n' "$descripcion"
      printf '     \033[0;90mpista: %s\033[0m\n' "$pista"
    fi
  # join(), no @tsv: @tsv duplica cada backslash literal (para poder escapar
  # tabs/saltos de linea en el formato), pero read -r nunca lo deshace, asi
  # que una regex con \. (punto literal de una version, una IP) se rompe en
  # silencio. join() no escapa nada; es seguro mientras ningun campo tenga
  # un tab o salto de linea, que es la convencion de una sola linea por campo.
  done < <(jq -r '.checks[] | [.id, .descripcion, .cmd, .assert, .pista] | join("\t")' "$archivo")

  echo
  if (( pasados == total )); then
    verde "$pasados/$total comprobaciones superadas."
    return 0
  fi
  rojo "$pasados/$total comprobaciones superadas."
  gris "Cada pista dice en que practica y en que paso se arregla."
  return 1
}

# ---------------------------------------------------------------------------
case "${1:-}" in
  --doctor)      doctor ;;
  -h|--help|"")  sed -n '3,13p' "${BASH_SOURCE[0]}" | sed 's|^# \?||' ;;
  *)             verificar_semana "$1" ;;
esac
