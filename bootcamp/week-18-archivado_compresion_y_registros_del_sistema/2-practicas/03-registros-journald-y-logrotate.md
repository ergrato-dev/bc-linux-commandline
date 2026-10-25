# Práctica 03 — Registros, `journald` y `logrotate`

> Duración estimada: 90 min · Teoría de apoyo: archivos [04](../1-teoria/04-var-log-y-registros-clasicos.md), [05](../1-teoria/05-journalctl.md), [06](../1-teoria/06-logrotate.md) y [07](../1-teoria/07-escribir-en-los-registros.md)

El contenedor `ubuntu-lab` **no ejecuta systemd**: no hay servicio de registros
funcionando. Para practicar, arrancas **a mano** los dos demonios que en una
máquina real arranca systemd, primero `rsyslog` (registros de texto clásicos) y
luego `journald` (el diario binario). Es el mismo programa; solo cambia quién lo
lanza.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Instalar lo que falta

**Por qué**: la imagen mínima no trae `rsyslog` ni `logrotate`. `journalctl` sí
viene (es parte de `systemd`).

**Comando**:

```bash
# En RHEL: dnf install rsyslog logrotate. En Arch: pacman -S logrotate (no hay rsyslog por defecto).
apt-get update -qq
apt-get install -y -qq rsyslog logrotate
```

**Verifica**:

```bash
command -v rsyslogd logrotate logger journalctl
# /usr/sbin/rsyslogd
# /usr/sbin/logrotate
# /usr/bin/logger
# /usr/bin/journalctl
```

## Paso 2: Arrancar `rsyslog` a mano y escribir con `logger`

**Por qué**: `logger` escribe en el socket `/dev/log`. Si nadie lo ha creado, el
mensaje se pierde **sin error** (teoría 07). Al arrancar `rsyslogd` aparece el
socket y empiezan a llegar los mensajes a `/var/log`.

**Comando**:

```bash
# Si ya hubo un rsyslogd y se cerro mal, queda un pidfile y un socket viejos: limpialos.
pkill -9 rsyslogd; rm -f /run/rsyslogd.pid /dev/log
rsyslogd
# rsyslogd: imklog: cannot open kernel log (/proc/kmsg): Operation not permitted.
# rsyslogd: activation of module imklog failed [v8.2312.0 try https://www.rsyslog.com/e/2145 ]
sleep 1; ls -l /dev/log | cut -c1-10
# srw-rw-rw-
```

Los dos avisos de `imklog` son normales: un contenedor no puede leer el registro
del **núcleo**. No afectan al resto.

**Verifica**:

```bash
logger -t p18 "mensaje normal"
logger -t p18 -p auth.info "mensaje auth"
logger -t p18 -p local0.warning "aviso local0"
sleep 1
grep p18 /var/log/syslog | sed -E 's/^[^ ]+ //'
# ubuntu-lab p18: mensaje normal
# ubuntu-lab p18: aviso local0
```

(El nombre de máquina será el de tu contenedor.) El mensaje `auth` **no** está en
`syslog`: las reglas de `/etc/rsyslog.d/50-default.conf` mandan `auth` a otro
archivo.

## Paso 3: Qué va a cada archivo y con qué permisos

**Por qué**: saber en qué archivo buscar es la mitad del diagnóstico. Y los
permisos de `/var/log` te dicen **quién puede leer** (los registros contienen
direcciones IP, nombres de usuario y a veces datos privados).

**Comando**:

```bash
grep p18 /var/log/auth.log | sed -E 's/^[^ ]+ //'
# ubuntu-lab p18: mensaje auth
ls -l /var/log/syslog /var/log/auth.log | awk '{print $1, $3, $4, $9}'
# -rw-r----- syslog adm /var/log/auth.log
# -rw-r----- syslog adm /var/log/syslog
```

**Verifica**: el grupo `adm` puede leer; el resto, no. En Ubuntu, el usuario
`ubuntu` pertenece a `adm` (por eso lee los registros sin `sudo`):

```bash
getent group adm
# adm:x:4:ubuntu,syslog
```

## Paso 4: Los registros binarios: `wtmp`, `btmp`, `lastlog`

**Por qué**: `last`, `lastb` y `lastlog` no leen texto: leen archivos
**binarios** (`/var/log/wtmp`, `btmp`, `lastlog`). Un `cat` o un `grep` sobre
ellos imprime basura. Se leen con sus comandos.

**Comando**:

```bash
ls -l /var/log/wtmp /var/log/btmp | awk '{print $1, $3, $4, $9}'
# -rw-rw---- root utmp /var/log/btmp
# -rw-rw-r-- root utmp /var/log/wtmp
last -n 3
# (vacio) wtmp begins Fri Sep 25 20:26:01 2026
lastlog | head -2
# Username         Port     From                                       Latest
# root                                                                **Never logged in**
```

**Verifica**: en el contenedor no hay sesiones de login, así que `last` solo
imprime la línea `wtmp begins`. En una máquina real verías aquí tus conexiones
SSH, con su origen y hora. `btmp` es `660`: contiene intentos **fallidos**, que
a veces incluyen una contraseña tecleada en el campo del usuario.

## Paso 5: Cambiar a `journald`

**Por qué**: en las distros modernas el diario es la fuente primaria. Para
practicar con él detienes `rsyslog` y arrancas `systemd-journald` a mano.

**Comando**:

```bash
pkill rsyslogd; rm -f /run/rsyslogd.pid /dev/log
/usr/lib/systemd/systemd-journald >/dev/null 2>&1 &
sleep 2
# systemd-cat entrega al diario por el socket de streams; logger NO llega aqui (sin /dev/log).
systemd-cat -t p18j -p warning echo "aviso del diario"
systemd-cat -t p18j -p info echo "info del diario"
systemd-cat -t p18j -p err echo "error del diario"
sleep 1
```

**Verifica**:

```bash
journalctl -t p18j -o cat --no-pager
# aviso del diario
# info del diario
# error del diario
```

`-t` filtra por etiqueta y `-o cat` quita las cabeceras: solo el mensaje.

## Paso 6: Filtrar por prioridad, texto y orden

**Por qué**: el diario guarda **campos**, no líneas: puedes pedir «solo los
errores» sin un `grep` frágil. `-p warning` incluye `warning` **y todo lo más
grave** (`err`, `crit`…); `err..err` pide exactamente un nivel.

**Comando**:

```bash
journalctl -t p18j -p warning -o cat --no-pager
# aviso del diario
# error del diario
journalctl -t p18j -p err..err -o cat --no-pager
# error del diario
journalctl -t p18j -g 'error|info' -o cat --no-pager
# info del diario
# error del diario
journalctl -t p18j -n 2 -r -o cat --no-pager
# error del diario
# info del diario
```

**Verifica**: cuenta los avisos o peores de tu etiqueta:

```bash
journalctl -t p18j -p warning -o cat --no-pager | wc -l
# 2
```

`-g` es una expresión regular sobre el mensaje; `-n 2 -r` son los **dos últimos**,
el más reciente primero.

## Paso 7: Formatos y ventanas de tiempo

**Por qué**: el mismo registro se ve de varias formas. `short-iso` da la hora con
zona; `json` te da **todos los campos** para procesarlos; `--since/--until`
acotan por tiempo.

**Comando**:

```bash
journalctl -t p18j -n 1 -o short-iso --no-pager | sed -E 's/^[^ ]+ //'
# ubuntu-lab p18j[34296]: error del diario
journalctl -t p18j -n 1 -o json --no-pager | python3 -c "
import sys,json
d=json.load(sys.stdin); print(d['PRIORITY'], d['SYSLOG_IDENTIFIER'], d['MESSAGE'])"
# 3 p18j error del diario
journalctl -t p18j --since "1 minute ago" -o cat --no-pager | wc -l
# 3
journalctl -t p18j --since "2 hours ago" --until "1 hour ago" --no-pager
# -- No entries --
```

**Verifica**: el número entre corchetes (`[34296]`) es el PID y será otro en tu
máquina; `PRIORITY` `3` es `err`, como en la tabla del archivo 07.

## Paso 8: Tamaño y salud del diario

**Por qué**: el diario también ocupa disco, y se puede comprobar que no está
corrupto. `--vacuum-*` recorta lo antiguo, pero **borra de verdad**.

> ⚠️ `journalctl --vacuum-time=...` y `--vacuum-size=...` eliminan registros. En
> el laboratorio no importa; en una máquina real, mira primero `--disk-usage`.

**Comando**:

```bash
journalctl --disk-usage
# Archived and active journals take up 15.1M in the file system.
journalctl --verify >/dev/null 2>&1; echo "rc=$?"
# rc=0
journalctl -F SYSLOG_IDENTIFIER --no-pager | grep -c p18j
# 1
```

**Verifica**: `--verify` con código `0` significa que los archivos del diario son
consistentes. `-F CAMPO` lista los **valores distintos** de un campo, útil para
descubrir qué etiquetas existen.

## Paso 9: `logrotate` con un registro de juguete

**Por qué**: probar `logrotate` sobre `/var/log` real es arriesgado. Con un
directorio propio y un archivo de **estado propio** (`-s`) no tocas nada del
sistema. El `-d` primero **no hace nada**; el `-f` fuerza la rotación.

**Comando**:

```bash
rm -rf /tmp/lr && mkdir -p /tmp/lr/logs && cd /tmp/lr
for i in 1 2 3; do echo "linea $i" >> logs/app.log; done
cat > app.conf <<'EOF'
/tmp/lr/logs/app.log {
    rotate 3
    daily
    missingok
    notifempty
    compress
    delaycompress
    create 0640 root root
}
EOF
logrotate -d -s state app.conf 2>&1 | sed -n 9,17p
# rotating pattern: /tmp/lr/logs/app.log  after 1 days (3 rotations)
# empty log files are not rotated, old logs are removed
# considering log /tmp/lr/logs/app.log
# Creating new state
#   Now: 2026-10-25 06:07
#   Last rotated at 2026-10-25 06:00
#   log does not need rotating (log has already been rotated)
```

La primera vez, `logrotate` solo **anota** el archivo en el estado: no rota. Fuerza:

```bash
logrotate -s state app.conf; ls logs
# app.log
logrotate -f -s state app.conf; ls logs
# app.log  app.log.1
echo nuevo >> logs/app.log; logrotate -f -s state app.conf; ls logs
# app.log  app.log.1  app.log.2.gz
```

**Verifica**: `.1` sin comprimir (`delaycompress`) y `.2.gz` comprimido:

```bash
zcat -f logs/app.log.1 logs/app.log.2.gz
# nuevo
# linea 1
# linea 2
# linea 3
```

(`zcat -f` lee comprimidos y sin comprimir por igual.)

## Paso 10: `create` frente a `copytruncate`

**Por qué**: la prueba que explica por qué un servicio «deja de escribir» tras
rotar. Un descriptor abierto simula el programa que mantiene el registro abierto.

**Comando**:

```bash
exec 8>>logs/nc.log; echo antes >&8
printf '/tmp/lr/logs/nc.log {\n rotate 2\n create\n nocompress\n}\n' > nc.conf
logrotate -f -s state nc.conf; echo despues >&8
echo "nc.log:"; cat logs/nc.log
# nc.log:
echo "nc.log.1:"; cat logs/nc.log.1
# nc.log.1:
# antes
# despues
exec 8>&-
```

Con `create`, el programa sigue escribiendo en el **archivo renombrado**. Con
`copytruncate`:

```bash
exec 9>>logs/ct.log; echo antes >&9
printf '/tmp/lr/logs/ct.log {\n rotate 2\n copytruncate\n nocompress\n}\n' > ct.conf
logrotate -f -s state ct.conf; echo despues >&9
echo "ct.log:"; cat logs/ct.log; echo "ct.log.1:"; cat logs/ct.log.1
# ct.log:
# despues
# ct.log.1:
# antes
exec 9>&-
```

**Verifica**: con `copytruncate`, `despues` está en el archivo **actual**; con
`create`, en el rotado.

## Paso 11: Limpieza

**Por qué**: no dejes demonios ni datos de prueba. Este `rm -rf` solo toca rutas
bajo `/tmp` que tú creaste.

```bash
pkill systemd-journal; pkill -9 rsyslogd; rm -rf /tmp/lr /tmp/p18 /tmp/p18b
rm -f /run/rsyslogd.pid /dev/log
```

**Verifica**:

```bash
ls /dev/log
# ls: cannot access '/dev/log': No such file or directory
```

(Si ves procesos `<defunct>` en `ps`, son zombis que el contenedor no recoge:
ya están muertos y no hacen nada.)

## ✅ Resultado

- [ ] Arrancaste `rsyslogd` a mano y comprobaste que aparece `/dev/log`
- [ ] Viste que `auth` va a `auth.log` y el resto a `syslog`, y por qué el grupo `adm` los lee
- [ ] Sabes que `wtmp`, `btmp` y `lastlog` son binarios y se leen con `last`, `lastb` y `lastlog`
- [ ] Arrancaste `journald`, escribiste con `systemd-cat` y filtraste por etiqueta, prioridad y texto
- [ ] Usaste `-o json` y `--since/--until`, y comprobaste el diario con `--verify`
- [ ] Probaste `logrotate` con `-d`, `-f` y un archivo de estado propio
- [ ] Demostraste con un descriptor abierto la diferencia entre `create` y `copytruncate`

Siguiente: la [práctica 04](04-backup-a-mano.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `rsyslogd: pidfile '/run/rsyslogd.pid' and pid ... already exist` | Un arranque anterior no cerró bien | `pkill -9 rsyslogd; rm -f /run/rsyslogd.pid /dev/log` y vuelve a lanzar |
| `ls: cannot access '/dev/log'` tras arrancar `rsyslogd` | No arrancó (ver el punto anterior) | Mira `pgrep -a rsyslogd`; limpia y relanza |
| `logger` no deja nada en `syslog` | `rsyslogd` no está activo | Repite el paso 2 |
| `journalctl` dice `-- No entries --` | Usaste `logger`, que sin `/dev/log` no llega al diario | Escribe con `systemd-cat` |
| `logrotate` no rota en la primera ejecución | Solo registra el estado | Usa `-f` |
| `logrotate: error: skipping ... insecure permissions` | El directorio es escribible por el grupo | Añade `su root root` al bloque o corrige los permisos |
| `Permission denied` al leer `/var/log/syslog` | Tu usuario no está en `adm` | `sudo` solo para esa lectura, o `usermod -aG adm` |

---

[← Práctica 02: integridad y restauración](02-integridad-y-restauracion.md) · [Práctica 04: `backup` a mano →](04-backup-a-mano.md)
