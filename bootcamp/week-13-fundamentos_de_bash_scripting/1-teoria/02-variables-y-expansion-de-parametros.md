# Variables y expansión de parámetros

> Una variable de bash es texto con nombre. Todo lo que sabrás hacer con ellas
> (valores por defecto, recortar rutas, contar caracteres) cabe en la sintaxis
> `${...}`, y casi nunca necesitas `sed` ni `cut` para eso.

## 🎯 Objetivos

- Asignar y leer variables sin los tres errores clásicos (espacios, `$` al asignar, nombres pegados)
- Distinguir variable de shell, variable de entorno y variable de un solo comando
- Usar `${v:-x}`, `${v:=x}`, `${v:?msg}` y `${v:+x}` y saber cuándo cada una
- Recortar y sustituir texto con `${v#..}`, `${v%..}`, `${v//a/b}` y `${#v}`
- Hacer cuentas enteras con `$(( ))`

## 1. Qué problema resuelve

Un script que repite `/var/log/toolkit/informe-2026-10-25.txt` cinco veces
tiene cinco sitios donde equivocarse. Una variable lo reduce a uno. Y un
script que **no controla** qué pasa cuando una variable no existe (`rm -rf
"$dir/"*` con `$dir` vacío) acaba borrando `/`. Las variables son cómodas y,
mal usadas, peligrosas: por eso esta semana se enseñan **junto** a sus
protecciones.

## 2. Cómo funciona

### 2.1 Asignar y leer

```bash
fruta=pera            # asignar: SIN espacios alrededor del =
echo "$fruta"         # leer: con $
# pera
x = 5
# bash: x: command not found
z=a b
# bash: b: command not found
```

Con espacios, bash cree que `x` es **un comando** y `=` y `5` sus argumentos.
`z=a b` significa "ejecuta el comando `b` con la variable `z=a` solo para él"
(ver 2.2). Las comillas lo resuelven: `y="a b"`.

Las llaves delimitan el nombre cuando le sigue texto pegado:

```bash
echo "$frutas|${fruta}s"
# |peras
```

`$frutas` es **otra** variable (vacía): bash toma todos los caracteres de
nombre. `${fruta}s` es lo que querías. **Usa llaves siempre que pegues texto
a la variable.**

Convenciones: `snake_case` en minúsculas para variables del script,
`MAYUSCULAS` para variables de entorno (`TOOLKIT_HOME`) y constantes. Los
nombres son sensibles a mayúsculas.

### 2.2 Shell, entorno y "solo para este comando"

```bash
v=local
bash -c 'echo "[${v:-vacio}]"'
# [vacio]
export v
bash -c 'echo "[${v:-vacio}]"'
# [local]
w=1 bash -c 'echo "[$w]"'
# [1]
echo "[${w:-vacio}]"
# [vacio]
```

| Forma | Quién la ve |
|---|---|
| `v=valor` | Solo tu shell (o tu script) |
| `export v=valor` | También los **procesos hijo** (la copia al `fork`, Semana 10) |
| `v=valor orden` | Solo `orden`, y solo mientras corre |

`export` **no** sube nada al padre: el entorno solo se hereda hacia abajo.

Variables que bash ya te da: `$HOME`, `$PWD`, `$UID`, `$$` (PID de la shell),
`$?` (último código de salida), `$BASH_VERSION`. Cuidado con `$USER`: **no
existe** en una shell lanzada con `docker exec` (lo comprobamos: imprime
vacío). Un script portable usa `id -un` o `${USER:-$(id -un)}`.

### 2.3 Valores por defecto: las cuatro formas con `:`

| Forma | Si la variable está vacía o sin definir | Si tiene valor |
|---|---|---|
| `${v:-x}` | Devuelve `x` (no toca `v`) | Devuelve `$v` |
| `${v:=x}` | Asigna `x` a `v` **y** lo devuelve | Devuelve `$v` |
| `${v:?msg}` | **Aborta el script** con `msg` a stderr | Devuelve `$v` |
| `${v:+x}` | Devuelve vacío | Devuelve `x` |

```bash
unset a
echo "[${a:-def}] [${a-def}]"
# [def] [def]
a=""
echo "[${a:-def}] [${a-def}] [${a:+alt}]"
# [def] [] []
unset a; echo "[${a:=asig}] [$a]"
# [asig] [asig]
a=x; echo "[${a:+alt}]"
# [alt]
```

Sin los dos puntos (`${a-def}`), la forma solo mira "no definida", no
"vacía": con `a=""` devolvió vacío. **Casi siempre quieres los dos puntos.**

`${v:?}` es la que protege un script. En archivo:

```bash
printf '#!/usr/bin/env bash\necho ${x:?falta x}\necho no\n' > req.sh && chmod +x req.sh
./req.sh; echo "codigo: $?"
# ./req.sh: line 2: x: falta x
# codigo: 1
```

El `echo no` **no se ejecutó**. Es la forma más corta de "exige este dato".
Y `${v:+x}` es la que usa `snapshot` para imprimir una línea **solo si
existe**: `${alerta:+$alerta}`.

### 2.4 Recortar y sustituir

Todas operan sobre el texto de la variable, sin lanzar ningún programa:

```bash
f=/home/ana/informe.final.tar.gz
echo "${f##*/}"      # quita el prefijo MÁS LARGO hasta la última /
# informe.final.tar.gz
echo "${f%/*}"       # quita el sufijo MÁS CORTO desde la última /
# /home/ana
echo "${f%.gz}"      # quita un sufijo exacto
# /home/ana/informe.final.tar
echo "${f%%.*}"      # quita el sufijo MÁS LARGO desde el primer .
# /home/ana/informe
echo "${f#*.}"       # quita el prefijo MÁS CORTO hasta el primer .
# final.tar.gz
echo "${f##*.}"      # extensión
# gz
echo "${#f}"         # longitud
# 30
echo "${f:6:3}"      # subcadena: desde el índice 6, 3 caracteres
# ana
echo "${f/ana/luis}" # primera sustitución
# /home/luis/informe.final.tar.gz
echo "${f//./_}"     # todas las sustituciones
# /home/ana/informe_final_tar_gz
echo "${f^^}"        # a mayúsculas (bash 4+)
# /HOME/ANA/INFORME.FINAL.TAR.GZ
```

Regla para no memorizar: `#` corta por la **izquierda** y `%` por la
**derecha** (en un teclado, `#` está a la izquierda del `%`); una sola es
la coincidencia **más corta**, doble es la **más larga**. `${f##*/}` es
`basename` y `${f%/*}` es `dirname`, sin proceso nuevo: `snapshot` usa
`${segundos%%.*}` para quitar los decimales de `/proc/uptime`.

### 2.5 Aritmética entera: `$(( ))`

```bash
echo $((10/3)) $((7%3)) $((2**10)) $((1<<4))
# 3 1 1024 16
n=5; ((n++)); echo $n
# 6
```

Solo enteros (`10/3` es `3`). Dentro de `$(( ))` no hace falta `$` delante de
los nombres. Dos trampas, ambas reales:

```bash
echo $((010)) $((0x1F))
# 8 31
echo $(( "08" ))
# ...: 08: value too great for base (error token is "08")
```

Un número con cero delante se lee como **octal** (`010` es 8, `08` es error):
sale cuando conviertes horas o meses con ceros (`date +%H`). Y recuerda la
Semana 12: `((expresion))` sale con `1` si vale `0`, y con `set -e` mata el
script; para contar se escribe `n=$(( n + 1 ))`.

### 2.6 Constantes y tipos

```bash
readonly K=3
K=4
# bash: K: readonly variable
declare -i n=5; n+=2; echo "$n"
# 7
```

`readonly` impide reasignar. `declare -i` fuerza aritmética. No los necesitas
a menudo; `readonly` para rutas fijas al principio del script sí.

## 3. Cómo se usa

Un patrón habitual al principio de cualquier script del toolkit:

```bash
# Configuración con valores por defecto que el entorno puede sobreescribir.
toolkit_home="${TOOLKIT_HOME:-$HOME/.toolkit}"
umbral="${UMBRAL_DISCO:-90}"
```

El usuario puede ajustar sin editar el script: `UMBRAL_DISCO=80 toolkit.sh
snapshot`. Es el mismo mecanismo `v=valor orden` del apartado 2.2.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `rm -rf $dir/*` | Con `$dir` vacío es `rm -rf /*` | `rm -rf "${dir:?}"/*` aborta si `dir` está vacía |
| `x = 5` o `$x=5` | Bash cree que `x` o el valor es un comando | `x=5` |
| `echo $frutas` queriendo `${fruta}s` | Lee otra variable, vacía, en silencio | Llaves: `${fruta}s` |
| `basename "$f"` en un bucle de 10 000 archivos | Un proceso por archivo | `${f##*/}` |
| `n=$(echo "$a + $b" \| bc)` para sumar enteros | Lanza dos procesos | `n=$(( a + b ))` |
| Nombres de una letra en un script de 200 líneas | `$x` no dice nada a quien lo lea a las 3 a. m. | `umbral`, `archivo`, `total` |
| Variables sin `local` dentro de funciones | Pisan las del script (Semana 14) | `local v` |

## 5. Trucos

- **Ver todas las variables** definidas con su tipo: `declare -p`. Una sola:
  `declare -p n` imprime `declare -i n="7"`; es lo que ves cuando dudas de qué
  contiene realmente.
- **`${!prefijo@}`** lista los nombres que empiezan por un prefijo:
  `echo "${!TOOLKIT@}"`.
- **`${var@Q}`** devuelve el valor entrecomillado de forma segura, para
  mensajes de depuración con espacios.
- **`set -u`** (parte de `set -euo pipefail`) convierte el uso de una variable
  sin definir en un error: `./u.sh: line 3: x: unbound variable`, código `1`.
  Es el seguro contra los errores de tecleo (`$fruts`). Con `set -u`, usa
  `${v:-}` cuando una variable **pueda** no existir a propósito.

## 📚 Recursos Adicionales

- `man bash`, sección *Parameter Expansion*: la lista completa de operadores
- [Bash Reference Manual — Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/bash.html#Shell-Parameter-Expansion)

## ✅ Checklist de Verificación

- [ ] `unset a; echo "${a:-def}"` imprime `def` y `echo "${a-def}"` también; con `a=""` solo lo hace la primera
- [ ] Un script con `${x:?falta x}` sale con `1` y no ejecuta la línea siguiente
- [ ] Sacas la extensión y el directorio de una ruta **sin** `basename` ni `dirname`
- [ ] Explicas por qué `$((08))` falla
- [ ] `bash -c 'echo "${v:-vacio}"'` imprime `vacio` hasta que haces `export v`

---

[← Shebang y ejecución](01-shebang-y-ejecucion.md) · [Quoting: comillas y expansiones →](03-quoting-comillas-y-expansiones.md)
