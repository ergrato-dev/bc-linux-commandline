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
#   toolkit.sh netcheck <host> [puerto] diagnostica la red por capas: interfaz, ruta, DNS y TCP (Semana 12)
#   toolkit.sh snapshot                 foto de la maquina: sistema, memoria, procesos, disco (Semana 13)
#   toolkit.sh snapshot --umbral N --salida archivo   avisa si el disco llega a N% y guarda el informe
#   toolkit.sh healthcheck              comprueba disco, memoria y procesos contra limites (Semana 14)
#   toolkit.sh healthcheck --solo disk,mem   ejecuta solo esas comprobaciones, en ese orden
#   toolkit.sh healthcheck --umbral-disco N --min-mem MiB --max-procesos N   ajusta los limites
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
# Codigos de salida de netcheck:  0 todo responde,  1 falta el host o puerto invalido, 2 alguna capa falla.
# Codigos de salida de snapshot:  0 disco bajo el umbral, 1 opcion o umbral invalido, 2 disco en o sobre el umbral.
# Codigos de salida de healthcheck: 0 todo en orden,     1 opcion o limite invalido, 2 alguna comprobacion falla.
#
# Este es el unico entrypoint del proyecto. doctor, inventory, organize,
# audit, logreport, logscan, topcount, sumfield, finddupes, procwatch,
# acctaudit, pkgcheck, netcheck y snapshot ya vienen completos de las
# semanas anteriores — esta semana completas healthcheck. snapshot llega
# refactorizado en funciones pequenas: leelo antes de empezar.

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
  local archivo
  for archivo in passwd group shells; do
    if [[ ! -f "$etc/$archivo" ]]; then
      echo "toolkit acctaudit: falta '$etc/$archivo'" >&2
      exit 1
    fi
  done

  echo "== toolkit acctaudit =="
  echo "directorio: $etc"

  # UID_MIN/UID_MAX de /etc/login.defs en Ubuntu: 1000 y 60000.
  local conteos
  conteos=$(awk -F: 'NF >= 7 {
    total++
    if ($3 < 1000) sistema++
    else if ($3 <= 60000) regulares++
  } END { print total + 0, sistema + 0, regulares + 0 }' "$etc/passwd")
  local total sistema regulares
  read -r total sistema regulares <<<"$conteos"
  echo "cuentas totales: $total"
  echo "cuentas de sistema (UID < 1000): $sistema"
  echo "cuentas regulares (UID 1000-60000): $regulares"

  # Un solo awk lee tres archivos: shells y group llenan tablas (NR==FNR
  # no sirve con tres archivos, por eso se compara FILENAME) y passwd se evalua.
  local hallazgos
  hallazgos=$(awk -F: -v shells="$etc/shells" -v groups="$etc/group" '
    FILENAME == shells { if ($0 !~ /^#/ && $0 != "") valida[$0] = 1; next }
    FILENAME == groups { gid[$3] = 1; next }
    NF < 7 { next }
    {
      if ($3 == 0 && $1 != "root") print "hallazgo: UID 0 extra: " $1
      if ($3 > 0 && $3 < 1000 && ($7 in valida)) print "hallazgo: cuenta de sistema con shell: " $1 " (" $7 ")"
      if (!($4 in gid)) print "hallazgo: grupo primario inexistente: " $1 " (GID " $4 ")"
      if ($3 != 0) { n[$3]++; quienes[$3] = quienes[$3] (n[$3] > 1 ? ", " : "") $1 }
    }
    END { for (u in n) if (n[u] > 1) print "hallazgo: UID duplicado: " u " (" quienes[u] ")" }
  ' "$etc/shells" "$etc/group" "$etc/passwd" | sort)

  local cantidad
  cantidad=$(printf '%s\n' "$hallazgos" | grep -c .) || true
  if [[ "$cantidad" -eq 0 ]]; then
    echo "sin hallazgos"
    exit 0
  fi

  echo "$hallazgos"
  echo "hallazgos: $cantidad"
  exit 2
}

cmd_pkgcheck() {
  local paquete=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *) paquete="$1"; shift ;;
    esac
  done
  if [[ -z "$paquete" ]]; then
    echo "toolkit pkgcheck: falta el nombre del paquete" >&2
    exit 1
  fi

  local gestor="" version=""
  if command -v dpkg-query >/dev/null 2>&1; then
    gestor="apt (dpkg)"
    # Status tiene que ser "install ok installed": un paquete quitado con
    # remove (no purge) sigue en la base de dpkg con estado "deinstall ok config-files".
    version=$(dpkg-query -W -f='${db:Status-Status} ${Version}' "$paquete" 2>/dev/null \
      | awk '$1 == "installed" { print $2 }') || true
  elif command -v rpm >/dev/null 2>&1; then
    gestor="dnf (rpm)"
    # rpm -q imprime "package X is not installed" en stdout: hay que mirar el codigo de salida.
    version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$paquete" 2>/dev/null) || version=""
  elif command -v pacman >/dev/null 2>&1; then
    gestor="pacman"
    version=$(pacman -Q "$paquete" 2>/dev/null | awk '{ print $2 }') || true
  else
    echo "toolkit pkgcheck: no encontre apt, dnf ni pacman en esta maquina" >&2
    exit 1
  fi

  echo "== toolkit pkgcheck =="
  echo "gestor: $gestor"
  echo "paquete: $paquete"

  if [[ -z "$version" ]]; then
    echo "estado: no instalado"
    exit 2
  fi

  echo "estado: instalado"
  echo "version: $version"
}

cmd_netcheck() {
  local host="" puerto=""
  while [[ $# -gt 0 ]]; do
    if [[ -z "$host" ]]; then host="$1"; else puerto="$1"; fi
    shift
  done
  if [[ -z "$host" ]]; then
    echo "toolkit netcheck: falta el host" >&2
    exit 1
  fi
  if [[ -n "$puerto" ]] && ! [[ "$puerto" =~ ^[0-9]+$ && "$puerto" -ge 1 && "$puerto" -le 65535 ]]; then
    echo "toolkit netcheck: puerto invalido: '$puerto'" >&2
    exit 1
  fi

  echo "== toolkit netcheck =="
  echo "destino: $host${puerto:+:$puerto}"

  local fallos=0

  # Capa 1-2: alguna interfaz que no sea lo con operstate "up" en /sys.
  local d nombre iface_up=""
  for d in /sys/class/net/*; do
    nombre="${d##*/}"
    [[ "$nombre" == lo ]] && continue
    if [[ "$(cat "$d/operstate" 2>/dev/null)" == up ]]; then
      iface_up="$nombre"
      break
    fi
  done
  if [[ -n "$iface_up" ]]; then
    echo "ok interfaz: $iface_up (up)"
  else
    echo "fallo interfaz: ninguna interfaz activa aparte de lo"
    fallos=$(( fallos + 1 ))
  fi

  # Capa 3: la ruta por defecto es la linea de /proc/net/route con destino 00000000.
  # El gateway esta en hexadecimal little-endian: 01001BAC = AC.1B.00.01 = 172.27.0.1.
  local ruta iface gw_hex gw
  ruta=$(awk 'NR > 1 && $2 == "00000000" { print $1, $3; exit }' /proc/net/route)
  if [[ -n "$ruta" ]]; then
    read -r iface gw_hex <<<"$ruta"
    gw=$(printf '%d.%d.%d.%d' "0x${gw_hex:6:2}" "0x${gw_hex:4:2}" "0x${gw_hex:2:2}" "0x${gw_hex:0:2}")
    echo "ok ruta por defecto: $iface via $gw"
  else
    echo "fallo ruta por defecto: no hay puerta de enlace"
    fallos=$(( fallos + 1 ))
  fi

  # DNS: getent usa la misma ruta que los programas (NSS), no solo el servidor DNS.
  local ip=""
  if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip="$host"
    echo "dns: no aplica (IP literal)"
  else
    ip=$(getent ahostsv4 "$host" | awk 'NR == 1 { print $1 }') || true
    if [[ -n "$ip" ]]; then
      echo "ok dns: $host -> $ip"
    else
      echo "fallo dns: $host no resuelve"
      fallos=$(( fallos + 1 ))
    fi
  fi

  # TCP: /dev/tcp es una funcion de bash, no un archivo: no hace falta nc ni curl.
  # Es seguro interpolar ip y puerto: ya estan validados (IPv4 o salida de getent, y entero).
  if [[ -n "$puerto" ]]; then
    if [[ -z "$ip" ]]; then
      echo "tcp: omitido (sin IP)"
    elif timeout 3 bash -c "exec 3<>/dev/tcp/$ip/$puerto" 2>/dev/null; then
      echo "ok tcp: $host:$puerto abierto"
    else
      echo "fallo tcp: $host:$puerto cerrado o sin respuesta"
      fallos=$(( fallos + 1 ))
    fi
  fi

  echo "fallos: $fallos"
  if [[ "$fallos" -gt 0 ]]; then
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Helpers de sistema (Semana 14). Cada funcion imprime UN dato en stdout y no
# toca variables globales: quien la llama lo captura con $( ).
# ---------------------------------------------------------------------------

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

sys_os_name() {
  # shellcheck source=/dev/null  # /etc/os-release lo lee bash en ejecucion, no shellcheck
  ( . /etc/os-release && echo "$PRETTY_NAME" )
}

sys_uptime_days() {
  local segundos _resto
  read -r segundos _resto < /proc/uptime
  echo $(( ${segundos%%.*} / 86400 ))
}

sys_mem_mib() {
  local memoria_kb
  memoria_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
  echo $(( memoria_kb / 1024 ))
}

sys_proc_count() {
  find /proc -mindepth 1 -maxdepth 1 -name '[0-9]*' | wc -l
}

sys_disk_usage() {
  df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
}

# Arma el informe. Recibe lo ya calculado y lo imprime: no decide nada.
snapshot_report() {
  local uso=$1 estado=$2 alerta=$3
  # $USER no existe en un contenedor lanzado con docker exec: id -un lo sustituye.
  local usuario="${USER:-$(id -un)}"
  cat <<EOT
== toolkit snapshot ==
fecha: $(date +%F)
host: $(uname -n)
usuario: $usuario
sistema: $(sys_os_name)
kernel: $(uname -r)
uptime: $(sys_uptime_days) dias
memoria: $(sys_mem_mib) MiB
procesos: $(sys_proc_count)
disco /: ${uso}%
${alerta:+$alerta
}estado: $estado
EOT
}

# Muestra el informe por pantalla o lo guarda en un archivo.
snapshot_emit() {
  local informe=$1 salida=$2
  if [[ -n "$salida" ]]; then
    mkdir -p "$(dirname "$salida")"
    printf '%s\n' "$informe" > "$salida"
    echo "informe guardado en: $salida"
  else
    printf '%s\n' "$informe"
  fi
}

cmd_snapshot() {
  local salida="" umbral=90
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --salida | --umbral)
        if [[ $# -lt 2 ]]; then
          echo "toolkit snapshot: $1 necesita un valor" >&2
          exit 1
        fi
        if [[ "$1" == --salida ]]; then salida="$2"; else umbral="$2"; fi
        shift 2
        ;;
      *)
        echo "toolkit snapshot: opcion desconocida: $1" >&2
        exit 1
        ;;
    esac
  done

  # is_uint va primero: -gt evalua su operando como aritmetica (Semana 12).
  if ! is_uint "$umbral" || [[ "$umbral" -gt 100 ]]; then
    echo "toolkit snapshot: umbral invalido: '$umbral'" >&2
    exit 1
  fi

  local uso estado="ok" alerta=""
  uso=$(sys_disk_usage)
  if [[ "$uso" -ge "$umbral" ]]; then
    estado="alerta"
    alerta="alerta: disco / al ${uso}% (umbral ${umbral}%)"
  fi

  local informe
  informe=$(snapshot_report "$uso" "$estado" "$alerta")
  snapshot_emit "$informe" "$salida"

  if [[ "$estado" == alerta ]]; then
    exit 2
  fi
}

# Una linea por comprobacion: estado, nombre y detalle. Ya viene hecha.
hc_line() { printf '%-5s %s: %s\n' "$1" "$2" "$3"; }

# Cada hc_check_NOMBRE recibe su limite como $1, imprime UNA linea con hc_line
# y sale con 0 (ok) o 1 (fallo). cmd_healthcheck las llama por nombre.

# TODO 1: hc_check_disk. Obten el uso con "uso=$(sys_disk_usage)" (declara
# "local uso" ANTES, en su propia linea: SC2155). Si uso < limite (comparacion
# numerica) imprime "hc_line ok disk "${uso}% (umbral ${limite}%)"" y sale con 0;
# si no, la misma linea con "fallo" y "return 1".
hc_check_disk() {
  local limite=$1
  hc_line fallo disk "TODO (limite ${limite})"
  return 1
}

# TODO 2: hc_check_mem. Igual, con sys_mem_mib. Ok si mem >= limite:
# "hc_line ok mem "${mem} MiB (minimo ${limite} MiB)"".
hc_check_mem() {
  local limite=$1
  hc_line fallo mem "TODO (limite ${limite})"
  return 1
}

# TODO 3: hc_check_procs. Igual, con sys_proc_count. Ok si procesos <= limite:
# "hc_line ok procs "${procesos} (maximo ${limite})"".
hc_check_procs() {
  local limite=$1
  hc_line fallo procs "TODO (limite ${limite})"
  return 1
}

cmd_healthcheck() {
  local solo="" solo_dado=0
  # Array asociativo: un limite por comprobacion, indexado por su nombre.
  local -A limite=([disk]=90 [mem]=128 [procs]=500)
  local -a orden=(disk mem procs)

  # TODO 4: recorre "$@" con "while [[ $# -gt 0 ]]" y un "case". Opciones, todas
  # con valor (shift 2): --solo LISTA (guarda en solo y pon solo_dado=1),
  # --umbral-disco N, --min-mem N y --max-procesos N (guardan en
  # limite[disk], limite[mem] y limite[procs]). Si falta el valor:
  # "toolkit healthcheck: OPCION necesita un valor" a stderr y "exit 1".
  # Cualquier otra cosa: "toolkit healthcheck: opcion desconocida: X" y "exit 1".

  # TODO 5: valida los limites. Recorre "${orden[@]}" y, si "${limite[$nombre]}"
  # no pasa is_uint, imprime "toolkit healthcheck: limite invalido para NOMBRE:
  # 'VALOR'" a stderr y "exit 1". Ademas, limite[disk] no puede pasar de 100
  # (mismo error, "exit 1"). is_uint va ANTES de cualquier -gt: Semana 12.
  local nombre=""

  # TODO 6: construye el array "pedidos". Por defecto es una copia de
  # "${orden[@]}"; si solo_dado vale 1, partelo por comas:
  # "IFS=, read -ra pedidos <<< "$solo"". Si queda vacio, error a stderr y
  # "exit 1". Cada nombre debe ser disk, mem o procs (usa un "case"); si no,
  # "toolkit healthcheck: comprobacion desconocida: 'X'" y "exit 1".
  local -a pedidos=("${orden[@]}")

  # TODO 7: recorre "${pedidos[@]}" contando "total" y "fallos" con
  # "x=$(( x + 1 ))" (nunca ((x++)) con set -e). Llama a cada comprobacion
  # POR NOMBRE: if ! "hc_check_${nombre}" "${limite[$nombre]}"; then ...
  local total=0 fallos=0

  # TODO 8: imprime "resumen: OK de TOTAL ok" (OK = total - fallos) y sal con
  # "exit 2" si hubo algun fallo (con 0 si no).
  echo "resumen: TODO ($solo $solo_dado $nombre ${pedidos[*]} $total $fallos)"
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
    netcheck) cmd_netcheck "$@" ;;
    snapshot) cmd_snapshot "$@" ;;
    healthcheck) cmd_healthcheck "$@" ;;
    "")
      echo "Uso: toolkit.sh <subcomando>" >&2
      echo "Subcomandos disponibles: doctor, inventory, organize, audit, logreport, logscan, topcount, sumfield, finddupes, procwatch, acctaudit, pkgcheck, netcheck, snapshot, healthcheck" >&2
      exit 1
      ;;
    *)
      echo "toolkit.sh: subcomando desconocido: $subcomando" >&2
      exit 1
      ;;
  esac
}

# Solo ejecuta main si lanzas el script; con "source toolkit.sh" cargas las funciones sin ejecutar nada.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
