# Práctica 03: SSH entre contenedores

Montas una conexión SSH completa **dentro del laboratorio**: un servidor en
`debian-lab`, un cliente en `ubuntu-lab`, claves en lugar de contraseñas, y
reproduces el aviso de huella cambiada que verás en el mundo real. Ningún
puerto sale del laboratorio: los contenedores solo se ven entre sí por la
red interna de Compose.

Los bloques *"desde tu máquina"* van en tu terminal normal; el resto, como
`root` dentro del contenedor indicado (`docker exec -it ubuntu-lab bash`).
Los comandos de `ana` se ejecutan con `su - ana -c '...'`.

## Paso 1: Preparar el servidor en debian-lab

**Por qué**: `debian-lab` no ejecuta systemd, así que `sshd` se arranca a
mano. Necesita el directorio `/run/sshd` (archivo 07). `ana` es el usuario
de prueba que vas a usar de los dos lados.

**Comando** (desde tu máquina):

```bash
docker exec debian-lab bash -c 'apt-get update >/dev/null && apt-get install -y openssh-server >/dev/null && mkdir -p /run/sshd && useradd -m -s /bin/bash ana && /usr/sbin/sshd'
docker exec ubuntu-lab bash -c 'useradd -m -s /bin/bash ana'
```

**Verifica**:

```bash
docker exec ubuntu-lab nc -zv -w2 debian-lab 22
# Connection to debian-lab (172.27.0.3) 22 port [tcp/*] succeeded!
docker exec debian-lab bash -c 'getent passwd ana | cut -d: -f1,7'
# ana:/bin/bash
```

La IP de `debian-lab` puede ser otra. Lo que importa: el puerto `22` abre.
Es la capa 4 de la que hablaba el archivo 04, aplicada a SSH.

## Paso 2: El primer intento falla, y es buena señal

**Por qué**: ver los dos errores en orden (primero la huella, luego la
autenticación) te enseña a reconocerlos por separado.

**Comando** (en ubuntu-lab):

```bash
su - ana -c 'ssh -o BatchMode=yes ana@debian-lab true'; echo "codigo: $?"
su - ana -c 'ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new ana@debian-lab true'; echo "codigo: $?"
```

**Verifica**:

```bash
# Host key verification failed.
# codigo: 255
# Warning: Permanently added 'debian-lab' (ED25519) to the list of known hosts.
# ana@debian-lab: Permission denied (publickey,password).
# codigo: 255
```

La primera falla porque `BatchMode` impide preguntar por la huella y
`ana` no conoce aún a `debian-lab`. La segunda la acepta (`accept-new`) y
falla más adelante: el servidor ofrece `publickey` y `password`, y `ana` no
tiene ninguna. Los dos errores son `255`: fallo de **conexión**, no del
comando remoto.

## Paso 3: Generar el par de claves

**Por qué**: es el paso B del dibujo del archivo 07: el cliente necesita una
identidad que el servidor pueda comprobar.

> ⚠️ **Advertencia**: `-N ""` deja la clave **sin passphrase**. Es
> aceptable aquí porque el contenedor es desechable y la clave no sale de
> él. Una clave real lleva passphrase y `ssh-agent`; este bootcamp no la
> guarda en ningún repositorio.

**Comando** (en ubuntu-lab):

```bash
su - ana -c 'ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 -C ana@ubuntu-lab'
su - ana -c 'stat -c "%a %n" ~/.ssh ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub'
```

**Verifica**:

```bash
# 700 /home/ana/.ssh
# 600 /home/ana/.ssh/id_ed25519
# 644 /home/ana/.ssh/id_ed25519.pub
```

La salida de `ssh-keygen` incluye una huella y un dibujo; no los copies a
ningún sitio. Solo importan los modos: **700** el directorio, **600** la
privada, **644** la pública.

## Paso 4: Autorizar la clave en el servidor

**Por qué**: es el otro extremo del paso B: el servidor solo deja entrar a
quien tenga su clave pública en `authorized_keys`. En una máquina real lo
haría `ssh-copy-id`; aquí `ana` no tiene contraseña, así que lo haces a mano.

**Comando** (desde tu máquina):

```bash
docker exec ubuntu-lab cat /home/ana/.ssh/id_ed25519.pub | docker exec -i debian-lab bash -c \
  'install -d -m 700 -o ana -g ana /home/ana/.ssh && cat >> /home/ana/.ssh/authorized_keys && chown ana:ana /home/ana/.ssh/authorized_keys && chmod 600 /home/ana/.ssh/authorized_keys'
```

**Verifica**:

```bash
docker exec debian-lab ls -l /home/ana/.ssh/authorized_keys | cut -c1-30
# -rw------- 1 ana ana
docker exec ubuntu-lab su - ana -c 'ssh -o BatchMode=yes ana@debian-lab "hostname; id -un"'
# debian-lab
# ana
```

Si ves `debian-lab` y `ana` sin que nadie te pida nada, la autenticación
por clave funciona.

## Paso 5: Ver cómo se negocia: `ssh -v` y los códigos de salida

**Por qué**: cuando una clave "no funciona", `-v` dice en qué punto falla
(archivo 07). Y el código de salida de `ssh` distingue "mi comando falló" de
"no conecté".

**Comando** (en ubuntu-lab):

```bash
su - ana -c 'ssh -v -o BatchMode=yes ana@debian-lab true 2>&1 | grep -E "^debug1: (Connecting to|Connection established|Authentications that can continue|Server accepts key|Authenticated)"' | sed -E 's/SHA256:[A-Za-z0-9+\/]+/SHA256:<huella>/'
for c in true false 'exit 7'; do
  su - ana -c "ssh -o BatchMode=yes ana@debian-lab '$c'"; echo "'$c' -> $?"
done
su - ana -c 'ssh -o BatchMode=yes -o ConnectTimeout=3 -p 2222 ana@debian-lab true' 2>/dev/null; echo "puerto cerrado -> $?"
```

**Verifica**:

```bash
# debug1: Connecting to debian-lab [172.27.0.3] port 22.
# debug1: Connection established.
# debug1: Authentications that can continue: publickey,password
# debug1: Server accepts key: /home/ana/.ssh/id_ed25519 ED25519 SHA256:<huella> explicit
# 'true' -> 0
# 'false' -> 1
# 'exit 7' -> 7
# puerto cerrado -> 255
```

`Server accepts key` es el momento exacto en que el servidor reconoce tu
clave. Y el `255` solo aparece cuando falló la propia conexión.

## Paso 6: Cuando los permisos estropean la clave

**Por qué**: el motivo más común de "he copiado la clave y no entra" son los
permisos de `authorized_keys` (archivo 07, `StrictModes`).

**Comando** (desde tu máquina):

```bash
docker exec debian-lab chmod 666 /home/ana/.ssh/authorized_keys
docker exec ubuntu-lab su - ana -c 'ssh -o BatchMode=yes ana@debian-lab true'; echo "codigo: $?"
```

**Verifica**:

```bash
# ana@debian-lab: Permission denied (publickey,password).
# codigo: 255
```

La clave es la correcta, pero `sshd` la **ignora** porque el archivo es
escribible por otros. Corrígelo y confirma:

```bash
docker exec debian-lab chmod 600 /home/ana/.ssh/authorized_keys
docker exec ubuntu-lab su - ana -c 'ssh -o BatchMode=yes ana@debian-lab true'; echo "codigo: $?"
# codigo: 0
```

## Paso 7: Un alias en `~/.ssh/config`

**Por qué**: teclear usuario, host y clave cada vez es tedioso y propenso a
errores. `~/.ssh/config` lo resume en un nombre (archivo 07).

**Comando** (en ubuntu-lab):

```bash
su - ana -c 'cat > ~/.ssh/config <<EOF
Host deb
    HostName debian-lab
    User ana
    IdentityFile ~/.ssh/id_ed25519
EOF
chmod 600 ~/.ssh/config'
su - ana -c 'ssh -G deb | grep -E "^(hostname|user|port|identityfile) "'
su - ana -c 'ssh -o BatchMode=yes deb hostname'
```

**Verifica**:

```bash
# user ana
# hostname debian-lab
# port 22
# identityfile ~/.ssh/id_ed25519
# debian-lab
```

`ssh -G deb` muestra la configuración **efectiva** sin conectar: así
comprobabas el alias antes de usarlo.

## Paso 8: Copiar archivos con scp

**Por qué**: `scp` usa la misma conexión y las mismas claves; es la forma
mínima de mover un archivo entre dos máquinas.

**Comando** (en ubuntu-lab):

```bash
su - ana -c 'echo datos > /tmp/f.txt && scp -q /tmp/f.txt deb:/tmp/f2.txt && ssh deb cat /tmp/f2.txt'
su - ana -c 'scp -q deb:/tmp/f2.txt /tmp/f3.txt && cat /tmp/f3.txt'
```

**Verifica**:

```bash
# datos
# datos
```

El primero va de `ubuntu-lab` a `debian-lab` y se lee **allí**; el segundo
lo trae de vuelta.

## Paso 9: Provocar y resolver un aviso de huella cambiada

**Por qué**: pasará el día que recrees un servidor. Reproducirlo aquí te
enseña a **leerlo** y a resolverlo borrando **solo** la entrada afectada
(archivo 07), nunca `known_hosts` entero.

> ⚠️ **Advertencia**: se regeneran las claves de host de `debian-lab`. Es
> el contenedor del laboratorio: nada real depende de ellas. La copia
> `known_hosts.bak` es la vuelta atrás si quieres repetir el paso.

**Comando** (desde tu máquina):

```bash
docker exec ubuntu-lab su - ana -c 'cp ~/.ssh/known_hosts ~/.ssh/known_hosts.bak'
docker exec debian-lab bash -c 'rm -f /etc/ssh/ssh_host_* && ssh-keygen -A >/dev/null && pkill -x sshd; sleep 0.5; /usr/sbin/sshd'
docker exec ubuntu-lab su - ana -c 'ssh -o BatchMode=yes deb true'; echo "codigo: $?"
```

**Verifica**:

```bash
# @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
# ...
# Offending ECDSA key in /home/ana/.ssh/known_hosts:3
#   remove with:
#   ssh-keygen -f '/home/ana/.ssh/known_hosts' -R 'debian-lab'
# Host key verification failed.
# codigo: 255
```

El número de línea (`:3`) puede ser otro. Resuélvelo como indica el
mensaje, **solo para ese host**:

```bash
docker exec ubuntu-lab su - ana -c "ssh-keygen -R debian-lab >/dev/null 2>&1; ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new deb true"; echo "codigo: $?"
# Warning: Permanently added 'debian-lab' (ED25519) to the list of known hosts.
# codigo: 0
```

## Paso 10: Un túnel `-L` hacia rhel-lab

**Por qué**: reenviar un puerto a través de SSH es un uso diario (llegar a
un servicio que solo se ve desde el servidor). Aquí, `debian-lab` hace de
intermediario hacia el servidor web de la Práctica 02.

**Comando** (en ubuntu-lab; necesita el servidor del paso 1 de la
Práctica 02 en marcha):

```bash
su - ana -c 'ssh -f -N -M -S /tmp/cm.sock -L 18900:rhel-lab:8000 deb'
sleep 1
curl -s http://127.0.0.1:18900/
su - ana -c 'ssh -S /tmp/cm.sock -O exit deb'
curl -s --max-time 1 http://127.0.0.1:18900/; echo "codigo: $?"
```

**Verifica**:

```bash
# hola desde rhel-lab
# Exit request sent.
# codigo: 7
```

La primera petición llega a `rhel-lab` **a través del túnel**; tras cerrarlo
con `-O exit`, el puerto local `18900` ya no existe y `curl` da `7`
(*refused*).

## Paso 11: Limpiar

**Por qué**: un usuario con una clave autorizada y un `sshd` abierto son un
acceso que nadie recuerda. El laboratorio se deja como estaba.

> ⚠️ **Advertencia**: `userdel -r` borra el home de `ana` y todo lo que
> contiene. Solo existe en el laboratorio y solo tiene claves de prueba;
> el respaldo no hace falta, pero **no** ejecutes este comando contra un
> usuario real.

**Comando** (desde tu máquina):

```bash
docker exec debian-lab bash -c 'pkill -x sshd; userdel -r ana 2>/dev/null; rm -f /var/run/sshd.pid'
docker exec ubuntu-lab bash -c 'pkill -u ana; userdel -r ana 2>/dev/null'
```

**Verifica**:

```bash
docker exec debian-lab getent passwd ana; echo "debian: $?"
# debian: 2
docker exec ubuntu-lab getent passwd ana; echo "ubuntu: $?"
# ubuntu: 2
docker exec ubuntu-lab nc -zv -w2 debian-lab 22; echo "ssh: $?"
# nc: connect to debian-lab (172.27.0.3) port 22 (tcp) failed: Connection refused
# ssh: 1
```

## ✅ Resultado

- [ ] `sshd` escuchaba en el puerto `22` de `debian-lab` y lo comprobaste con `nc -z`
- [ ] Entraste como `ana` sin contraseña usando una clave `ed25519`
- [ ] Reprodujiste `Permission denied (publickey,password)` por permisos y lo corregiste
- [ ] Usaste un alias de `~/.ssh/config` y copiaste archivos con `scp`
- [ ] Provocaste el aviso de huella cambiada y lo resolviste con `ssh-keygen -R`
- [ ] Abriste y cerraste un túnel `-L` hacia `rhel-lab`
- [ ] Dejaste el laboratorio sin `ana` ni `sshd`

```bash
./scripts/verificar-semana.sh 12
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Missing privilege separation directory: /run/sshd` | Falta `mkdir -p /run/sshd` | Créalo y vuelve a lanzar `/usr/sbin/sshd` |
| `Connection refused` en el puerto 22 | `sshd` no está arrancado | `docker exec debian-lab /usr/sbin/sshd` |
| `Permission denied (publickey,password)` tras copiar la clave | Permisos de `~/.ssh` o `authorized_keys`, o dueño equivocado | `700` el directorio, `600` el archivo, y `chown ana:ana` |
| `Host key verification failed` en un script | `BatchMode` y host desconocido (o cambiado) | Primera vez: `accept-new`; cambiada: `ssh-keygen -R host` |
| `UNPROTECTED PRIVATE KEY FILE!` | La privada tiene modo `644` | `chmod 600 ~/.ssh/id_ed25519` |
| `su: user ana does not exist` | No se creó en ese contenedor | `useradd -m -s /bin/bash ana` en el contenedor que corresponda |
| El túnel del paso 10 da `7` desde el principio | El servidor de `rhel-lab` no está arrancado | Práctica 02, paso 1 |

---

[← Práctica 02](02-dns-y-curl-contra-el-laboratorio.md) · [Práctica 04 →](04-netcheck-a-mano.md)
