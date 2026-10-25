# Glosario — Semana 15

**atómico** (*atomic*): operación que se ve completa o no se ve; nadie observa
un estado intermedio. `mv` dentro del mismo sistema de archivos es atómico
(un `rename()`), por eso se escribe en un temporal y se renombra.

**backoff**: esperar más entre cada reintento (1 s, 2 s, 4 s...) para no
martillear un servicio caído.

**bloqueo** (*lock*): marca que impide que dos ejecuciones hagan a la vez algo
que no deben. `flock` lo guarda en el kernel, ligado a un descriptor de archivo.

**código de salida** (*exit status*): número de 0 a 255 con el que termina un
proceso. `0` es éxito; `126` no ejecutable, `127` no encontrado, `128 + N`
muerto por la señal `N`.

**descriptor de archivo** (*file descriptor*): número con el que un proceso
nombra un archivo abierto. `exec {fd}> archivo` pide a bash uno libre.

**errexit**: nombre largo de `set -e`; aborta el script cuando un comando falla,
salvo en contextos donde el fallo se está comprobando.

**flock**: programa de `util-linux` que pide un bloqueo sobre un archivo.
Con `-n` no espera; con `-w` espera un tiempo.

**getopts**: orden interna de bash que procesa opciones cortas (`-v`, `-n 3`)
y deja el valor en `OPTARG` y la posición en `OPTIND`.

**idempotente** (*idempotent*): operación que repetida deja el mismo resultado
que ejecutada una vez. `mkdir -p` lo es; `mkdir` sin `-p` no.

**mktemp**: crea un archivo o directorio temporal con nombre aleatorio y
permisos restrictivos (`600`/`700`) y devuelve su ruta.

**noclobber**: opción (`set -o noclobber`) que impide que `>` pise un archivo
existente; `>|` lo fuerza.

**pipefail**: opción (`set -o pipefail`) que hace que una tubería devuelva el
código del primer comando que falló y no solo el del último.

**PIPESTATUS**: array con el código de cada comando de la última tubería.

**PS4**: prefijo que `set -x` imprime antes de cada comando; puede incluir
`${BASH_SOURCE}`, `${LINENO}` y `${FUNCNAME}`.

**reintento** (*retry*): volver a ejecutar un comando que falló. Debe tener
tope, espera y un comando idempotente.

**señal** (*signal*): aviso asíncrono que el kernel o un proceso envía a otro
(`INT`, `TERM`, `HUP`...). `KILL` y `STOP` no se pueden atrapar.

**SIGPIPE**: señal que recibe un proceso que escribe en una tubería cuyo lector
ya cerró. Termina con `141` (`128 + 13`).

**temporal** (*temporary file*): archivo de vida corta, creado con `mktemp`
y borrado por un `trap` aunque el script falle.

**timeout**: programa de coreutils que ejecuta un comando con límite de tiempo.
Sale con `124` si lo agota y con `137` si hubo que usar `KILL`.

**trap**: orden interna que asocia un comando a una señal o a un evento de la
shell (`EXIT`, `ERR`, `RETURN`). Un segundo `trap` sobre la misma señal reemplaza
al primero.

**unbound variable**: error de `set -u` al expandir una variable sin definir.

**zombi** (*zombie*): proceso terminado cuyo padre aún no ha llamado a `wait`;
`guard_interrupt` lo evita recogiendo al hijo.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 16 →](../../week-16-automatizacion_y_tareas_programadas/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
