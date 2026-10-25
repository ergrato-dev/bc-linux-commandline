# Menor privilegio y permisos peligrosos

> La mayoría de los incidentes de seguridad en una máquina Linux no usan un fallo exótico: usan un permiso de más.
> Esta semana aprendes a darle a cada cuenta y a cada archivo **solo lo que necesita**, y a encontrar lo que sobra.

## 🎯 Objetivos

- Dar a un usuario un comando concreto con `sudo` en lugar de una shell de root
- Comprobar un archivo de reglas con `visudo -c` antes de que rompa `sudo`
- Encontrar archivos con setuid/setgid y archivos o directorios escribibles por todos
- Explicar qué hace el bit *sticky* y por qué `/tmp` lo tiene
- Elegir una `umask` que no deje tus archivos legibles por todo el mundo

## 1. Qué problema resuelve

Las Semanas 04 y 11 te enseñaron permisos, usuarios y `sudo`. La pregunta de esta
semana es otra: dado un sistema **que no controlas**, ¿qué cuentas y qué archivos
darían más poder del necesario? Un atacante (o un script con una errata) hereda
los permisos de quien lo ejecuta: cuanto menos tenga esa cuenta, menos daño hace.
Eso es el **principio de mínimo privilegio**.

## 2. Cómo funciona

### 2.1 `sudo` por comando, no por shell

La regla más cómoda y más peligrosa es `ana ALL=(ALL) NOPASSWD: ALL`: ana es
root sin contraseña. Casi nunca hace falta. Se puede conceder **un** comando:

```bash
docker exec ubuntu-lab bash -c '
useradd -m -s /bin/bash ana
printf "ana ALL=(root) NOPASSWD: /usr/bin/systemctl status *\n" > /etc/sudoers.d/ana
chmod 0440 /etc/sudoers.d/ana
sudo -l -U ana | tail -2'
# User ana may run the following commands on ubuntu-lab:
#     (root) NOPASSWD: /usr/bin/systemctl status *
```

Se lee: el usuario `ana`, en cualquier máquina (`ALL`), puede ejecutar como `root`
**solo** `/usr/bin/systemctl status ...`, sin contraseña. Y lo demás queda
cerrado:

```bash
docker exec ubuntu-lab su ana -c 'sudo -n /usr/bin/cat /etc/shadow'
# sudo: a password is required
```

(`-n` evita que `sudo` se quede esperando una contraseña: falla y ya.) Tres
reglas para escribir reglas:

- **Ruta absoluta** del comando, nunca el nombre sin ruta.
- **Los argumentos cuentan.** Un comando sin argumentos permite cualquiera; con
  `*` permite todo lo que siga. `status *` es seguro para `systemctl status`; un
  `*` tras `vi` o `less` no lo es (abren una shell con `!sh`).
- **Un archivo por regla en `/etc/sudoers.d/`**, con modo `0440`. No toques
  `/etc/sudoers` directamente.

### 2.2 `visudo -c`: comprobar antes de bloquearte

Un error de sintaxis en un archivo de `sudoers` puede dejar a **nadie** con
`sudo`. `visudo` es el editor que comprueba la sintaxis antes de guardar, y
`visudo -c` comprueba lo ya existente:

```bash
docker exec ubuntu-lab visudo -c
# /etc/sudoers: parsed OK
# /etc/sudoers.d/README: parsed OK
# /etc/sudoers.d/ana: parsed OK
```

Con una regla mal escrita señala la línea y la columna, y el código de salida es
distinto de cero:

```bash
docker exec ubuntu-lab bash -c '
printf "ana ALL=(ALL NOPASSWD ALL\n" > /tmp/mala
visudo -cf /tmp/mala; echo "rc=$?"'
# /tmp/mala:1:14: syntax error
# ana ALL=(ALL NOPASSWD ALL
#              ^~~~~~~~
# rc=1
```

`-f ARCHIVO` comprueba un archivo **antes** de copiarlo a `/etc/sudoers.d/`: el
flujo seguro es escribir en `/tmp`, `visudo -cf`, y solo entonces instalar.
Un modo distinto de `0440` también se avisa:

```bash
docker exec ubuntu-lab bash -c 'chmod 0644 /etc/sudoers.d/ana; visudo -c 2>&1 | grep bad; chmod 0440 /etc/sudoers.d/ana'
# /etc/sudoers.d/ana: bad permissions, should be mode 0440
```

### 2.3 Cuentas bloqueadas

Una cuenta sin contraseña válida **no puede iniciar sesión con contraseña**. Se
ve con `passwd -S`:

```bash
docker exec ubuntu-lab passwd -S ana
# ana L 2026-10-25 0 99999 7 -1
```

La `L` es *locked*. `passwd -l USUARIO` bloquea una cuenta que ya no se usa sin
borrarla (sus archivos siguen siendo suyos); `passwd -u` la desbloquea si tiene
contraseña. Las cuentas de servicio (`www-data`, `syslog`) se crean bloqueadas y
con shell `/usr/sbin/nologin`: no son personas.

### 2.4 setuid y setgid: ejecutar con otros permisos

Un archivo con el bit **setuid** se ejecuta con los permisos de su **propietario**,
no de quien lo lanza. Es como `passwd` puede modificar `/etc/shadow` siendo tú un
usuario normal. Se ve como una `s` en el permiso (`4755`):

```bash
docker exec ubuntu-lab bash -c 'find /usr/bin -xdev -type f -perm -4000 -printf "%m %u %p\n" | sort -k3 | head -4'
# 4755 root /usr/bin/chfn
# 4755 root /usr/bin/chsh
# 4755 root /usr/bin/gpasswd
# 4755 root /usr/bin/mount
```

Y **setgid** (`2755`) lo mismo con el **grupo**:

```bash
docker exec ubuntu-lab bash -c 'find /usr/bin -xdev -type f -perm -2000 -printf "%m %g %p\n" | sort -k3 | head -3'
# 2755 shadow /usr/bin/chage
# 2755 crontab /usr/bin/crontab
# 2755 shadow /usr/bin/expiry
```

Esa lista es **corta y conocida** en una instalación sana. Lo que hay que
buscar es un binario setuid que **no** debería estar: un `find` o un editor
setuid propiedad de root es una puerta abierta, porque lo que ejecutes desde él
corre como root. `toolkit harden perms` te hace este recorrido.

### 2.5 Escribible por todos y el bit *sticky*

Un archivo `-rw-rw-rw-` (modo `666`) lo puede cambiar cualquiera. Un
**directorio** con `777` además deja a cualquiera **borrar** los archivos de otros.
El bit *sticky* (`1777`, la `t` final) lo arregla: solo el propietario del
archivo (o root) puede borrarlo o renombrarlo aunque el directorio sea de todos.

```bash
docker exec ubuntu-lab stat -c '%a %A %n' /tmp
# 1777 drwxrwxrwt /tmp
```

Por eso `/tmp` y `/var/tmp` son `1777`. La búsqueda de riesgo es:

```bash
docker exec ubuntu-lab bash -c 'find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | head -3'
# (los directorios escribibles por todos que NO tienen sticky)
```

(`-perm -0002` = «el bit de escritura para *otros* está activo»; `! -perm -1000` =
«y el sticky no».) `-xdev` evita saltar a otros sistemas de archivos, como `/proc`.

### 2.6 La `umask`: el origen de los permisos por defecto

Los permisos de un archivo nuevo nacen de un máximo (`666` para archivos, `777`
para directorios) **menos** la `umask`. Con `022` (la habitual) los archivos
salen `644`: legibles por todos. Con `077`, privados:

```bash
docker exec ubuntu-lab bash -c '
(umask 077; touch /tmp/u77; mkdir /tmp/d77; stat -c "%a %n" /tmp/u77 /tmp/d77)
(umask 022; touch /tmp/u22; stat -c "%a %n" /tmp/u22); rm -rf /tmp/u77 /tmp/d77 /tmp/u22'
# 600 /tmp/u77
# 700 /tmp/d77
# 644 /tmp/u22
```

Un script que crea archivos con datos sensibles (claves, copias, informes) debe
fijar `umask 077` al principio, o crear los archivos con `mktemp` (que ya los
hace `600`), como hiciste en `backup` (Semana 18).

## 3. Cómo se usa

### 3.1 Una revisión rápida de una máquina ajena

```bash
find / -xdev -type f -perm -4000 2>/dev/null | sort     # setuid: ¿todos conocidos?
find / -xdev -type f -perm -0002 2>/dev/null            # archivos escribibles por todos
find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null   # directorios sin sticky
sudo -l -U USUARIO                                      # qué puede hacer cada cuenta
visudo -c                                               # ¿están bien las reglas?
```

Cinco comandos, todos de solo lectura. `toolkit harden perms DIR` automatiza los
tres primeros.

### 3.2 Divergencia de distro

Los permisos y `sudo` son iguales en las cuatro familias; cambia **quién tiene
`sudo`**: en Debian/Ubuntu es el grupo `sudo`; en RHEL y Arch, `wheel` (Semana 11).
Y en RHEL con SELinux activo, además de los permisos clásicos manda el contexto
(`ls -Z`): un permiso correcto puede seguir denegado. Los contenedores del
laboratorio no lo ejecutan.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `NOPASSWD: ALL` | Es root sin contraseña para esa cuenta | Un comando concreto con ruta absoluta |
| `sudo su -` o `sudo bash` como costumbre | Pierdes el registro de qué hiciste y trabajas como root | `sudo COMANDO` cada vez |
| Editar `/etc/sudoers` a mano | Una errata bloquea `sudo` para todos | `visudo`, o un archivo en `sudoers.d` comprobado con `visudo -cf` |
| `chmod 777` «para que funcione» | Cualquiera lo cambia | Arreglar el propietario o el grupo, no abrir a todos |
| `chmod u+s` en un script o editor | Todo lo que ejecutes desde él corre como su dueño | No hacerlo; usar una regla de `sudo` |
| Directorio compartido sin sticky | Cualquiera borra los archivos de otros | `chmod 1777`, o mejor un grupo con setgid (`2770`) |
| `umask 000` | Todo lo que crees será escribible por todos | `022` por defecto, `077` para datos sensibles |
| Dejar cuentas antiguas activas | Credenciales olvidadas | `passwd -l`, y `userdel` cuando sobren |

## 5. Trucos

- **`sudo -l -U USUARIO`** (como root) enseña qué puede hacer una cuenta, sin
  entrar como ella. Es la auditoría de `sudo` en una línea.
- **`find / -xdev -newer /etc/passwd -type f -perm -4000`** busca setuid creados
  **después** de un archivo de referencia: un binario setuid reciente en un sistema
  estable merece una mirada.
- **`stat -c '%a %U:%G %n' /etc/shadow /etc/passwd /etc/sudoers`** en una línea:
  `640 root:shadow`, `644 root:root`, `440 root:root` es lo normal.

## 📚 Recursos Adicionales

- `man sudoers` (sintaxis completa) y `man visudo`
- `man 2 chmod`, sección de los bits setuid, setgid y sticky

## ✅ Checklist de Verificación

- [ ] Concedes un comando a un usuario con una regla en `sudoers.d` y compruebas con `sudo -l -U`
- [ ] Compruebas un archivo de reglas con `visudo -cf` y ves el error de sintaxis
- [ ] Listas los binarios setuid y setgid de `/usr/bin` y reconoces los habituales
- [ ] Encuentras directorios escribibles por todos sin sticky
- [ ] Explicas por qué `/tmp` es `1777`
- [ ] Demuestras el efecto de `umask 077` frente a `022`

---

[← Arranque, rendimiento y registros](04-arranque-rendimiento-y-registros.md) · [Endurecer unidades y SSH →](06-endurecer-unidades-y-ssh.md)
