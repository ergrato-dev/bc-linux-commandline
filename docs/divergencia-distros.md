# Divergencia entre distribuciones

Ubuntu 24.04 LTS es el entorno canónico de este bootcamp: todas las prácticas
y todo el autograding corren contra `ubuntu-lab`. Pero el objetivo es que
operes **cualquier** distro mayor, así que donde un comando cambia de familia
a familia, el material lo dice explícito acá — no solo en prosa suelta dentro
de cada semana.

Esta tabla crece semana a semana. Cada fila enlaza a la semana donde se
explica en profundidad.

| Área | Ubuntu/Debian (`apt`) | RHEL/Fedora (`dnf`) | Arch (`pacman`) | Semana |
|---|---|---|---|:--:|
| Gestor de paquetes | `apt install` / `apt remove` | `dnf install` / `dnf remove` | `pacman -S` / `pacman -R` | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Buscar paquete | `apt search` | `dnf search` | `pacman -Ss` | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Firewall por defecto | `ufw` | `firewalld` | ninguno preinstalado | [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |
| Init / service manager | systemd | systemd | systemd (base mínima, menos unidades preinstaladas) | [16](../bootcamp/week-16-automatizacion_y_tareas_programadas/), [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |
| Seguridad obligatoria | AppArmor (activo por defecto) | SELinux (activo por defecto) | ninguno por defecto | [04](../bootcamp/week-04-permisos_y_propiedad/) |
| ACLs | `acl` paquete aparte en bases mínimas | preinstalado en la mayoría | paquete `acl` aparte | [04](../bootcamp/week-04-permisos_y_propiedad/) |
| `awk` por defecto | `mawk` (liviano, sin extensiones de gawk) | `gawk` (GNU Awk completo) | `gawk` (GNU Awk completo) | [08](../bootcamp/week-08-awk_y_pipelines_de_datos/) |
| `ps`/`pgrep`/`pkill` (paquete `procps`) | preinstalado en `ubuntu-lab`; ausente en imágenes `debian` mínimas | ausente en imágenes `rhel`/UBI mínimas, requiere `dnf install procps-ng` | preinstalado (`procps-ng`) | [10](../bootcamp/week-10-gestion_de_procesos_y_senales/) |
| Grupo que da acceso a `sudo` | `sudo` (regla `%sudo` activa) | `wheel` (regla `%wheel` activa) | `wheel` (regla **comentada** en `sudoers`: hay que activarla con `visudo`) | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| `sudo` en la imagen mínima | ausente (`apt install sudo`) | ausente (`dnf install sudo`) | ausente (`pacman -S sudo`) | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Asistente de alta de usuarios | `useradd` y también `adduser` (Perl, interactivo) | solo `useradd` | solo `useradd` | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Quitar paquete y su configuración | `apt remove` (conserva config, estado `rc`) / `apt purge` | `dnf remove` (config modificada queda como `.rpmsave`; no hay `purge`) | `pacman -R` (`.pacsave`) / `pacman -Rn` | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Dónde vive la firma del paquete | En el **índice** del repositorio (`InRelease`); un `.deb` suelto no se verifica | En **cada `.rpm`** (`rpm -K` lo comprueba) | En cada paquete (`SigLevel` de `pacman.conf`) | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Base de datos de paquetes instalados | `/var/lib/dpkg/status` (texto) | `/var/lib/rpm/rpmdb.sqlite` (SQLite) | `/var/lib/pacman/local/` (un directorio por paquete) | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Paquete de `ip` y `ss` | `iproute2` (ausente en `ubuntu-lab`/`debian-lab` mínimas) | `iproute` | `iproute2` | [12](../bootcamp/week-12-redes_desde_la_linea_de_comandos/) |
| Paquete de `dig`, `host` y `nslookup` | `bind9-dnsutils` (el nombre `dnsutils` es un alias) | `bind-utils` | `bind` | [12](../bootcamp/week-12-redes_desde_la_linea_de_comandos/) |
| `nc` (netcat) | `netcat-openbsd` (netcat de OpenBSD) | `nmap-ncat` (**Ncat**: las opciones básicas `-z`/`-v` coinciden, el resto no) | `openbsd-netcat` | [12](../bootcamp/week-12-redes_desde_la_linea_de_comandos/) |
| Cliente SSH (`ssh`, `scp`) | `openssh-client` | `openssh-clients` | `openssh` (cliente y servidor juntos) | [12](../bootcamp/week-12-redes_desde_la_linea_de_comandos/) |
| Servicio del servidor SSH | `ssh` (`ssh.service`); servidor en `openssh-server` | `sshd` (`sshd.service`) | `sshd` (`sshd.service`) | [12](../bootcamp/week-12-redes_desde_la_linea_de_comandos/) |
| Configuración de red persistente | Ubuntu: `netplan`; Debian: `ifupdown` o `systemd-networkd` | NetworkManager (`nmcli`) | `systemd-networkd` o NetworkManager, a elegir | [12](../bootcamp/week-12-redes_desde_la_linea_de_comandos/) |
| `/bin/sh` (el intérprete POSIX) | `dash` (no conoce `[[ ]]`: da `[[: not found`) | `bash` | `bash` | [13](../bootcamp/week-13-fundamentos_de_bash_scripting/) |
| Paquete de `shellcheck` | `shellcheck` | `ShellCheck`, **desde EPEL** (`dnf install epel-release` antes) | `shellcheck` | [13](../bootcamp/week-13-fundamentos_de_bash_scripting/) |
| Comando `hostname` en la imagen mínima | presente | presente | **ausente**: `uname -n` es la forma portable | [13](../bootcamp/week-13-fundamentos_de_bash_scripting/) |
| `patch` en la imagen mínima | ausente (`apt-get install patch`) | ausente (`dnf install patch`) | ausente (`pacman -S patch`) | [13](../bootcamp/week-13-fundamentos_de_bash_scripting/) |
| Archivo de login que carga `.bashrc` | `~/.profile` (esqueleto de Ubuntu) | `~/.bash_profile` (esqueleto de RHEL) | `~/.bash_profile` (esqueleto de Arch) | [17](../bootcamp/week-17-personalizacion_del_entorno_y_productividad/) |
| `~/bin` y `~/.local/bin` en el `PATH` | los añade `~/.profile` **al hacer login, si existen** | los añade `~/.bashrc` (con guarda) | **ninguno** de los dos | [17](../bootcamp/week-17-personalizacion_del_entorno_y_productividad/) |
| `PS1` por defecto del usuario | `\u@\h:\w\$` | `[\u@\h \W]\$` | `[\u@\h \W]\$` | [17](../bootcamp/week-17-personalizacion_del_entorno_y_productividad/) |
| `chsh -l` (listar shells) | **no existe** (`chsh` viene de `passwd`); usa `cat /etc/shells` | `chsh` no viene instalado (paquete `util-linux-user`) | funciona (`util-linux`) | [01](../bootcamp/week-01-terminal_shell_y_primeros_pasos/) |
| Paquete `bash-completion` | `bash-completion` | `bash-completion` | `bash-completion` (repositorio `extra`) | [17](../bootcamp/week-17-personalizacion_del_entorno_y_productividad/) |
| Paquete `screen` | `screen` | **desde EPEL** (`dnf install epel-release` antes) | `screen` | [17](../bootcamp/week-17-personalizacion_del_entorno_y_productividad/) |
| `bzip2`, `xz` y `zstd` en la imagen mínima | ausentes (`apt-get install bzip2 xz-utils zstd`) | ausentes (`dnf install bzip2 xz zstd`) | **ya instalados** | [18](../bootcamp/week-18-archivado_compresion_y_registros_del_sistema/) |
| Paquete de `xz` | `xz-utils` | `xz` | `xz` | [18](../bootcamp/week-18-archivado_compresion_y_registros_del_sistema/) |
| Registros de texto del sistema | `syslog` y `auth.log` (los escribe `rsyslog`, ausente en la imagen mínima) | `messages` y `secure` con `rsyslog`; en `rhel-lab` mínima no hay ninguno | solo el diario de `journald`; no hay `rsyslog` | [18](../bootcamp/week-18-archivado_compresion_y_registros_del_sistema/) |
| `/var/log/journal` (diario persistente) | existe | **ausente** en `rhel-lab`: con `Storage=auto` el diario es volátil | existe en `arch-lab` | [18](../bootcamp/week-18-archivado_compresion_y_registros_del_sistema/) |
| Paquete `logrotate` | `logrotate` (ausente en la imagen mínima) | `logrotate` (repositorio `baseos`) | `logrotate` (repositorio `core`) | [18](../bootcamp/week-18-archivado_compresion_y_registros_del_sistema/) |
| Carpeta de las unidades del paquete | `/lib/systemd/system/` (es un enlace a `/usr/lib/...`) | `/usr/lib/systemd/system/` | `/usr/lib/systemd/system/` | [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |
| Unidad del planificador `cron` | `cron.service` | `crond.service` (paquete `cronie`) | `cronie.service` (paquete `cronie`, repositorio `extra`) | [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |
| Directorio `sshd_config.d/` | existe; `sshd_config` lo incluye con `Include` al principio | existe y trae `50-redhat.conf` del paquete | existe en el paquete `openssh` | [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |

## Por qué esto y no una semana por distro

Enseñar `apt`, `dnf` y `pacman` como tres cursos paralelos triplicaría el
contenido sin triplicar el aprendizaje: el *modelo mental* de "gestor de
paquetes" es el mismo, cambia la sintaxis. Este bootcamp enseña el modelo una
vez y la sintaxis comparada donde diverge, usando los contenedores de
exploración (`debian-lab`, `rhel-lab`, `arch-lab`) para que lo veas correr, no
solo lo leas.

## Cómo practicar la divergencia

```bash
# el mismo objetivo, tres gestores
docker exec -it ubuntu-lab apt search htop
docker exec -it rhel-lab   dnf search htop
docker exec -it arch-lab   pacman -Ss htop
```

---

[← Volver al índice de documentación](README.md)
