# Glosario — Semana 02

**Brace expansion** (expansión de llaves): generación de texto a partir de
`{a,b,c}`, sin consultar el sistema de archivos.

**CDPATH**: variable que extiende dónde busca `cd` cuando le das un nombre
sin ruta completa.

**Enlace duro** (*hard link*): otro nombre que apunta al mismo inodo que un
archivo existente — no es una copia.

**Enlace simbólico** (*symlink*): archivo que contiene una ruta de texto
hacia otro archivo o carpeta.

**FHS** (*Filesystem Hierarchy Standard*): estándar que define qué tipo de
contenido va en cada directorio de primer nivel de Linux.

**Glob / globbing**: expansión de patrones de nombre de archivo (`*`, `?`,
`[...]`) que hace bash antes de ejecutar un comando.

**Inodo**: estructura que guarda los metadatos y la ubicación real del
contenido de un archivo en disco.

**Nullglob**: opción de bash (`shopt -s nullglob`) que hace que un glob sin
coincidencias se convierta en nada, en vez de quedar como texto literal.

**Pila de directorios**: lista de rutas que manejan `pushd`/`popd`/`dirs`
para navegar entre varios lugares.

**Ruta absoluta**: ruta que empieza con `/` y describe una ubicación exacta
sin depender del directorio actual.

**Ruta relativa**: ruta que no empieza con `/` y se interpreta siempre
contra el directorio actual (`$PWD`).

**usr-merge**: fusión de `/bin`, `/sbin`, `/lib` como enlaces simbólicos a
sus equivalentes dentro de `/usr`.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 03 →](../../week-03-manipulacion_de_archivos_y_directorios/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
