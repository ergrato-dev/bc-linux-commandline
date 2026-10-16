# Glosario — Semana 09

**Byte nulo** (`\0`): el único byte garantizado de no aparecer dentro de
un nombre de archivo válido en Linux; usado como separador seguro por
`find -print0` y `xargs -0`.

**Hash**: huella digital corta y (para fines prácticos) única, calculada
a partir del contenido completo de un archivo.

**maxdepth / mindepth**: banderas de `find` que limitan cuántos niveles
de subdirectorios recorre una búsqueda.

**-exec {} \;**: acción de `find` que ejecuta un comando una vez por
cada resultado encontrado.

**-exec {} +**: acción de `find` que agrupa resultados en lotes,
ejecutando el comando la menor cantidad de veces posible.

**-print0**: acción de `find` que separa cada resultado con un byte
nulo en vez de un salto de línea.

**xargs**: herramienta que convierte líneas de su entrada en argumentos
de otro comando, dividiendo en varias invocaciones si hace falta.

**--no-run-if-empty** (`-r`): bandera de `xargs` que evita ejecutar el
comando cuando no hay ningún argumento que pasar.

**-P** (*max-procs*): bandera de `xargs` que ejecuta varias invocaciones
en paralelo.

**-L**: bandera de `xargs` que agrupa por líneas de entrada originales,
a diferencia de `-n`, que agrupa por cantidad de argumentos.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 10 →](../../week-10-gestion_de_procesos_y_senales/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
