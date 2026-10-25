# Práctica 04: netcheck a mano

Construyes **a mano**, función a función, la lógica exacta que después
completas en el starter de `toolkit.sh`. Si entiendes cada paso de aquí,
completar los `TODO` es traducir esto a variables de bash.

Todo corre dentro de `ubuntu-lab`. Los bloques *"desde tu máquina"* van en
tu terminal normal.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Validar el puerto sin ejecutar nada ajeno

**Por qué**: `netcheck` recibe un puerto del usuario, y un `[[ $p -ge 1 ]]`
**evalúa** su contenido como aritmética (archivo 08). Se demuestra con un
comando inofensivo y se corrige con una regex **antes** de la comparación.

**Comando**:

```bash
mkdir -p /tmp/p12
cat > /tmp/p12/netcheck.sh <<'EOS'
valida_puerto() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ && "$p" -ge 1 && "$p" -le 65535 ]]
}
EOS
. /tmp/p12/netcheck.sh

p='a[$(touch /tmp/p12/pwn)]'
valida_puerto "$p"; echo "valida_puerto: $?"
ls /tmp/p12/pwn
```

**Verifica**: la función rechaza el valor hostil **y** `touch` no se ejecutó.

```bash
# valida_puerto: 1
# ls: cannot access '/tmp/p12/pwn': No such file or directory
```

Y para ver lo que **habría** pasado con la comparación sin regex:

```bash
[[ $p -ge 1 ]]; ls /tmp/p12/pwn
# /tmp/p12/pwn                  <- touch SÍ se ejecutó
rm -f /tmp/p12/pwn
```

Comprueba el resto de casos:

```bash
for v in 80 0 65536 abc ""; do valida_puerto "$v" && echo "'$v' valido" || echo "'$v' invalido"; done
# '80' valido
# '0' invalido
# '65536' invalido
# 'abc' invalido
# '' invalido
```

## Paso 2: Capa 1, la interfaz

**Por qué**: la fuente más portátil es `/sys/class/net/*/operstate` (archivo
08): no depende de `ip`. Se salta `lo` porque siempre está.

**Comando**:

```bash
cat >> /tmp/p12/netcheck.sh <<'EOS'
capa_interfaz() {
  local d nombre
  for d in /sys/class/net/*; do
    nombre="${d##*/}"
    [[ "$nombre" == lo ]] && continue
    if [[ "$(cat "$d/operstate" 2>/dev/null)" == up ]]; then
      echo "ok interfaz: $nombre (up)"
      return 0
    fi
  done
  echo "fallo interfaz: ninguna interfaz activa aparte de lo"
  return 1
}
EOS
. /tmp/p12/netcheck.sh
capa_interfaz; echo "codigo: $?"
```

**Verifica**:

```bash
# ok interfaz: eth0 (up)
# codigo: 0
```

La función devuelve `0` o `1` y **imprime** su veredicto: el contador de
fallos lo llevará quien la llame (paso 6).

## Paso 3: Capa 2, la ruta por defecto

**Por qué**: la ruta por defecto es la línea de `/proc/net/route` con
destino `00000000`, y el gateway va en hexadecimal con los bytes al revés
(archivo 02).

**Comando**:

```bash
cat >> /tmp/p12/netcheck.sh <<'EOS'
capa_ruta() {
  local ruta iface gw_hex
  ruta=$(awk 'NR > 1 && $2 == "00000000" { print $1, $3; exit }' /proc/net/route)
  if [[ -z "$ruta" ]]; then
    echo "fallo ruta por defecto: no hay puerta de enlace"
    return 1
  fi
  read -r iface gw_hex <<<"$ruta"
  printf 'ok ruta por defecto: %s via %d.%d.%d.%d\n' "$iface" "0x${gw_hex:6:2}" "0x${gw_hex:4:2}" "0x${gw_hex:2:2}" "0x${gw_hex:0:2}"
}
EOS
. /tmp/p12/netcheck.sh
capa_ruta; echo "codigo: $?"
```

**Verifica**:

```bash
# ok ruta por defecto: eth0 via 172.27.0.1
# codigo: 0
```

Comprueba que coincide con `ip`: `ip -4 route show default | awk '{print $3}'`
debe imprimir la misma puerta de enlace. La IP puede ser otra en tu
laboratorio; lo que debe coincidir son las dos salidas entre sí.

## Paso 4: Capa 3, el DNS

**Por qué**: tres casos con tres respuestas distintas: un nombre que
resuelve, una IP (que no necesita DNS) y un nombre que no existe (archivo
03). `getent` y no `dig`, para resolver **como lo haría el programa**.

**Comando**:

```bash
cat >> /tmp/p12/netcheck.sh <<'EOS'
capa_dns() {
  local host="$1" ip
  if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip_resuelta="$host"
    echo "dns: no aplica (IP literal)"
    return 0
  fi
  ip=$(getent ahostsv4 "$host" | awk 'NR == 1 { print $1 }') || true
  if [[ -n "$ip" ]]; then
    ip_resuelta="$ip"
    echo "ok dns: $host -> $ip"
  else
    echo "fallo dns: $host no resuelve"
    return 1
  fi
}
EOS
. /tmp/p12/netcheck.sh
for h in localhost rhel-lab 127.0.0.1 no-existe.invalid; do capa_dns "$h"; echo "codigo: $?"; done
```

**Verifica**:

```bash
# ok dns: localhost -> 127.0.0.1
# codigo: 0
# ok dns: rhel-lab -> 172.27.0.4
# codigo: 0
# dns: no aplica (IP literal)
# codigo: 0
# fallo dns: no-existe.invalid no resuelve
# codigo: 1
```

Dos detalles: `|| true` evita que `getent` (que sale con `2` al no resolver)
rompa la asignación con `set -e` activo en el script final; y la función
**guarda** la IP en la variable global `ip_resuelta` para que la capa 4 no
tenga que resolver otra vez. El `172.27.0.4` puede ser otro en tu laboratorio.

## Paso 5: Capa 4, el puerto TCP

**Por qué**: una prueba de conexión sin `nc` ni `curl`, con la función
`/dev/tcp` de bash y un `timeout` para que una IP que descarta paquetes no
cuelgue el script (archivo 04).

**Comando**:

```bash
cat >> /tmp/p12/netcheck.sh <<'EOS'
capa_tcp() {
  local ip="$1" puerto="$2" host="$3"
  if timeout 3 bash -c "exec 3<>/dev/tcp/$ip/$puerto" 2>/dev/null; then
    echo "ok tcp: $host:$puerto abierto"
  else
    echo "fallo tcp: $host:$puerto cerrado o sin respuesta"
    return 1
  fi
}
EOS
. /tmp/p12/netcheck.sh
perl -MIO::Socket::INET -e 'my $s=IO::Socket::INET->new(Listen=>5,LocalAddr=>q(127.0.0.1),LocalPort=>18212,ReuseAddr=>1) or die; sleep 120' &
sleep 1
capa_tcp 127.0.0.1 18212 localhost; echo "codigo: $?"
capa_tcp 127.0.0.1 18999 localhost; echo "codigo: $?"
```

**Verifica**:

```bash
# ok tcp: localhost:18212 abierto
# codigo: 0
# fallo tcp: localhost:18999 cerrado o sin respuesta
# codigo: 1
```

El servidor de `perl` queda escuchando en `127.0.0.1:18212` durante dos
minutos; lo usan los pasos siguientes. Es interpolar `$ip` y `$puerto` en
`bash -c` sin riesgo porque el paso 1 ya validó el puerto y el paso 4
obtuvo la IP de `getent`.

## Paso 6: Juntarlo con un contador y un código de salida

**Por qué**: las cuatro capas devuelven `0`/`1`; `netcheck` las ejecuta
**todas**, cuenta cuántas fallan y devuelve `0` o `2` (archivo 08). Es la
función que traducirás al starter.

**Comando**:

```bash
cat >> /tmp/p12/netcheck.sh <<'EOS'
netcheck_manual() {
  local host="$1" puerto="${2:-}" fallos=0
  ip_resuelta=""
  echo "destino: $host${puerto:+:$puerto}"
  capa_interfaz || fallos=$(( fallos + 1 ))
  capa_ruta || fallos=$(( fallos + 1 ))
  capa_dns "$host" || fallos=$(( fallos + 1 ))
  if [[ -n "$puerto" ]]; then
    if [[ -z "$ip_resuelta" ]]; then
      echo "tcp: omitido (sin IP)"
    else
      capa_tcp "$ip_resuelta" "$puerto" "$host" || fallos=$(( fallos + 1 ))
    fi
  fi
  echo "fallos: $fallos"
  if [[ "$fallos" -gt 0 ]]; then
    return 2
  fi
}
EOS
. /tmp/p12/netcheck.sh
netcheck_manual localhost 18212; echo "codigo: $?"
netcheck_manual localhost 18999; echo "codigo: $?"
netcheck_manual no-existe.invalid 80; echo "codigo: $?"
```

**Verifica**:

```bash
# destino: localhost:18212
# ok interfaz: eth0 (up)
# ok ruta por defecto: eth0 via 172.27.0.1
# ok dns: localhost -> 127.0.0.1
# ok tcp: localhost:18212 abierto
# fallos: 0
# codigo: 0
# destino: localhost:18999
# ok interfaz: eth0 (up)
# ok ruta por defecto: eth0 via 172.27.0.1
# ok dns: localhost -> 127.0.0.1
# fallo tcp: localhost:18999 cerrado o sin respuesta
# fallos: 1
# codigo: 2
# destino: no-existe.invalid:80
# ok interfaz: eth0 (up)
# ok ruta por defecto: eth0 via 172.27.0.1
# fallo dns: no-existe.invalid no resuelve
# tcp: omitido (sin IP)
# fallos: 1
# codigo: 2
```

Mira el tercer caso: **un** fallo, no dos. La capa 4 se omite cuando no hay
IP, porque probar un puerto sin destino sería un falso fallo añadido.

## Paso 7: Pasarlo al starter

**Por qué**: ya tienes la lógica probada. Los `TODO` del starter son
exactamente estos pasos, con una diferencia: ahí van **dentro** de una sola
función, `cmd_netcheck`, y los fallos se cuentan con `fallos=$(( fallos + 1 ))`
(no `((fallos++))`: abortaría bajo `set -e`).

**Comando** (desde **tu máquina**, no desde el contenedor):

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-12-redes_desde_la_linea_de_comandos/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
docker exec ubuntu-lab /root/bin/toolkit.sh netcheck localhost 18212
```

**Verifica**: mientras no completes los `TODO`, `netcheck` imprime `ip: TODO`
y `fallos: 0`; cuando termines, el resultado del paso 6 con el prefijo
`== toolkit netcheck ==`.

## Paso 8: Limpiar

**Por qué**: el servidor de `perl` y los archivos de prueba no deben quedar
entre prácticas.

**Comando** (en ubuntu-lab):

```bash
pkill -x perl
rm -rf /tmp/p12
```

**Verifica**:

```bash
ss -Htln | wc -l
# 1
ls /tmp/p12 2>&1
# ls: cannot access '/tmp/p12': No such file or directory
```

## ✅ Resultado

- [ ] Viste que `[[ $p -ge 1 ]]` ejecuta código y que la regex previa lo evita
- [ ] Construiste las cuatro capas y las probaste una a una
- [ ] Montaste `netcheck_manual` con código de salida `0` limpio y `2` con fallos
- [ ] Comprobaste que un DNS roto cuenta **un** fallo y omite la capa 4
- [ ] Copiaste el starter al laboratorio con `docker cp`

```bash
./scripts/verificar-semana.sh 12
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `valida_puerto: command not found` | Cerraste la shell entre pasos | Vuelve a ejecutar `. /tmp/p12/netcheck.sh` |
| `fallo tcp` para `localhost 18212` | El servidor de `perl` terminó (120 s) | Repite el servidor del paso 5 |
| `ok interfaz` no aparece | No hay interfaz `up` distinta de `lo` | `cat /sys/class/net/*/operstate`; en el laboratorio debería haber `eth0` |
| El script se detiene tras `fallo dns` | Falta el `\|\| true` (con `set -e` activo) | Añádelo tras el `awk` de `getent` |
| `netcheck_manual` no devuelve el código esperado | Se leyó `$?` tras otro comando | Imprime `$?` **inmediatamente** después |
| `docker: command not found` dentro del contenedor | Ejecutaste el paso 7 dentro de `ubuntu-lab` | Sal con `exit` y ejecútalo en tu máquina |

---

[← Práctica 03](03-ssh-entre-contenedores.md) · [Proyecto: capa 12 de toolkit →](../3-proyecto/README.md)
