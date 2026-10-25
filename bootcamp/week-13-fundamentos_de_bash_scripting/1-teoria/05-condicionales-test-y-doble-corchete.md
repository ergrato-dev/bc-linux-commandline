# Condicionales: `test`, `[[ ]]` y `case`

> En bash `if` no evalúa expresiones: **ejecuta un comando y mira su código de
> salida**. Todo lo demás (`[ ]`, `[[ ]]`, `grep -q`) son comandos que
> devuelven `0` o distinto de `0`. Una vez que lo ves así, los condicionales
> dejan de tener rarezas.

## 🎯 Objetivos

- Escribir `if`/`elif`/`else` sobre **cualquier comando**, no solo sobre pruebas
- Elegir entre `[ ]` (`test`) y `[[ ]]` y explicar por qué en bash se prefiere `[[ ]]`
- Distinguir comparación de **texto** (`==`, `<`) de comparación **numérica** (`-eq`, `-lt`)
- Usar las pruebas de archivo (`-f`, `-d`, `-e`, `-s`, `-r`, `-w`, `-x`) y las de cadena (`-z`, `-n`)
- Combinar con `&&`, `||` y `!`, evitando la trampa de `A && B || C`
- Usar `case` para decidir entre muchos patrones, y `=~` para una regex

## 1. Qué problema resuelve

Un script que no decide es un guion. Los scripts del toolkit deciden
constantemente: ¿existe el archivo?, ¿el disco pasa del umbral?, ¿el
argumento es un número? Y es donde más errores sutiles entran: `[ $x = a ]`
con `$x` vacío es un error de sintaxis, `[[ 10 < 9 ]]` es **verdadero**.

## 2. Cómo funciona

### 2.1 `if` mira un código de salida

```bash
if grep -q root /etc/passwd; then
  echo hay-root
fi
# hay-root
if ! command -v nope >/dev/null; then
  echo no-nope
fi
# no-nope
```

La condición es **un comando**. Si sale con `0`, entra en `then`. `grep -q`
no imprime nada: solo devuelve el código (útil porque queremos la respuesta,
no el texto). `command -v nombre` es la forma portable de preguntar "¿existe
este programa?". La forma completa:

```bash
if [[ $uso -ge 90 ]]; then
  echo "critico"
elif [[ $uso -ge 70 ]]; then
  echo "aviso"
else
  echo "ok"
fi
```

### 2.2 `[ ]`, `test` y `[[ ]]`

`[` es **un programa** (también existe como orden interna de bash) con un
`]` final obligatorio que es solo su último argumento: por eso necesita
espacios y por eso `$x` sin comillas lo rompe. `test expresión` es lo mismo
sin corchetes. `[[ ]]` es **sintaxis de bash**: no es un comando, así que
bash la analiza **antes** de expandir y no parte las variables.

```bash
x=""
[ $x = a ];   echo "codigo: $?"
# bash: [: =: unary operator expected
# codigo: 2
[[ $x = a ]]; echo "codigo: $?"
# codigo: 1
[ "$x" = a ]; echo "codigo: $?"
# codigo: 1
```

| | `[ ]` / `test` | `[[ ]]` |
|---|---|---|
| ¿Es POSIX (funciona en `sh`/`dash`)? | **sí** | no: en `dash` da `[[: not found` |
| ¿Parte las variables sin comillas? | sí: hay que entrecomillar | no |
| `&&`, `\|\|` dentro | no (`-a`, `-o`, obsoletos) | sí |
| Patrones (`==  a*`) y regex (`=~`) | no | **sí** |
| `<`, `>` | hay que escapar (`\<`) | sí, pero comparan texto |

Regla del bootcamp: **en un script bash, `[[ ]]`**; entrecomillar las
variables igualmente por costumbre (`[[ "$x" = a ]]` funciona en las dos
formas). `[ ]` solo cuando el script deba ser POSIX.

### 2.3 Pruebas de archivo

```bash
mkdir -p /tmp/c13 && cd /tmp/c13 && touch f && mkdir -p d
[[ -f f ]] && echo f-archivo
# f-archivo
[[ -d d ]] && echo d-dir
# d-dir
[[ -e nada ]] || echo no-existe
# no-existe
[[ -s f ]] || echo vacio
# vacio
[[ -x f ]] || echo no-exec
# no-exec
[[ -r f && -w f ]] && echo rw
# rw
```

| Prueba | Verdadera si |
|---|---|
| `-e ruta` | existe (de cualquier tipo) |
| `-f ruta` | es un archivo regular |
| `-d ruta` | es un directorio |
| `-s ruta` | existe **y no está vacío** |
| `-r` `-w` `-x` | puedes leerlo / escribirlo / ejecutarlo (tú, no el dueño) |
| `-L ruta` | es un enlace simbólico |
| `-z "$s"` / `-n "$s"` | cadena vacía / no vacía |

`[[ -f x ]]` para "es un archivo": `-e` incluiría directorios, y `logreport`
(Semana 05) ya validaba con `-f`.

### 2.4 Texto frente a número: la trampa más cara

Los operadores `==`, `!=`, `<`, `>` comparan **texto** (orden alfabético).
Los numéricos son `-eq -ne -lt -le -gt -ge`:

```bash
[[ 10 -lt 9 ]] && echo num-si || echo num-no
# num-no
[[ 10 < 9 ]]   && echo str-si || echo str-no
# str-si
[[ "2" == "02" ]] && echo igual-str || echo distinto-str
# distinto-str
[[ 2 -eq 02 ]] && echo igual-num
# igual-num
```

`10 < 9` es **verdadero** como texto (`"1"` va antes que `"9"`). Con un uso
de disco como `9` frente a un umbral `90`, `[[ $uso > $umbral ]]` falla
sin avisar. Regla: **números con `-lt/-ge`, texto con `==`**. Y como `-ge` evalúa
su operando como aritmética (Semana 12), **valida antes con regex** si el
dato viene de fuera:

```bash
if ! [[ "$umbral" =~ ^[0-9]+$ && "$umbral" -le 100 ]]; then
  echo "umbral invalido: '$umbral'" >&2
  exit 1
fi
```

Si la primera parte falla, `&&` no evalúa la segunda. Para comparar en
aritmética pura también existe `(( uso >= umbral ))` (sin `$`), pero devuelve
`1` si la expresión es falsa **o cero**: con `set -e` evita usarlo suelto.

### 2.5 Patrones y expresiones regulares dentro de `[[ ]]`

```bash
[[ abc == a* ]] && echo glob-ok
# glob-ok
[[ "v1.22.3" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] && echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[0]}"
# 1 22 v1.22.3
```

`==` con patrón (sin comillas a la derecha, archivo 03) y `=~` con regex
extendida. Los grupos entre paréntesis quedan en el array `BASH_REMATCH` (`[0]`
el total, `[1]` el primer grupo). La regex va **sin comillas**, o en una
variable (`re='^a'; [[ $s =~ $re ]]`): entre comillas pasa a ser texto
literal.

### 2.6 `&&`, `||` y `!`

```bash
true && echo A || echo B
# A
false && echo A || echo B
# B
true && false || echo "C-trampa"
# C-trampa
```

La tercera línea es la trampa de `A && B || C`: **no es un `if/else`**. Si
`A` se cumple pero `B` **falla**, también se ejecuta `C`. Para `if/else`,
escribe un `if`. Los usos sanos de `&&`/`||` son una sola acción:
`comando || { echo "falló" >&2; exit 1; }` y `[[ -f $f ]] && procesar "$f"`.

### 2.7 `case`: muchas ramas, un patrón cada una

```bash
for x in a.txt b.log c; do
  case "$x" in
    *.txt)       echo "$x txt" ;;
    *.log|*.out) echo "$x log" ;;
    *)           echo "$x otro" ;;
  esac
done
# a.txt txt
# b.log log
# c otro
```

Cada rama es un **patrón de glob** (`*.log`, `[0-9]*`), `|` junta varios y `*)`
es el "en cualquier otro caso". Cada rama acaba en `;;`. Con una sola
variable y varios valores es más legible (y más rápido) que una cadena de
`elif`. Es el mismo `case` de los procesadores de opciones (archivo 04).

## 3. Cómo se usa

Tres patrones del toolkit:

```bash
# 1. Validar y salir (guard clause): lo malo, primero y al margen izquierdo.
[[ -f "$archivo" ]] || { echo "no es un archivo: $archivo" >&2; exit 1; }

# 2. Decidir un estado y actuar después, sin anidar.
estado="ok"
if [[ "$uso" -ge "$umbral" ]]; then estado="alerta"; fi

# 3. Salir con el código que corresponda.
if [[ "$estado" == alerta ]]; then exit 2; fi
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `[ $x = a ]` | `x` vacío es error de sintaxis; `x="a b"`, también | `[[ "$x" = a ]]` |
| `[[ $uso > $umbral ]]` | Compara **texto**: `9 > 90` | `[[ $uso -gt $umbral ]]` |
| `[ $a -eq 1 -a $b -eq 2 ]` | `-a` y `-o` son ambiguos y obsoletos | `[[ $a -eq 1 && $b -eq 2 ]]` |
| `A && B \|\| C` como if/else | `C` también corre si `B` falla | `if A; then B; else C; fi` |
| `if [ "$(cmd)" ]` para ver si algo existe | Ejecuta de más y es frágil | `if cmd >/dev/null; then` |
| `[[ $s =~ "^a" ]]` | Las comillas vuelven la regex texto: no coincide | `re='^a'; [[ $s =~ $re ]]` |
| `if [[ $? -ne 0 ]]` tras un comando | Frágil (archivo 04) | `if ! comando; then` |
| Comparar `==` con un patrón por error | `[[ $a == $b ]]` con `b="h*"` coincide con `hola` | Comillas en el lado derecho para literal: `"$b"` |

## 5. Trucos

- **`[[ -v nombre ]]`** pregunta si una variable **está definida** (aunque
  esté vacía), sin expandirla; con `set -u` es la forma segura de comprobarlo.
- **`-nt` y `-ot`**: `[[ a.txt -nt b.txt ]]` es verdadero si `a.txt` es **más
  reciente** que `b.txt`. Un `make` en una línea.
- **`-ef`**: `[[ a -ef b ]]` es verdadero si ambos son el **mismo** archivo
  (mismo inodo, p. ej. enlace duro: Semana 03).
- **`command -v`** devuelve la ruta (o nada) y `0`/`1`: `type -a nombre` enseña
  **todas** las apariciones, y distingue funciones, alias y builtins
  (`cd is a shell builtin`).
- **`case` con `;&` y `;;&`** (bash 4+): `;&` continúa en la rama siguiente
  sin evaluarla, `;;&` sigue probando patrones. Raro, pero existe.
- **`if` con varios comandos**: `if cd "$d" && make; then ...` usa el código
  del **último** de la lista.

## 📚 Recursos Adicionales

- `help test` y `help [[`: la lista completa de operadores, en tu terminal
- `man bash`, sección *CONDITIONAL EXPRESSIONS*

## ✅ Checklist de Verificación

- [ ] Reproduces `[ $x = a ]` con `x=""` y ves el error de sintaxis
- [ ] Predices `[[ 10 < 9 ]]` (verdadero) y `[[ 10 -lt 9 ]]` (falso) antes de ejecutarlos
- [ ] Escribes una validación de número con `=~ ^[0-9]+$` **antes** de `-le 100`
- [ ] Explicas por qué `true && false || echo C` imprime `C`
- [ ] Escribes un `case` que distinga `.txt`, `.log` y el resto

---

[← Argumentos y códigos de salida](04-argumentos-y-codigos-de-salida.md) · [Sustitución de comandos, here-docs y printf →](06-sustitucion-de-comandos-heredocs-y-printf.md)
