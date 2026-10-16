# Glosario — Semana 06

**Agrupación**: usar `(...)` (o `\(...\)` en BRE) para que un cuantificador
o la alternancia apliquen a varios caracteres como una sola unidad.

**Ancla**: metacarácter que fija una posición en la línea (`^` inicio,
`$` final) en vez de coincidir con un carácter.

**Alternancia**: `|` (o `\|` en BRE), coincide si cualquiera de varias
opciones aparece.

**BRE** (*Basic Regular Expressions*): el dialecto de regex por defecto
de `grep`, donde `+`, `?`, `{n,m}` y `(...)` necesitan escape para actuar
como especiales.

**Clase de caracteres**: `[...]`, coincide con uno de los caracteres
listados en esa posición; `[^...]` la invierte.

**Clase POSIX**: categoría de caracteres independiente de un rango ASCII
(`[[:alpha:]]`, `[[:digit:]]`, etc.), sensible al `locale` del sistema.

**Cuantificador**: metacarácter que indica cuántas veces se repite lo
anterior (`*`, `+`, `?`, `{n,m}`).

**Cuantificador perezoso** (*lazy*): en PCRE, se detiene en la primera
coincidencia posible (`.+?`) en vez de extenderse lo más posible.

**Cuantificador voraz** (*greedy*): el comportamiento por defecto de un
cuantificador — se extiende tanto como sea posible antes de retroceder.

**ERE** (*Extended Regular Expressions*): el dialecto activado con
`grep -E`, donde esos mismos metacaracteres son especiales sin escape.

**Lookahead**: en PCRE, `(?=...)`, exige que algo aparezca después de la
coincidencia sin incluirlo en el resultado extraído.

**Patrón literal**: un patrón sin metacaracteres, interpretado como texto
exacto.

**PCRE** (*Perl Compatible Regular Expressions*): el dialecto activado
con `grep -P`, con clases abreviadas (`\d`, `\w`, `\s`) y funciones que
ERE no tiene, como lookahead y cuantificadores perezosos.

**Referencia hacia atrás** (*backreference*): `\1`, `\2`, etc., se
refieren al texto que efectivamente coincidió con un grupo anterior del
mismo patrón.

**UUOC** (*Useless Use of Cat*): antipatrón de usar `cat archivo | comando`
cuando `comando` ya puede leer el archivo directamente.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 07 →](../../week-07-procesamiento_de_texto_sed_cut_sort_uniq/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
