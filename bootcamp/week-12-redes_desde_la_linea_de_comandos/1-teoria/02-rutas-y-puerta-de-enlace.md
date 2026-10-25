# Rutas y puerta de enlace

> Tener una IP no basta: hay que saber **por dónde salir**. La tabla de
> rutas decide, para cada destino, a qué máquina se entrega el paquete.

## 🎯 Objetivos

- Leer `ip route` y distinguir la ruta de la red local de la ruta por defecto
- Preguntar al kernel por qué camino saldrá un destino concreto con `ip route get`
- Decodificar a mano la puerta de enlace en `/proc/net/route`
- Distinguir "sin ruta" de "ruta que no responde"

## 1. Qué problema resuelve

El archivo 01 terminó con una pregunta: `172.27.0.5` y `172.27.0.4` están
en la misma red `/16` y se hablan directamente, pero `8.8.8.8` no. ¿A quién
se le entrega un paquete cuyo destino está **fuera** de tu red?

La respuesta es la **tabla de rutas**: una lista de reglas "los destinos de
este rango salen por aquí". Si falta la regla correcta, el paquete ni
siquiera sale de tu máquina y el error aparece antes de gastar un segundo en
DNS o en el servidor remoto: por eso es la segunda capa del diagnóstico.

## 2. Cómo funciona

### 2.1 Las dos rutas de una máquina normal

```bash
ip route
# default via 172.27.0.1 dev eth0
# 172.27.0.0/16 dev eth0 proto kernel scope link src 172.27.0.5
```

| Línea | Se lee como |
|---|---|
| `172.27.0.0/16 dev eth0 ... src 172.27.0.5` | "Lo que esté en `172.27.0.0/16` está **directamente** conectado a `eth0`; yo me presento con la IP `172.27.0.5`". El kernel la crea solo al asignar la IP (`proto kernel`) |
| `default via 172.27.0.1 dev eth0` | "Todo lo demás se entrega a `172.27.0.1` (la **puerta de enlace**, *gateway*) por `eth0`, y ella se encarga de reenviarlo" |

`default` es la forma abreviada de `0.0.0.0/0`: el prefijo de 0 bits, que
coincide con **cualquier** destino. Como es la regla menos específica, solo se
usa cuando ninguna otra encaja.

### 2.2 La regla más específica gana

El kernel elige, entre las rutas que encajan con el destino, la de
**prefijo más largo** (*longest prefix match*):

- Para `172.27.0.4`, encajan `/16` y `default`. Gana `/16`: entrega directa.
- Para `8.8.8.8`, solo encaja `default`: se entrega a la puerta de enlace.

La puerta de enlace tiene que estar **en tu propia red** (`172.27.0.1` está
en `172.27.0.0/16`); si no, el kernel no sabría cómo entregarle el paquete.

### 2.3 Preguntarle al kernel: `ip route get`

En lugar de razonar la tabla de cabeza, pregúntale. Es el comando más útil de
este archivo:

```bash
ip route get 8.8.8.8
# 8.8.8.8 via 172.27.0.1 dev eth0 src 172.27.0.5 uid 0
#     cache

ip route get 172.27.0.4
# 172.27.0.4 dev eth0 src 172.27.0.5 uid 0
#     cache

ip route get 127.0.0.1
# local 127.0.0.1 dev lo src 127.0.0.1 uid 0
#     cache <local>
```

Sin `via`, el destino está en la red local (entrega directa). Con `via`,
sale por la puerta de enlace. Con `local`, es la propia máquina.

### 2.4 Cómo se ve por dentro: `/proc/net/route`

`ip` lee de `/proc/net/route`, un archivo que el kernel genera al vuelo. Es
la fuente que usará `toolkit netcheck`, porque está **siempre**, tengas o no
`iproute2` instalado:

```bash
cat /proc/net/route
# Iface  Destination  Gateway   Flags RefCnt Use Metric Mask      MTU Window IRTT
# eth0   00000000     01001BAC  0003  0      0   0      00000000  0   0      0
# eth0   00001BAC     00000000  0001  0      0   0      0000FFFF  0   0      0
```

Tres cosas hay que saber leer:

1. **`Destination 00000000` y `Mask 00000000`** es la ruta por defecto
   (`0.0.0.0/0`). Es la línea que `netcheck` busca.
2. **Los números están en hexadecimal y en orden *little-endian***: los
   bytes aparecen **al revés**. `01001BAC` son los bytes `01 00 1B AC`; leídos
   de derecha a izquierda, `AC.1B.00.01`, que en decimal es `172.27.0.1`.
3. **`Flags`** es una suma de bits: `1` = ruta activa (*UP*), `2` = usa
   puerta de enlace (*GATEWAY*). `0003` = activa **y** con gateway; `0001` =
   activa y directa.

Decodificarlo con bash puro (sin `ip`) es un ejercicio de cortar la cadena
hexadecimal de dos en dos:

```bash
# ${var:desplazamiento:longitud} extrae un trozo de la cadena; 0x.. hace que
# printf %d interprete hexadecimal. Los bytes se leen de derecha a izquierda.
gw_hex=01001BAC
printf '%d.%d.%d.%d\n' "0x${gw_hex:6:2}" "0x${gw_hex:4:2}" "0x${gw_hex:2:2}" "0x${gw_hex:0:2}"
# 172.27.0.1
```

La misma función sirve para la máscara de la red local (`0000FFFF`):

```bash
m=0000FFFF; printf '%d.%d.%d.%d\n' "0x${m:6:2}" "0x${m:4:2}" "0x${m:2:2}" "0x${m:0:2}"
# 255.255.0.0
```

Y la trampa clásica: sin el prefijo `0x`, `printf %d 01001BAC` lo toma por un
número **octal** y falla con `invalid octal number`.

## 3. Cómo se usa

```bash
# La puerta de enlace en una sola palabra, lista para un script.
ip -4 route show default | awk '{print $3}'
# 172.27.0.1

# Lo mismo con la ruta hacia un destino concreto (el campo tras "via").
ip route get 8.8.8.8 | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") print $(i+1) }'
# 172.27.0.1
```

### 3.1 Comprobar que la puerta de enlace responde

La puerta de enlace es la primera máquina de la ruta de salida. Si no
responde, nada de fuera funcionará aunque el resto esté bien:

```bash
ping -c1 -W1 172.27.0.1
# 1 packets transmitted, 1 received, 0% packet loss, time 0ms
```

### 3.2 `tracepath`: ver el camino salto a salto

```bash
# -n: no resuelvas nombres (más rápido y no depende del DNS); -m: máximo de saltos.
tracepath -n rhel-lab
#  1?: [LOCALHOST]                      pmtu 1500
#  1:  172.27.0.4                                            0.084ms reached
#  1:  172.27.0.4                                            0.026ms reached
#      Resume: pmtu 1500 hops 1 back 1
```

Un solo salto y `reached`: `rhel-lab` está en tu misma red, sin
intermediarios. Hacia fuera, el primer salto es siempre la puerta de enlace
(`172.27.0.1`). `tracepath` viene con `iputils` y no exige `root`; `traceroute` es
otro programa, con otro paquete, que aquí no se usa.

> En una máquina real, `tracepath` hacia internet lista los routers de tu
> proveedor: son direcciones de tu red real, no las copies en una consulta
> pública sin pensarlo.

### 3.3 Qué significa cada fallo

| Síntoma | Qué ha pasado | Dónde mirar |
|---|---|---|
| `Network is unreachable` | **No hay ruta** para ese destino (sin `default`, por ejemplo): el paquete ni sale. No se puede provocar en el laboratorio (exigiría borrar la ruta, y no hay `NET_ADMIN`) | `ip route`, `ip route get` |
| `Connection timed out` / `ping` sin respuesta | **Sí hay ruta**, el paquete salió, pero nadie contesta: máquina apagada, regla de cortafuegos que descarta, o ruta mal puesta más allá | `ping` a la puerta de enlace, `tracepath` |
| `Time to live exceeded` | Un router descartó el paquete porque se acabó su vida (TTL). Normal con `ping -t 1` | Confirma que el primer salto es el gateway |

El segundo es el que sí puedes ver aquí: `10.255.255.1` no existe, pero
`ip route get 10.255.255.1` dice que saldría por la puerta de enlace
(entra en `default`), y `curl --max-time 2` da `28` (tiempo agotado).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Diagnosticar "no hay internet" mirando solo el navegador | Mezcla cuatro capas distintas en un solo síntoma | `ip route get`, `ping` a la puerta de enlace, y subir capa a capa |
| Añadir rutas con `ip route add` y olvidarlas | No sobreviven al reinicio y nadie recuerda por qué hay una ruta rara | Configuración persistente de tu familia (archivo 01, 3.2) |
| Decodificar el gateway "de memoria" sin invertir los bytes | `01001BAC` no es `1.0.27.172`: es `172.27.0.1` | `${h:6:2}`, `${h:4:2}`, `${h:2:2}`, `${h:0:2}` |
| Asumir que la puerta de enlace es siempre `x.x.x.1` | Es una convención, no una norma | Leerla de la tabla de rutas |
| Fiarse de `ping` como prueba de "el servidor está bien" | Muchos cortafuegos descartan ICMP aunque el servicio funcione | Probar el **puerto** real (archivo 04) |

## 5. Trucos

- `ip -o route get 8.8.8.8` imprime la respuesta en **una sola línea**: más
  fácil de procesar con `awk` que las dos líneas por defecto.
- `ip route show table all` incluye también la tabla `local` (las
  direcciones de la propia máquina), que `ip route` a secas oculta.
- `ping -t 1 destino` fuerza un TTL de 1: el primer router responde
  `Time to live exceeded` y así **descubres quién es** el primer salto sin
  `traceroute`.
- `ip -6 route` está vacío en este laboratorio: los contenedores de Docker
  no tienen IPv6 por defecto. Es normal, no un fallo.

## 📚 Recursos Adicionales

- `man ip-route`: todas las opciones de la tabla de rutas
- `man 5 proc`, sección `/proc/net/route`: el formato del archivo decodificado a mano

## ✅ Checklist de Verificación

- [ ] `docker exec ubuntu-lab ip route` muestra `default via` y la red `/16`
- [ ] `docker exec ubuntu-lab ip route get 8.8.8.8` incluye `via` y `docker exec ubuntu-lab ip route get 172.27.0.4` no
- [ ] Sabes decodificar `01001BAC` a mano sin copiar la respuesta
- [ ] Sabes explicar por qué `10.255.255.1` da timeout y no "unreachable"

---

[← Interfaces y direcciones IP](01-interfaces-y-direcciones-ip.md) · [DNS desde la línea de comandos →](03-dns-desde-la-linea-de-comandos.md)
