#!/usr/bin/env bash
#
# toolkit.sh — caja de herramientas personal de sysadmin.
#
# Uso:
#   toolkit.sh doctor                   reporta el estado del entorno (Semana 01)
#   toolkit.sh doctor --tipos           ademas distingue builtins de externos
#   toolkit.sh inventory [ruta]         cuenta archivos/directorios/enlaces (Semana 02)
#   toolkit.sh inventory [ruta] --ext E filtra ademas por extension E
#   toolkit.sh organize [ruta]          plan para agrupar archivos por extension (Semana 03)
#   toolkit.sh organize [ruta] --apply  ejecuta ese plan de verdad
#   toolkit.sh audit [ruta]             audita permisos riesgosos (Semana 04)
#   toolkit.sh logreport <archivo>      resume un log: lineas, errores (Semana 05)
#   toolkit.sh logreport <archivo> --salida archivo.txt   fija el nombre del informe
#   toolkit.sh logscan [directorio]     busca ERROR/WARN/CRIT en *.log, recursivo (Semana 06)
#   toolkit.sh logscan [directorio] --patron REGEX   usa un patron extendido propio
#   toolkit.sh topcount <archivo>       ranking de valores mas frecuentes de una columna (Semana 07)
#   toolkit.sh topcount <archivo> --campo N --delim D --top N   ajusta columna, separador y cuantos mostrar
#   toolkit.sh sumfield <archivo>       suma un campo numerico, agrupado por otro campo (Semana 08)
#   toolkit.sh sumfield <archivo> --campo N --delim D --grupo M   ajusta campo de valor, separador y campo de agrupacion
#   toolkit.sh finddupes [directorio]   encuentra archivos duplicados por contenido, recursivo (Semana 09)
#   toolkit.sh finddupes [directorio] --ext E   filtra ademas por extension E
#   toolkit.sh procwatch <patron>       lista procesos por nombre y detecta zombies entre ellos (Semana 10)
#   toolkit.sh procwatch <patron> --senal SIG [--apply]   envia una senal a los procesos encontrados (no zombies)
#   toolkit.sh acctaudit [directorio]   audita passwd/group/shells de un directorio tipo /etc (Semana 11)
#   toolkit.sh pkgcheck <paquete>       dice si un paquete esta instalado y en que version (Semana 11)
#
# Codigos de salida de audit:     0 sin riesgos,    1 ruta invalida,       2 riesgos encontrados.
# Codigos de salida de logreport: 0 sin ERROR,      1 archivo invalido,    2 ERROR encontrado.
# Codigos de salida de logscan:   0 sin matches,    1 directorio invalido, 2 coincidencias encontradas.
# Codigos de salida de topcount:  0 sin dominancia, 1 archivo invalido,    2 un valor domina mas de la mitad.
# Codigos de salida de sumfield:  0 datos limpios,  1 archivo invalido,    2 valores no numericos encontrados.
# Codigos de salida de finddupes: 0 sin duplicados, 1 directorio invalido, 2 duplicados encontrados.
# Codigos de salida de procwatch: 0 sin zombies,    1 falta el patron,    2 zombie encontrado entre las coincidencias.
# Codigos de salida de acctaudit: 0 sin hallazgos,  1 directorio invalido, 2 hallazgos encontrados.
# Codigos de salida de pkgcheck:  0 instalado,      1 falta el paquete o gestor, 2 paquete no instalado.
#
# Este es el unico entrypoint del proyecto. doctor, inventory, organize,
# audit, logreport, logscan, topcount, sumfield, finddupes y procwatch ya
# vienen completos de las semanas anteriores — esta semana completas
# acctaudit y pkgcheck.

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
  local objetivo="." extension=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ext) extension="$2"; shift 2 ;;
      *) objetivo="$1"; shift ;;
    esac
  done
  if [[ ! -d "$objetivo" ]]; then
    echo "toolkit inventory: '$objetivo' no es un directorio" >&2
    exit 1
  fi
  local absoluta
  absoluta=$(cd "$objetivo" && pwd)
  echo "== toolkit inventory =="
  echo "ruta: $absoluta"
  local regulares directorios enlaces
  regulares=$(find "$absoluta" -maxdepth 1 -type f | wc -l)
  directorios=$(find "$absoluta" -mindepth 1 -maxdepth 1 -type d | wc -l)
  enlaces=$(find "$absoluta" -maxdepth 1 -type l | wc -l)
  echo "archivos regulares: $regulares"
  echo "directorios: $directorios"
  echo "enlaces simbolicos: $enlaces"
  if [[ -n "$extension" ]]; then
    shopt -s nullglob
    local coincidencias=("$absoluta"/*."$extension")
    shopt -u nullglob
    echo "coincidencias .$extension: ${#coincidencias[@]}"
    local f
    for f in "${coincidencias[@]}"; do
      echo "  - $(basename "$f")"
    done
  fi
}

cmd_organize() {
  local objetivo="." aplicar=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) aplicar=true; shift ;;
      *) objetivo="$1"; shift ;;
    esac
  done
  if [[ ! -d "$objetivo" ]]; then
    echo "toolkit organize: '$objetivo' no es un directorio" >&2
    exit 1
  fi
  local absoluta
  absoluta=$(cd "$objetivo" && pwd)
  echo "== toolkit organize =="
  echo "ruta: $absoluta"
  if [[ "$aplicar" == true ]]; then
    echo "modo: aplicando cambios"
  else
    echo "modo: dry-run (nada se mueve sin --apply)"
  fi
  shopt -s nullglob
  local archivos=("$absoluta"/*)
  shopt -u nullglob
  local plan_count=0
  local archivo nombre extension destino
  for archivo in "${archivos[@]}"; do
    [[ -f "$archivo" ]] || continue
    nombre=$(basename "$archivo")
    if [[ "$nombre" == *.* && "$nombre" != .* ]]; then
      extension="${nombre##*.}"
    else
      extension="sin-extension"
    fi
    destino="$absoluta/$extension"
    plan_count=$(( plan_count + 1 ))
    echo "plan: mkdir -p '$destino' && mv '$archivo' '$destino/$nombre'"
    if [[ "$aplicar" == true ]]; then
      mkdir -p "$destino"
      mv -n "$archivo" "$destino/$nombre"
    fi
  done
  echo "total movimientos planeados: $plan_count"
  if [[ "$aplicar" != true && "$plan_count" -gt 0 ]]; then
    echo "nada se movio todavia. Repite con --apply para ejecutar el plan."
  fi
}

cmd_audit() {
  local objetivo="."
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *) objetivo="$1"; shift ;;
    esac
  done
  if [[ ! -d "$objetivo" ]]; then
    echo "toolkit audit: '$objetivo' no es un directorio" >&2
    exit 1
  fi
  local absoluta
  absoluta=$(cd "$objetivo" && pwd)
  echo "== toolkit audit =="
  echo "ruta: $absoluta"
  echo "umask actual: $(umask)"
  local escribibles_por_otros
  escribibles_por_otros=$(find "$absoluta" -maxdepth 1 -perm -0002 | wc -l)
  echo "archivos/directorios escribibles por otros: $escribibles_por_otros"
  local con_suid con_sgid
  con_suid=$(find "$absoluta" -maxdepth 1 -perm -4000 | wc -l)
  con_sgid=$(find "$absoluta" -maxdepth 1 -perm -2000 | wc -l)
  echo "archivos con SUID: $con_suid"
  echo "archivos con SGID: $con_sgid"
  local riesgo=0
  if [[ "$escribibles_por_otros" -gt 0 ]]; then
    echo "riesgo: hay entradas escribibles por cualquier usuario" >&2
    riesgo=1
  fi
  if [[ "$con_suid" -gt 0 || "$con_sgid" -gt 0 ]]; then
    echo "riesgo: hay archivos con SUID/SGID activo" >&2
    riesgo=1
  fi
  if [[ "$riesgo" -eq 1 ]]; then
    exit 2
  fi
}

cmd_logreport() {
  local archivo="" salida=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --salida) salida="$2"; shift 2 ;;
      *) archivo="$1"; shift ;;
    esac
  done

  if [[ -z "$archivo" ]]; then
    echo "toolkit logreport: falta la ruta del log" >&2
    exit 1
  fi

  if [[ ! -f "$archivo" ]]; then
    echo "toolkit logreport: '$archivo' no es un archivo" >&2
    exit 1
  fi

  if [[ -z "$salida" ]]; then
    salida="${archivo}.informe.txt"
  fi

  echo "== toolkit logreport =="
  echo "archivo: $archivo"

  local total_lineas
  total_lineas=$(wc -l < "$archivo")
  echo "lineas totales: $total_lineas"

  local errores
  errores=$(grep -c "ERROR" "$archivo") || errores=0
  echo "lineas con ERROR: $errores"

  grep "ERROR" "$archivo" > "$salida" || true
  echo "informe guardado en: $salida"

  if [[ "$errores" -gt 0 ]]; then
    exit 2
  fi
}

cmd_logscan() {
  local directorio="." patron='ERROR|WARN|CRIT'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --patron) patron="$2"; shift 2 ;;
      *) directorio="$1"; shift ;;
    esac
  done

  if [[ ! -d "$directorio" ]]; then
    echo "toolkit logscan: '$directorio' no es un directorio" >&2
    exit 1
  fi

  local absoluta
  absoluta=$(cd "$directorio" && pwd)
  echo "== toolkit logscan =="
  echo "directorio: $absoluta"
  echo "patron: $patron"

  local total_logs
  total_logs=$(find "$absoluta" -type f -name '*.log' | wc -l)
  echo "archivos .log: $total_logs"

  if [[ "$total_logs" -eq 0 ]]; then
    echo "no se encontraron archivos .log"
    exit 0
  fi

  local total_coincidencias
  total_coincidencias=$( { grep -rEh --include='*.log' "$patron" "$absoluta" || true; } | wc -l )
  echo "lineas coincidentes: $total_coincidencias"

  local archivos_con_match
  archivos_con_match=$( { grep -rEl --include='*.log' "$patron" "$absoluta" || true; } | wc -l )
  echo "archivos con coincidencias: $archivos_con_match"

  grep -rEn --include='*.log' "$patron" "$absoluta" || true

  if [[ "$total_coincidencias" -gt 0 ]]; then
    exit 2
  fi
}

cmd_topcount() {
  local archivo="" campo=1 delim=":" top=5
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --campo) campo="$2"; shift 2 ;;
      --delim) delim="$2"; shift 2 ;;
      --top) top="$2"; shift 2 ;;
      *) archivo="$1"; shift ;;
    esac
  done

  if [[ -z "$archivo" ]]; then
    echo "toolkit topcount: falta la ruta del archivo" >&2
    exit 1
  fi
  if [[ ! -f "$archivo" ]]; then
    echo "toolkit topcount: '$archivo' no es un archivo" >&2
    exit 1
  fi

  echo "== toolkit topcount =="
  echo "archivo: $archivo"
  echo "campo: $campo"
  echo "delimitador: $delim"

  local total
  total=$(sed '/^#/d; /^$/d' "$archivo" | tr -s "$delim" | cut -d"$delim" -f"$campo" | tr '[:upper:]' '[:lower:]' | wc -l)
  echo "entradas validas: $total"

  if [[ "$total" -eq 0 ]]; then
    echo "no hay datos para procesar"
    exit 0
  fi

  local tabla
  tabla=$(sed '/^#/d; /^$/d' "$archivo" | tr -s "$delim" | cut -d"$delim" -f"$campo" | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn)

  echo "$tabla" | head -n "$top"

  local top1_count top1_valor
  read -r top1_count top1_valor <<< "$(echo "$tabla" | head -1)"
  echo "valor mas frecuente: $top1_valor ($top1_count de $total)"

  if (( top1_count * 2 > total )); then
    echo "riesgo: '$top1_valor' domina mas de la mitad de las entradas" >&2
    exit 2
  fi
}

cmd_sumfield() {
  local archivo="" campo=2 delim=":" grupo=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --campo) campo="$2"; shift 2 ;;
      --delim) delim="$2"; shift 2 ;;
      --grupo) grupo="$2"; shift 2 ;;
      *) archivo="$1"; shift ;;
    esac
  done

  if [[ -z "$archivo" ]]; then
    echo "toolkit sumfield: falta la ruta del archivo" >&2
    exit 1
  fi
  if [[ ! -f "$archivo" ]]; then
    echo "toolkit sumfield: '$archivo' no es un archivo" >&2
    exit 1
  fi

  echo "== toolkit sumfield =="
  echo "archivo: $archivo"
  echo "campo valor: $campo"
  echo "campo grupo: $grupo"
  echo "delimitador: $delim"

  local no_numericos
  no_numericos=$(awk -F"$delim" -v campo="$campo" 'NF>=campo && $campo !~ /^-?[0-9]+([.][0-9]+)?$/' "$archivo" | wc -l)
  echo "valores no numericos: $no_numericos"

  local tabla
  tabla=$(awk -F"$delim" -v campo="$campo" -v grupo="$grupo" '
    NF>=campo && NF>=grupo && $campo ~ /^-?[0-9]+([.][0-9]+)?$/ {
      suma[$grupo]+=$campo
    }
    END { for (k in suma) print suma[k], k }
  ' "$archivo" | sort -rn)

  echo "$tabla"

  local total
  total=$(echo "$tabla" | awk '{s+=$1} END {print s+0}')
  echo "suma total: $total"

  if [[ "$no_numericos" -gt 0 ]]; then
    echo "riesgo: hay $no_numericos valores no numericos en el campo $campo" >&2
    exit 2
  fi
}

cmd_finddupes() {
  local directorio="" extension=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ext) extension="$2"; shift 2 ;;
      *) directorio="$1"; shift ;;
    esac
  done
  if [[ -z "$directorio" ]]; then
    directorio="."
  fi
  if [[ ! -d "$directorio" ]]; then
    echo "toolkit finddupes: '$directorio' no es un directorio" >&2
    exit 1
  fi

  local absoluta
  absoluta=$(cd "$directorio" && pwd)
  echo "== toolkit finddupes =="
  echo "directorio: $absoluta"

  local salida
  if [[ -n "$extension" ]]; then
    salida=$(find "$absoluta" -type f -name "*.$extension" -print0 | xargs -r0 sha256sum)
  else
    salida=$(find "$absoluta" -type f -print0 | xargs -r0 sha256sum)
  fi

  local total_archivos
  total_archivos=$(printf '%s\n' "$salida" | grep -c .) || true
  echo "archivos analizados: $total_archivos"

  local grupos
  grupos=$(printf '%s\n' "$salida" | awk '{print $1}' | sort | uniq -d | grep -c .) || true
  echo "grupos de duplicados: $grupos"

  if [[ "$grupos" -eq 0 ]]; then
    echo "no se encontraron duplicados"
    exit 0
  fi

  local hash
  while read -r hash; do
    echo "duplicado ($hash):"
    printf '%s\n' "$salida" | awk -v h="$hash" '$1==h { $1=""; sub(/^ /,""); print "  "$0 }'
  done < <(printf '%s\n' "$salida" | awk '{print $1}' | sort | uniq -d)

  exit 2
}

cmd_procwatch() {
  local patron=""
  local senal=""
  local aplicar=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --senal) senal="$2"; shift 2 ;;
      --apply) aplicar=true; shift ;;
      *) patron="$1"; shift ;;
    esac
  done
  if [[ -z "$patron" ]]; then
    echo "toolkit procwatch: falta el patron de busqueda" >&2
    exit 1
  fi

  echo "== toolkit procwatch =="
  echo "patron: $patron"

  local procesos
  procesos=$(pgrep -a "$patron") || true

  local total
  total=$(printf '%s\n' "$procesos" | grep -c .) || true
  echo "coincidencias: $total"

  if [[ "$total" -eq 0 ]]; then
    echo "no se encontraron procesos"
    exit 0
  fi

  echo "$procesos"

  local zombies=0 pid stat
  while read -r pid _; do
    stat=$(ps -p "$pid" -o stat= 2>/dev/null) || stat=""
    if [[ "$stat" == Z* ]]; then
      zombies=$(( zombies + 1 ))
      echo "zombie detectado: PID $pid (no se le puede enviar ninguna senal)" >&2
    elif [[ -n "$senal" ]]; then
      if [[ "$aplicar" == true ]]; then
        kill -s "$senal" "$pid" 2>/dev/null || true
        echo "senal $senal enviada a PID $pid"
      else
        echo "dry-run: kill -s $senal $pid (usa --apply para enviarla de verdad)"
      fi
    fi
  done < <(printf '%s\n' "$procesos")

  echo "zombies encontrados: $zombies"

  if [[ "$zombies" -gt 0 ]]; then
    exit 2
  fi
}

cmd_acctaudit() {
  local etc="/etc"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *) etc="$1"; shift ;;
    esac
  done

  # TODO 1: comprueba que existan los tres archivos "$etc/passwd",
  # "$etc/group" y "$etc/shells" (un "for archivo in passwd group shells" y
  # "[[ ! -f ... ]]"). Si falta alguno, imprime a stderr "toolkit acctaudit:
  # falta '<ruta>'" y termina con "exit 1".

  echo "== toolkit acctaudit =="
  echo "directorio: $etc"

  # TODO 2: cuenta con UN solo "awk -F:" sobre "$etc/passwd" (ignora las
  # lineas con menos de 7 campos): total de cuentas, cuentas de sistema
  # (UID menor a 1000) y cuentas regulares (UID de 1000 a 60000; esos son
  # UID_MIN y UID_MAX de /etc/login.defs en Ubuntu). Imprime
  # "cuentas totales: N", "cuentas de sistema (UID < 1000): N" y
  # "cuentas regulares (UID 1000-60000): N". En el END usa "total + 0" para
  # que un archivo sin cuentas imprima 0 y no una cadena vacia.
  # shellcheck disable=SC2034  # el TODO 3 la usa
  local total="TODO"

  # TODO 3: un solo "awk -F:" que lea, en este orden, "$etc/shells",
  # "$etc/group" y "$etc/passwd" (distingue cada archivo por FILENAME, no
  # por NR==FNR: son tres). Guarda las shells validas (ignora comentarios y
  # lineas vacias) y los GID existentes; despues, por cada linea de passwd
  # imprime "hallazgo: ..." cuando ocurra alguno de estos cuatro casos:
  #   a) UID 0 y nombre distinto de root       -> "UID 0 extra: NOMBRE"
  #   b) UID entre 1 y 999 y shell en shells   -> "cuenta de sistema con shell: NOMBRE (SHELL)"
  #   c) GID primario que no esta en group     -> "grupo primario inexistente: NOMBRE (GID N)"
  #   d) UID repetido (salvo el 0)             -> en el END, "UID duplicado: N (a, b)"
  # Pasa la salida por "sort" para que el orden sea estable y guardala en
  # una variable, por ejemplo "hallazgos".
  local hallazgos="TODO"

  # TODO 4: cuenta las lineas no vacias de "$hallazgos" con "grep -c ."
  # protegido con "|| true". Si son 0, imprime "sin hallazgos" y "exit 0".
  # Si no, imprime "$hallazgos", luego "hallazgos: N" y termina con "exit 2".
  echo "$hallazgos"
}

cmd_pkgcheck() {
  local paquete=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *) paquete="$1"; shift ;;
    esac
  done

  # TODO 1: si "$paquete" esta vacio, imprime a stderr "toolkit pkgcheck:
  # falta el nombre del paquete" y termina con "exit 1".

  # TODO 2: decide el gestor con "command -v ... >/dev/null 2>&1" en este
  # orden: dpkg-query -> gestor="apt (dpkg)"; rpm -> gestor="dnf (rpm)";
  # pacman -> gestor="pacman". Si no esta ninguno, imprime a stderr
  # "toolkit pkgcheck: no encontre apt, dnf ni pacman en esta maquina" y
  # "exit 1". En la misma rama de cada gestor, guarda en "version" la
  # version instalada (cadena vacia si el paquete no esta instalado):
  #   dpkg-query -W -f='${db:Status-Status} ${Version}' PAQ | awk '$1 == "installed" { print $2 }'
  #   rpm -q --qf '%{VERSION}-%{RELEASE}' PAQ   (mira el codigo de salida, no el texto)
  #   pacman -Q PAQ | awk '{ print $2 }'
  # Los tres comandos fallan con codigo distinto de 0 si no hay paquete:
  # protege cada asignacion con "|| true" (o "|| version=""") por set -e.
  local gestor="TODO" version="TODO"

  echo "== toolkit pkgcheck =="
  echo "gestor: $gestor"
  echo "paquete: $paquete"

  # TODO 3: si "$version" esta vacia, imprime "estado: no instalado" y
  # termina con "exit 2". Si no, imprime "estado: instalado" y
  # "version: $version" (el codigo de salida es 0 implicito).
  echo "version: $version"
}

main() {
  local subcomando="${1:-}"
  shift || true
  case "$subcomando" in
    doctor) cmd_doctor "$@" ;;
    inventory) cmd_inventory "$@" ;;
    organize) cmd_organize "$@" ;;
    audit) cmd_audit "$@" ;;
    logreport) cmd_logreport "$@" ;;
    logscan) cmd_logscan "$@" ;;
    topcount) cmd_topcount "$@" ;;
    sumfield) cmd_sumfield "$@" ;;
    finddupes) cmd_finddupes "$@" ;;
    procwatch) cmd_procwatch "$@" ;;
    acctaudit) cmd_acctaudit "$@" ;;
    pkgcheck) cmd_pkgcheck "$@" ;;
    "")
      echo "Uso: toolkit.sh <subcomando>" >&2
      echo "Subcomandos disponibles: doctor, inventory, organize, audit, logreport, logscan, topcount, sumfield, finddupes, procwatch, acctaudit, pkgcheck" >&2
      exit 1
      ;;
    *)
      echo "toolkit.sh: subcomando desconocido: $subcomando" >&2
      exit 1
      ;;
  esac
}

main "$@"
