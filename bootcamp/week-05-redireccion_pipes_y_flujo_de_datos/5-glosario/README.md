# Glosario — Semana 05

**Buffering**: estrategia de acumular datos antes de escribirlos, en vez
de escribir línea por línea — cambia cuando la salida va a un pipe en vez
de a una terminal.

**Código de salida** (*exit code*): número entre 0 y 255 que un proceso
devuelve al terminar, con `0` como convención de éxito.

**Cortocircuito** (evaluación): detenerse en cuanto el resultado de una
expresión lógica ya está decidido, sin evaluar el resto.

**Descriptor de archivo**: número que identifica un canal de entrada/salida
abierto por un proceso (`0`, `1`, `2` por convención; pueden abrirse más).

**Here-document**: bloque de texto multilínea redirigido a `stdin` con
`<<`, hasta una marca de cierre.

**Here-string**: una sola línea o variable redirigida a `stdin` con `<<<`,
sin marca de cierre.

**Pipe**: conexión directa, a nivel de kernel, entre el stdout de un
proceso y el stdin de otro.

**pipefail**: opción de bash (`set -o pipefail`) que hace que el código de
salida de un pipeline sea el del primer comando que falló, no el del
último.

**PIPESTATUS**: array de bash con el código de salida de cada comando de
la última pipeline ejecutada.

**stderr**: salida de error estándar, descriptor `2`.

**stdin**: entrada estándar, descriptor `0`.

**stdout**: salida estándar, descriptor `1`.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 06 →](../../week-06-busqueda_de_texto_con_grep_y_regex/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
