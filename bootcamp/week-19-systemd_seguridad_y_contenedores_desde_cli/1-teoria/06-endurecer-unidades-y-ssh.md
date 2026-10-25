# Endurecer unidades y SSH

> Un servicio comprometido hereda todo lo que su unidad le dio. systemd permite **quitarle** casi todo con unas pocas líneas.
> Y el servidor SSH es la puerta más visitada de cualquier máquina: su configuración merece una lectura atenta.

## 🎯 Objetivos

- Medir la exposición de una unidad con `systemd-analyze security --offline`
- Aplicar las directivas de aislamiento más rentables en un drop-in
- Leer una configuración de SSH sabiendo que **la primera aparición gana**
- Comprobar la configuración **efectiva** con `sshd -T` y su sintaxis con `sshd -t`
- Reconocer los tres ajustes de SSH que más importan: root, contraseñas y X11

## 1. Qué problema resuelve

Una unidad sencilla corre como `root`, ve todo el sistema de archivos, puede abrir
cualquier socket y llamar a cualquier llamada al sistema. Si el programa tiene un
fallo, el atacante lo hereda todo. Las directivas de aislamiento de systemd
**reducen ese radio de explosión** sin tocar el programa: no hay que recompilar
nada ni confiar en que el autor lo haya previsto.

SSH tiene el problema contrario: un único servicio, expuesto por diseño, con
decenas de opciones cuyos valores por defecto no son los más seguros.

## 2. Cómo funciona

### 2.1 Medir antes de tocar: `systemd-analyze security`

Puntúa una unidad de 0 (muy aislada) a 10 (sin aislar). Con `--offline=true` lo
hace **leyendo el archivo**, sin systemd en marcha, así que funciona en
`ubuntu-lab`. Lo aplicas a la unidad que generó `toolkit schedule gen` (archivo 03):

```bash
docker exec ubuntu-lab bash -c '
rm -rf /tmp/sg && mkdir /tmp/sg && cd /tmp/sg
~/bin/toolkit.sh schedule gen copias --cron "30 2 * * *" --salida /tmp/sg \
  -- /root/bin/toolkit.sh backup create /etc --dest /var/backups/toolkit --name etc >/dev/null
systemd-analyze security --offline=true ./copias.service --no-pager | tail -1'
# → Overall exposure level for copias.service: 9.4 UNSAFE :-{
```

Una unidad válida, que `verify` aprobó, y **9,4 sobre 10**: `UNSAFE`. La tabla
completa dice qué falta; las primeras filas:

```bash
docker exec ubuntu-lab bash -c 'cd /tmp/sg && systemd-analyze security --offline=true ./copias.service --no-pager | sed -n 2,5p | cut -c1-110'
#   NAME                       DESCRIPTION
# ✗ RemoveIPC=                 Service user may leave SysV IPC objects around
# ✗ RootDirectory=/RootImage=  Service runs within the host's root directory
# ✗ User=/DynamicUser=         Service runs as root user
```

Cada `✗` es una directiva que podrías añadir. La última columna (el «peso»)
dice cuánto baja la nota; las más rentables son las de peso mayor.

### 2.2 Las directivas que más bajan la nota

Se ponen en un **drop-in** (archivo 01), no en la unidad del paquete. Esta es la
lista de menos a más esfuerzo, con la puntuación real de la unidad `copias` al ir
añadiéndolas:

| Directiva añadida | Qué hace | Nota |
|---|---|:--:|
| *(unidad base)* | | 9,4 |
| `NoNewPrivileges=yes` | El proceso y sus hijos no ganan privilegios (setuid, `sudo`) | 9,2 |
| `ProtectSystem=strict` + `ReadWritePaths=` | `/usr`, `/etc`, `/boot`… en solo lectura; solo escribe donde digas | 9,0 |
| `PrivateTmp=yes` | Su propio `/tmp`, invisible para los demás | 8,8 |
| `PrivateDevices=yes` | Sin acceso a `/dev` reales (discos, etc.) | 8,2 |
| `ProtectKernelTunables`, `…Modules`, `…ControlGroups`, `…Logs`, `ProtectClock`, `ProtectHostname` | No puede tocar `/proc/sys`, cargar módulos, cgroups, el reloj… | 6,9 |
| `RestrictAddressFamilies=AF_UNIX` | Solo sockets locales: sin red | 6,2 |
| `RestrictNamespaces`, `RestrictRealtime`, `RestrictSUIDSGID`, `LockPersonality`, `MemoryDenyWriteExecute` | Cierra rutas clásicas de escalada | 5,2 |
| `SystemCallFilter=@system-service` | Solo las llamadas al sistema de un servicio normal | 3,8 |
| `CapabilityBoundingSet=CAP_DAC_READ_SEARCH` | De todos los poderes de root, solo «leer cualquier archivo» | 2,2 |
| `UMask=0077` | Lo que cree no lo lee nadie más | 2,2 |
| `IPAddressDeny=any` | Ni una dirección IP alcanzable | 2,0 |

El drop-in completo, 22 líneas, se queda en `OK`:

```ini
# /etc/systemd/system/copias.service.d/10-hard.conf
[Service]
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=/var/backups/toolkit /var/tmp
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
SystemCallFilter=@system-service
CapabilityBoundingSet=CAP_DAC_READ_SEARCH
UMask=0077
IPAddressDeny=any
```

> ⚠️ **La nota mide exposición, no que el servicio siga funcionando.** Cada
> restricción puede romper algo legítimo: `ProtectSystem=strict` impide escribir
> en cualquier sitio no listado, `RestrictAddressFamilies=AF_UNIX` prohíbe la red.
> En una máquina real: añade **de una en una**, `systemctl restart` y mira
> `journalctl -u NOMBRE`. Aquí solo hemos medido: no se ha ejecutado esa copia con
> estas restricciones.

`systemd-analyze security` también acepta el nombre de una unidad **cargada** en
una máquina viva (`systemd-analyze security ssh.service`), y sin argumentos lista
la nota de todas: la forma de encontrar las peores.

### 2.3 SSH: la primera aparición gana

En `sshd_config`, si una directiva aparece dos veces, **vale la primera**, al
contrario que en las unidades de systemd. Y `Include` mete otros archivos **en
el punto donde está**:

```bash
docker exec ubuntu-lab bash -c '
mkdir -p /run/sshd; cd /etc/ssh/sshd_config.d
printf "PasswordAuthentication yes\n" > 50-cloud.conf
sshd -T | grep -i "^passwordauthentication"
printf "PasswordAuthentication no\n" > 10-hard.conf
sshd -T | grep -i "^passwordauthentication"
rm -f 10-hard.conf 50-cloud.conf'
# passwordauthentication yes
# passwordauthentication no
```

La línea `Include /etc/ssh/sshd_config.d/*.conf` está al **principio** de la
configuración de Ubuntu, y los `.conf` se leen en orden alfabético: `10-hard.conf`
**gana** a `50-cloud.conf` y al propio `sshd_config`. Por eso el ajuste de
endurecimiento va en un archivo con número bajo.

`Match` abre un bloque condicional (`Match User bob`): todo lo que sigue solo se
aplica a esa conexión, y `toolkit harden ssh` deja de leer ahí.

### 2.4 `sshd -T` y `sshd -t`

| Orden | Hace |
|---|---|
| `sshd -t` | Comprueba la **sintaxis**; no imprime nada si todo va bien |
| `sshd -T` | Imprime la configuración **efectiva**: todos los valores tras `Include`, valores por defecto y reglas |

```bash
docker exec ubuntu-lab bash -c 'mkdir -p /run/sshd; sshd -T | grep -iE "^(permitrootlogin|passwordauthentication|permitemptypasswords|x11forwarding|maxauthtries)" | sort'
# maxauthtries 6
# passwordauthentication yes
# permitemptypasswords no
# permitrootlogin without-password
# x11forwarding yes
```

`sshd -T` es **la verdad**: lo que dice el archivo se puede leer mal (orden,
`Include`, `Match`); lo que dice `sshd -T` es lo que el servidor hará.
(`without-password` es el antiguo nombre de `prohibit-password`, el valor por
defecto desde OpenSSH 7: root puede entrar con **clave**, no con contraseña.)
Un valor inválido lo rechaza `sshd -t`:

```bash
docker exec ubuntu-lab bash -c 'printf "PermitRootLogin maybe\n" > /tmp/b.conf; sshd -t -f /tmp/b.conf; echo "rc=$?"'
# /tmp/b.conf line 1: unsupported option "maybe".
# rc=255
```

### 2.5 Los tres ajustes que importan

| Directiva | Valor seguro | Por qué |
|---|---|---|
| `PermitRootLogin` | `no` (o `prohibit-password`) | Un atacante ya conoce el usuario: solo adivina la contraseña |
| `PasswordAuthentication` | `no` | Las contraseñas se adivinan por fuerza bruta; las claves, no |
| `X11Forwarding` | `no` | Reenviar la pantalla expone tu servidor X al servidor |

Y `PermitEmptyPasswords no` (el defecto) para no aceptar cuentas sin contraseña.
**Antes de poner `PasswordAuthentication no`**, comprueba que puedes entrar con
tu clave (Semana 12) **desde otra terminal abierta**; si te equivocas con una
sesión cerrada, te quedas fuera.

Una clave para entrar se genera así, sin contraseña solo en el laboratorio
(en una máquina real, con *passphrase*, `-N` sin vacío):

```bash
docker exec ubuntu-lab bash -c 'mkdir -m 700 /tmp/k; ssh-keygen -q -t ed25519 -N "" -C lab -f /tmp/k/id; ls -l /tmp/k | awk "NR>1{print \$1, \$9}"; rm -rf /tmp/k'
# -rw------- id
# -rw-r--r-- id.pub
```

La privada `600`, la pública `644`. `ssh` rechaza una privada con permisos
amplios.

## 3. Cómo se usa

### 3.1 Un flujo para endurecer un servicio

1. `systemd-analyze security --offline=true ./unidad.service` — línea base.
2. Un drop-in con **una** familia de directivas (empieza por `NoNewPrivileges`,
   `PrivateTmp`, `ProtectSystem`).
3. `systemd-analyze verify` — ¿sigue siendo válida?
4. Reinicia y mira `journalctl -u NOMBRE`: ¿se queja de permisos?
5. Repite con la siguiente familia. Para en cuanto algo se rompa.

### 3.2 Un flujo para endurecer SSH

1. `sshd -T | grep -iE '^(permitrootlogin|passwordauthentication|x11forwarding)'` — qué hay.
2. Escribe `/etc/ssh/sshd_config.d/10-hard.conf` con los cambios.
3. `sudo sshd -t` — la sintaxis.
4. `sudo systemctl reload ssh` (o `sshd` en RHEL/Arch) — **sin** cerrar tu sesión.
5. Abre **otra** terminal y entra. Solo entonces cierra la primera.

### 3.3 Divergencia de distro

- **Unidad de SSH**: `ssh.service` (Debian/Ubuntu), `sshd.service` (RHEL/Arch).
- **`sshd_config.d/`**: existe en Ubuntu 24.04, en RHEL 9 y en Arch (el paquete
  `openssh` trae el directorio). En RHEL el paquete ya deja ahí un
  `50-redhat.conf`: tu `10-hard.conf` lo precede y gana. Si tu `sshd_config` no
  tiene la línea `Include`, el directorio no se lee.
- **Cortafuegos** (no se practica en el laboratorio: los contenedores no tienen
  permiso para reglas de red): `ufw` en Ubuntu, `firewalld` en RHEL, y `nftables`
  en la base de todas. El principio es el mismo: por defecto, cerrar; abrir solo
  el puerto 22 y lo que necesites.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Bajar la nota de golpe, con 20 directivas | No sabes cuál rompió el servicio | Añadir de una en una y probar |
| Fiarte de la nota como si fuera una prueba | Mide exposición, no funcionamiento | Reiniciar y leer `journalctl -u` |
| Editar `sshd_config` sin `sshd -t` | Un error impide arrancar `sshd` | `sshd -t` antes de recargar |
| Recargar SSH y cerrar la sesión a la vez | Si falla, te quedas fuera | Probar en **otra** terminal |
| `PermitRootLogin yes` «porque es cómodo» | Expone la cuenta más valiosa | Un usuario normal con `sudo` |
| Poner el ajuste en `50-cloud.conf` | Otro archivo anterior lo tapa | Un número bajo (`10-…`) y comprobar con `sshd -T` |
| Leer el archivo y no `sshd -T` | `Include` y `Match` cambian el resultado | `sshd -T` |
| Claves privadas con `644` | `ssh` las rechaza, o peor, otro usuario las lee | `chmod 600` |

## 5. Trucos

- **`systemd-analyze security`** (sin argumentos, en una máquina viva) ordena
  **todos** los servicios por exposición: de un vistazo, los peores.
- **`sshd -T -C user=bob,host=x,addr=1.2.3.4`** evalúa la configuración **como si**
  se conectara ese usuario, incluyendo sus bloques `Match`.
- **`ssh-keygen -lf archivo.pub`** muestra el tamaño y el tipo de una clave sin
  abrir el archivo (`256 ... (ED25519)`).

## 📚 Recursos Adicionales

- `man systemd.exec` (todas las directivas de aislamiento) y `man systemd-analyze`
- `man sshd_config` (el apartado que explica que la primera aparición gana)

## ✅ Checklist de Verificación

- [ ] Mides con `--offline=true` la exposición de una unidad generada por `schedule gen`
- [ ] Escribes un drop-in con al menos cinco directivas de aislamiento y la nota baja
- [ ] Explicas por qué una nota baja no prueba que el servicio funcione
- [ ] Demuestras con `sshd -T` que `10-` gana a `50-` en `sshd_config.d`
- [ ] Provocas el error de `sshd -t` con un valor inválido
- [ ] Nombras los tres ajustes de SSH más importantes y su valor seguro
- [ ] Describes cómo recargar SSH sin quedarte fuera

---

[← Menor privilegio y permisos peligrosos](05-menor-privilegio-y-permisos.md) · [Contenedores desde la CLI →](07-contenedores-desde-la-cli.md)
