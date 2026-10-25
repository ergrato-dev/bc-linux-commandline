# Práctica 01: usuarios y grupos reales

Toda esta práctica corre **dentro de `ubuntu-lab`**, como `root`, y deja el
contenedor limpio al final. Entra con:

```bash
docker exec -it ubuntu-lab bash
```

Las cuentas `ana` y `luis` son de práctica y se borran en el último paso.

## Paso 1: Contar las cuentas que ya existen

**Por qué**: antes de crear nada, saber qué hay. Es la línea base contra la
que verás cambiar la máquina, y repasa el rango de UID del archivo 01.

**Comando**:

```bash
# UID entre UID_MIN y UID_MAX de login.defs = cuentas regulares (personas).
getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 { n++ } END { print n + 0 }'
```

**Verifica**:

```bash
getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 { print $1 }'
# ubuntu
```

## Paso 2: Crear un usuario completo

**Por qué**: `useradd` sin banderas crea una cuenta sin home y con shell
`/bin/sh`. Las tres banderas (`-m`, `-s`, `-c`) son las que hacen que la
cuenta sirva.

**Comando**:

```bash
useradd -m -s /bin/bash -c "Ana Prueba" ana
id ana
getent passwd ana
ls -ld /home/ana
```

**Verifica**:

```bash
getent passwd ana
# ana:x:1001:1001:Ana Prueba:/home/ana:/bin/bash

grep '^ana:' /etc/shadow | cut -d: -f1,2
# ana:!

passwd -S ana | cut -d' ' -f1,2
# ana L
```

El `!` y la `L` dicen lo mismo: la cuenta existe pero nadie puede entrar con
contraseña todavía.

## Paso 3: Reproducir la trampa de `usermod -G`

**Por qué**: es el error más caro del archivo 02. Hay que **verlo** destruir
un grupo para no repetirlo en una máquina real.

**Comando**:

```bash
groupadd devs
usermod -aG devs ana
id -nG ana
# ana devs

# Ahora, SIN -a:
usermod -G sudo ana
id -nG ana
```

**Verifica**: `devs` desapareció.

```bash
id -nG ana
# ana sudo

# Restaura con -a: se AÑADE, no se reemplaza.
usermod -aG devs ana
id -nG ana
# ana sudo devs
```

## Paso 4: Bloquear y cambiar la shell

**Por qué**: la baja temporal (vacaciones, investigación de un incidente)
cierra la puerta **sin borrar nada**, así que se puede deshacer.

**Comando**:

```bash
usermod -L ana
usermod -s /usr/sbin/nologin ana
```

**Verifica**:

```bash
getent passwd ana | cut -d: -f7
# /usr/sbin/nologin

su ana -c 'echo hola'
# This account is currently not available.
```

Devuélvela a su estado normal antes de seguir:

```bash
usermod -s /bin/bash ana
```

## Paso 5: La baja que deja un archivo huérfano

> ⚠️ **Advertencia**: `userdel -r` borra el home **sin papelera**, y este
> paso borra con `rm -rf` una carpeta de práctica. Haz el respaldo del
> primer comando **antes**, y comprueba la ruta antes de ejecutar `rm`.

**Por qué**: ver con tus ojos qué queda cuando se da de baja una cuenta
sin `-r`: el home sigue ahí, con un **número** como dueño.

**Comando**:

```bash
useradd -m -s /bin/bash luis
tar -czf /tmp/luis-home.tgz -C /home luis     # respaldo primero
userdel luis                                   # sin -r: el home se queda
ls -ldn /home/luis
find /home -nouser                             # archivos cuyo UID ya no existe
```

**Verifica**:

```bash
ls -ldn /home/luis
# drwxr-x--- 2 1002 1003 4096 Oct 25 02:10 /home/luis   <- UID/GID numericos, sin nombre

find /home -nouser | head -2
# /home/luis
# /home/luis/.profile
```

Los números (1002, 1003) pueden variar en tu máquina; lo importante es que
aparezcan **números en vez de nombres**. Limpieza, con la ruta ya revisada:

```bash
rm -rf /home/luis /tmp/luis-home.tgz
find /home -nouser | wc -l
# 0
```

## Paso 6: Un directorio compartido con SGID

**Por qué**: es la receta real para que un equipo comparta archivos sin
abrir la carpeta a todo el sistema. Se prueba con **usuarios normales**,
nunca con `root` (que se salta los permisos).

**Comando**:

```bash
useradd -m -s /bin/bash luis      # luis NO esta en devs
mkdir /srv/proy
chgrp devs /srv/proy
chmod 2770 /srv/proy
su ana -c 'touch /srv/proy/a.txt'
```

**Verifica**:

```bash
ls -ld /srv/proy
# drwxrws--- 2 root devs 4096 Oct 25 02:10 /srv/proy

ls -l /srv/proy/a.txt
# -rw-rw-r-- 1 ana devs 0 Oct 25 02:10 /srv/proy/a.txt

su luis -c 'ls /srv/proy'
# ls: cannot open directory '/srv/proy': Permission denied
```

El archivo de `ana` nació con grupo `devs` (SGID), y `luis` no entra.

## Paso 7: Dejar el contenedor limpio

**Por qué**: las prácticas siguientes asumen que `ana`, `luis` y `devs` no
existen. Un laboratorio sucio es la causa número uno de resultados raros.

**Comando**:

```bash
userdel -r ana
userdel -r luis
groupdel devs
rm -rf /srv/proy
```

**Verifica**:

```bash
getent passwd ana luis devs; echo "codigo: $?"
# codigo: 2

getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 { print $1 }'
# ubuntu
```

## ✅ Resultado

- [ ] Creaste `ana` con home, shell y comentario, y `getent passwd ana` lo confirma
- [ ] Reprodujiste que `usermod -G` sin `-a` borra grupos y lo corregiste con `-aG`
- [ ] Viste un home huérfano con `ls -ldn` y lo localizaste con `find -nouser`
- [ ] Probaste un directorio SGID con un usuario dentro y otro fuera del grupo
- [ ] El contenedor quedó sin `ana`, `luis` ni `devs`

```bash
./scripts/verificar-semana.sh 11
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `useradd: user 'ana' already exists` | Una práctica anterior dejó la cuenta | `userdel -r ana` y repetir el paso |
| `ls /srv/proy` funciona para `luis` | `luis` entró en `devs` o la prueba se hizo como `root` | `id -nG luis` no debe incluir `devs`; prueba siempre con `su luis -c` |
| `su luis -c ...` dice `This account is currently not available` | La shell de `luis` quedó en `nologin` | `usermod -s /bin/bash luis` |
| `su ana -c 'echo hola'` imprime `hola` en el Paso 4 | La shell no cambió a `nologin` | Repetir `usermod -s /usr/sbin/nologin ana` y comprobar con `getent` |
| `find /home -nouser` no encuentra nada | El `userdel` usó `-r` | Repetir con `userdel luis` **sin** `-r` |

---

[← 07 — Construyendo acctaudit y pkgcheck](../1-teoria/07-construyendo-acctaudit-y-pkgcheck.md) · [Práctica 02 →](02-sudo-con-criterio.md)
