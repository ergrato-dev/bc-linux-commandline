# Bucles: `for`, `while` y `until`

> Un bucle repite un bloque para cada elemento de una lista o mientras se
> cumpla una condición. Casi todos los fallos que verás son de **qué lista
> recorres** (partida por espacios, vacía, con comodines) y no del bucle en sí.

## 🎯 Objetivos

- Recorrer listas, rangos, comodines y líneas de un archivo con el bucle adecuado
- Escribir un rango con `{1..3}`, con `seq` y con `for (( ))`, y saber cuándo cada uno
- Usar `break`, `continue` y `break 2` para controlar la salida
- Evitar las tres trampas de siempre: `$(ls)`, el comodín sin coincidencias y la tubería con subshell
- Leer un archivo línea a línea (también con nombres con espacios) sin perder datos

## 1. Qué problema resuelve

`toolkit.sh healthcheck` ejecuta tres comprobaciones; mañana serán cinco.
Escribir cada llamada a mano es repetir código, y un cambio hay que
hacerlo en cinco sitios. Un bucle recorre la lista y la lista es **un dato**:
añadir una comprobación es añadir un nombre. Los bucles también procesan
archivos de logs, usuarios, hosts: cualquier "haz esto para cada cosa".

## 2. Cómo funciona

### 2.1 `for` sobre una lista

```bash
for x in a "b c" d; do echo "<$x>"; done
# <a>
# <b c>
# <d>
```

`for VARIABLE in PALABRAS; do ...; done`. La lista son **palabras** después
de todas las expansiones (archivo 03 de la Semana 13): `"b c"` entrecomillado
es **un** elemento. La variable sigue existiendo al acabar el bucle, con el
último valor:

```bash
for z in 1 2 3; do :; done; echo "z=$z"
# z=3
```

Sin `in`, `for a; do` recorre los argumentos del script o de la función
(`"$@"`):

```bash
set -- x y; for a; do echo "<$a>"; done
# <x>
# <y>
```

### 2.2 Rangos: tres formas

```bash
for i in {1..3}; do echo -n "$i "; done; echo
# 1 2 3
for i in {01..03}; do echo -n "$i "; done; echo
# 01 02 03
for i in {10..1..3}; do echo -n "$i "; done; echo
# 10 7 4 1
for ((i=0; i<3; i++)); do echo -n "$i "; done; echo
# 0 1 2
n=3; for i in $(seq 1 $n); do echo -n "$i "; done; echo
# 1 2 3
```

| Forma | Cuándo |
|---|---|
| `{1..3}` | Límites **literales** (conserva ceros: `{01..03}`; admite paso: `{10..1..3}`) |
| `for ((i=0; i<n; i++))` | El límite está en una **variable** |
| `$(seq 1 "$n")` | Límite en variable, en una línea; lanza un proceso |

La trampa: las llaves se expanden **antes** que las variables, así que
`{1..$n}` no funciona:

```bash
n=3; for i in {1..$n}; do echo -n "[$i]"; done; echo
# [{1..3}]
```

Con límite variable: `for ((i=1; i<=n; i++))`. El bucle de estilo C
evalúa **aritmética**, sin `$` dentro de los paréntesis.

### 2.3 `for` sobre comodines (y el comodín que no coincide)

```bash
for f in /tmp/f14/*.zip; do echo "<$f>"; done
# </tmp/f14/*.zip>
shopt -s nullglob
for f in /tmp/f14/*.zip; do echo "<$f>"; done
echo fin
# fin
shopt -u nullglob
```

Sin coincidencias, bash deja el **patrón literal** (`*.zip`), y el cuerpo
corre una vez con un archivo que no existe. Dos defensas: `shopt -s nullglob`
(el patrón sin coincidencias desaparece) o comprobar dentro: `[[ -e $f ]] ||
continue`. Con nombres con espacios, `for f in *.txt` es seguro: el
resultado del glob **no** se vuelve a partir.

### 2.4 `while` y `until`

```bash
i=0; while [[ $i -lt 3 ]]; do echo -n "w$i "; i=$((i+1)); done; echo
# w0 w1 w2
i=0; until [[ $i -ge 3 ]]; do echo -n "u$i "; i=$((i+1)); done; echo
# u0 u1 u2
```

`while` repite **mientras** el comando de la condición salga con `0`;
`until` repite **hasta que** salga con `0`. Como `if`, la condición es un
comando cualquiera: `while read ...`, `while ! ping ...`, `until grep -q
listo log.txt; do sleep 1; done` (esperar a un servicio).

`while true; do ...; [[ condicion ]] && break; done` es el bucle "infinito
con salida": útil para reintentos.

### 2.5 `break`, `continue` y `break N`

```bash
for i in 1 2 3 4 5; do
  [[ $i -eq 2 ]] && continue
  [[ $i -eq 4 ]] && break
  echo -n "$i "
done; echo
# 1 3
for i in 1 2; do for j in a b c; do [[ $j == b ]] && break 2; echo "$i$j"; done; done
# 1a
```

`continue` salta al siguiente elemento; `break` sale del bucle; `break 2`
sale de **dos** niveles (el bucle de dentro y el de fuera). Con `set -e`,
cuidado con `[[ ... ]] && continue` como **última** línea de un bloque:
el `&&` falso devuelve `1` (Semana 13).

### 2.6 Leer un archivo línea a línea

```bash
printf 'a b\n  c\n' > l.txt
while IFS= read -r linea; do echo "<$linea>"; done < l.txt
# <a b>
# <  c>
```

`IFS=` conserva los espacios y `-r` los `\`. La redirección `< l.txt` va
**después de `done`**: alimenta al bucle entero. Una variante cuando el
cuerpo también lee del teclado: usar otro descriptor (`<&3` y `3< l.txt`).

Para listas de archivos con nombres arbitrarios, `find -print0` y `read
-d ''` (el separador es el byte nulo, que no puede estar en un nombre):

```bash
touch "a b.txt" c.txt
find . -name '*.txt' -print0 | while IFS= read -r -d '' f; do echo "<$f>"; done
# <./c.txt>
# <./a b.txt>
```

Esta tubería corre el `while` en un **subshell**: lo que cambies dentro
(un contador) no sale (Semana 13, `< <(...)` lo resuelve).

## 3. Cómo se usa

Contar elementos con una función de contador segura con `set -e`:

```bash
total=0
for f in *.txt; do
  total=$(( total + 1 ))
done
echo "$total"
# 2   (en una carpeta con dos archivos .txt)
```

(`total=$(( total + 1 ))` es una asignación: siempre sale con `0`. `((total++))`
sale con `1` cuando vale `0` y aborta con `set -e`: lo vimos en la Semana 12.)
Y el bucle estrella del toolkit, que recorre **nombres** y llama a una función
por cada uno (archivo 06):

```bash
for nombre in disk mem procs; do
  "hc_check_${nombre}" "${limite[$nombre]}"
done
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `for f in $(ls)` | Parte por espacios: `a b.txt` son dos elementos | `for f in *` |
| `for i in {1..$n}` | Las llaves se expanden antes que `$n` | `for ((i=1; i<=n; i++))` |
| `for l in $(cat archivo)` | Parte por palabras, no por líneas | `while IFS= read -r l; do ...; done < archivo` |
| `for f in *.zip` sin comprobar | Sin zips, el cuerpo corre con `*.zip` literal | `nullglob` o `[[ -e $f ]] \|\| continue` |
| `cmd \| while read ...; do total=...; done` y usar `$total` luego | La tubería es un subshell | `done < <(cmd)` |
| `while read linea` sin `IFS=` ni `-r` | Pierde espacios y `\` | `while IFS= read -r linea` |
| Bucle infinito sin `break` ni tope | Cuelga un `cron` para siempre | Tope de intentos y `break` |
| `((i++))` como contador con `set -e` | Aborta el script al llegar al `0` | `i=$(( i + 1 ))` |

## 5. Trucos

- **`for i in {a..e}`** también recorre letras: `a b c d e`.
- **`while IFS=: read -r user _ uid _; do ...; done < /etc/passwd`** recorre
  `/etc/passwd` con los campos ya separados en variables (los `_` descartan
  los que no usas).
- **`until`** es lo natural para **esperar**: `until [[ -f /tmp/listo ]]; do sleep
  1; done`. Añade siempre un tope de intentos en un script real.
- **`for` sin lista ni `in` en una función** recorre los argumentos de esa
  función, no los del script.

## 📚 Recursos Adicionales

- `man bash`, sección *Compound Commands* (`for`, `while`, `until`, `select`)
- `help for`, `help while`, `help break`: la ayuda integrada de bash

## ✅ Checklist de Verificación

- [ ] `for i in {01..03}` imprime `01 02 03` y `{1..$n}` **no** funciona con `n=3`
- [ ] Reproduces el comodín sin coincidencias y lo arreglas con `nullglob`
- [ ] Un `for f in $(ls)` parte `a b.txt` en dos, y `for f in *` no
- [ ] `break 2` sale de dos bucles anidados
- [ ] Un `while IFS= read -r` conserva los dos espacios de `"  c"`

---

[← Índice de la semana](../README.md) · [Funciones: definición y uso →](02-funciones-definicion-y-uso.md)
