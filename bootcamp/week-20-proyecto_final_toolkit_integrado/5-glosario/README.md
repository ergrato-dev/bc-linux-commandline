# Glosario — Semana 20

**`ar`**: formato de archivo antiguo (cabecera `!<arch>`) que usa un `.deb` para
agrupar sus tres miembros. No hace falta la orden `ar` para abrirlo: `dpkg-deb`
lo hace por ti.

**arquitectura `all`** (*Architecture: all*): campo de `control` que indica que el
paquete no depende del procesador. Es el caso de un script.

**atómico** (*atomic*): que ocurre entero o no ocurre. `mv` dentro del mismo sistema
de archivos lo es; por eso `release build` escribe el `.deb` en un temporal y lo
renombra.

**autoprueba** (*selftest*): conjunto pequeño de casos que una herramienta ejecuta
sobre sí misma. `toolkit selftest` lanza cinco.

**caso negativo** (*negative test*): prueba que exige que la herramienta **proteste**
ante una entrada mala. Evita los falsos negativos.

**`control`**: archivo de metadatos de un paquete `.deb` (`Package`, `Version`,
`Depends`, `Description`…). Vive en `DEBIAN/control`.

**`DEBIAN/`**: directorio del árbol de montaje con los metadatos del paquete. No se
instala; debe tener modo `0755`.

**`dpkg`**: gestor de bajo nivel de la familia Debian. Instala (`-i`), consulta
(`-l`, `-s`, `-L`, `-S`), verifica (`--verify`) y quita (`-r`, `-P`).

**`dpkg-deb`**: herramienta que construye (`--build`) e inspecciona (`-I`, `-f`, `-c`,
`-x`) paquetes `.deb`.

**estampar** (*stamp*): escribir un valor, como la versión, en la **copia** que va al
paquete, sin tocar el fuente.

**firma** (*signature*): prueba criptográfica del **origen** de un archivo. Una suma
detecta cambios; solo la firma dice quién lo hizo.

**groff**: procesador del lenguaje `roff`. `groff -man -Tascii` renderiza una página
de manual; `-z -ww` la comprueba.

**idempotente** (*idempotent*): que repetirlo da el mismo resultado. Reconstruir la
misma versión no duplica su línea en `SHA256SUMS`.

**integridad** (*integrity*): garantía de que un archivo no ha cambiado. No equivale
a seguridad ni a origen.

**maqueta** (*fixture*): datos de prueba que se crean para cada ejecución, en un
directorio temporal que se borra al salir.

**`md5sums`**: archivo de control con la suma MD5 de cada archivo instalado. Lo usa
`dpkg --verify`.

**página de manual** (*man page*): documentación de una orden en formato `roff`,
comprimida en `/usr/share/man/man1/`.

**paquete** (*package*): unidad con nombre, versión, dependencias y lista de archivos
que el gestor instala, actualiza, verifica y quita.

**preliminar** (*pre-release*): versión previa a la final. En `dpkg` se marca con `~`:
`1.0.0~rc1` precede a `1.0.0`.

**prueba de humo** (*smoke test*): prueba rápida y superficial que responde «¿arranca y
hace lo básico?».

**purgar** (*purge*): `dpkg -P`. Quita los archivos del paquete y también su
configuración; `-r` conserva esta última.

**reproducible** (*reproducible*): que construir dos veces da bytes idénticos. `gzip -n`
y `LC_ALL=C sort` ayudan.

**`--root-owner-group`**: opción de `dpkg-deb --build` que guarda todos los archivos
como `root:root`.

**`roff`**: lenguaje de marcado de las páginas de manual (líneas que empiezan por un
punto, como `.TH` o `.SH`).

**`SHA256SUMS`**: archivo con una línea `HASH  NOMBRE` por paquete. `sha256sum -c` lo
comprueba.

**`shellcheck`**: analizador estático de scripts de shell. Encuentra errores sin
ejecutar nada.

**temporal** (*temporary file*): archivo creado con `mktemp` y borrado con `trap`. En
`release build` se crea junto al destino.

**`trap`**: orden de bash que ejecuta algo al recibir una señal o al salir (`EXIT`).
`trap - EXIT` lo desactiva.

**versionado semántico** (*semantic versioning*): esquema `MAYOR.MENOR.PARCHE`. MAYOR
rompe compatibilidad, MENOR añade, PARCHE corrige.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Índice del bootcamp →](../../README.md)

[Glosario global](../../../docs/glosario-global.md)
