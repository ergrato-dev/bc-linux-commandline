# Puertos, sockets y `ss`

> Una IP lleva el paquete hasta la máquina; el **puerto** decide qué
> programa lo recibe. Preguntar "¿alguien escucha?" es la cuarta capa del
> diagnóstico, y `ss` es el comando que contesta.

## 🎯 Objetivos

- Explicar qué es un puerto, un socket y el estado `LISTEN`
- Listar los servicios que escuchan con `ss -tlnp` y leer cada columna
- Distinguir un servidor que escucha en `127.0.0.1` de uno que escucha en `0.0.0.0`
- Probar un puerto remoto con `/dev/tcp` o `nc -z` y distinguir *refused* de *timeout*

## 1. Qué problema resuelve

Una máquina ejecuta a la vez un servidor web, un servidor SSH y un gestor de
base de datos, y todos reciben paquetes por la misma IP. El **puerto**
(un número de 1 a 65535) es lo que separa unos de otros: `22` es SSH
(`getent services ssh` lo confirma), `80` es HTTP, `443` es HTTPS.

Y cuando un servicio "no responde", casi siempre es una de tres cosas:
**no está arrancado**, **escucha en otra dirección** o **algo en medio lo
bloquea**. `ss` resuelve las dos primeras en una línea; el resto del archivo
enseña a distinguir la tercera.

## 2. Cómo funciona

### 2.1 Socket, `LISTEN` y conexión

Un **socket** es el extremo de una comunicación: una dirección IP y un
puerto. Un servidor abre un socket y se pone a **escuchar** (`LISTEN`);
cada cliente que se conecta crea una conexión **establecida** (`ESTAB`)
entre su socket y el del servidor.

Mientras un servidor está en `LISTEN`, el kernel acepta conexiones por él.
Si **nadie** escucha en ese puerto, el kernel responde al intento con un
rechazo inmediato (`Connection refused`): sabes que la máquina está ahí
pero el servicio no.

### 2.2 `ss`: qué escucha en mi máquina

Para tener algo que mirar, el laboratorio no trae servidores, así que se
abren dos con `perl` (como `root`; terminan solos a los 20 segundos):

```bash
# Uno solo en loopback (127.0.0.1) y otro en todas las direcciones (0.0.0.0).
perl -MIO::Socket::INET -e 'my $s=IO::Socket::INET->new(Listen=>5,LocalAddr=>q(127.0.0.1),LocalPort=>18080,ReuseAddr=>1) or die; sleep 20' &
perl -MIO::Socket::INET -e 'my $s=IO::Socket::INET->new(Listen=>5,LocalAddr=>q(0.0.0.0),LocalPort=>18081,ReuseAddr=>1) or die; sleep 20' &
```

```bash
ss -tlnp
# State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
# LISTEN 0      5          127.0.0.1:18080      0.0.0.0:*    users:(("perl",pid=7247,fd=3))
# LISTEN 0      4096      127.0.0.11:42129      0.0.0.0:*
# LISTEN 0      5            0.0.0.0:18081      0.0.0.0:*    users:(("perl",pid=7248,fd=3))
```

Las cuatro letras de `-tlnp` son lo que hay que memorizar:

| Opción | Significa |
|:--:|---|
| `-t` | Solo TCP (`-u` para UDP) |
| `-l` | Solo sockets en **escucha** (`LISTEN`); sin esto, `ss` lista las conexiones |
| `-n` | **N**o traduzcas puertos ni IP a nombres (más rápido, sin DNS) |
| `-p` | Muestra el **proceso** dueño del socket |

Y las columnas:

| Columna | Qué dice |
|---|---|
| `Local Address:Port` | En qué dirección y puerto **escucha**: aquí está la clave (2.3) |
| `Send-Q` (en `LISTEN`) | Tamaño máximo de la cola de conexiones pendientes (el *backlog* con que se abrió el socket) |
| `Recv-Q` (en `LISTEN`) | Conexiones pendientes de aceptar ahora mismo: casi siempre `0` |
| `Process` | `users:(("perl",pid=7247,fd=3))`: el programa, su PID y el descriptor de archivo |

La línea `127.0.0.11:42129` **no es un servidor tuyo**: es el servidor DNS
interno de Docker (el `nameserver` que viste en el archivo 03). No tiene
columna `Process` porque pertenece a otro espacio de procesos del host.

> `-p` solo muestra los procesos que **puedes** ver: como usuario normal
> (`ana`), la línea de `perl` sale sin `users:(...)`. Para ver todos,
> `sudo ss -tlnp`.

### 2.3 `127.0.0.1` contra `0.0.0.0`

La **dirección de escucha** decide quién puede conectarse:

| Escucha en | Quién puede conectarse |
|---|---|
| `127.0.0.1:puerto` | Solo la propia máquina (loopback). Invisible desde fuera |
| `0.0.0.0:puerto` (o `*:puerto`) | **Cualquier** dirección de la máquina: loopback y la IP de la red |
| `172.27.0.5:puerto` | Solo por esa IP concreta |

Se demuestra desde **otro** contenedor, con la mejor herramienta del
siguiente apartado:

```bash
docker exec rhel-lab bash -c 'timeout 2 bash -c "exec 3<>/dev/tcp/ubuntu-lab/18080"; echo "18080 -> $?"'
# bash: connect: Connection refused
# bash: line 1: /dev/tcp/ubuntu-lab/18080: Connection refused
# 18080 -> 1
docker exec rhel-lab bash -c 'timeout 2 bash -c "exec 3<>/dev/tcp/ubuntu-lab/18081"; echo "18081 -> $?"'
# 18081 -> 0
```

El servidor del `18080` escucha **solo** en `127.0.0.1`: desde `rhel-lab` da
`Connection refused` aunque el proceso esté vivo y funcione desde dentro.
Es el error más frecuente de "mi servidor no responde": la dirección de
escucha.

> 🔐 **Seguridad**: escuchar en `0.0.0.0` es exponer el servicio a **toda**
> la red a la que está conectada la máquina. En una base de datos o un
> panel de administración, eso suele ser un fallo grave. Los contenedores del
> laboratorio **no publican puertos al host** (`docker port ubuntu-lab` sale
> vacío): solo se ven entre sí por la red interna de Compose.

### 2.4 Probar un puerto desde fuera

Tres formas, de la más portátil a la más cómoda:

```bash
# 1. /dev/tcp: una función de bash (no es un archivo real). No necesita instalar nada.
timeout 2 bash -c 'exec 3<>/dev/tcp/rhel-lab/22'; echo $?
# 1 (en rhel-lab no hay sshd: connection refused)

# 2. nc -z: abre la conexión y la cierra sin enviar datos; -v lo cuenta; -w: tiempo máximo.
nc -zv -w2 127.0.0.1 18080
# Connection to 127.0.0.1 18080 port [tcp/*] succeeded!
nc -zv -w2 127.0.0.1 18082
# nc: connect to 127.0.0.1 port 18082 (tcp) failed: Connection refused

# 3. curl, que además habla el protocolo (archivo 05).
```

`nc` admite un rango: `nc -zv 127.0.0.1 18079-18082` prueba los cuatro
puertos y solo informa `succeeded` en `18080` y `18081`.

### 2.5 *Refused* contra *timeout*: dos fallos que no se parecen

| Respuesta | Qué significa | Qué buscar |
|---|---|---|
| `Connection refused` (código `7` en `curl`, `1` en `nc`/`/dev/tcp`) | La máquina **contestó al instante** que ahí no escucha nadie | Servicio apagado, puerto equivocado, escucha en otra dirección |
| `Connection timed out` (código `28` en `curl`) | **Nadie contestó**: el paquete se perdió o fue descartado | Máquina apagada, ruta mala o cortafuegos que descarta en silencio |

Es la diferencia más útil de toda la semana: un *refused* te dice que
llegaste hasta la máquina; un *timeout* te dice que no sabes dónde se
perdió el paquete.

### 2.6 Por dentro: `/proc/net/tcp`

`ss` lee del kernel, igual que `ip`. `/proc/net/tcp` lista los sockets
TCP IPv4; la columna `st` en hexadecimal vale `0A` para `LISTEN`:

```bash
awk 'NR > 1 && $4 == "0A" { print $2 }' /proc/net/tcp
# 0100007F:46A0
# 0B00007F:A491
# 00000000:46A1
```

Cada línea es `IP:puerto` en hexadecimal. La IP está en el mismo orden
invertido del archivo 02 (`0100007F` = `7F.00.00.01` = `127.0.0.1`), pero el
**puerto no se invierte**: `46A0` hexadecimal es `18080`.

```bash
printf '%d\n' 0x46A0 0x46A1
# 18080
# 18081
```

## 3. Cómo se usa

```bash
# Una sola línea por socket, sin cabecera: apto para awk.
ss -Htln | awk '{print $4}'
# 127.0.0.1:18080
# 127.0.0.11:42129
# 0.0.0.0:18081

# ¿Quién escucha en un puerto concreto? (el filtro va entre comillas)
ss -tlnp 'sport = :18080'
# State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
# LISTEN 0      5          127.0.0.1:18080      0.0.0.0:*    users:(("perl",pid=7247,fd=3))

# Resumen general de sockets.
ss -s
# Total: 8
# TCP:   101 (estab 0, closed 98, orphaned 0, timewait 1)

# Conexiones establecidas (sin -l).
ss -tn state established
```

`-H` quita la cabecera y `-Htln | wc -l` cuenta cuántos servicios escuchan.
Para UDP, `ss -uln`: no tiene `LISTEN` (UDP no tiene conexión) y el estado
es `UNCONN`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `netstat -tulpn` | `net-tools` está abandonado y no viene en instalaciones nuevas | `ss -tulpn`: mismas letras, mismo resultado |
| Probar un puerto con `ping` | `ping` usa ICMP, no TCP: que responda no prueba que el servicio escuche | `nc -zv host puerto` o `/dev/tcp` |
| `nc -zu host puerto` para "ver si UDP está abierto" | UDP no tiene conexión: solo detecta el cierre si llega un ICMP, y un cortafuegos que lo descarta parece "abierto" | Hablar el protocolo real (`dig @host` para DNS) |
| Arrancar un servidor en `0.0.0.0` "para que funcione" | Lo expone a toda la red sin que nadie lo haya decidido | Escuchar en `127.0.0.1` y abrir solo lo necesario |
| Confundir `refused` con `timeout` | Se buscan en el sitio equivocado: servicio apagado frente a cortafuegos | Leer el mensaje exacto: los dos significan cosas distintas |

## 5. Trucos

- `ss -tlnp` como usuario normal **no** muestra los procesos de otros;
  que falte la columna `Process` no significa que no haya dueño.
- `ss -tlnH '( sport = :18080 or sport = :18081 )'` combina condiciones
  (`and`, `or`) en un solo filtro; los paréntesis y los espacios importan.
- Los puertos bajos (menos de 1024) solían exigir `root` para abrirse. Hoy
  depende de `net.ipv4.ip_unprivileged_port_start`; en el laboratorio vale
  `0` y cualquier usuario puede abrirlos: `cat /proc/sys/net/ipv4/ip_unprivileged_port_start`.
- `getent services 8000/tcp` busca por número y devuelve el nombre; en
  este caso no hay entrada y sale con código `2`, aunque el puerto
  funcione: `/etc/services` es un directorio de **nombres**, no de puertos abiertos.

## 📚 Recursos Adicionales

- `man ss`, `man nc`: filtros de `ss` y todas las opciones de `nc` (cuidado: varían entre netcat de OpenBSD y Ncat)
- `man 5 services`: la lista de nombres de puertos conocidos

## ✅ Checklist de Verificación

- [ ] `docker exec ubuntu-lab ss -tlnp` lista al menos `127.0.0.11` (el DNS de Docker)
- [ ] Arrancaste los dos servidores de `perl` y los viste en `ss -tlnp`
- [ ] Desde `rhel-lab`, el puerto `18080` da *refused* y el `18081` conecta
- [ ] Sabes explicar por qué `46A0` es `18080` y no se invierte

---

[← DNS desde la línea de comandos](03-dns-desde-la-linea-de-comandos.md) · [curl y HTTP desde la CLI →](05-curl-y-http-desde-la-cli.md)
