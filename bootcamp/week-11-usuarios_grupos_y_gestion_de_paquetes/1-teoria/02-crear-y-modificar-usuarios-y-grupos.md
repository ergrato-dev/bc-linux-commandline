# Crear y modificar usuarios y grupos

> `useradd`, `usermod` y `userdel` no inventan nada: editan los archivos de cuentas
> del archivo 01 de forma coherente y con bloqueo. Casi todo lo que sale mal
> con ellos sale de **una bandera olvidada**.

## 🎯 Objetivos

- Crear un usuario con home, shell y comentario correctos en una sola orden
- Añadir un usuario a un grupo **sin** quitarle los que ya tenía
- Bloquear, desbloquear y dar de baja una cuenta sin dejar archivos huérfanos
- Compartir un directorio entre varias personas con un grupo y el bit SGID

## 1. Qué problema resuelve

Alguien entra al equipo, alguien se va, alguien cambia de proyecto. Hacerlo
a mano con un editor sobre `/etc/passwd` es lento y peligroso (archivo
anterior, antipatrón 1). Las herramientas de esta semana hacen el mismo
cambio **en `passwd`, `shadow`, `group` y `gshadow` a la vez**, con
bloqueo de archivo y comprobaciones. Eso es lo que las hace obligatorias.

## 2. Cómo funciona

### 2.1 `useradd`: crear una cuenta

```bash
# -m crea el home copiando /etc/skel; -s fija la shell; -c es el comentario (GECOS).
useradd -m -s /bin/bash -c "Ana Prueba" ana

id ana
# uid=1001(ana) gid=1001(ana) groups=1001(ana)

getent passwd ana
# ana:x:1001:1001:Ana Prueba:/home/ana:/bin/bash
```

Dos cosas que `useradd` hizo sin que se lo pidieras: asignó el siguiente
UID libre (1001, porque `ubuntu` ya ocupa el 1000 en esta imagen) y creó
un **grupo con el mismo nombre** como grupo primario (`USERGROUPS_ENAB yes`
en `/etc/login.defs`). Su contraseña está bloqueada hasta que se le dé una:

```bash
grep '^ana:' /etc/shadow | cut -d: -f1,2
# ana:!
```

**Las tres banderas que no se olvidan:**

| Bandera | Sin ella | Verificado |
|---|---|---|
| `-m` | No hay home: `getent` lo muestra, pero `/home/ana` no existe | `ls -d /home/sinhome` → `No such file or directory` |
| `-s /bin/bash` | La shell es la del valor por defecto, `/bin/sh` | `useradd -D` muestra `SHELL=/bin/sh` |
| `-c "Nombre"` | El campo GECOS queda vacío | opcional, pero un `passwd` sin nombre es difícil de auditar |

`/etc/skel` es la plantilla que se copia al home nuevo:

```bash
ls -A /etc/skel
# .bash_logout
# .bashrc
# .profile
```

Lo que pongas ahí lo recibirá **todo usuario nuevo** (Semana 17 lo usa
para repartir dotfiles).

> 🔀 **Divergencia de distro**: en Debian/Ubuntu existe además `adduser`,
> un asistente interactivo (pregunta contraseña y datos, usa `-m` por
> defecto). Es un script de Perl del paquete `adduser`: **no existe en
> RHEL ni en Arch**. `useradd` es el comando portable; lo demás es
> comodidad de una familia. Ver [`docs/divergencia-distros.md`](../../../docs/divergencia-distros.md).

### 2.2 `usermod`: cambiar lo que ya existe, y su trampa

```bash
groupadd devs
usermod -aG devs ana          # -a (append) + -G: AÑADE devs a sus grupos
id ana
# uid=1001(ana) gid=1001(ana) groups=1001(ana),1003(devs)
```

**La trampa más cara de este archivo**: sin `-a`, `-G` **reemplaza** la
lista completa de grupos suplementarios.

```bash
# Ana tenia devs. Un "usermod -G sudo ana" sin -a lo borra y deja solo sudo.
usermod -G sudo ana
id ana
# uid=1001(ana) gid=1001(ana) groups=1001(ana),27(sudo)

usermod -aG devs,adm ana      # ahora si: se añaden, no se reemplazan
id ana
# uid=1001(ana) gid=1001(ana) groups=1001(ana),4(adm),27(sudo),1003(devs)
```

Y para **quitar** de un grupo no hay `usermod -r`: se usa `gpasswd`:

```bash
gpasswd -d ana adm
# Removing user ana from group adm
```

Los grupos se leen **al iniciar sesión**. Si `ana` ya tiene una sesión
abierta, `usermod -aG` no la afecta hasta que cierre y vuelva a entrar
(o use `newgrp devs`). Para comprobar el estado real de la cuenta, abre
una sesión nueva: `su ana -c id`.

### 2.3 Bloquear, caducar, cambiar de shell

```bash
usermod -L ana                  # -L: antepone "!" al hash de shadow
passwd -S ana
# ana L 2026-10-25 0 99999 7 -1

usermod -s /usr/sbin/nologin ana   # la cuenta existe, pero no abre sesion
getent passwd ana | cut -d: -f7
# /usr/sbin/nologin

chage -M 90 ana                 # la contraseña caduca a los 90 dias
```

`passwd -S` imprime el estado de la contraseña: `L` bloqueada, `P` con
contraseña usable, `NP` sin contraseña. Una cuenta **sin** hash en
`shadow` no se puede "desbloquear" porque no hay nada que desbloquear:

```bash
usermod -U ana
# usermod: unlocking the user's password would result in a passwordless account.
# You should set a password with usermod -p to unlock this user's password.
```

El mensaje protege de un error serio: quitar el `!` de un campo vacío
dejaría una cuenta **sin contraseña**.

### 2.4 `userdel`: la baja, y el archivo huérfano

> ⚠️ **Advertencia**: `userdel -r` **borra el home y el spool de correo**.
> No hay papelera. Haz copia antes.

```bash
# Respaldo primero: -C entra a /home para guardar "ana" sin la ruta absoluta.
tar -czf /tmp/ana-home.tgz -C /home ana
tar -tzf /tmp/ana-home.tgz | head -2
# ana/
# ana/.profile

userdel -r ana        # borra la cuenta y /home/ana
# userdel: ana mail spool (/var/mail/ana) not found   <- aviso inofensivo
```

Sin `-r` la cuenta desaparece pero el home **queda con el UID como dueño
numérico**:

```bash
userdel ana
ls -ld /home/ana
# drwxr-x--- 2 1001 1001 4096 Oct 25 02:00 /home/ana
```

Un UID huérfano es un riesgo de seguridad: el siguiente `useradd` puede
reutilizar el 1001 y ese usuario nuevo **hereda el home de otra persona**.
Para buscar archivos de usuarios ya borrados, `find / -nouser` (Semana 09).

### 2.5 Grupos y un directorio compartido

Un grupo sirve para compartir sin abrir permisos a "otros". La receta
completa combina esta semana con la Semana 04 (SGID):

```bash
groupadd devs
usermod -aG devs ana
mkdir /srv/proy
chgrp devs /srv/proy      # el grupo dueño es devs
chmod 2770 /srv/proy      # 2 = SGID: lo creado dentro hereda el grupo devs
ls -ld /srv/proy
# drwxrws--- 2 root devs 4096 Oct 25 01:58 /srv/proy

su ana -c 'touch /srv/proy/a.txt; ls -l /srv/proy/a.txt'
# -rw-rw-r-- 1 ana devs 0 Oct 25 01:58 /srv/proy/a.txt
```

El archivo de `ana` quedó con grupo `devs` gracias al SGID, no al grupo
primario de `ana`. Alguien fuera del grupo no entra:

```bash
su luis -c 'ls /srv/proy'
# ls: cannot open directory '/srv/proy': Permission denied
```

> 💡 Esto se prueba con un usuario real, no con `root`: `root` salta los
> permisos y la prueba mentiría (Semana 04).

## 3. Cómo se usa

El ciclo completo de alta, cambio y baja de un colaborador:

```bash
# Alta: usuario, home, shell, grupo de trabajo.
useradd -m -s /bin/bash -c "Luis Prueba" -G devs luis

# Cambio de proyecto: se añade el grupo nuevo SIN quitar los viejos.
usermod -aG soporte luis

# Baja temporal (vacaciones largas): no se borra nada, solo se cierra la puerta.
usermod -L luis && usermod -s /usr/sbin/nologin luis

# Baja definitiva: respaldo, luego borrado con home.
tar -czf /tmp/luis-home.tgz -C /home luis && userdel -r luis
```

> 🔀 **Divergencia de distro**: la sintaxis de `useradd`/`usermod`/`userdel`
> es la misma en `ubuntu-lab`, `debian-lab`, `rhel-lab` y `arch-lab`
> (paquetes `passwd` y `login` en Debian, `shadow-utils` en RHEL, `shadow` en Arch). Cambia el grupo que da administración:
> `sudo` en Debian/Ubuntu, **`wheel`** en RHEL y Arch (archivo siguiente).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `usermod -G grupo usuario` sin `-a` | Reemplaza todos los grupos suplementarios del usuario | `usermod -aG grupo usuario` |
| `useradd nombre` sin `-m` ni `-s` | Sin home y con shell `/bin/sh` | `useradd -m -s /bin/bash nombre` |
| `userdel nombre` y olvidarse del home | Deja un UID huérfano que otro usuario puede heredar | Respaldo y `userdel -r`, o `find / -nouser` después |
| `userdel -r` sin respaldo | El home se borra sin papelera | `tar -czf` antes, siempre |
| Dar un grupo con `chmod 777` "para que funcione" | Abre la carpeta a todo el sistema | Grupo dedicado + `chmod 2770` |
| Crear cuentas de servicio con shell de login | Una cuenta de servicio con shell es una puerta de entrada | `useradd -r -s /usr/sbin/nologin servicio` |

## 5. Trucos

- `useradd -D` imprime los **valores por defecto** de `useradd` (shell,
  skel, grupo) sin tener que abrir `/etc/default/useradd`.
- `getent group devs | cut -d: -f4 | tr ',' '\n'` lista los miembros de un
  grupo uno por línea.
- `usermod -aG` acepta una lista: `usermod -aG devs,adm ana`, sin espacios
  tras la coma.
- `id -nG ana | tr ' ' '\n' | sort` ordena los grupos para comparar dos
  usuarios con `diff <(...) <(...)`.

## 📚 Recursos Adicionales

- `man useradd`, `man usermod`, `man userdel`, `man gpasswd`, `man chage`
- [Linux man-pages — useradd(8)](https://man7.org/linux/man-pages/man8/useradd.8.html)

## ✅ Checklist de Verificación

- [ ] `useradd -m -s /bin/bash -c "Ana Prueba" ana` crea `/home/ana` y `getent passwd ana` termina en `/bin/bash`
- [ ] Tras `usermod -aG devs ana`, `id -nG ana` incluye `devs` y su grupo anterior
- [ ] `usermod -G sudo ana` (sin `-a`) hace desaparecer `devs` de `id -nG ana`
- [ ] `userdel ana` deja `/home/ana` con dueño numérico visible en `ls -n`
- [ ] Un usuario fuera del grupo no puede hacer `ls /srv/proy`

---

[← 01 — Usuarios, UID y los archivos de cuentas](01-usuarios-uid-y-los-archivos-de-cuentas.md) · [sudo, su y mínimo privilegio →](03-sudo-su-y-minimo-privilegio.md)
