# sudo, su y el mínimo privilegio

> Trabajar como `root` todo el día es el equivalente a conducir sin cinturón:
> funciona hasta el día en que no. `sudo` existe para dar **solo el poder
> que una tarea necesita, solo mientras la hace, y dejando rastro**.

## 🎯 Objetivos

- Explicar la diferencia entre `su`, `su -`, `sudo` y `sudo -i`
- Leer qué puede hacer un usuario con `sudo -l`
- Escribir una regla de `sudoers` con el comando mínimo, validada con `visudo`
- Reconocer `sudo su -` y `NOPASSWD: ALL` como antipatrones

## 1. Qué problema resuelve

En el archivo 01 viste que `root` es el UID `0`: el kernel le salta casi
todas las comprobaciones. Dar la contraseña de `root` a cinco personas
significa que **cinco personas son indistinguibles en los registros** y
que revocar a una exige cambiar la contraseña de todas.

`sudo` invierte el modelo: cada persona usa **su propia identidad**, el
sistema consulta una política (`/etc/sudoers`) que dice quién puede
ejecutar qué como quién, y cada ejecución queda registrada con el nombre
real. El principio detrás se llama **mínimo privilegio**: ningún usuario
ni proceso debería tener más permisos de los que su tarea requiere.

## 2. Cómo funciona

### 2.1 `su` y `su -`: cambiar de identidad

`su` (*substitute user*) abre una shell como otro usuario. Pide **la
contraseña de ese otro usuario**, salvo que seas `root`. La diferencia
entre `su` y `su -` es el entorno que carga:

```bash
cd /tmp

su luis -c 'pwd; echo HOME=$HOME'     # sin guion: conserva tu directorio actual
# /tmp
# HOME=/home/luis

su - luis -c 'pwd; echo HOME=$HOME'   # con guion: sesion de login completa
# /home/luis
# HOME=/home/luis
```

`su -` (equivale a `su -l`) simula un inicio de sesión: limpia el entorno,
carga los perfiles del usuario y entra a **su** home. Sin el guion
conservas variables y directorio del usuario anterior, mezcla que causa
errores difíciles de rastrear ("funciona con mi usuario, falla con el
otro"). Regla práctica: si quieres *ser* ese usuario, usa `su -`.

### 2.2 `sudo`: una orden, con otra identidad

```bash
# Instala sudo primero: no viene en la imagen minima de ubuntu-lab.
apt-get install -y sudo     # (como root dentro del contenedor)
```

> 🔀 **Divergencia de distro**: `sudo` **no viene preinstalado** en las
> imágenes mínimas de Ubuntu, Debian, Rocky ni Arch que usa el laboratorio.
> En un servidor o escritorio real sí suele estar. El paquete se llama
> igual (`sudo`) en las cuatro familias; solo cambia el gestor que lo
> instala (archivos 04 y 05).

`sudo comando` ejecuta **una sola orden** como `root` (o como el usuario
que indiques con `-u`), tras pedir **tu** contraseña, no la de `root`:

```bash
sudo -u luis id          # ejecutar como luis, no como root

# -n: no preguntes; falla si haria falta contraseña. Como root nunca la pide,
# por eso la prueba se hace con un usuario normal.
su luis -c 'sudo -n true'
# sudo: a password is required
```

`sudo -n` es lo que se usa en scripts: un `sudo` que se queda esperando
una contraseña en un script de `cron` es un fallo silencioso (Semana 16).

### 2.3 La política: `/etc/sudoers` y `sudoers.d`

La política vive en `/etc/sudoers`, y **no se edita con un editor
normal**: se edita con `visudo`, que bloquea el archivo y valida la sintaxis
antes de guardar. Un `sudoers` roto te deja **sin `sudo`**, y sin `sudo` ni
contraseña de `root` no hay forma fácil de repararlo.

```bash
grep -v '^#' /etc/sudoers | grep .
# Defaults	env_reset
# Defaults	mail_badpass
# Defaults	secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
# Defaults	use_pty
# root	ALL=(ALL:ALL) ALL
# %admin ALL=(ALL) ALL
# %sudo	ALL=(ALL:ALL) ALL
# @includedir /etc/sudoers.d
```

Cada regla se lee `QUIEN  DONDE=(COMO_QUIEN:COMO_GRUPO)  QUE`:

| Regla | Significa |
|---|---|
| `root ALL=(ALL:ALL) ALL` | El usuario `root`, en cualquier host, como cualquier usuario y grupo, cualquier comando |
| `%sudo ALL=(ALL:ALL) ALL` | **Todo miembro del grupo `sudo`** (el `%` indica grupo) puede hacer lo mismo |
| `@includedir /etc/sudoers.d` | Lee además todos los archivos de esa carpeta |

La carpeta `sudoers.d` es el sitio correcto para **tus** reglas: un
archivo por tema, que se puede añadir y quitar sin tocar el principal.

> 🔀 **Divergencia de distro**: el grupo que da administración cambia.
> En **Debian/Ubuntu** es `sudo` (regla `%sudo` activa por defecto). En
> **RHEL/Rocky** es `wheel` (regla `%wheel ALL=(ALL) ALL` activa por
> defecto). En **Arch** también es `wheel`, pero la regla viene
> **comentada** (`# %wheel ALL=(ALL:ALL) ALL`) y hay que activarla con
> `visudo`. Meter a alguien en `sudo` en una Rocky no le da ningún poder.

### 2.4 Una regla de mínimo privilegio, validada

El caso real: `luis` solo necesita ejecutar *una orden concreta* como
`root`. No necesita `ALL`.

```bash
# NOPASSWD limita a UN comando con ruta absoluta; no es "ALL".
echo 'luis ALL=(root) NOPASSWD: /usr/bin/id' > /etc/sudoers.d/luis
chmod 0440 /etc/sudoers.d/luis       # 0440 (solo lectura) es lo que sudo espera en sudoers.d
visudo -cf /etc/sudoers.d/luis       # -c comprueba, -f indica el archivo
# /etc/sudoers.d/luis: parsed OK
```

`visudo -c` es la verificación ejecutable: **nunca dejes un archivo en
`sudoers.d` sin haber pasado por ella**. Con una sintaxis mala:

```bash
echo 'luis ALL=(root' > /tmp/mala
visudo -cf /tmp/mala; echo "codigo: $?"
# /tmp/mala:1:15: syntax error
# luis ALL=(root
#               ^
# codigo: 1
```

Qué puede hacer `luis` ahora, y qué no:

```bash
su luis -c 'sudo -l'
# User luis may run the following commands on ubuntu-lab:
#     (root) NOPASSWD: /usr/bin/id

su luis -c 'sudo -n id'
# uid=0(root) gid=0(root) groups=0(root)

su luis -c 'sudo -n ls /'
# sudo: a password is required
```

`id` como root funciona; **cualquier otra cosa** exige contraseña, y
`luis` no tiene una. Eso es el mínimo privilegio en acción. `sudo -l`
(también `sudo -l -U usuario` como administrador) es la forma de
**auditar** qué puede hacer alguien sin leer `sudoers` a mano.

Los permisos del archivo importan: si queda escribible por todos, `sudo`
**se niega a leerlo**:

```bash
chmod 0666 /etc/sudoers.d/luis
su luis -c 'sudo -n id'
# sudo: /etc/sudoers.d/luis is world writable
# sudo: a password is required
chmod 0440 /etc/sudoers.d/luis
```

## 3. Cómo se usa

| Necesitas… | Usa | Por qué |
|---|---|---|
| Una orden como `root` | `sudo orden` | Una acción, un registro, se vuelve a ser tú al terminar |
| Editar un archivo de sistema | `sudoedit /etc/archivo` | Edita una copia con **tu** editor y solo escribe al guardar |
| Ser otro usuario (probar su entorno) | `sudo -u luis -i` o `su - luis` | Entorno de login completo del otro usuario |
| Ver qué puedes hacer | `sudo -l` | Evita descubrirlo con un "not allowed" a mitad de tarea |
| Una shell de `root` de verdad | `sudo -i` **solo si hay una razón** | Pierdes el registro por orden: úsalo con parquedad |

> 🔐 **Seguridad**: en todo el bootcamp, `sudo` va con el **comando
> mínimo necesario**. `sudo su -` y `sudo bash` convierten un registro
> auditable en una shell de `root` anónima (antipatrón de la tabla
> siguiente).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `sudo su -` / `sudo bash` por costumbre | Una sesión de `root` completa; los comandos ya no se registran uno a uno | `sudo orden` para cada acción que lo necesite |
| `usuario ALL=(ALL) NOPASSWD: ALL` | Es `root` sin contraseña: quien robe la sesión, es `root` | `NOPASSWD:` solo con ruta absoluta a un comando concreto |
| Editar `/etc/sudoers` con `nano` | Un error de sintaxis deja a todos sin `sudo` | `visudo`, o un archivo en `sudoers.d` validado con `visudo -cf` |
| Regla con comando sin ruta absoluta | Puede resolver a un ejecutable que el usuario controla en su `PATH` | `/usr/bin/systemctl`, nunca `systemctl` |
| Dar `sudo` para un editor o `less` | Esos programas abren una shell (`!sh`): escape a `root` | `sudoedit`, o ningún acceso |
| Compartir la contraseña de `root` | No hay trazabilidad ni revocación individual | Una cuenta por persona + `sudo` |

## 5. Trucos

- `sudo -k` descarta la caché de credenciales: la siguiente orden vuelve a
  pedir contraseña. Útil tras dejar la sesión de `sudo` abierta.
- `sudo !!` repite la **orden anterior** con `sudo` delante — el atajo para
  el "Permission denied" que acabas de recibir (es expansión de historial
  de `bash`, Semana 01).
- `sudo -l -U ana` (como administrador) lista lo que **otro** usuario puede
  hacer sin impersonarlo.
- `visudo -c` sin `-f` valida **toda** la política, incluidos los archivos
  de `sudoers.d`: pásalo como última comprobación antes de cerrar sesión.

## 📚 Recursos Adicionales

- `man sudoers` (la sintaxis completa de reglas), `man sudo`, `man visudo`
- [sudo.ws — manual de sudoers](https://www.sudo.ws/docs/man/sudoers.man/)

## ✅ Checklist de Verificación

- [ ] `su luis -c pwd` imprime el directorio actual, `su - luis -c pwd` imprime `/home/luis`
- [ ] `visudo -cf /etc/sudoers.d/luis` responde `parsed OK`
- [ ] `su luis -c 'sudo -l'` lista **solo** `/usr/bin/id`
- [ ] `su luis -c 'sudo -n ls /'` falla con `a password is required`
- [ ] Un archivo con `chmod 0666` en `sudoers.d` hace que `sudo` lo rechace

---

[← 02 — Crear y modificar usuarios y grupos](02-crear-y-modificar-usuarios-y-grupos.md) · [Qué es un gestor de paquetes →](04-que-es-un-gestor-de-paquetes.md)
