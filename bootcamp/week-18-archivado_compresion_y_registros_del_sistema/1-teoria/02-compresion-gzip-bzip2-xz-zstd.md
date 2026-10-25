# Compresión: `gzip`, `bzip2`, `xz` y `zstd`

> Cuatro compresores, un compromiso: **cuánto ahorras frente a cuánto tardas y a quién se lo das**.
> Elegir bien es saber qué mide cada uno, no memorizar una letra de `tar`.

## 🎯 Objetivos

- Comprimir, descomprimir y comprobar con `gzip`, `bzip2`, `xz` y `zstd`
- Comparar tamaño y tiempo con medidas reales, no con folclore
- Usar `tar -z`, `-j`, `-J` y `--zstd` sabiendo qué hace cada una
- Leer un comprimido sin descomprimirlo (`zcat`, `zgrep`)
- Elegir un compresor con criterio y reconocer cuándo no sirve comprimir

## 1. Qué problema resuelve

Un directorio de documentación de `/usr/share/doc` ocupa 4,4 MiB en un `tar` sin
comprimir. Guardado así, cada copia diaria cuesta lo mismo que el original. La
**compresión** sustituye los patrones repetidos por referencias, y el mismo
archivo baja a unos 0,9 MiB con `xz`. Ahorra disco, ancho de banda y tiempo de
copia; el precio es CPU.

## 2. Cómo funciona

### 2.1 Un compresor, un archivo

`gzip`, `bzip2`, `xz` y `zstd` comprimen **un solo flujo de bytes**, no
directorios. Por eso se combinan con `tar`: primero se agrupa, luego se comprime
(el diagrama del archivo 01). Los cuatro comparten las mismas opciones básicas:

| Opción | Hace |
|---|---|
| `-c` | escribe en la salida estándar y **deja el original** |
| `-k` | *keep*: conserva el original (por defecto lo **sustituyen**) |
| `-d` | descomprime (`gunzip`, `bunzip2`, `unxz` y `unzstd` son atajos) |
| `-t` | comprueba la integridad, sin extraer nada |
| `-1` … `-9` | nivel: bajo = rápido, alto = más pequeño |

El detalle que sorprende: **por defecto reemplazan el archivo**.

```bash
cd /tmp/t18 && echo hola > solo.txt
gzip solo.txt && ls solo*
# solo.txt.gz
```

`solo.txt` ya no existe. Para conservarlo, `-k`; para escribir en otro sitio,
`-c` y una redirección (`gzip -c solo.txt > otro.gz`).

### 2.2 Los cuatro, con medidas

El mismo `tar` de `/usr/share/doc` (4 659 200 bytes), con el máximo de cada uno:

```bash
tar -cf corp.tar -C /usr/share doc 2>/dev/null
ls -l corp.tar | awk '{print $5}'
# 4659200
for c in "gzip -9" "bzip2 -9" "xz -9" "zstd -19"; do
  printf '%-9s %s\n' "$c" "$($c -c corp.tar | wc -c)"
done
# gzip -9   1954673
# bzip2 -9  1500770
# xz -9     934668
# zstd -19  934109
```

| Compresor | Bytes | % del original | Tiempo relativo | Nota |
|---|--:|--:|---|---|
| sin comprimir | 4 659 200 | 100 % | — | |
| `gzip -9` | 1 954 673 | 42 % | rápido | el universal; lo lee **cualquier** sistema |
| `bzip2 -9` | 1 500 770 | 32 % | unas 2× `gzip` | casi en desuso |
| `xz -9` | 934 668 | 20 % | **el más lento**, ~5× `gzip` | el que más aprieta; lo usan las distros para sus paquetes |
| `zstd -19` | 934 109 | 20 % | lento en `-19` | con `-3` (por defecto) es **más rápido que `gzip`** |

Los tiempos varían con tu máquina; **lo estable es el orden**. Con `zstd` el
nivel lo cambia todo: en esta misma prueba, `zstd -3` da 1 113 526 bytes
(24 %) en un tiempo casi despreciable, y `zstd -19` iguala a `xz`. Y descomprimir
es siempre más barato que comprimir: `zstd` descomprime unas 5× más rápido que
`xz` en este corpus.

El nivel de `gzip` importa menos de lo que parece: `-1` da 2 174 108, `-6`
(el por defecto) 1 960 702 y `-9` 1 954 673. Subir de `-6` a `-9` ahorra un 0,3 %.

### 2.3 Con `tar`: las letras que llaman al compresor

`tar` no comprime él mismo: **invoca** al programa. Cada letra es un atajo:

| Opción de `tar` | Compresor | Extensión |
|---|---|---|
| `-z` | `gzip` | `.tar.gz` / `.tgz` |
| `-j` | `bzip2` | `.tar.bz2` |
| `-J` | `xz` | `.tar.xz` |
| `--zstd` | `zstd` | `.tar.zst` |
| `-I 'orden'` | cualquiera | `tar -I 'gzip -1' -cf ...` |

```bash
tar -czf d.tar.gz datos && tar -cJf d.tar.xz datos && tar -cjf d.tar.bz2 datos
tar --zstd -cf d.tar.zst datos
tar -I 'gzip -1' -cf d1.tar.gz datos && gzip -t d1.tar.gz && echo ok
# ok
```

Al **listar y extraer** no necesitas decir cuál: `tar -tf d.tar.xz` y
`tar -xf d.tar.zst` detectan el formato por la cabecera del archivo. Solo crear
requiere la letra.

### 2.4 Cómo reconocer cada formato

La extensión puede mentir; los primeros bytes no:

```bash
gzip -c solo.txt.gz | head -c 2 | od -An -tx1
#  1f 8b
od -An -tx1 -N6 d.tar.xz
#  fd 37 7a 58 5a 00
od -An -tx1 -N3 d.tar.bz2
#  42 5a 68
od -An -tx1 -N4 d.tar.zst
#  28 b5 2f fd
```

`1f 8b` es `gzip`, `fd 37 7a 58 5a 00` es `xz`, `42 5a 68` (`BZh`) es `bzip2` y
`28 b5 2f fd` es `zstd`. Es lo que hace la orden `file` cuando la tienes (no
viene en la imagen mínima).

## 3. Cómo se usa

### 3.1 Comprobar, listar y leer sin descomprimir

```bash
gzip -t d.tar.gz && echo "integro"
# integro
gzip -l corp.tar.gz
#          compressed        uncompressed  ratio uncompressed_name
#             1960702             4659200  57.9% corp.tar
echo "linea uno" | gzip > z.gz
zcat z.gz
# linea uno
zgrep -c uno z.gz
# 1
```

`zcat`, `zgrep`, `zless` y `zdiff` leen un `.gz` al vuelo; el equivalente para
`xz` es `xzcat`/`xzgrep`, y para `bzip2` `bzcat`/`bzgrep`. Es lo que usas para
mirar un registro rotado (archivo 06) sin dejar un descomprimido atrás.

`gzip -t` es la comprobación de integridad **del compresor**, no la de tus
datos: un archivo al que se añaden bytes se queja pero lo descomprime
(`decompression OK, trailing garbage ignored`, código de salida 2). La
huella de verdad es la suma (archivo 03).

### 3.2 Varios hilos y concatenación

`xz -T0` usa todos los núcleos; `zstd -T0` también. `gzip` y `bzip2` son de un
solo hilo (el paquete `pigz` es el `gzip` paralelo, y no viene instalado). Y una
curiosidad útil: los `.gz` se pueden **concatenar** y se leen como uno:

```bash
echo a | gzip > c1.gz; echo b | gzip > c2.gz
cat c1.gz c2.gz | gunzip
# a
# b
```

### 3.3 Cuándo no merece la pena

Comprimir datos **ya comprimidos** (JPEG, MP4, `.zip`, un `.gz`) o aleatorios no
ahorra nada, y puede crecer:

```bash
head -c 100000 /dev/urandom > rnd
gzip -c rnd | wc -c
# 100042
```

100 000 bytes aleatorios salen como 100 042: el compresor añade su cabecera y no
encuentra patrones. En una copia de seguridad de fotos, comprimir solo cuesta CPU.

### 3.4 Divergencia de distro

La imagen mínima de cada familia trae **cosas distintas**:

| Programa | Ubuntu y Debian | Rocky/RHEL | Arch |
|---|---|---|---|
| `tar`, `gzip` | instalados | instalados | instalados |
| `bzip2`, `xz`, `zstd` | **no** instalados | **no** instalados | instalados |
| Paquete de `xz` | `xz-utils` | `xz` | `xz` |
| Paquete de `bzip2` y `zstd` | `bzip2`, `zstd` | `bzip2`, `zstd` | `bzip2`, `zstd` |

En el laboratorio, `apt-get install -y xz-utils bzip2 zstd` y listo. En una
máquina sin ellos, `tar -cJf` falla con `/bin/sh: 1: xz: not found` y `tar: Child returned
status 127`: la letra de `tar` no instala el compresor.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `gzip archivo` sin pensar | Sustituye el original; si falla a medias, ya no está | `-k`, o `-c > otro` |
| `xz -9` en un cron cada minuto | Satura la CPU para ahorrar un 1 % | `zstd -3` o `gzip -6` |
| Comprimir JPEG, vídeo o `.zip` | No ahorra nada y cuesta CPU | Archivar sin comprimir (`tar -cf`) |
| Fiarse de la extensión | `.gz` puede ser otro formato | Mirar los bytes iniciales, o `file` |
| Dar un `.tar.zst` a quien no tiene `zstd` | No lo puede abrir | `gzip` para lo que va a otros |
| Subir al nivel `-9` por defecto | Ahorra poco y tarda más | Medir: el nivel por defecto suele bastar |
| Creer que `gzip -t` valida tus datos | Solo mira el formato del compresor | Una suma (`sha256sum`) y una restauración de prueba |
| Descomprimir para hacer `grep` | Ocupa disco y se olvida | `zgrep`, `zcat \| grep` |

## 5. Trucos

- **`zcat -f archivo`** lee igual un archivo comprimido o sin comprimir: sirve en
  un script que procesa `registro` y `registro.1.gz` con el mismo código.
- **`xz -T0 -c archivo > archivo.xz`** reparte el trabajo entre todos tus
  núcleos: `xz` es lento, pero escala.
- **`tar -tf viejo.tar.zst | head`** mira dentro de cualquier formato sin decir
  cuál: `tar` lo detecta solo.

## 📚 Recursos Adicionales

- `man gzip`, `man xz`, `man zstd`
- [Zstandard: compresión rápida (Facebook/Meta)](https://facebook.github.io/zstd/)

## ✅ Checklist de Verificación

- [ ] Sabes que `gzip` sustituye el original salvo con `-k` o `-c`
- [ ] Mides el tamaño de un mismo `tar` con los cuatro compresores
- [ ] Creas `.tar.gz`, `.tar.xz`, `.tar.bz2` y `.tar.zst` y los listas sin decir el formato
- [ ] Lees un `.gz` con `zcat` y `zgrep`
- [ ] Reconoces un formato por sus primeros bytes
- [ ] Explicas por qué comprimir datos aleatorios no ahorra nada
- [ ] Sabes qué paquete instala `xz` en tu familia de distribuciones

---

[← `tar`: archivar sin comprimir](01-tar-archivar-sin-comprimir.md) · [Integridad y restauración →](03-integridad-y-restauracion.md)
