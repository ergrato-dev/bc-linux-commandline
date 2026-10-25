# Glosario — Semana 18

**archivado** (*archiving*): empaquetar muchos archivos y su metadato (permisos,
propietario, enlaces, fechas) en uno solo. No comprime: de eso se encarga otro
programa. `tar` archiva.

**`auth.log`**: registro de texto de autenticación (SSH, `sudo`, `su`) en
Debian/Ubuntu. En RHEL se llama `secure`.

**`btmp`**: registro **binario** de intentos de login fallidos; se lee con `lastb`.
Va con permisos `660`.

**compresión** (*compression*): reducir el tamaño de unos datos aprovechando su
redundancia. Los datos aleatorios o ya comprimidos no se reducen.

**`copytruncate`**: directiva de `logrotate` que copia el registro y vacía el
original sin cambiar su inodo, para programas que no saben reabrirlo. Puede
perder líneas.

**`create`**: directiva de `logrotate` que renombra el registro y crea uno nuevo
vacío. Un programa que mantiene el archivo abierto sigue escribiendo en el viejo.

**diario** (*journal*): almacén binario e indexado de `systemd-journald`. Se lee
con `journalctl`.

**`facility`**: la «categoría» de un mensaje de syslog (`auth`, `user`, `local0`…).
Junto a la severidad forma la prioridad de `logger -p facility.nivel`.

**huella** / suma de comprobación (*checksum*, *hash*): valor de longitud fija
calculado a partir de un archivo; si el archivo cambia un bit, la huella cambia.

**`journalctl`**: orden que lee el diario con filtros por unidad (`-u`), etiqueta
(`-t`), prioridad (`-p`), texto (`-g`) y tiempo (`--since`, `--until`).

**`last`** / **`lastb`** / **`lastlog`**: comandos que leen los registros binarios
`wtmp`, `btmp` y `lastlog`. No se leen con `cat` ni `grep`.

**`logger`**: orden que envía un mensaje al registro del sistema. Si nadie escucha
`/dev/log`, el mensaje se pierde con código `0`.

**`logrotate`**: programa que rota, comprime y borra registros según unas reglas.
La primera vez que ve un archivo solo lo anota en su estado.

**miembro** (*member*): cada archivo, directorio o enlace guardado dentro de un
archivo `tar`. Su nombre puede ser peligroso (`/…` o `..`).

**prioridad** / severidad (*priority*, *severity*): nivel de un mensaje, de `0`
(`emerg`) a `7` (`debug`). `journalctl -p err` incluye también los más graves.

**`rsyslog`**: demonio de syslog que escribe los registros de texto en
`/var/log`. No viene en las imágenes mínimas ni en Arch.

**rotación** (*rotation*): renombrar el registro actual, empezar uno nuevo y
borrar los más antiguos para que no llene el disco.

**serie** (*series*): conjunto de copias con el mismo nombre
(`proy-AAAAMMDD-HHMMSS.tar.gz`). `prune` actúa sobre una serie, no sobre toda la carpeta.

**`sha256sum`**: calcula y comprueba huellas SHA-256. `-c` comprueba; `--status`
solo devuelve el código.

**`syslog`**: protocolo y registro clásico de mensajes del sistema; en Ubuntu,
`/var/log/syslog`.

**`systemd-cat`**: envuelve una orden y manda su `stdout` y `stderr` al diario.

**`tar`** (*tape archive*): programa de archivado. `-c` crea, `-t` lista, `-x`
extrae, `-f` nombra el archivo y `-C` cambia de directorio.

**`wtmp`**: registro **binario** de sesiones iniciadas y cerradas; se lee con
`last`.

**`xz`** / **`zstd`** / **`bzip2`** / **`gzip`**: los cuatro compresores de la
semana. `gzip` está en todas partes; `xz` y `zstd` comprimen más; `bzip2` queda
en medio y se usa poco.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 19: Systemd, seguridad y contenedores →](../../week-19-systemd_seguridad_y_contenedores_desde_cli/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
