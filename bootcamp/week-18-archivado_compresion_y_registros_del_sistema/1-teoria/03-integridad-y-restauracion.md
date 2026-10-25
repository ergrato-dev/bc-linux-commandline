# Integridad y restauración

> Una copia de seguridad no está **hecha** hasta que sabes que se puede leer y has visto cómo se restaura.
> `sha256sum` te dice si el archivo cambió; solo una restauración de prueba te dice si sirve.

## 🎯 Objetivos

- Crear y comprobar huellas con `sha256sum` y `sha256sum -c`, y leer sus tres tipos de fallo
- Distinguir qué detecta una suma, qué detecta `tar -t` y qué solo detecta restaurar
- Restaurar en un directorio vacío y comparar con el original
- Reconocer un archivo con rutas peligrosas y saber qué hace `tar` ante ellas
- Aplicar la regla 3-2-1 y una política de retención sin perder lo que importa

## 1. Qué problema resuelve

Una copia puede estar mal sin que nadie se entere: un disco que falla al escribir,
una transferencia cortada, un `.tar.gz` truncado porque se llenó el disco, o un
bit cambiado en el almacenamiento. El error aparece **el día que la necesitas**.
Tres defensas, de menos a más completa:

| Defensa | Detecta | No detecta |
|---|---|---|
| `gzip -t` / `tar -tf` | Un archivo truncado o con la estructura rota | Un cambio que deja el formato válido |
| `sha256sum -c` | **Cualquier** cambio posterior a la huella | Que la copia ya naciera mal (faltan archivos) |
| **Restaurar y comparar** | Que falte algo, que no se pueda leer, que las rutas sean otras | Nada que quepa en la prueba |

## 2. Cómo funciona

### 2.1 Una huella: `sha256sum`

`sha256sum` calcula una huella de 256 bits (64 caracteres hexadecimales) del
contenido. Dos archivos con la misma huella son iguales; cambiar **un bit** da
otra huella completamente distinta:

```bash
cd /tmp/t18 && rm -rf rs && mkdir -p rs/datos/docs && cd rs
echo hola > datos/docs/a.txt; echo mundo > datos/docs/b.txt
tar -czf d.tar.gz datos
sha256sum d.tar.gz | tee d.tar.gz.sha256
# 33de7cc48c8baad80da0...  d.tar.gz
sha256sum -c d.tar.gz.sha256
# d.tar.gz: OK
```

El archivo `.sha256` es texto: la huella, **dos espacios** y el nombre. `-c` lo
lee y recalcula. El nombre va **relativo** (`d.tar.gz`, sin ruta), y `-c` lo
busca desde donde lo ejecutes: si guardas la suma con ruta absoluta, solo
funciona en esa máquina:

```bash
sha256sum /tmp/t18/rs/d.tar.gz > abs.sha && cut -c65- abs.sha
#   /tmp/t18/rs/d.tar.gz
```

Por eso `toolkit backup` hace `cd` al directorio de las copias antes de llamar a
`sha256sum`: así la suma funciona allí donde muevas el par de archivos.

### 2.2 Los tres modos de fallar

Con varias sumas en un archivo, `sha256sum -c` informa de **cada archivo**:

```bash
sha256sum datos/docs/*.txt > sumas.txt
echo hack >> datos/docs/b.txt
sha256sum -c sumas.txt; echo "rc=$?"
# datos/docs/a.txt: OK
# datos/docs/b.txt: FAILED
# sha256sum: WARNING: 1 computed checksum did NOT match
# rc=1
```

Y los otros dos fallos, con **otro mensaje**:

```bash
rm datos/docs/a.txt
sha256sum -c sumas.txt 2>&1
# sha256sum: datos/docs/a.txt: No such file or directory
# datos/docs/a.txt: FAILED open or read
# datos/docs/b.txt: FAILED
# sha256sum: WARNING: 1 listed file could not be read
# sha256sum: WARNING: 1 computed checksum did NOT match
echo "basura" > mal.sha256; sha256sum -c mal.sha256 2>&1
# sha256sum: mal.sha256: no properly formatted checksum lines found
```

`FAILED` es un archivo que cambió; `FAILED open or read`, uno que falta; y un
archivo de sumas mal formado no verifica **nada** (y sale con 1: la comprobación
vacía no es un éxito). Para un script:

| Opción | Hace |
|---|---|
| `--status` | no imprime nada: solo el código de salida (`0` todo bien, `1` algo falla) |
| `--quiet` | imprime solo los `FAILED`, no los `OK` |
| `--ignore-missing` | no cuenta como fallo un archivo ausente de la lista |

Úsalas sabiendo qué cambian: `--status` es lo que usa `backup verify`, porque
el mensaje lo escribe el propio subcomando.

### 2.3 Lo que una suma **no** dice

- **No protege contra quien la cambia**. Si la suma está junto al archivo, quien
  edita el archivo puede editar también la suma. Detecta **accidentes**, no
  ataques; para eso hace falta firmar (`gpg`), fuera de este bootcamp.
- **No dice que la copia esté completa**. Una copia de una carpeta vacía tiene
  una suma perfecta.
- **MD5 y SHA-1** (`md5sum`, `sha1sum`) siguen existiendo, y valen para detectar
  accidentes, pero se pueden **falsificar a propósito**. Para huellas nuevas,
  `sha256sum` (o `b2sum`, que también viene en `coreutils`).

### 2.4 `tar -t` y `gzip -t`: lo estructural

Cortar un archivo da un error claro con `gzip`, y `tar` se queja pero **antes
listó lo que pudo**:

```bash
head -c 100 d.tar.gz > t.tar.gz
gzip -t t.tar.gz; echo "rc=$?"
# gzip: t.tar.gz: unexpected end of file
# rc=1
tar -tzf t.tar.gz
# datos/
# tar: Child returned status 1
# tar: Error is not recoverable: exiting now
```

Es la segunda defensa y la más barata: **leer el archivo entero sin extraer**
(`tar -tzf archivo > /dev/null`). Un bit cambiado en medio suele romper la
descompresión (`tar -t` termina con código 2), pero **no siempre** lo detecta
un `tar` sin comprimir: ahí solo la suma lo asegura.

## 3. Cómo se usa

### 3.1 Restaurar de prueba

La única prueba definitiva: extraer en un directorio **vacío** y comparar con el
original. Si ya no tienes el original, compara contra las sumas guardadas:

```bash
rm -rf datos && mkdir r1 && tar -xzf d.tar.gz -C r1
(cd r1 && find datos -type f -exec sha256sum {} + | sort -k2) | cut -c1-12,65-
# 133ee989293f  datos/docs/a.txt
# 1c376ef87b87  datos/docs/b.txt
```

Con el original aún a mano, `diff -r original restaurado` (o `diff -r -x cache`
si excluiste algo) es más simple: sin salida es que son iguales. Hazlo con una
periodicidad, no solo el día del desastre.

### 3.2 Un archivo con rutas peligrosas

Un archivo puede llevar miembros con `..` o con rutas absolutas. Qué hace GNU
`tar` ante ellos, comprobado:

```bash
mkdir ev && echo e > ev/e
tar -czf evil.tar.gz -C ev --transform 's,^,../fuera/,' e
# tar: Removing leading `../' from member names
tar -tzf evil.tar.gz
# ../fuera/e
mkdir salida && tar -xzf evil.tar.gz -C salida; echo "rc=$?"
# tar: ../fuera/e: Member name contains '..'
# tar: Exiting with failure status due to previous errors
# rc=2
```

GNU `tar` **se niega** a extraer un miembro con `..` y quita la `/` inicial de
uno absoluto. Pero esa defensa depende de la implementación y de las
opciones (`-P`, otras versiones, `bsdtar`, `unzip`, un script casero). Un
programa que restaure copias ajenas debe **mirar el listado él mismo** y
rechazarlo con un mensaje claro: es lo que hace `backup restore`.

```bash
tar -tzf archivo.tar.gz | grep -E '(^/|(^|/)\.\.(/|$))' && echo PELIGROSO
```

### 3.3 La regla 3-2-1

| Número | Significa | Ejemplo |
|---|---|---|
| **3** copias | El original y dos copias | Disco + disco externo + remoto |
| **2** soportes | Dos tipos de almacenamiento distintos | Local y en la nube |
| **1** fuera de casa | Al menos una copia en otro lugar | Otro edificio, otro proveedor |

Y la política de **retención**: no guardar todas para siempre. `toolkit backup
prune --keep N` conserva las N más recientes de una serie. La regla práctica:
cuenta con **cuánto tiempo tardarías en descubrir un error** (un archivo que
borraste hace tres semanas), y conserva más que eso.

### 3.4 Permisos de la copia

Una copia contiene lo mismo que el original, y a veces claves y credenciales.
Se escribe con permisos **restringidos**: `mktemp` crea el archivo con `600`, y
`toolkit backup` lo renombra sin cambiarlos. Un `chmod 644` «para que lo lea
otro usuario» publica tu `~/.ssh`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Crear la copia y no comprobarla | Descubres el fallo al restaurar | `sha256sum` + `tar -tf` al crearla |
| Guardar la suma con ruta absoluta | Solo se puede comprobar en esa máquina | Suma con nombre relativo, desde su directorio |
| Fiarse de `ls -l` para ver que «pesa» | Un archivo truncado también pesa | `sha256sum -c` |
| Poner la suma como única defensa | No detecta que la copia ya naciera incompleta | Restaurar de prueba |
| Restaurar sobre el directorio real «para probar» | Sobrescribes lo que querías proteger | Un directorio vacío y un `diff -r` |
| Extraer un archivo de otro sin mirar sus rutas | Escribe fuera del destino (según el `tar`) | `tar -tf archivo` y filtrar `..` y `/` |
| Todas las copias en el mismo disco | El disco falla y se llevan original y copias | 3-2-1: otro soporte y otro lugar |
| Copias legibles por todos | Exponen claves y datos personales | `600` y un directorio `700` |

## 5. Trucos

- **`sha256sum -c --status archivo.sha256 && echo OK`** es la comprobación en una
  línea para un script: sin ruido, solo el código.
- **`tar -tzf archivo > /dev/null && echo legible`**: leer todo el archivo, sin
  guardar nada. Equivale a un `fsck` barato.
- **`find carpeta -type f -exec sha256sum {} + | sort -k2`** da una huella por
  archivo, con orden estable: comparable con otra con `diff`.

## 📚 Recursos Adicionales

- `man sha256sum` (en `coreutils`)
- [GNU Coreutils: sha2 utilities](https://www.gnu.org/software/coreutils/manual/html_node/sha2-utilities.html)

## ✅ Checklist de Verificación

- [ ] Creas una suma con `sha256sum` y la compruebas con `-c` desde otro directorio
- [ ] Provocas los tres fallos (`FAILED`, `FAILED open or read`, sin formato) y los reconoces
- [ ] Truncas un `.tar.gz` y ves lo que dicen `gzip -t` y `tar -tzf`
- [ ] Restauras en un directorio vacío y comparas con `diff -r`
- [ ] Ves cómo GNU `tar` se niega a extraer un miembro con `..`
- [ ] Explicas la regla 3-2-1 y qué retención tiene sentido para ti
- [ ] Sabes por qué una copia no se deja legible por todos

---

[← Compresión: `gzip`, `bzip2`, `xz` y `zstd`](02-compresion-gzip-bzip2-xz-zstd.md) · [`/var/log` y los registros clásicos →](04-var-log-y-registros-clasicos.md)
