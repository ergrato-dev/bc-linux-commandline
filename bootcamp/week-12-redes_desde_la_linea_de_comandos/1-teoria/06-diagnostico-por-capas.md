# Diagnóstico por capas

> "No funciona" no es un diagnóstico. Las cinco capas de esta semana
> convierten ese síntoma en una pregunta concreta con un comando que la
> contesta. Este archivo junta las piezas y es el diseño de `netcheck`.

![Las cinco capas del diagnóstico de red, de abajo hacia arriba](../0-assets/01-diagnostico-por-capas.svg)

## 🎯 Objetivos

- Aplicar el método de abajo hacia arriba a un fallo real
- Traducir un síntoma (`ping` funciona pero `curl` no) a la capa que falla
- Usar el código de salida de `curl` como atajo para saltar a la capa correcta
- Decidir qué capas dependen de cuáles, y qué probar cuando una falta

## 1. Qué problema resuelve

Un fallo de red se presenta siempre igual: "no llego". Detrás puede haber
cinco causas distintas y cada una se arregla en un sitio diferente. Sin
método se prueba al azar: se reinicia el servicio, se cambia el DNS, se
culpa al cortafuegos. Con método, cada comando **descarta** una capa y el
fallo queda acorralado.

La idea es la misma que seguiste en las semanas anteriores con los
pipelines: dividir un problema grande en etapas que se comprueban por
separado.

## 2. Cómo funciona

### 2.1 Cada capa depende de la de abajo

| Capa | Pregunta | Depende de |
|:--:|---|---|
| 1. Interfaz | ¿hay una interfaz activa con enlace? | nada |
| 2. Ruta | ¿hay una puerta de enlace para salir? | interfaz con IP |
| 3. DNS | ¿el nombre se convierte en una IP? | ruta al servidor DNS |
| 4. TCP | ¿alguien escucha en ese puerto? | IP del destino y ruta hasta él |
| 5. Aplicación | ¿responde bien el protocolo? | puerto abierto |

De ahí sale la regla práctica: **un fallo en una capa explica los de las
capas de arriba**. Si no hay ruta, el DNS "fallará" y el puerto
"no responderá": no son tres problemas, es uno. Arregla siempre la capa
**más baja** que falle.

Una excepción con nombre propio: si el destino ya es una **IP**, la capa 3
no existe (no hay nada que resolver); si el DNS falla, la capa 4 **no se
puede probar**, porque no hay IP a la que conectar. `netcheck` lo expresa
así: `dns: no aplica (IP literal)` en el primer caso y `tcp: omitido
(sin IP)` en el segundo.

### 2.2 Dos recorridos

- **De abajo hacia arriba** (el de este archivo): seguro, no se salta nada.
  Es lo que haces cuando no sabes nada del fallo.
- **De arriba hacia abajo**: lanzas `curl` primero y **lees su código de
  salida** (archivo 05: `6` DNS, `7` TCP, `28` ruta/cortafuegos, `22`
  aplicación) y vas directo a esa capa. Más rápido cuando el servicio es
  HTTP.

### 2.3 Un fallo real, de principio a fin

Escenario: "mi aplicación no llega a `rhel-lab:8000`". Se **reproduce**
apagando el servidor de juguete (archivo 05); desde tu máquina:

```bash
docker exec rhel-lab bash -c 'kill "$(cat /tmp/http.pid)"'
```

Y se diagnostica desde `ubuntu-lab`, capa por capa:

```bash
# 1. Interfaz: ¿hay enlace?
cat /sys/class/net/eth0/operstate
# up

# 2. Ruta: ¿hay por dónde salir?
ip route get 172.27.0.4
# 172.27.0.4 dev eth0 src 172.27.0.5 uid 0
#     cache

# 3. DNS: ¿resuelve el nombre?
getent hosts rhel-lab
# 172.27.0.4      rhel-lab

# 3.5 ¿Llego a la máquina? (ICMP; ayuda, pero no prueba el servicio)
ping -c1 -W1 rhel-lab | grep 'received'
# 1 packets transmitted, 1 received, 0% packet loss, time 0ms

# 4. TCP: ¿escucha el puerto?
nc -zv -w2 rhel-lab 8000
# nc: connect to rhel-lab (172.27.0.4) port 8000 (tcp) failed: Connection refused
```

Veredicto: las capas 1 a 3 están bien, **la máquina existe y responde**
(`ping`), y en el puerto 8000 hay un `refused`: el servidor **no está
arrancado** (o escucha en otra dirección: archivo 04). No hace falta tocar
nada de red; hay que arrancar el servicio. Para devolver el laboratorio a
su estado:

```bash
docker exec -d rhel-lab bash -c 'echo $$ > /tmp/http.pid; cd /srv/www && exec python3 -m http.server 8000 --bind 0.0.0.0'
```

### 2.4 Tabla de síntomas

| Qué ves | Capa | Causa probable |
|---|:--:|---|
| `ip -br link` sin interfaz `UP` | 1 | Cable, interfaz sin activar, contenedor sin red |
| `Network is unreachable` | 2 | No hay ruta por defecto |
| `ping` a la IP funciona, `ping` al nombre falla | 3 | DNS mal configurado o nombre inexistente |
| `curl: (6) Could not resolve host` | 3 | Lo mismo, visto desde la aplicación |
| `Connection refused` | 4 | La máquina existe; **no hay servicio** en ese puerto (o escucha en `127.0.0.1`) |
| `Connection timed out` | 2 ó 4 | Nada contesta: cortafuegos que descarta, máquina caída o ruta rota más allá |
| `curl: (22)` con `-f`, o `404`/`500` | 5 | El servicio respondió, pero con un error de aplicación |
| `ping` falla pero `curl` funciona | — | El destino bloquea **ICMP**: no es un fallo |

La última fila importa tanto como las otras: `ping` **no es** la prueba
definitiva. Muchos servidores bloquean ICMP a propósito; que no conteste
no significa que el servicio esté caído.

## 3. Cómo se usa

### 3.1 Un orden que ahorra tiempo

1. **¿Funciona desde la propia máquina?** `curl localhost:puerto`. Si no
   funciona ni ahí, el fallo es del servicio, no de la red.
2. **¿Y desde otra máquina?** Si desde dentro sí y desde fuera no, mira la
   dirección de escucha (`ss -tlnp`) y el cortafuegos.
3. **Lee el mensaje de error entero**, no solo el código: `Connection
   refused` y `Connection timed out` son diagnósticos distintos.
4. **Cambia una cosa cada vez** y vuelve a probar. Si cambias tres, no sabes
   cuál arregló el fallo.

### 3.2 Del diagnóstico a un script

Cuando haces lo mismo cinco veces, es una función. Este es el esqueleto que
construirás en el archivo 08: cada capa imprime una línea `ok` o `fallo`,
suma un fallo al contador y, al final, el código de salida resume todo.

```bash
fallos=0
# Capa 1.
if [[ "$(cat /sys/class/net/eth0/operstate)" == up ]]; then
  echo "ok interfaz"
else
  echo "fallo interfaz"; fallos=$(( fallos + 1 ))
fi
# Capa 3 (la IP la reutiliza la capa 4).
ip=$(getent ahostsv4 rhel-lab | awk 'NR == 1 { print $1 }') || true
if [[ -n "$ip" ]]; then
  echo "ok dns: $ip"
else
  echo "fallo dns"; fallos=$(( fallos + 1 ))
fi
```

La estructura importa más que los detalles: un script de diagnóstico que
**aborta en el primer fallo** oculta los demás; uno que **cuenta** y sigue
da el cuadro completo. Y `|| true` tras `getent` evita que `set -e` corte
el script cuando el nombre no resuelve (`getent` sale con `2`).

### 3.3 Leer bien un `ping`

```bash
ping -c3 rhel-lab
# 64 bytes from rhel-lab.bc-linux-commandline_lab (172.27.0.4): icmp_seq=1 ttl=64 time=0.160 ms
# 64 bytes from rhel-lab.bc-linux-commandline_lab (172.27.0.4): icmp_seq=2 ttl=64 time=0.112 ms
# 64 bytes from rhel-lab.bc-linux-commandline_lab (172.27.0.4): icmp_seq=3 ttl=64 time=0.078 ms
#
# --- rhel-lab ping statistics ---
# 3 packets transmitted, 3 received, 0% packet loss, time 2214ms
# rtt min/avg/max/mdev = 0.078/0.116/0.160/0.033 ms
```

| Pieza | Qué te dice |
|---|---|
| `-c3` | Envía solo tres (sin él, `ping` no termina hasta `Ctrl+C`) |
| `rhel-lab.bc-linux-...` | `ping` hace una resolución **inversa** del IP para mostrar el nombre: es cosmético |
| `ttl=64` | Vida restante del paquete; cada router la reduce en uno |
| `time=0.160 ms` | Tiempo de ida y vuelta. Entre contenedores, décimas de milisegundo; hacia internet, decenas |
| `0% packet loss` | **Lo importante**: pérdida distinta de cero es una red mala (cable, wifi, saturación) |
| `mdev` | Desviación: si es alta frente a la media, la conexión es inestable |

Y el **código de salida** de `ping` es distinto según el fallo (se comprobó
en el laboratorio): `0` si respondió algo, `1` si no hubo respuesta
(`10.255.255.1`) y `2` ante un error como un nombre que no resuelve
(`ping: no-existe.invalid: Name or service not known`).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Empezar por reiniciar el servicio o cambiar el DNS | Cambias algo sin saber qué falla; si funciona, no sabes por qué | Diagnosticar primero |
| Concluir "la red está caída" porque `ping` falla | `ping` solo prueba ICMP | Probar el puerto y el protocolo real |
| Diagnosticar solo desde un extremo | Un fallo puede existir solo en un sentido (cortafuegos, escucha en `127.0.0.1`) | Probar desde dentro **y** desde otra máquina |
| Saltarse capas "porque seguro que eso va bien" | La capa que das por buena es donde suele estar el fallo | Probarlas todas; tardan segundos |
| Un script de diagnóstico que aborta en la primera capa mala | Oculta los demás fallos | Contar los fallos y salir al final con un código distinto de cero |

## 5. Trucos

- `ip route get IP` combina las capas 1 y 2 en un solo comando: si
  imprime una ruta con `dev eth0`, hay interfaz y salida.
- `curl -sS -o /dev/null -w '%{http_code}\n' url ; echo $?` imprime el
  código HTTP **y** el de salida: juntos dicen en qué capa y cómo falló.
- `timeout 3 bash -c 'exec 3<>/dev/tcp/host/puerto'` es la prueba TCP que
  no depende de que haya `nc` ni `curl` instalados (archivo 04): la que
  usará `netcheck`.
- Un `ping` a la puerta de enlace separa "mi red" de "internet": si responde
  y a `8.8.8.8` no, el problema está más allá de tu red local.

## 📚 Recursos Adicionales

- `man ping`, `man tracepath`: opciones y códigos de salida
- [Modelo TCP/IP](https://es.wikipedia.org/wiki/Modelo_TCP/IP): el mapa de capas completo, de donde salen las cinco de esta semana (simplificadas)

## ✅ Checklist de Verificación

- [ ] Apagaste el servidor del archivo 05 y reconstruiste el veredicto capa por capa
- [ ] Sabes por qué `ping` funcionando no prueba que el servicio esté vivo
- [ ] Sabes qué capa señala cada código de salida de `curl` (6, 7, 22, 28)
- [ ] Dejaste el servidor de `rhel-lab` otra vez arrancado

---

[← curl y HTTP desde la CLI](05-curl-y-http-desde-la-cli.md) · [SSH: claves, config y scp →](07-ssh-claves-config-y-scp.md)
