# Glosario — Semana 12

**authorized_keys**: archivo `~/.ssh/authorized_keys` del servidor, con las
claves públicas que pueden entrar como ese usuario. Exige permisos `600`
(`StrictModes`).

**backlog**: cola de conexiones TCP que el kernel acepta mientras el
servidor aún no las ha atendido; `ss -tl` lo muestra en `Send-Q`.

**CIDR** (*Classless Inter-Domain Routing*): notación `IP/prefijo`, como
`172.27.0.5/16`, donde el prefijo es el número de bits que identifican la red.

**clave pública / privada** (*public / private key*): par de claves de SSH.
La pública se comparte y se instala en los servidores; la privada, con modo
`600`, no sale nunca de la máquina del usuario.

**dig**: herramienta que consulta un servidor DNS directamente, sin pasar
por NSS ni `/etc/hosts`. Sale con `0` aunque la respuesta sea `NXDOMAIN`.

**DNS** (*Domain Name System*): sistema que traduce nombres a direcciones IP.

**ed25519**: tipo de clave SSH recomendado hoy: corta, rápida y segura.

**getent**: consulta las bases de datos del sistema a través de NSS; con
`getent hosts` resuelve un nombre **como lo haría un programa**.

**gateway** (*puerta de enlace*): máquina a la que se entregan los paquetes
destinados fuera de la red local; va en la ruta `default via`.

**huella** (*fingerprint*): resumen corto de una clave (`SHA256:...`) para
compararla de un vistazo; `known_hosts` guarda la de cada servidor.

**interfaz** (*interface*): punto por donde una máquina se conecta a una red
(`eth0`, `lo`). `ip -br link` la lista.

**known_hosts**: archivo `~/.ssh/known_hosts` con las huellas de los
servidores que ya conoces; si una cambia, SSH se niega a conectar.

**loopback** (`lo`): interfaz virtual que conecta la máquina consigo misma
(`127.0.0.1`). Un servidor que escucha solo ahí es invisible desde fuera.

**MTU** (*Maximum Transmission Unit*): tamaño máximo de un paquete en una
interfaz, en bytes (1500 en Ethernet).

**NSS** (*Name Service Switch*): mecanismo de `libc` que, según
`/etc/nsswitch.conf`, decide en qué orden se consultan las fuentes de nombres
(`files`, `dns`...).

**NXDOMAIN**: respuesta de DNS que significa "ese nombre no existe".

**prefijo** (*prefix length*): número tras la barra de una dirección CIDR;
`/16` son 16 bits de red y 16 de máquina.

**puerto** (*port*): número de 1 a 65535 que identifica a qué programa de la
máquina va una conexión (`22` SSH, `80` HTTP).

**refused** (*Connection refused*): rechazo inmediato de una conexión: la
máquina existe, pero en ese puerto no escucha nadie.

**ruta por defecto** (*default route*): regla `default via GATEWAY` que se
usa cuando ninguna otra ruta encaja con el destino.

**socket**: extremo de una comunicación de red: una dirección IP y un
puerto. `ss` los lista.

**ss** (*socket statistics*): comando que lista sockets y conexiones;
sustituye a `netstat`. `ss -tlnp` muestra qué escucha y qué proceso lo abrió.

**StrictHostKeyChecking**: opción de SSH que decide qué hacer con un
servidor desconocido o cambiado (`ask`, `accept-new`, `yes`, `no`).

**TCP** (*Transmission Control Protocol*): protocolo con conexión que usan
SSH, HTTP y casi todos los servicios; tiene `LISTEN` y `ESTAB`.

**timeout** (*Connection timed out*): ausencia de respuesta: el paquete se
perdió o fue descartado. No equivale a `refused`.

**TTL** (*Time To Live*): en un paquete, vida restante en saltos; en DNS,
segundos que una respuesta puede guardarse en caché.

**túnel** (*tunnel*): reenvío de un puerto a través de una conexión SSH
(`ssh -L`).

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 13 →](../../week-13-fundamentos_de_bash_scripting/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
