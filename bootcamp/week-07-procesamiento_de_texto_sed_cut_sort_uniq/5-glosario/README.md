# Glosario — Semana 07

**Clave de ordenamiento**: la columna o rango de columnas (`sort -k`) que
`sort` usa para decidir el orden, en vez de la línea completa.

**Delimitador**: carácter que separa campos dentro de una línea (`-d` en
`cut`, `-t` en `sort`).

**Dirección** (de `sed`): número de línea, rango, o patrón que acota
dónde se aplica un comando de `sed`.

**Edición in-place**: modificar un archivo directamente (`sed -i`), en
vez de solo imprimir el resultado a stdout.

**Grupo de captura**: porción de un patrón entre paréntesis, reutilizable
en el reemplazo con `\1`, `\2`, etc.

**Orden estable**: un ordenamiento donde los elementos que empatan en la
clave de orden conservan su posición relativa original.

**Pipeline de ranking de frecuencia**: la combinación `cut | tr | sort |
uniq -c | sort -rn`, que convierte una columna de datos en un conteo
ordenado de valores más a menos frecuentes.

**Set** (de `tr`): el conjunto de caracteres a traducir, borrar o
comprimir — `tr` no entiende patrones, solo caracteres individuales.

**Sustitución**: el comando `s///` de `sed`, que reemplaza texto que
coincide con un patrón.

**UUOC**: ver glosario de la Semana 06 — el mismo antipatrón aplica a
`cat archivo | sed` en vez de `sed archivo`.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 08 →](../../week-08-awk_y_pipelines_de_datos/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
