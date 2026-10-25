# Práctica 01: interfaces, rutas y puertos

Recorres las tres primeras capas del diagnóstico sobre el laboratorio: qué
interfaz tienes, por dónde sales y qué escucha en tu máquina. Todo es
**lectura**: los contenedores no tienen `NET_ADMIN` y no cambias la red de
nadie.

Los bloques marcados *"en ubuntu-lab"* se ejecutan dentro del contenedor y
los marcados *"desde tu máquina"*, en tu terminal normal.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Instalar las herramientas de red

**Por qué**: la imagen mínima no trae `ip`, `ss`, `ping`, `curl`, `dig` ni
`nc` (archivo 01). Instalarlas es el primer uso real de lo aprendido en la
Semana 11 con `apt`.

**Comando** (en ubuntu-lab):

```bash
# Antes de instalar, comprueba qué falta: command -v imprime la ruta o nada.
for b in ip ss ping curl dig nc ssh; do command -v "$b" >/dev/null || echo "falta: $b"; done
apt-get update >/dev/null
apt-get install -y iproute2 iputils-ping iputils-tracepath curl dnsutils netcat-openbsd openssh-client >/dev/null
```

**Verifica**:

```bash
for b in ip ss ping curl dig nc ssh tracepath; do command -v "$b" >/dev/null && echo "ok: $b" || echo "falta: $b"; done
# ok: ip
# ok: ss
# ok: ping
# ok: curl
# ok: dig
# ok: nc
# ok: ssh
# ok: tracepath
```

## Paso 2: Inventario de interfaces

**Por qué**: la capa 1 del diagnóstico: ¿hay una interfaz activa? Lo
miras con `ip` y con el archivo del kernel, para ver que son la misma
información.

**Comando**:

```bash
ip -br addr
ip -br link
cat /sys/class/net/eth0/operstate
ls /sys/class/net
```

**Verifica**:

```bash
ip -br addr
# lo               UNKNOWN        127.0.0.1/8 ::1/128
# eth0@if911       UP             172.27.0.5/16
cat /sys/class/net/eth0/operstate
# up
ls /sys/class/net
# eth0
# lo
```

Tu IP, el número tras `@if` y la MAC serán otros: lo que debe coincidir es
la **forma** (`lo` y `eth0`, y `eth0` en `UP`).

## Paso 3: Leer la dirección y calcular la red

**Por qué**: el prefijo CIDR decide qué máquinas ves directamente y cuáles
necesitan puerta de enlace (archivo 01). Extraerlo con una línea es lo que
hará `netcheck` más adelante en otra forma.

**Comando**:

```bash
ip -4 -o addr show eth0 | awk '{print $4}'
hostname -I
```

**Verifica**:

```bash
ip -4 -o addr show eth0 | awk '{print $4}'
# 172.27.0.5/16
hostname -I
# 172.27.0.5
```

Ahora **tú**, sin comando: con ese `/16`, ¿cuántas máquinas caben en la
red y cuál es la máscara? La respuesta es `65534` y `255.255.0.0`: 16
bits de máquina dan `2^16 - 2` direcciones (se descartan la de red y la de
difusión). Y comprueba que el vecino que va a ser tu servidor de pruebas
está **en tu misma red**:

```bash
getent hosts rhel-lab
# 172.27.0.4      rhel-lab
```

`172.27.0.4` y tu IP comparten `172.27`: misma red `/16`, trato directo.

## Paso 4: La tabla de rutas y la puerta de enlace

**Por qué**: la capa 2. Quieres ver que hay **dos** rutas (la local y la
por defecto) y saber con qué comando preguntar al kernel por un destino
concreto (archivo 02).

**Comando**:

```bash
ip route
ip route get 172.27.0.4
ip route get 8.8.8.8
ip -4 route show default | awk '{print $3}'
```

**Verifica**:

```bash
ip route
# default via 172.27.0.1 dev eth0
# 172.27.0.0/16 dev eth0 proto kernel scope link src 172.27.0.5

ip route get 172.27.0.4
# 172.27.0.4 dev eth0 src 172.27.0.5 uid 0
#     cache

ip route get 8.8.8.8
# 8.8.8.8 via 172.27.0.1 dev eth0 src 172.27.0.5 uid 0
#     cache

ip -4 route show default | awk '{print $3}'
# 172.27.0.1
```

Fíjate: el destino de tu red **no** lleva `via`; el de fuera sí. Esa es la
diferencia entre entrega directa y entrega por la puerta de enlace.

Comprueba también que la puerta de enlace responde, y que **no puedes
modificar** la tabla desde aquí:

```bash
ping -c1 -W1 172.27.0.1 | grep 'received'
# 1 packets transmitted, 1 received, 0% packet loss, time 0ms
ip route add 10.88.0.0/24 via 172.27.0.1
# RTNETLINK answers: Operation not permitted
```

El segundo comando falla a propósito: el contenedor no tiene la capacidad
`NET_ADMIN`, y es una protección del laboratorio.

## Paso 5: Decodificar `/proc/net/route` a mano

**Por qué**: es la fuente que usará `netcheck` para la capa 2 (archivo 02).
Aquí lo haces despacio para entender la trampa de los bytes invertidos.

**Comando**:

```bash
cat /proc/net/route
awk 'NR > 1 && $2 == "00000000" { print $1, $3 }' /proc/net/route
```

**Verifica**:

```bash
awk 'NR > 1 && $2 == "00000000" { print $1, $3 }' /proc/net/route
# eth0 01001BAC
```

`01001BAC`: ¿qué IP es? Hazlo primero **a mano** (bytes `01 00 1B AC`, de
derecha a izquierda: `AC`=172, `1B`=27, `00`=0, `01`=1) y comprueba con
bash:

```bash
gw_hex=01001BAC
printf '%d.%d.%d.%d\n' "0x${gw_hex:6:2}" "0x${gw_hex:4:2}" "0x${gw_hex:2:2}" "0x${gw_hex:0:2}"
# 172.27.0.1
```

Y la trampa clásica, para que la reconozcas cuando la veas:

```bash
printf '%d\n' 01001BAC
# bash: printf: 01001BAC: invalid octal number
```

Sin `0x`, `printf` lo toma por octal. Y comprueba que coincide con lo que
dice `ip`:

```bash
ip -4 route show default | awk '{print $3}'
# 172.27.0.1
```

## Paso 6: Levantar dos servidores y verlos con `ss`

**Por qué**: capa 4. Para practicar `ss` necesitas algo que escuche. Se
abren dos con `perl`: uno en `127.0.0.1` y otro en `0.0.0.0` (archivo 04).

**Comando** (en ubuntu-lab):

```bash
# Viven 300 segundos como máximo; el paso 8 los apaga antes con pkill.
perl -MIO::Socket::INET -e 'my $s=IO::Socket::INET->new(Listen=>5,LocalAddr=>q(127.0.0.1),LocalPort=>18080,ReuseAddr=>1) or die; sleep 300' &
perl -MIO::Socket::INET -e 'my $s=IO::Socket::INET->new(Listen=>5,LocalAddr=>q(0.0.0.0),LocalPort=>18081,ReuseAddr=>1) or die; sleep 300' &
sleep 1
ss -tlnp
```

**Verifica**:

```bash
ss -tlnp
# State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
# LISTEN 0      5          127.0.0.1:18080      0.0.0.0:*    users:(("perl",pid=7247,fd=3))
# LISTEN 0      4096      127.0.0.11:42129      0.0.0.0:*
# LISTEN 0      5            0.0.0.0:18081      0.0.0.0:*    users:(("perl",pid=7248,fd=3))
```

Los PID y el puerto `42129` serán otros. Lo importante: ves `18080` en
`127.0.0.1`, `18081` en `0.0.0.0`, y una tercera línea sin proceso: el DNS
interno de Docker (`127.0.0.11`).

Un filtro y un recuento:

```bash
ss -Htln | wc -l
# 3
ss -tlnp 'sport = :18080' | tail -1 | awk '{print $4}'
# 127.0.0.1:18080
```

## Paso 7: Probarlos desde otro contenedor

**Por qué**: el servidor del `18080` funciona **desde dentro** y falla
desde fuera. Es el error más frecuente de "mi servicio no responde"
(archivo 04) y tienes que haberlo visto con tus ojos.

**Comando** (desde tu máquina):

```bash
for p in 18080 18081; do
  docker exec rhel-lab bash -c "timeout 2 bash -c 'exec 3<>/dev/tcp/ubuntu-lab/$p' 2>/dev/null && echo '$p abierto' || echo '$p rechazado (codigo '\$?')'"
done
```

**Verifica**:

```bash
# 18080 rechazado (codigo 1)
# 18081 abierto
```

Y desde dentro, ambos responden (es la misma máquina):

```bash
nc -zv -w2 127.0.0.1 18080
# Connection to 127.0.0.1 18080 port [tcp/*] succeeded!
nc -zv -w2 127.0.0.1 18081
# Connection to 127.0.0.1 18081 port [tcp/*] succeeded!
```

`18080` solo existe para la propia máquina; `18081` también para la red.

## Paso 8: Limpiar

**Por qué**: los servidores de prueba no deben quedar vivos entre
prácticas (y `18080` lo volverán a usar los pasos de otras prácticas).

**Comando** (en ubuntu-lab):

```bash
pkill -x perl
sleep 1
ss -Htln | wc -l
```

**Verifica**:

```bash
ss -Htln | wc -l
# 1
```

Solo queda el DNS de Docker.

## ✅ Resultado

- [ ] Instalaste las herramientas de red y las listaste con `command -v`
- [ ] Leíste la IP y el prefijo, y calculaste el tamaño de la red
- [ ] Obtuviste la puerta de enlace con `ip` **y** decodificando `/proc/net/route`
- [ ] Viste el servidor de `127.0.0.1` rechazado desde otro contenedor y el de `0.0.0.0` abierto
- [ ] Dejaste `ss -Htln | wc -l` en `1`

```bash
./scripts/verificar-semana.sh 12
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ip: command not found` | No se instaló `iproute2` | Paso 1; recuerda `apt-get update` antes |
| `ss -tlnp` no muestra `perl` | Los servidores terminaron (300 s) o se lanzaron sin `&` | Repite el paso 6 |
| `Address already in use` al lanzar `perl` | Un servidor anterior sigue vivo | `pkill -x perl` y repite |
| El `docker exec rhel-lab ...` imprime `abierto` para `18080` | Se lanzó el servidor de `18080` con `0.0.0.0` por error | Revisa el `LocalAddr` del paso 6 |
| `Could not resolve host: rhel-lab` | Los contenedores no comparten red | `./scripts/start.sh` los recrea en la misma red |
| `ip route add` funciona | Estás en tu máquina real, no en el contenedor | Comprueba el prompt: debe decir `root@ubuntu-lab`; **no** pruebes rutas en tu host |

---

[← Construyendo netcheck](../1-teoria/08-construyendo-netcheck.md) · [Práctica 02 →](02-dns-y-curl-contra-el-laboratorio.md)
