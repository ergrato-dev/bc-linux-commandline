# Glosario — Semana 01

**Alias**: nombre corto que el shell sustituye por un comando más largo antes
de ejecutarlo. Solo tiene efecto en modo interactivo.

**Builtin** (comando interno): código que vive dentro del propio binario de
bash, no en un archivo aparte. Ejemplos: `cd`, `echo`, `type`.

**Emulador de terminal**: programa con ventana gráfica que dibuja texto y
captura el teclado (*terminal emulator*). No interpreta comandos — eso lo
hace el shell.

**Hash table** (tabla hash): memoria interna de bash que guarda la última
ruta encontrada para cada comando externo, para no recorrer todo `$PATH` de
nuevo cada vez.

**PATH**: variable de entorno con una lista de carpetas, separadas por `:`,
donde bash busca comandos externos.

**Prompt**: el texto que bash muestra antes de esperar tu próximo comando,
construido a partir de la variable `PS1`.

**PTY** (pseudo-terminal): dispositivo virtual creado por el kernel que
conecta un emulador de terminal con un shell, imitando a un terminal físico.

**Readline**: biblioteca que le da a bash la edición de línea interactiva
(atajos de teclado, historial, búsqueda incremental).

**Shell**: programa intérprete de comandos. El de referencia en este
bootcamp es `bash`.

**Shell de login**: modo de shell que se inicia al iniciar sesión (consola
física, SSH). Carga `/etc/profile` y luego el primero que exista entre
`~/.bash_profile`, `~/.bash_login` o `~/.profile`.

**SHLVL**: variable que cuenta cuántos shells hay anidados en la sesión
actual.

**SIGHUP**: señal que el kernel manda al proceso de control de una sesión
cuando esa sesión se corta (cerrar la terminal, perder la conexión SSH).

**TTY** (teletype): nombre original de los terminales físicos; hoy se usa
también para referirse al dispositivo (`/dev/pts/N`) que conecta emulador y
shell.

---

[← Volver al glosario global](../../../docs/glosario-global.md) · [Volver al README de la semana](../README.md)
