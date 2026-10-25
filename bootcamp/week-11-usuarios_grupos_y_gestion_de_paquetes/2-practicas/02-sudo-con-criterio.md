# Práctica 02: sudo con criterio

Corre dentro de `ubuntu-lab` como `root`. La meta no es "tener `sudo`": es
dar a una persona **una sola orden** con privilegios, comprobar que lo demás
sigue prohibido, y dejar la política validada.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Instalar `sudo` y crear al usuario de prueba

**Por qué**: la imagen mínima de `ubuntu-lab` **no trae `sudo`**
(archivo 03). Instalarlo es también un primer uso real del gestor de
paquetes de la Semana 11.

**Comando**:

```bash
command -v sudo || echo "sin sudo"
apt-get update >/dev/null && apt-get install -y sudo >/dev/null
useradd -m -s /bin/bash luis
```

**Verifica**:

```bash
command -v sudo
# /usr/bin/sudo

sudo --version | head -1
# Sudo version 1.9.15p5
```

## Paso 2: Comparar `su` y `su -`

**Por qué**: la diferencia es el entorno. Verla en dos líneas evita
meses de "funciona con mi usuario y falla con el otro".

**Comando**:

```bash
cd /tmp
su luis -c 'pwd; echo HOME=$HOME'
su - luis -c 'pwd; echo HOME=$HOME'
```

**Verifica**: la primera conserva `/tmp`, la segunda entra al home.

```bash
su luis -c pwd
# /tmp
su - luis -c pwd
# /home/luis
```

## Paso 3: Escribir una regla mínima, validarla y **luego** instalarla

**Por qué**: un error en `/etc/sudoers.d` puede dejar a todos sin `sudo`.
El patrón seguro es escribir en `/tmp`, **validar con `visudo`**, y solo si
pasa copiar al sitio definitivo con los permisos correctos.

**Comando**:

```bash
# Una sola orden, con ruta absoluta: es el minimo privilegio.
echo 'luis ALL=(root) NOPASSWD: /usr/bin/id' > /tmp/luis.sudoers
visudo -cf /tmp/luis.sudoers
install -m 0440 -o root -g root /tmp/luis.sudoers /etc/sudoers.d/luis
```

**Verifica**:

```bash
visudo -cf /tmp/luis.sudoers
# /tmp/luis.sudoers: parsed OK

ls -l /etc/sudoers.d/luis
# -r--r----- 1 root root 38 Oct 25 02:10 /etc/sudoers.d/luis
```

`install -m 0440 -o root -g root` crea el archivo **con** modo y dueño en un
solo paso, sin ventana en la que quede con permisos de más.

## Paso 4: Comprobar lo permitido y lo prohibido

**Por qué**: una política solo está verificada cuando has visto **ambos**
lados: lo que funciona y lo que se rechaza.

**Comando**:

```bash
su luis -c 'sudo -l'
su luis -c 'sudo -n id'
su luis -c 'sudo -n ls /'
```

**Verifica**:

```bash
su luis -c 'sudo -l' | tail -2
# User luis may run the following commands on ubuntu-lab:
#     (root) NOPASSWD: /usr/bin/id

su luis -c 'sudo -n id'
# uid=0(root) gid=0(root) groups=0(root)

su luis -c 'sudo -n ls /'
# sudo: a password is required
```

`id` como `root` funciona; cualquier otra cosa se rechaza. `-n` evita que
`sudo` se quede esperando una contraseña: así falla de forma limpia, que es
lo que necesita un script.

## Paso 5: Romper los permisos a propósito

**Por qué**: ver cómo `sudo` reacciona a un archivo mal protegido enseña a
reconocer el mensaje cuando lo veas de verdad.

**Comando**:

```bash
chmod 0666 /etc/sudoers.d/luis
su luis -c 'sudo -n id'
```

**Verifica**: `sudo` **se niega a leer** la regla.

```bash
su luis -c 'sudo -n id' 2>&1
# sudo: /etc/sudoers.d/luis is world writable
# sudo: a password is required
```

Arréglalo y comprueba que vuelve a funcionar:

```bash
chmod 0440 /etc/sudoers.d/luis
su luis -c 'sudo -n id'
# uid=0(root) gid=0(root) groups=0(root)
```

## Paso 6: Detectar un error de sintaxis antes de que haga daño

**Por qué**: `visudo -c` es la red de seguridad. Un archivo con sintaxis
rota que llegara a `/etc/sudoers.d` podría dejar **sin `sudo`** a toda la
máquina.

**Comando**:

```bash
echo 'luis ALL=(root' > /tmp/mala.sudoers
visudo -cf /tmp/mala.sudoers; echo "codigo: $?"
```

**Verifica**:

```bash
visudo -cf /tmp/mala.sudoers; echo "codigo: $?"
# /tmp/mala.sudoers:1:15: syntax error
# luis ALL=(root
#               ^
# codigo: 1
```

Como falló en `/tmp`, **nunca llegó** a `/etc/sudoers.d`. Y para validar
**toda** la política de una sola vez:

```bash
visudo -c
# /etc/sudoers: parsed OK
# /etc/sudoers.d/README: parsed OK
# /etc/sudoers.d/luis: parsed OK
```

## Paso 7: Comparar el grupo administrador entre familias

**Por qué**: meter a alguien en `sudo` en una Rocky no le da ningún poder:
allí el grupo es `wheel`. Verlo en los cuatro contenedores fija la
divergencia.

**Comando** (desde **tu máquina**, fuera de `ubuntu-lab`; escribe `exit` antes):

```bash
for c in ubuntu-lab debian-lab rhel-lab arch-lab; do
  echo "== $c"
  docker exec "$c" getent group sudo wheel
done
```

**Verifica**:

```bash
# == ubuntu-lab
# sudo:x:27:ubuntu
# == debian-lab
# sudo:x:27:
# == rhel-lab
# wheel:x:10:
# == arch-lab
# wheel:x:998:
```

## Paso 8: Dejar el contenedor limpio

**Por qué**: una regla `NOPASSWD` olvidada en `/etc/sudoers.d` es un
agujero. Se quita lo que se creó.

**Comando**:

```bash
docker exec ubuntu-lab bash -c 'rm -f /etc/sudoers.d/luis /tmp/luis.sudoers /tmp/mala.sudoers && userdel -r luis'
```

**Verifica**:

```bash
docker exec ubuntu-lab ls /etc/sudoers.d
# README

docker exec ubuntu-lab getent passwd luis; echo "codigo: $?"
# codigo: 2
```

## ✅ Resultado

- [ ] Instalaste `sudo` y viste que no venía en la imagen
- [ ] Comprobaste que `su luis` conserva el directorio y `su - luis` entra al home
- [ ] Validaste una regla con `visudo -cf` **antes** de instalarla con `install -m 0440`
- [ ] Viste lo permitido (`id`) y lo prohibido (`ls /`) con `sudo -n`
- [ ] Reprodujiste `is world writable` y un `syntax error` sin dañar la política

```bash
./scripts/verificar-semana.sh 11
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `sudo: command not found` | `sudo` no está instalado | `apt-get update && apt-get install -y sudo` |
| `su luis -c 'sudo -n id'` pide contraseña | El archivo no está en `/etc/sudoers.d`, o tiene error | `visudo -c` y `ls -l /etc/sudoers.d/luis` |
| `visudo -cf` da `parsed OK` pero la regla no funciona | La ruta del comando no es absoluta o no existe | `command -v id` y usa esa ruta exacta |
| `apt-get install` falla con `Unable to locate package` | Falta el índice | `apt-get update` primero |
| `su: Authentication failure` | Intentas `su` desde un usuario **no** root | Esta práctica entra como `root`; `su` no pide contraseña a `root` |

---

[← Práctica 01](01-usuarios-y-grupos-reales.md) · [Práctica 03 →](03-paquetes-en-cuatro-familias.md)
