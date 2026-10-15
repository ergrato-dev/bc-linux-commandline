# `stat` y metadatos

> `ls -l` te muestra **una** fecha. Cada archivo en realidad tiene tres, y
> confundirlas lleva a conclusiones equivocadas sobre cuándo pasó algo.

## 🎯 Objetivos

- Leer la salida completa de `stat`, más allá de lo que resume `ls -l`
- Distinguir las tres fechas de un archivo: acceso, modificación, cambio
- Usar metadatos para diagnosticar cuándo y cómo cambió algo

## 1. Qué problema resuelve

"¿Cuándo se modificó este archivo?" parece una pregunta simple, pero Linux
guarda tres fechas distintas para cada archivo, y cada una contesta una
pregunta diferente. Usar la equivocada lleva a diagnósticos incorrectos —
por ejemplo, pensar que un archivo "no cambió" porque su contenido es
idéntico, cuando en realidad sus permisos sí cambiaron hace minutos.

## 2. Cómo funciona

### 2.1 `stat`: todos los metadatos, no solo una línea

```bash
stat /etc/hostname
#   File: /etc/hostname
#   Size: 12          Blocks: 8          IO Block: 4096   regular file
# Device: ...    Inode: 123456      Links: 1
# Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
# Access: 2026-01-01 10:00:00.000000000 +0000
# Modify: 2026-01-01 10:00:00.000000000 +0000
# Change: 2026-01-01 10:00:00.000000000 +0000
```

`stat` da en una sola llamada lo que `ls -l` reparte en columnas, más el
inodo completo, el tamaño en bloques, y las tres fechas — todo lo que
necesitas para entender el historial reciente de un archivo sin adivinar.

### 2.2 Las tres fechas: atime, mtime, ctime

| Fecha | Nombre | Cambia cuando... |
|---|---|---|
| **Access** (`atime`) | Último acceso | Alguien **leyó** el archivo (no necesariamente lo modificó) |
| **Modify** (`mtime`) | Última modificación | **Cambió el contenido** del archivo |
| **Change** (`ctime`) | Último cambio | Cambió el **contenido o los metadatos** (permisos, dueño, nombre) |

`ls -l` muestra `mtime` por defecto — la fecha que la mayoría de la gente
asocia con "cuándo se tocó esto". Pero `mtime` no se actualiza si solo
cambiaste permisos con `chmod`: para eso está `ctime`.

```bash
touch archivo.txt
stat -c '%X %Y %Z' archivo.txt    # atime mtime ctime, como timestamps unix

chmod 600 archivo.txt
stat -c '%X %Y %Z' archivo.txt    # ctime cambio, mtime NO
```

### 2.3 Por qué `ctime` no es "fecha de creación"

Una confusión común: pensar que `ctime` significa "creation time". No es
así — significa "change time", y se actualiza con *cualquier* cambio de
metadatos, no solo al crear el archivo. Linux (a diferencia de algunos
sistemas de archivos de otros sistemas operativos) **no guarda** una fecha
de creación real en la mayoría de los filesystems tradicionales — `ext4`
técnicamente sí tiene un campo `crtime`, pero las herramientas estándar
(`stat`, `ls`) no lo exponen por defecto.

```bash
# en sistemas con soporte, statx expone el tiempo de creacion real
stat --format='%w' archivo.txt    # "-" si el filesystem no lo soporta
```

### 2.4 `atime` y por qué muchos sistemas lo desactivan

Actualizar `atime` significa escribir al disco **cada vez que alguien lee**
un archivo — incluso una simple lectura sin modificar nada genera una
escritura. En sistemas con mucha lectura (servidores web, bases de datos),
este costo es real, y por eso muchas instalaciones montan sus sistemas de
archivos con `noatime` (desactivar esa actualización) o `relatime` (una
versión más relajada, el valor por defecto en Ubuntu).

```bash
mount | grep " / "
# muestra las opciones de montaje de la raiz, incluido relatime si esta activo
```

### 2.5 El tamaño de un directorio, según `stat`

```bash
mkdir /tmp/vacio
stat /tmp/vacio
# Size: 4096        Blocks: 8          IO Block: 4096   directory
```

Un directorio recién creado y vacío ya "pesa" 4096 bytes. Esto no es un
error ni un desperdicio: ese tamaño es el espacio reservado para la lista
de entradas del directorio mismo (los nombres que contiene), no el
contenido de los archivos que viven adentro. Por eso `du -sh` sobre una
carpeta (que suma tamaños reales de contenido) y el campo `Size` de `stat`
sobre esa misma carpeta (que refleja la tabla de entradas) casi nunca
coinciden — miden cosas distintas, y ninguno de los dos está "mal".

### 2.6 Links: el campo que ya viste en la Semana 02

```bash
stat archivo.txt | grep Links
# Links: 1
```

El campo `Links` de `stat` es el mismo contador de enlaces duros que viste
con `ls -li` en la Semana 02 — `stat` simplemente lo muestra con nombre
explícito en vez de como una columna numérica sin etiqueta.

### 2.7 `stat` sobre un enlace simbólico: dos respuestas posibles

Recordando los enlaces simbólicos de la Semana 02, `stat` puede responder
sobre el **enlace mismo** o sobre el **destino** al que apunta, según el
flag:

```bash
ln -s /etc/hostname /tmp/enlace

stat /tmp/enlace
# Size: 13 ... symbolic link    <- datos DEL ENLACE: tamaño de la ruta que contiene

stat -L /tmp/enlace
# Size: 12 ... regular file     <- datos del DESTINO, siguiendo el enlace
```

Sin `-L`, `stat` describe el enlace como objeto propio (su tamaño es la
longitud de la ruta de texto que contiene, no el tamaño del destino). Con
`-L` ("dereference"), sigue el enlace y describe lo que hay del otro lado —
el mismo comportamiento por defecto que tiene `cp` sin `-d`, visto en el
archivo anterior.

## 3. Cómo se usa

```bash
# Formato personalizado: solo lo que te interesa, sin el resto
stat -c 'Tamaño: %s bytes, Modificado: %y' archivo.txt

# Comparar mtime de dos archivos para saber cual es mas reciente
stat -c '%Y %n' archivo1.txt archivo2.txt | sort -rn
```

```bash
# Encontrar que cambio mas recientemente en un directorio, usando ctime
# (util cuando sospechas que algo mas que el contenido cambio, ej. permisos)
ls -lc /etc | head -5
```

```bash
# Formato "touch" exacto: copiar las tres fechas de un archivo a otro
touch -r original.txt copia.txt
stat -c '%y' original.txt copia.txt
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Asumir que `ctime` es la fecha de creación | `ctime` cambia con cualquier modificación de metadatos, no solo al crear | Para fecha de creación real, buscar soporte de `crtime`/`statx` si el filesystem lo expone; de lo contrario, asumir que Linux tradicional no la guarda |
| Pensar que un archivo "no cambió" porque `ls -l` (que muestra `mtime`) no cambió | Los permisos o el dueño pudieron cambiar sin tocar el contenido — eso se refleja en `ctime`, no en `mtime` | Revisar `ctime` con `stat` cuando sospeches un cambio de metadatos, no solo de contenido |
| Depender de `atime` para auditoría de "quién leyó qué" en un sistema con `relatime`/`noatime` | La actualización de `atime` puede estar relajada o desactivada, dando falsos negativos | Confirmar las opciones de montaje antes de confiar en `atime` para ese propósito |
| Comparar `du -sh` de una carpeta contra el `Size` de `stat` esperando que coincidan | Miden cosas distintas: contenido real versus tabla de entradas del directorio | Usar `du` para tamaño de contenido, `stat` para metadatos del directorio mismo |

## 5. Trucos

- `stat -c '%Y %n'` combinado con `sort -rn` ordena archivos por fecha de
  modificación real (timestamp numérico), más preciso que fiarse del orden
  visual de `ls -lt` cuando hay muchos archivos con fechas cercanas.
- `touch -r archivo-modelo archivo-destino` copia la fecha de un archivo a
  otro, sin tener que calcular ni escribir ninguna fecha a mano.
- `find . -newer archivo-de-referencia` (adelanto de la Semana 09) encuentra
  todo lo modificado después de cierto archivo — útil para "¿qué cambió
  desde el último backup?".

## Resumen

`stat` da acceso a todo lo que `ls -l` resume y recorta: tres fechas
distintas (acceso, modificación, cambio de metadatos), no solo una, más el
inodo y el tamaño real de bloques. Confundir `mtime` con `ctime`, o pensar
que `ctime` es "fecha de creación", lleva a diagnósticos equivocados sobre
cuándo y qué cambió realmente en un archivo.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — stat invocation](https://www.gnu.org/software/coreutils/manual/html_node/stat-invocation.html) — todos los especificadores de formato (`%s`, `%y`, `%n`, etc.).
- `man stat`, `man 2 statx` — la referencia de comando y la syscall moderna detrás, respectivamente.

## ✅ Checklist de Verificación

- [ ] Leíste la salida completa de `stat` sobre un archivo propio
- [ ] Reprodujiste que `chmod` cambia `ctime` pero no `mtime`
- [ ] Explicaste por qué `ctime` no es "fecha de creación", con tus propias palabras
- [ ] Confirmaste si tu sistema usa `relatime`/`noatime` con `mount`

---

[← 04 — Eliminar con criterio](04-eliminar-con-criterio.md) · [06 — Patrones seguros para operaciones destructivas →](06-patrones-seguros-para-operaciones-destructivas.md)
