# Práctica 01 — `tar` y compresión

> Duración estimada: 60 min · Teoría de apoyo: archivos [01](../1-teoria/01-tar-archivar-sin-comprimir.md) y [02](../1-teoria/02-compresion-gzip-bzip2-xz-zstd.md)

Trabajas **dentro de `ubuntu-lab`**, en un directorio de juguete en `/tmp/p18`.
No tocas nada fuera de él.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Instalar los compresores y preparar los datos

**Por qué**: la imagen mínima trae `tar` y `gzip`, pero **no** `bzip2`, `xz` ni
`zstd` (teoría 02, apartado 3.4). Y necesitas un directorio con un poco de todo:
archivos de texto, uno con permisos restringidos, uno grande y compresible, y un
enlace simbólico.

**Comando**:

```bash
# -qq: casi sin salida. xz se llama xz-utils en Debian/Ubuntu y xz en RHEL/Arch.
apt-get update -qq
apt-get install -y -qq xz-utils bzip2 zstd
rm -rf /tmp/p18 && mkdir -p /tmp/p18/datos/docs /tmp/p18/datos/img && cd /tmp/p18
echo hola > datos/docs/a.txt; echo mundo > datos/docs/b.txt
head -c 20000 /dev/zero | tr '\0' 'A' > datos/img/relleno.dat
ln -s docs/a.txt datos/enlace; chmod 600 datos/docs/b.txt
```

**Verifica**:

```bash
command -v xz bzip2 zstd | wc -l
# 3
find datos | wc -l
# 7
```

## Paso 2: Crear y listar un `tar`

**Por qué**: `-c`, `-t` y `-f` son las tres letras que más vas a escribir. Y
`-v` (en `-t`) te enseña lo que el archivo **guarda de cada cosa**: permisos,
propietario y el destino del enlace.

**Comando**:

```bash
# -c crea, -v enseña cada archivo, -f nombre del archivo (la f va la ULTIMA de las letras).
tar -cvf datos.tar datos
# datos/
# datos/docs/
# datos/docs/a.txt
# datos/docs/b.txt
# datos/enlace
# datos/img/
# datos/img/relleno.dat
tar -tvf datos.tar | awk '{print $1, $6}'
# drwxr-xr-x datos/
# drwxr-xr-x datos/docs/
# -rw-r--r-- datos/docs/a.txt
# -rw------- datos/docs/b.txt
# lrwxrwxrwx datos/enlace
# drwxr-xr-x datos/img/
# -rw-r--r-- datos/img/relleno.dat
```

**Verifica**:

```bash
tar -tf datos.tar | wc -l
# 7
```

Fíjate en dos cosas: `b.txt` conserva su `-rw-------`, y el enlace se guarda
**como enlace** (empieza por `l`), no como una copia de `a.txt`.

## Paso 3: Rutas absolutas frente a relativas

**Por qué**: la ruta con que guardas un archivo es la que tendrá al restaurarlo.
`tar` te protege de las absolutas, y `-C` es la forma correcta de controlar la
ruta que queda dentro.

**Comando**:

```bash
tar -cf abs.tar /tmp/p18/datos/docs
# tar: Removing leading `/' from member names
tar -tf abs.tar | head -2
# tmp/p18/datos/docs/
# tmp/p18/datos/docs/a.txt
tar -cf rel.tar -C /tmp/p18 datos/docs
tar -tf rel.tar | head -2
# datos/docs/
# datos/docs/a.txt
```

**Verifica**:

```bash
tar -tf rel.tar | head -1
# datos/docs/
```

La primera guarda `tmp/p18/datos/docs/`; la segunda, `datos/docs/`. Con `-C` tú
decides **desde dónde** se cuenta la ruta.

## Paso 4: Extraer solo una parte

**Por qué**: restaurar una carpeta entera para recuperar un archivo es lento y
arriesgado. `tar` extrae uno o varios miembros, con comodín, y puede quitar
niveles de la ruta.

**Comando**:

```bash
mkdir o1 && tar -xf datos.tar -C o1 datos/docs/a.txt && find o1 -type f
# o1/datos/docs/a.txt
mkdir o2 && tar -xf datos.tar -C o2 --wildcards '*.txt' && find o2 -type f | sort
# o2/datos/docs/a.txt
# o2/datos/docs/b.txt
mkdir o3 && tar -xf datos.tar -C o3 --strip-components=1 && ls o3
# docs
# enlace
# img
```

**Verifica**:

```bash
find o2 -type f | wc -l
# 2
```

## Paso 5: Excluir y leer la lista de un archivo

**Por qué**: casi nunca quieres **todo**: cachés, temporales, copias. `--exclude`
filtra por patrón y `-T` toma los nombres de un archivo (lo que produce `find`).

**Comando**:

```bash
# El patron va entre comillas: si no, la shell lo expande ANTES de llegar a tar.
tar -cf ex.tar --exclude='*.dat' datos
tar -tf ex.tar | grep -c relleno
# 0
printf 'datos/docs/a.txt\ndatos/docs/b.txt\n' > lista
tar -cf l.tar -T lista && tar -tf l.tar
# datos/docs/a.txt
# datos/docs/b.txt
```

**Verifica**:

```bash
tar -tf ex.tar | wc -l
# 6
```

(Son los 7 originales menos `relleno.dat`.)

## Paso 6: Comparar con el disco y no sobrescribir

**Por qué**: `tar -d` te dice si lo archivado **ya no coincide** con el disco, y
`-k` evita que una extracción pise lo que existe. Sin `-k`, `tar` sobrescribe en
silencio.

**Comando**:

```bash
echo cambio >> datos/docs/a.txt
tar -df datos.tar
# datos/docs/a.txt: Size differs
mkdir o4 && tar -xf datos.tar -C o4
tar -xkf datos.tar -C o4 2>&1 | head -2
# tar: datos/docs/a.txt: Cannot open: File exists
# tar: datos/docs/b.txt: Cannot open: File exists
```

**Verifica**:

```bash
ls -l o4/datos/docs/b.txt | cut -c1-10
# -rw-------
```

El permiso `600` de `b.txt` sobrevivió al viaje de ida y vuelta.

## Paso 7: Medir los cuatro compresores

**Por qué**: la elección de compresor se hace con **números de tus datos**, no
con folclore. Archivas `/usr/share/doc` (texto, lo más típico de comprimir) y
comparas.

**Comando**:

```bash
tar -cf corp.tar -C /usr/share doc 2>/dev/null
wc -c < corp.tar
# 4700160
for c in "gzip -9" "bzip2 -9" "xz -9" "zstd -19"; do
  printf '%-9s %s\n' "$c" "$($c -c corp.tar | wc -c)"
done
# gzip -9   1972376
# bzip2 -9  1517841
# xz -9     949076
# zstd -19  948266
zstd -3 -c corp.tar | wc -c
# 1128522
```

Tus cifras serán **otras** (dependen de lo que tengas instalado en
`/usr/share/doc`); lo que no cambia es el **orden**: `gzip` > `bzip2` > `xz` ≈
`zstd -19`, y `zstd -3` queda entre `bzip2` y `xz`, muy rápido.

**Verifica**:

```bash
g=$(gzip -9 -c corp.tar | wc -c); x=$(xz -9 -c corp.tar | wc -c)
[ "$x" -lt "$g" ] && echo "xz menor que gzip"
# xz menor que gzip
```

## Paso 8: Los cuatro formatos con `tar`

**Por qué**: `tar` solo **llama** al compresor. Crear exige la letra; listar y
extraer, no: `tar` mira los primeros bytes. Y esos bytes te dicen qué es un
archivo aunque la extensión mienta.

**Comando**:

```bash
tar -czf d.tar.gz datos; tar -cJf d.tar.xz datos; tar -cjf d.tar.bz2 datos
tar --zstd -cf d.tar.zst datos
ls d.tar.*
# d.tar.bz2  d.tar.gz  d.tar.xz  d.tar.zst
for f in d.tar.*; do tar -tf $f | head -1; done
# datos/
# datos/
# datos/
# datos/
od -An -tx1 -N2 d.tar.gz; od -An -tx1 -N6 d.tar.xz; od -An -tx1 -N3 d.tar.bz2; od -An -tx1 -N4 d.tar.zst
#  1f 8b
#  fd 37 7a 58 5a 00
#  42 5a 68
#  28 b5 2f fd
```

**Verifica**:

```bash
tar -tf d.tar.xz | head -1
# datos/
```

Listaste un `.xz` y un `.zst` **sin decirle a `tar` cuál era**.

## Paso 9: `gzip` sustituye el original (y cómo evitarlo)

**Por qué**: el comportamiento por defecto que más sorprende. Y `zcat`/`zgrep`
leen un comprimido sin dejar un descomprimido atrás.

**Comando**:

```bash
echo hola > solo.txt
gzip solo.txt && ls solo*
# solo.txt.gz
gzip -k -d solo.txt.gz && ls solo*
# solo.txt  solo.txt.gz
gzip -t solo.txt.gz && echo integro
# integro
printf 'a\nuno\nb\n' | gzip > z.gz
zcat z.gz | wc -l
# 3
zgrep -c uno z.gz
# 1
```

**Verifica**:

```bash
ls solo.txt solo.txt.gz | wc -l
# 2
```

El primer `gzip` **hizo desaparecer** `solo.txt`; el `-k -d` los deja los dos.

## Paso 10: Comprimir lo incomprimible

**Por qué**: comprobar con tus ojos que comprimir datos aleatorios (o ya
comprimidos) no ahorra, y a veces crece.

**Comando**:

```bash
head -c 100000 /dev/urandom > rnd
gzip -c rnd | wc -c
# 100042
```

**Verifica**:

```bash
[ "$(gzip -c rnd | wc -c)" -gt 100000 ] && echo "crece"
# crece
```

## ✅ Resultado

- [ ] Instalaste `xz-utils`, `bzip2` y `zstd` y sabes qué paquete trae `xz` en tu familia
- [ ] Creaste, listaste y extraíste un `tar`, y viste que guarda permisos y enlaces
- [ ] Viste el aviso de la `/` inicial y usaste `-C` para controlar la ruta
- [ ] Extrajiste un archivo, un comodín y quitaste un nivel con `--strip-components`
- [ ] Excluiste con `--exclude` y leíste una lista con `-T`
- [ ] Comparaste con `-d` y evitaste sobrescribir con `-k`
- [ ] Mediste los cuatro compresores sobre los mismos datos y ordenaste el resultado
- [ ] Reconociste cada formato por sus bytes y por qué `tar` lo detecta solo
- [ ] Comprobaste que `gzip` sustituye el original salvo con `-k`

Siguiente: la [práctica 02](02-integridad-y-restauracion.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `xz: not found` / `Child returned status 127` | Falta el compresor | Repite el paso 1 |
| `tar -cfv x.tar ...` crea un archivo llamado `v` | La `f` consumió la `v` | `-cvf x.tar` (la `f` la última) |
| El `.tar` contiene `tmp/p18/...` | Diste una ruta absoluta | `-C /tmp/p18 datos` |
| `--exclude` no excluye | Patrón sin comillas | `--exclude='*.dat'` |
| `gzip: ... already exists; do you wish to overwrite` | `solo.txt` ya existe al descomprimir | Responde `n`, o usa `-f` a conciencia |
| Las cifras no coinciden con las de arriba | Otro `/usr/share/doc` | Solo importa el orden |

---

[← Construyendo `backup`](../1-teoria/08-construyendo-backup.md) · [Práctica 02: integridad y restauración →](02-integridad-y-restauracion.md)
