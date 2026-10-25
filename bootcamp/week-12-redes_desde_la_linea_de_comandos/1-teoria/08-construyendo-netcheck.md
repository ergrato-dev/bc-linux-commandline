# Construyendo `netcheck`

> Los siete archivos anteriores enseñaron cada pieza por separado. Este las
> junta en el subcomando `netcheck` del `toolkit`: un diagnóstico por capas
> en una orden, con un código de salida que un script puede usar.

## 🎯 Objetivos

- Diseñar `netcheck` decidiendo, capa por capa, qué fuente de datos usar y por qué
- Validar un puerto sin dejar que un argumento hostil ejecute código en un `[[ ]]`
- Contar fallos sin que `set -e` aborte el script a mitad
- Elegir los códigos de salida: `0`, `1` (uso) y `2` (hallazgo)

## 1. Qué problema resuelve

Ya sabes diagnosticar a mano (archivo 06). Hacerlo cada vez, con cinco
comandos y de memoria, es lento y se hace mal a las 3 de la mañana.
`netcheck` automatiza el recorrido y deja un registro legible:

```bash
toolkit.sh netcheck rhel-lab 8000
# == toolkit netcheck ==
# destino: rhel-lab:8000
# ok interfaz: eth0 (up)
# ok ruta por defecto: eth0 via 172.27.0.1
# ok dns: rhel-lab -> 172.27.0.4
# ok tcp: rhel-lab:8000 abierto
# fallos: 0
```

Y cuando falla, **dice qué capa**:

```bash
toolkit.sh netcheck rhel-lab 9999; echo "codigo: $?"
# == toolkit netcheck ==
# destino: rhel-lab:9999
# ok interfaz: eth0 (up)
# ok ruta por defecto: eth0 via 172.27.0.1
# ok dns: rhel-lab -> 172.27.0.4
# fallo tcp: rhel-lab:9999 cerrado o sin respuesta
# fallos: 1
# codigo: 2
```

## 2. Cómo funciona

### 2.1 Una fuente por capa, y la más portátil

| Capa | Fuente elegida | Por qué esa y no otra |
|---|---|---|
| Interfaz | `/sys/class/net/*/operstate` | Existe siempre; `ip` puede no estar instalado (archivo 01) |
| Ruta | `/proc/net/route` | Idem: un archivo del kernel, sin dependencias (archivo 02) |
| DNS | `getent ahostsv4` | Resuelve **como lo hará el programa**, pasando por NSS y `/etc/hosts` (archivo 03) |
| TCP | `/dev/tcp` de bash | Función de bash: no hace falta `nc` ni `curl` (archivo 04) |

El criterio es el mismo en las cuatro: **ninguna depende de un paquete que
la imagen mínima no trae**. Un diagnóstico que no arranca porque falta
`iproute2` no sirve justo en el momento en que más lo necesitas.

`netcheck` **no usa** `ping`: ICMP lo bloquean muchos servidores y no prueba
el servicio (archivo 06). Y **no usa** `curl`: comprueba hasta la capa 4; la
capa 5 es otra pregunta (cada servicio tiene su protocolo).

### 2.2 Los argumentos y su validación

```bash
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
```

El primer argumento es el host y el segundo (opcional) el puerto. Salir
con `1` ante un uso inválido es la convención de toda la fase: `1` es "me
usaste mal"; `2` será "encontré un problema".

#### El orden dentro del `[[ ]]` importa

`[[ "$puerto" -ge 1 ]]` **evalúa el contenido como una expresión
aritmética**. Bash trata el valor de la variable como código si tiene la
forma `a[$(comando)]`. Se puede ver, sin riesgo, en el laboratorio:

```bash
p='a[$(touch /tmp/pwn)]'
[[ $p -ge 1 ]]; ls /tmp/pwn
# /tmp/pwn                    <- ¡se ejecutó touch: el "puerto" corrió un comando!
rm -f /tmp/pwn

[[ $p =~ ^[0-9]+$ && $p -ge 1 ]]; ls /tmp/pwn
# ls: cannot access '/tmp/pwn': No such file or directory
```

La segunda forma **no lo ejecuta** porque `&&` corta en cuanto la primera
condición es falsa: la regex `^[0-9]+$` rechaza `a[$(...)]` antes de que
llegue a la comparación numérica. Siempre: **primero comprobar que es un
número con regex, luego compararlo**. Es el patrón de validación de entrada
de todo el bootcamp.

Esto también justifica algo del apartado 2.5: como `host` y `puerto` ya
están validados cuando llegan al `bash -c`, es seguro interpolarlos.

### 2.3 Capa 1: interfaz

```bash
  local d nombre iface_up=""
  for d in /sys/class/net/*; do
    nombre="${d##*/}"
    [[ "$nombre" == lo ]] && continue
    if [[ "$(cat "$d/operstate" 2>/dev/null)" == up ]]; then
      iface_up="$nombre"
      break
    fi
  done
```

`${d##*/}` quita todo hasta la última `/`: de `/sys/class/net/eth0` deja
`eth0`. Se salta `lo` (siempre `unknown`, y siempre está) y se queda con la
primera interfaz `up`. Si no hay ninguna, la capa 1 falla.

### 2.4 Capa 2: la ruta por defecto, y decodificar el gateway

```bash
  local ruta iface gw_hex gw
  ruta=$(awk 'NR > 1 && $2 == "00000000" { print $1, $3; exit }' /proc/net/route)
  if [[ -n "$ruta" ]]; then
    read -r iface gw_hex <<<"$ruta"
    gw=$(printf '%d.%d.%d.%d' "0x${gw_hex:6:2}" "0x${gw_hex:4:2}" "0x${gw_hex:2:2}" "0x${gw_hex:0:2}")
    echo "ok ruta por defecto: $iface via $gw"
  fi
```

Es la decodificación del archivo 02 (bytes de derecha a izquierda) dentro
de una función. `awk` imprime `interfaz gateway_hex` y sale con `exit` en la
primera coincidencia; `read -r iface gw_hex <<<"$ruta"` las separa en dos
variables sin crear otro proceso.

### 2.5 Capa 3 y 4: DNS y TCP

```bash
  local ip=""
  if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip="$host"
    echo "dns: no aplica (IP literal)"
  else
    ip=$(getent ahostsv4 "$host" | awk 'NR == 1 { print $1 }') || true
```

Dos detalles que son trampas de `set -euo pipefail`:

- `getent` sale con `2` si no resuelve, y con `pipefail` **toda la
  tubería** falla, así que la asignación aborta el script. El `|| true`
  evita que `set -e` corte antes de poder escribir `fallo dns`.
- `ahostsv4` y no `hosts`: `getent hosts` puede devolver una dirección
  **IPv6** primero, y el laboratorio no tiene ruta IPv6.

La prueba TCP:

```bash
    elif timeout 3 bash -c "exec 3<>/dev/tcp/$ip/$puerto" 2>/dev/null; then
      echo "ok tcp: $host:$puerto abierto"
    else
      echo "fallo tcp: $host:$puerto cerrado o sin respuesta"
```

- `/dev/tcp/IP/puerto` **no es un archivo**: bash lo reconoce y abre un
  socket. `exec 3<>...` lo asigna al descriptor 3; si la conexión falla, el
  `exec` falla y el `bash -c` sale con `1`.
- `timeout 3` limita la espera: sin él, una IP que descarta paquetes
  (archivo 04, *timeout*) dejaría el script colgado minutos.
- Se usa la **IP** ya resuelta, no el nombre, para no resolver dos veces.
- Si no hay `ip` (el DNS falló), se imprime `tcp: omitido (sin IP)`: probar
  un puerto sin destino sería un falso fallo adicional (archivo 06).

### 2.6 Contar fallos sin que `set -e` aborte

```bash
fallos=$(( fallos + 1 ))
```

Parece una forma rara de escribir `((fallos++))`, y es **a propósito**:

```bash
bash -c 'set -e; f=0; ((f++)); echo no-llega'; echo "codigo: $?"
# codigo: 1                          <- el script abortó: ((f++)) vale 0 la primera vez
bash -c 'set -e; f=0; f=$(( f + 1 )); echo f=$f'
# f=1
```

`((expr))` sale con `1` cuando la expresión vale `0`, y `f++` **devuelve el
valor anterior** (`0` la primera vez). Con `set -e` eso mata el script en el
primer fallo, justo cuando querías **seguir** contando. `fallos=$(( ... ))`
es una asignación: siempre sale con `0`.

### 2.7 Los tres códigos de salida

```bash
  echo "fallos: $fallos"
  if [[ "$fallos" -gt 0 ]]; then
    exit 2
  fi
```

| Código | Significa | Quién lo usa |
|:--:|---|---|
| `0` | Todas las capas responden | un `if toolkit.sh netcheck ...; then` |
| `1` | Uso inválido (falta host, puerto fuera de rango) | quien lo invoca mal |
| `2` | Al menos una capa falla | cron o un monitor, para alertar |

## 3. Cómo se usa

```bash
toolkit.sh netcheck localhost 18080     # servidor local
toolkit.sh netcheck 127.0.0.1           # IP literal: sin DNS ni TCP
toolkit.sh netcheck no-existe.invalid 80
# == toolkit netcheck ==
# destino: no-existe.invalid:80
# ok interfaz: eth0 (up)
# ok ruta por defecto: eth0 via 172.27.0.1
# fallo dns: no-existe.invalid no resuelve
# tcp: omitido (sin IP)
# fallos: 1
```

Un DNS roto cuenta **un** fallo, no dos: la capa 4 se omite. Es la regla
del archivo 06 hecha código: un fallo bajo explica el de arriba.

`netcheck` en un script:

```bash
# if consume el código de salida: no hace falta mirar $?.
if toolkit.sh netcheck rhel-lab 8000 >/dev/null; then
  echo "rhel-lab:8000 disponible"
else
  echo "rhel-lab:8000 NO disponible" >&2
fi
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `[[ "$puerto" -ge 1 ]]` sin validar antes con regex | Evalúa su contenido como aritmética: un argumento hostil ejecuta código | `[[ $p =~ ^[0-9]+$ && $p -ge 1 ]]` |
| `((fallos++))` con `set -e` | Aborta en el primer fallo (el valor anterior es `0`) | `fallos=$(( fallos + 1 ))` |
| Abortar en la primera capa que falla | Oculta los demás fallos | Contar y seguir; omitir solo lo que depende de lo roto |
| Depender de `ip` o `nc` en el diagnóstico | No están en la imagen mínima | `/sys`, `/proc` y `/dev/tcp` |
| Probar TCP sin `timeout` | Una IP que descarta paquetes cuelga el script | `timeout 3 bash -c ...` |
| Usar el nombre en vez de la IP en la prueba TCP | Resuelve otra vez y puede dar otra IP | Reutilizar la IP de la capa 3 |

## 5. Trucos

- `${puerto:+:$puerto}` expande a `:puerto` **solo si** `puerto` tiene valor:
  así `destino: rhel-lab` y `destino: rhel-lab:8000` salen de la misma línea
  de `echo`.
- `read -r a b <<<"$cadena"` parte una cadena en variables sin `awk` ni
  `cut`: here-string de bash.
- `bash -x toolkit.sh netcheck localhost` imprime cada orden que ejecuta:
  la manera más rápida de ver por qué una capa decidió lo que decidió.

## 📚 Recursos Adicionales

- Bash Reference Manual, sección *Redirections*: la entrada de `/dev/tcp`
- Bash Reference Manual, sección *Shell Arithmetic*: por qué `[[ ]]` evalúa

## ✅ Checklist de Verificación

- [ ] Reprodujiste la inyección `a[$(touch /tmp/pwn)]` y viste cómo la regex la corta
- [ ] Reprodujiste el `((f++))` que aborta con `set -e`
- [ ] `toolkit.sh netcheck` sin host sale con `1`; con un puerto cerrado, con `2`
- [ ] Sabes explicar por qué un DNS roto cuenta un solo fallo

---

[← SSH: claves, config y scp](07-ssh-claves-config-y-scp.md) · [Práctica 01: interfaces, rutas y puertos →](../2-practicas/01-interfaces-rutas-y-puertos.md)
