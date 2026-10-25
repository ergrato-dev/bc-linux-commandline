# Práctica 03: Menor privilegio, permisos peligrosos y SSH

> Duración: 60 min · Teoría: archivos [05](../1-teoria/05-menor-privilegio-y-permisos.md) y [06](../1-teoria/06-endurecer-unidades-y-ssh.md)

Todo ocurre en `ubuntu-lab`. Abre una shell dentro (`docker exec -it ubuntu-lab bash`)
y trabaja como `root`: es un contenedor desechable. Esta práctica **crea un usuario
y una regla de `sudo`** de prueba, y al final los borra; el paso 10 los limpia.

> ⚠️ No repitas estos pasos sobre tu máquina real sin entender cada uno: un error
> en `sudoers` o en `sshd_config` puede dejarte sin acceso.

## Paso 1: Conceder un solo comando con `sudo`

**Por qué**: dar `ALL` a una cuenta es root sin contraseña. Un comando concreto, con
ruta absoluta, reduce el daño si la cuenta se compromete. Y se **comprueba antes de
instalar**: un error de sintaxis en `sudoers` puede dejar a todos sin `sudo`.

**Comando**:

```bash
mkdir -p /run/sshd
useradd -m -s /bin/bash ana
# Se escribe fuera de /etc, se comprueba, y solo entonces se instala (modo 0440).
printf 'ana ALL=(root) NOPASSWD: /usr/bin/systemctl status *\n' > /tmp/ana.rule
visudo -cf /tmp/ana.rule
install -m 0440 -o root -g root /tmp/ana.rule /etc/sudoers.d/ana
```

**Verifica**:

```bash
visudo -cf /tmp/ana.rule
# /tmp/ana.rule: parsed OK
stat -c '%a %U:%G' /etc/sudoers.d/ana
# 440 root:root
```

## Paso 2: Auditar qué puede hacer una cuenta

**Por qué**: `sudo -l -U` te dice, como root, qué puede ejecutar otra cuenta sin
entrar como ella. Es la auditoría de `sudo` en una línea.

**Comando**:

```bash
sudo -l -U ana
```

**Verifica**:

```bash
sudo -l -U ana | tail -2
# User ana may run the following commands on ubuntu-lab:
#     (root) NOPASSWD: /usr/bin/systemctl status *
```

## Paso 3: Comprobar que lo demás sigue cerrado

**Por qué**: una regla se prueba por lo que **impide**, no solo por lo que permite.
`-n` hace que `sudo` falle en vez de quedarse esperando una contraseña.

**Comando**:

```bash
# ana intenta leer /etc/shadow con sudo: no esta en su regla.
su ana -c 'sudo -n /usr/bin/cat /etc/shadow'; echo "rc=$?"
```

**Verifica**:

```bash
su ana -c 'sudo -n /usr/bin/cat /etc/shadow' 2>&1; echo "rc=$?"
# sudo: a password is required
# rc=1
```

## Paso 4: Dejar que `visudo` encuentre el error

**Por qué**: con un paréntesis sin cerrar, `visudo -cf` señala la línea y la columna
y devuelve `1`. Sin esta comprobación, el archivo habría roto `sudo` al instalarse.

**Comando**:

```bash
printf 'ana ALL=(ALL NOPASSWD ALL\n' > /tmp/mala.rule
visudo -cf /tmp/mala.rule; echo "rc=$?"
```

**Verifica**:

```bash
visudo -cf /tmp/mala.rule 2>&1 | head -1
# /tmp/mala.rule:1:14: syntax error
visudo -cf /tmp/mala.rule >/dev/null 2>&1; echo "rc=$?"
# rc=1
```

## Paso 5: Inventariar setuid y setgid

**Por qué**: un binario setuid se ejecuta con los permisos de su dueño. La lista de
un sistema sano es corta y conocida; cualquier añadido merece una explicación.

**Comando**:

```bash
find /usr/bin -xdev -type f -perm -4000 -printf '%m %u %p\n' | sort -k3
find /usr/bin -xdev -type f -perm -2000 -printf '%m %g %p\n' | sort -k3
```

**Verifica**:

```bash
find /usr/bin -xdev -type f -perm -4000 | wc -l
# 9
find /usr/bin -xdev -type f -perm -2000 | wc -l
# 4
find /usr/bin -xdev -type f -perm -4000 -name passwd -printf '%m %u\n'
# 4755 root
```

## Paso 6: Arreglar un directorio compartido sin sticky

**Por qué**: un directorio `777` deja a cualquiera borrar los archivos de otros. El
bit *sticky* (`1777`) lo corrige: solo el dueño puede borrar lo suyo. Lo creas mal a
propósito, lo encuentras y lo arreglas.

**Comando**:

```bash
rm -rf /tmp/wk19 && mkdir -p /tmp/wk19/open && chmod 0777 /tmp/wk19/open
# Escribible por otros (-0002) y SIN sticky (! -1000):
find /tmp/wk19 -type d -perm -0002 ! -perm -1000
chmod +t /tmp/wk19/open
```

**Verifica**:

```bash
find /tmp/wk19 -type d -perm -0002 ! -perm -1000 | wc -l
# 0
stat -c '%a' /tmp/wk19/open
# 1777
```

## Paso 7: Ver el efecto de la `umask`

**Por qué**: los permisos por defecto nacen de la `umask`. Con `022` los archivos
salen legibles por todos; para datos sensibles, `077`.

**Comando**:

```bash
(umask 077; touch /tmp/wk19/p; stat -c '%a' /tmp/wk19/p)
(umask 022; touch /tmp/wk19/q; stat -c '%a' /tmp/wk19/q)
```

**Verifica**:

```bash
stat -c '%a %n' /tmp/wk19/p /tmp/wk19/q
# 600 /tmp/wk19/p
# 644 /tmp/wk19/q
```

## Paso 8: Leer la configuración efectiva de SSH

**Por qué**: `sshd_config` y `sshd_config.d/` se combinan y **gana la primera
aparición**. `sshd -T` te da el resultado real; leer el archivo a ojo, no.

**Comando**:

```bash
sshd -T | grep -iE '^(permitrootlogin|passwordauthentication|x11forwarding)' | sort
printf 'PasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/50-cloud.conf
printf 'PasswordAuthentication no\n'  > /etc/ssh/sshd_config.d/10-hard.conf
sshd -T | grep -i '^passwordauthentication'
```

**Verifica**:

```bash
sshd -T | grep -i '^passwordauthentication'
# passwordauthentication no
# (10-hard.conf se lee antes que 50-cloud.conf: gana. Sin el 10 saldria "yes".)
```

## Paso 9: Auditar un `sshd_config` con `toolkit harden ssh`

**Por qué**: tu herramienta reproduce las reglas del paso 8: primera aparición,
sin distinguir mayúsculas, y parando en `Match`. Pruébalo con un archivo donde
`yes` aparece **antes** de `no`.

**Comando**:

```bash
cat > /tmp/wk19/sshd_config <<'EOF'
# configuracion de practica
PermitRootLogin yes
permitrootlogin no
Match User bob
    PasswordAuthentication no
EOF
/root/bin/toolkit.sh harden ssh /tmp/wk19/sshd_config; echo "rc=$?"
```

**Verifica**:

```bash
/root/bin/toolkit.sh harden ssh /tmp/wk19/sshd_config
# riesgo PermitRootLogin: permite entrar como root (valor: yes)
# riesgo PasswordAuthentication: admite contrasenas (valor: por defecto, yes)
# ok PermitEmptyPasswords
# ok X11Forwarding
# hallazgos: 2
```

Dos lecciones en esa salida: el `no` de `permitrootlogin` **no cuenta** porque `yes`
va primero, y el `PasswordAuthentication no` dentro de `Match` tampoco: solo se
aplica a `bob`. Ahora corrígelo y comprueba:

```bash
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/; 1a PasswordAuthentication no\nX11Forwarding no' /tmp/wk19/sshd_config
/root/bin/toolkit.sh harden ssh /tmp/wk19/sshd_config --quiet; echo "rc=$?"
sshd -t -f /tmp/wk19/sshd_config; echo "rc=$?"
# hallazgos: 0
# rc=0
# rc=0
```

## Paso 10: Auditar permisos y limpiar

**Por qué**: `harden perms` repite el trabajo de los pasos 5 y 6 con una sola
orden. Después se borra todo lo creado: una práctica de seguridad no deja cuentas
ni reglas olvidadas.

**Comando**:

```bash
/root/bin/toolkit.sh harden perms /tmp/wk19; echo "rc=$?"
/root/bin/toolkit.sh harden perms /usr/bin --depth 1 | tail -3
# --- limpieza: solo lo que creaste en esta practica ---
rm -f /etc/ssh/sshd_config.d/10-hard.conf
userdel -r ana
rm -rf /etc/sudoers.d/ana /tmp/ana.rule /tmp/mala.rule /tmp/wk19
```

**Verifica**:

```bash
# Antes de borrar:
#   ok perms
#   hallazgos: 0
#   rc=0
# y sobre /usr/bin (suid y sgid reales del sistema):
#   riesgo suid: /usr/bin/sudo
#   riesgo suid: /usr/bin/umount
#   hallazgos: 13
# Despues de limpiar:
id ana 2>&1; ls /etc/sudoers.d
# id: 'ana': no such user
# README
```

## ✅ Resultado

- [ ] Concedí un único comando con `sudo` tras comprobarlo con `visudo -cf`
- [ ] Comprobé con `sudo -n` que lo demás sigue cerrado
- [ ] Vi el error de sintaxis de `visudo` (`rc=1`)
- [ ] Inventarié los binarios setuid (9) y setgid (4) de `/usr/bin`
- [ ] Corregí un directorio `777` sin sticky
- [ ] Demostré `umask 077` frente a `022`
- [ ] Usé `sshd -T` para ver que `10-` gana a `50-`
- [ ] `harden ssh` detectó dos riesgos y los dio por corregidos al arreglar el archivo

```bash
bash scripts/verificar-semana.sh 19
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `sshd -T`: `Missing privilege separation directory` | Falta `/run/sshd` | `mkdir -p /run/sshd` |
| `sshd -T`: `no hostkeys available` | No hay claves de host | `ssh-keygen -A` |
| `useradd: user 'ana' already exists` | Se ejecutó dos veces | `userdel -r ana` y repite |
| `visudo: command not found` | Falta el paquete `sudo` | `apt install sudo` en el laboratorio |
| `sudo -n` pide contraseña con el comando permitido | La ruta o el argumento no coinciden con la regla | Usa la ruta exacta (`/usr/bin/systemctl status ...`) |
| `harden ssh` no ve tu cambio | El valor está tras una línea `Match` | Muévelo antes del primer `Match` |
| `harden perms` tarda mucho | Recorre todo el árbol | Añade `--depth 1` |

---

[← Práctica 02: Unidades y endurecimiento](02-unidades-y-endurecimiento.md) · [Práctica 04: Contenedores desde el anfitrión →](04-contenedores-desde-el-anfitrion.md)
