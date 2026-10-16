# Glosario — Semana 10

**comm**: campo del kernel con el nombre del ejecutable de un proceso,
truncado a 15 caracteres — lo que `pgrep`/`pkill` comparan por defecto,
sin `-f`.

**disown**: builtin de bash que quita un trabajo de la lista de `jobs`
de la sesión actual, sin enviarle ninguna señal al proceso.

**huérfano** (*orphan*): proceso cuyo padre terminó antes que él — el
kernel le reasigna como padre al proceso `1`.

**job control** (control de trabajos): el conjunto de mecanismos de la
shell (`jobs`, `fg`, `bg`, `Ctrl-Z`) para manejar varios procesos en
una misma sesión interactiva.

**nohup**: comando que protege a un proceso de recibir `SIGHUP` cuando
se cierra la terminal que lo lanzó.

**PGID** (*Process Group ID*): identificador del grupo de procesos al
que pertenece un proceso — una señal enviada al grupo llega a todos
sus miembros.

**PID** (*Process ID*): identificador único de un proceso mientras
existe.

**PPID** (*Parent Process ID*): el PID del proceso que creó a este.

**señal** (*signal*): notificación asíncrona que el kernel envía a un
proceso, interrumpiendo su ejecución normal para que reaccione (o, por
defecto, termine).

**SID** (*Session ID*): identificador de la sesión a la que pertenece
un grupo de procesos, típicamente asociada a una terminal.

**SIGHUP**: señal enviada tradicionalmente al cerrar la terminal; por
convención, muchos daemons la reinterpretan como "recargar
configuración".

**SIGINT**: señal enviada por `Ctrl+C`; puede ignorarse o capturarse
con `trap`.

**SIGKILL**: señal de terminación que ningún proceso puede ignorar,
bloquear ni capturar.

**SIGTERM**: señal de terminación por defecto de `kill`; puede
ignorarse o capturarse, a diferencia de `SIGKILL`.

**SIGUSR1 / SIGUSR2**: señales sin significado fijo por convención —
cada programa decide qué hacer con ellas.

**STAT**: columna de `ps` con el estado actual de un proceso (`R`
ejecutando, `S` durmiendo, `D` espera no interrumpible, `T` detenido,
`Z` zombie), más modificadores opcionales.

**trap**: builtin de bash que ejecuta un comando propio al recibir una
señal, en vez de la acción por defecto.

**zombie**: proceso que ya terminó pero cuya entrada en la tabla de
procesos no se liberó todavía, porque su padre no llamó a `wait()`.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Índice del bootcamp →](../../README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
