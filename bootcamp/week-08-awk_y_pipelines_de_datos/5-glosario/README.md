# Glosario — Semana 08

**Acción** (awk): el bloque `{ }` que se ejecuta cuando el patrón de una
regla coincide (o siempre, si no hay patrón).

**Array asociativo**: estructura de `awk` indexada por texto en vez de
número, usada para contar o acumular por clave.

**Coerción**: conversión automática de un valor entre texto y número en
`awk`; un texto no numérico se convierte en `0` en contexto numérico,
sin error.

**FNR**: número de línea dentro del archivo **actual**, se reinicia en
cada archivo nuevo cuando `awk` procesa varios.

**FS** (*Field Separator*): variable de `awk` que define el separador de
campos; por defecto, espacios/tabs, colapsando repeticiones.

**gawk**: implementación de `awk` de GNU, con extensiones propias
(`gensub`, `asort`) más allá del estándar POSIX.

**mawk**: implementación liviana de `awk`, por defecto en Ubuntu y
Debian; cubre POSIX pero no las extensiones de `gawk`.

**NF** (*Number of Fields*): cantidad de campos de la línea actual.

**NR** (*Number of Records*): número de línea procesada, acumulado entre
todos los archivos de entrada.

**OFS** (*Output Field Separator*): separador usado al reconstruir `$0`
con `print`, solo si algún campo se reasignó.

**Patrón** (awk): la condición (regex, comparación, rango) que decide si
una acción se ejecuta para una línea dada.

**printf**: función de formato con el mismo especificador que `printf`
de C (`%s`, `%d`, `%f`), con control de ancho y decimales que `print` no
tiene.

**Registro**: una unidad de entrada para `awk` — por defecto, una línea.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 09 →](../../week-09-busqueda_de_archivos_find_y_xargs/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
