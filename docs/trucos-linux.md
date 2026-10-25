# Trucos de Linux — acumulativo

Cheatsheet que crece una sección por semana. Si el README de una semana y
esta sección difieren, **gana el README de la semana** (es el que se escribe
primero).

---

## Semana 01 — Terminal, shell y primeros pasos

- `type -a comando` muestra **todas** las coincidencias de un nombre (alias,
  función, builtin, archivo), no solo la que gana — útil para ver qué está
  tapando a qué.
- `hash -r` fuerza a bash a olvidar rutas memorizadas y volver a buscar en
  `$PATH` — el arreglo real detrás de "lo instalé pero dice que no existe".
- `man -k .` (un punto como patrón) lista todas las páginas de manual
  instaladas en el sistema — una forma de "explorar" cuando no sabes qué
  buscar.
- `Ctrl+X Ctrl+E` abre el comando que estás escribiendo en tu editor
  (`$EDITOR`) — mejor que editar carácter por carácter para comandos largos.

## Semana 02 — Navegación y sistema de archivos

- `cd -` alterna entre los dos últimos directorios sin escribir ninguna ruta.
- `readlink -f ruta` resuelve cualquier cadena de enlaces simbólicos hasta el
  destino final real.
- `cp archivo{,.bak}` respalda un archivo en un solo comando, usando
  expansión de llaves.
- `dircolors --print-database` vuelca la paleta completa que interpreta
  `LS_COLORS`, por si un color inesperado te genera dudas.

## Semana 03 — Manipulación de archivos y directorios

- `cp --backup=numbered` respalda el destino existente antes de
  sobrescribirlo, en vez de perderlo sin rastro.
- `rm -I` pregunta una sola vez en borrados masivos — más seguro que `-f`,
  menos tedioso que `-i`.
- `touch -r modelo destino` copia la fecha de un archivo a otro sin
  calcularla a mano.
- `stat -c '%Y %n' * | sort -rn` ordena archivos por fecha real de
  modificación, más preciso que fiarse del orden visual de `ls -lt`.

## Semana 04 — Permisos y propiedad

- `namei -l /ruta/completa` muestra los permisos de cada componente de una
  ruta, uno por uno — útil cuando el problema está en un directorio
  intermedio, no en el archivo final.
- `chmod --reference=otro-archivo` copia permisos exactos sin calcular el
  número.
- `find / -perm -4000 -type f 2>/dev/null` audita todos los binarios con
  SUID activo en el sistema.
- `getfacl archivo1 | setfacl --set-file=- archivo2` copia una ACL completa
  de un archivo a otro.

## Semana 05 — Redirección, pipes y flujo de datos

- `</dev/null` fuerza un EOF inmediato — útil para confirmar si un comando
  "colgado" está esperando stdin.
- `: > archivo` vacía un archivo sin borrarlo y recrearlo.
- `${PIPESTATUS[@]}` da el código de salida de cada comando de un pipeline,
  no solo el del último.
- `comando | sudo tee archivo` escribe con privilegios donde `sudo comando
  > archivo` falla.

## Semana 06 — Búsqueda de texto con grep y regex

- `grep -f patrones.txt archivo` lee los patrones a buscar desde un
  archivo (uno por línea) en vez de escribirlos todos en la línea de
  comandos — útil con listas largas de palabras prohibidas o IPs
  bloqueadas.
- `zgrep "patron" archivo.log.gz` busca directo dentro de un log
  comprimido con `gzip`, sin descomprimirlo primero a mano.
- `GREP_COLORS="mt=01;34"` (antes del comando) cambia el color de
  resaltado de la coincidencia — útil cuando el rojo/verde por defecto se
  confunde con el esquema de color de tu terminal.
- `grep -z` trata el archivo completo como registros separados por `NUL`
  en vez de por salto de línea — permite que `.` y patrones multilínea
  cuenten un registro completo como una sola "línea" lógica.

## Semana 07 — Procesamiento de texto: sed, cut, sort, uniq, tr

- `sed -n '$p'` imprime solo la última línea de un archivo, sin
  necesitar `tail`.
- `cut -d: -f2-` (rango abierto) extrae desde una columna hasta el final
  de la línea, sin saber cuántas columnas tiene en total.
- `sort -R` da un orden aleatorio — útil para elegir una muestra al azar
  de un archivo combinado con `head`.
- `tr -d '[:punct:]'` quita toda la puntuación de un texto de una sola
  vez, sin enumerar cada símbolo.

## Semana 08 — awk y pipelines de datos

- `awk 'NF'` (sin acción) imprime solo las líneas no vacías — `NF` es
  `0` en una línea vacía, que `awk` interpreta como falso.
- `awk '{ print $NF }'` imprime el último campo de cada línea, sin
  saber de antemano cuántos campos tiene.
- El operador ternario (`condicion ? si : sino`) evita un `if`/`else`
  completo para una decisión binaria simple dentro de una acción.
- `awk --version` (o `readlink -f "$(command -v awk)"` si falla)
  confirma en segundos si estás con `mawk` o `gawk`, antes de depurar
  un error de "función no definida".

## Semana 09 — Búsqueda de archivos y ejecución en lote

- `find . -maxdepth 1 -type d -empty` encuentra directorios vacíos de
  primer nivel, sin necesitar revisar cada uno a mano.
- `find /etc -iname "*.conf" 2>/dev/null` descarta los mensajes de
  "Permission denied" sin perder los resultados válidos.
- `xargs -t` imprime cada comando antes de ejecutarlo — confirma
  exactamente qué va a correr, antes de que corra de verdad.
- `nproc` da el número de núcleos disponibles, un punto de partida
  razonable para elegir un valor de `xargs -P`.

## Semana 10 — Gestión de procesos y señales

- `ps -eo pid,%mem,%cpu,cmd --sort=-%mem` ordena por mayor uso de
  memoria, sin tener que leer la lista completa a ojo.
- `trap -p` lista todos los traps activos de la sesión actual, con el
  comando exacto configurado para cada señal.
- `pkill -c -0 "patron"` cuenta coincidencias sin enviar ninguna señal
  real — a diferencia de `pkill -c` solo, que sí la envía mientras cuenta.
- `kill -l 143` traduce un código de salida de vuelta al nombre de la
  señal que lo causó, sin tener que hacer la resta a mano.

## Semana 11 — Usuarios, grupos y gestión de paquetes

- `su -s /bin/bash www-data -c id` ejecuta algo como una cuenta de
  servicio **con shell `nologin`**: `-s` fuerza una shell para esa orden,
  sin tocar `/etc/passwd`. Sin `-s`, `su www-data -c id` solo imprime
  `This account is currently not available.`
- `dpkg-query -W -f='${Installed-Size}\t${Package}\n' | sort -rn | head -3`
  lista los paquetes que más espacio ocupan (en KiB), sin parsear
  `dpkg -l`: el formato lo eliges tú con `-f`.
- `passwd -Sa | awk '$2 == "L"'` lista de golpe todas las cuentas con la
  contraseña bloqueada; `passwd -Sa` sola da el estado de **todas**.
- `getent passwd 1000` busca por **UID numérico** (y `getent group 27` por
  GID): la forma de traducir el número que ves en `ls -n` a un nombre.

## Semana 12 — Redes desde la línea de comandos

- `getent -s dns hosts nombre` consulta **solo** la fuente `dns` de NSS, y
  `getent -s files hosts nombre` solo `/etc/hosts`: separa "es mi archivo
  local" de "es el DNS" sin salir de `getent`.
- `ss -tni state established` añade por conexión los contadores internos
  de TCP (`rtt`, `cwnd`, `mss`): el tiempo de ida y vuelta real de una
  conexión viva, sin `ping`.
- `ssh -J servidor-intermedio usuario@destino` salta por un servidor
  intermedio con una sola orden (*ProxyJump*): llega a una máquina que solo
  se ve desde el intermedio.
- `ssh -o ControlMaster=auto -o ControlPath=/tmp/cm-%r@%h:%p -o ControlPersist=30 host`
  reutiliza **una** conexión para las siguientes: tres `ssh` seguidos
  tardaron 0,56 s sin ella y 0,21 s con ella en el laboratorio.
- `sed -i` falla sobre `/etc/hosts` dentro de un contenedor (`Device or
  resource busy`) porque Docker lo monta como archivo: se escribe **dentro**
  con `>>` o `cat >`, y se restaura con `cp`.

## Semana 13 — Fundamentos de bash scripting

- Dentro de un script, `PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '` antes de `set -x`
  hace que cada línea trazada lleve `archivo:línea`: `+ ps4b.sh:4: x=5`.
  (Como variable de entorno delante de `bash -x`, no surtió efecto en la
  prueba del laboratorio: va **dentro** del script.)
- `shellcheck -f diff script.sh | patch -p1 script.sh` **aplica** los
  arreglos que `shellcheck` sabe hacer solo (comillas, `cd ... || exit`). La imagen
  mínima no trae `patch`: `apt-get install -y patch`. Revisa el resultado
  con `git diff` o `diff` antes de fiarte.
- `printf -v variable 'formato' args` guarda el resultado **en una variable**
  sin subshell ni `$( )`: `printf -v fecha '%(%F)T' -1` deja `2026-10-25` en
  `$fecha`.
- `: "${DIR:?falta DIR}"` exige una variable **sin ejecutar nada más**: `:`
  es un comando que no hace nada y su argumento se expande, así que
  `${DIR:?}` aborta el script con el mensaje. Mensaje en `stderr` y código
  `1`, y una sola línea al principio del script para sus requisitos.

## Semana 14 — Control de flujo y funciones en bash

- `shopt -s lastpipe` hace que el **último** comando de una tubería corra en la
  shell actual: `printf 'a\nb\n' | while read -r l; do n=$((n+1)); done`
  deja `n=2` en lugar de `0`. Solo funciona en scripts (sin control de
  trabajos); en el laboratorio dio `n=2` en las cuatro distribuciones.
- `"${a[@]@Q}"` entrecomilla **cada elemento** de forma que se pueda pegar de
  vuelta en bash: con `a=(uno "dos tres" "it's")` imprime `'uno' 'dos tres'
  'it'\''s'`. Es la forma limpia de mostrar un array en un mensaje de error.
- `mapfile -d '' -t archivos < <(find . -name '*.txt' -print0)` carga en un
  array nombres de archivo **con cualquier carácter** (el separador es el byte
  nulo): es `read -d ''` sin el bucle.
- `echo ${!hc_*}` expande a los **nombres** de las variables que empiezan por
  `hc_` (`hc_a hc_b`): para depurar "qué variables dejó mi script" sin
  `declare -p` entero.

## Semana 15 — Scripts robustos: manejo de errores

- `flock -n -E 9 archivo.lock comando` elige **tú** el código de salida cuando
  el bloqueo está ocupado (aquí `9`), en lugar del `1` por defecto, que se
  confunde con un fallo del propio comando. En el laboratorio dio `9` en las
  cuatro distribuciones.
- `wait -n` espera al **primero** de los trabajos en segundo plano que
  termine y devuelve su código: con `sleep 1 & sleep 2 & wait -n` vuelve a
  1 s, no a 2. Sirve para lanzar varias tareas y reaccionar a la primera que
  acabe o falle.
- `$EPOCHREALTIME` da la hora en segundos con microsegundos (`1761387302.481213`)
  sin lanzar ningún proceso: restando dos lecturas mides cuánto tardó un
  trozo del script con más precisión que `$SECONDS`.

---

[← Volver al índice de documentación](README.md)
