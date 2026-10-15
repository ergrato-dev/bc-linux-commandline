# Glosario — Semana 03

**atime** (*access time*): fecha del último acceso de lectura a un archivo.

**ctime** (*change time*): fecha del último cambio de contenido o
metadatos (permisos, dueño, nombre) de un archivo. No es "fecha de
creación".

**Dry-run**: ejecución que muestra qué haría un comando, sin aplicar
ningún cambio real.

**Escritura atómica**: patrón de escribir a un archivo temporal y mover al
destino final, para que otro proceso nunca vea un archivo a medio escribir.

**Idempotente**: dicho de una operación que produce el mismo resultado sin
importar cuántas veces se repita.

**mtime** (*modification time*): fecha de la última modificación del
contenido de un archivo — la que muestra `ls -l` por defecto.

**Papelera de reciclaje**: mecanismo que mueve archivos "borrados" a un
lugar intermedio recuperable. No existe por defecto en la terminal de
Linux.

**Reflink**: copia que, en sistemas de archivos con *copy-on-write*, no
duplica datos hasta que uno de los dos lados se modifica.

**Sparse file** (archivo disperso): archivo con rangos marcados como ceros
que no ocupan espacio real en disco.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 04 →](../../week-04-permisos_y_propiedad/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
