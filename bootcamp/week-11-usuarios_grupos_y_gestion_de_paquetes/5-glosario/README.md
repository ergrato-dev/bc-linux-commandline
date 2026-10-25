# Glosario — Semana 11

**adduser**: asistente interactivo de la familia Debian para crear cuentas;
es un script del paquete `adduser` y no existe en RHEL ni en Arch, donde el
comando portable es `useradd`.

**apt**: frontend de paquetes de Debian/Ubuntu: lee los repositorios,
resuelve dependencias y llama a `dpkg` para instalar.

**AUR** (*Arch User Repository*): repositorio comunitario de Arch con
recetas (`PKGBUILD`) que se ejecutan en tu máquina; no son paquetes
revisados por la distribución.

**chage**: comando que muestra y cambia la caducidad de la contraseña de
una cuenta (`chage -l`, `chage -M 90`).

**dependencia** (*dependency*): paquete que otro necesita instalado para
funcionar; el gestor las resuelve y las instala en orden.

**dnf**: frontend de paquetes de la familia RHEL/Fedora; usa `rpm` por
debajo.

**dpkg**: herramienta de bajo nivel de Debian/Ubuntu que instala un
archivo `.deb` local y mantiene la base de paquetes instalados; no
resuelve dependencias.

**GECOS**: quinto campo de `/etc/passwd`, un comentario libre (nombre
real, teléfono); `useradd -c` lo rellena.

**gestor de paquetes** (*package manager*): programa que instala, actualiza
y quita software resolviendo dependencias y registrando qué archivo
pertenece a qué paquete.

**GID** (*Group ID*): número que identifica a un grupo; el campo 4 de
`/etc/passwd` guarda el GID primario de cada cuenta.

**grupo primario / suplementario**: el primario (campo 4 de `passwd`) es el
grupo con el que se crean los archivos nuevos; los suplementarios (campo 4
de `/etc/group`) amplían los permisos del usuario.

**InRelease**: índice firmado de un repositorio `apt` que lista los hashes
de todos sus paquetes; `apt update` lo descarga y verifica.

**mínimo privilegio** (*least privilege*): principio de dar a un usuario o
proceso solo los permisos que su tarea necesita.

**NSS** (*Name Service Switch*): capa que decide dónde buscar usuarios y
grupos (`files`, `ldap`, `sss`); `getent` la consulta, `cat /etc/passwd`
no.

**nologin**: shell especial (`/usr/sbin/nologin`) para cuentas que existen
pero no deben abrir sesión interactiva.

**pacman**: gestor de paquetes de Arch; resuelve dependencias e instala en
un solo binario, sin capa `dpkg`/`rpm` aparte.

**paquete** (*package*): archivo con programas y metadatos (versión,
dependencias) que un gestor sabe instalar y quitar.

**PPA** (*Personal Package Archive*): repositorio de terceros de Ubuntu
alojado en Launchpad y mantenido por una persona o equipo.

**purge**: variante de `apt remove` que además borra los archivos de
configuración del paquete; deja el estado `un` en `dpkg -l`.

**repositorio** (*repository*): servidor que publica un índice firmado y
los paquetes de una release de la distribución.

**rpm**: herramienta de bajo nivel de RHEL/Fedora que instala un `.rpm`
local; cada `.rpm` va firmado individualmente (`rpm -K` lo comprueba).

**shadow** (`/etc/shadow`): archivo con los hashes de contraseñas y su
caducidad, legible solo por `root` y el grupo `shadow`.

**shells** (`/etc/shells`): lista de shells válidas como shell de login;
una cuenta cuya shell no figura ahí no es un acceso interactivo real.

**Signed-By**: campo de una entrada `apt` (formato *deb822*) que fija la
única clave capaz de firmar ese repositorio.

**su**: comando para abrir una shell como otro usuario; `su -` simula un
inicio de sesión completo (entorno limpio, home del usuario).

**sudo**: comando que ejecuta **una orden** con otra identidad (por
defecto `root`) según la política de `/etc/sudoers`, dejando registro.

**sudoers**: archivo de política de `sudo` (`/etc/sudoers` y
`/etc/sudoers.d/`); se edita con `visudo`.

**UID 0**: el identificador del superusuario: el kernel salta casi todas
las comprobaciones de permisos a quien lo tiene, se llame como se llame.

**visudo**: editor seguro de `sudoers`: bloquea el archivo y valida la
sintaxis; `visudo -cf archivo` comprueba un archivo sin instalarlo.

**wheel**: grupo que da acceso a `sudo` en RHEL y Arch; en Debian/Ubuntu
el equivalente se llama `sudo`.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Índice del bootcamp →](../../README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
