# Glosario — Semana 17

**alias** (*alias*): nombre corto que la shell interactiva sustituye por un
texto antes de ejecutar. No se expande en scripts ni en la misma línea donde se
define; no admite argumentos en medio (para eso, una función).

**`bash-completion`**: paquete que trae los autocompletados de `git`, `ssh`,
`apt`… y el cargador perezoso. Se llama igual en `apt`, `dnf` y `pacman`.

**carga perezosa** (*lazy loading*): cargar el autocompletado de una orden solo
la primera vez que se pulsa `Tab` en ella, desde un archivo con su nombre.

**`compgen`**: genera candidatos (palabras, directorios, órdenes) filtrados por
un prefijo; es la pieza con que se rellena `COMPREPLY`.

**`complete`**: registra, consulta (`-p`) o borra (`-r`) cómo se autocompleta una
orden. `-W` da una lista fija y `-F` una función.

**`COMP_CWORD` / `COMP_WORDS` / `COMPREPLY`**: las variables de una función de
autocompletado: índice de la palabra actual, todas las palabras, y la salida.

**dotfile**: archivo de configuración cuyo nombre empieza por punto
(`.bashrc`, `.tmux.conf`), por lo que `ls` no lo enseña.

**enlace simbólico** (*symbolic link*): archivo que contiene la ruta de otro. Se
crea con `ln -s DESTINO ENLACE`; si es relativo, se resuelve desde el directorio
del enlace.

**entorno** (*environment*): conjunto de variables que un proceso hereda de su
padre. Solo viajan las exportadas, y siempre como copia.

**`export`**: marca una variable para que la hereden los procesos hijos.

**`hash`**: caché de rutas de órdenes ya encontradas. `hash -r` la borra.

**`HISTCONTROL`**: opciones del historial; `ignorespace` no guarda las órdenes
que empiezan por espacio y `ignoredups` descarta las repetidas seguidas.

**historial** (*history*): lista de órdenes escritas. Se guarda en
`~/.bash_history` al salir de la shell, con permisos `600`.

**`~/.inputrc`**: configuración de `readline` (ignorar mayúsculas al completar,
mostrar candidatos a la primera, asignar teclas).

**login** (*login shell*): shell que lee `~/.profile` (o `.bash_profile`,
`.bash_login`; el primero que exista) y `.bash_logout` al salir. SSH y cada panel
de `tmux` abren una.

**panel / ventana / sesión** (*pane / window / session*): los tres niveles de
`tmux` bajo el servidor: un trozo de pantalla, una pantalla, un conjunto de ellas.

**`PATH`**: lista de directorios, separados por `:`, donde la shell busca las
órdenes. Gana el primero; una entrada vacía equivale al directorio actual.

**prefijo** (*prefix*): combinación (`Ctrl-b` por defecto en `tmux`) que se pulsa
antes de cada atajo.

**`PROMPT_COMMAND`**: orden (o array de órdenes) que bash ejecuta antes de pintar
cada prompt.

**`PS1`**: texto del prompt. Con comillas simples se evalúa cada vez; los
códigos invisibles se rodean de `\[` y `\]`.

**`readline`**: biblioteca que gestiona la edición de la línea (flechas,
`Ctrl-R`, `Tab`). Se configura con `~/.inputrc`.

**`screen`**: multiplexor de terminal anterior a `tmux`, aún presente en
servidores antiguos.

**`stow`** (*GNU Stow*): programa que crea enlaces simbólicos relativos desde
carpetas de «paquetes».

**`tmux`**: multiplexor que mantiene programas vivos en un servidor aunque se
cierre tu conexión, y permite volver a ellos.

**`.toolkit-bak`**: sufijo del respaldo que `toolkit dotfiles link --force` hace
de un archivo existente, y que `unlink` restaura.

**`~/.local/bin`** / **`~/bin`**: directorios de usuario añadidos al `PATH` en el
login **solo si existen**. Cuál lo hace depende de la distribución.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 18: Archivado, compresión y registros →](../../week-18-archivado_compresion_y_registros_del_sistema/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
