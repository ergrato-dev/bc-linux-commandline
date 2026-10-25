# Sustitución de comandos, here-docs y `printf`

> Un script no solo ejecuta comandos: **captura** su salida para guardarla en
> variables, **construye** texto con varias líneas y lo **formatea**. Son tres
> herramientas pequeñas (`$( )`, `<<EOF`, `printf`) que, juntas, generan
> cualquier informe.

## 🎯 Objetivos

- Capturar la salida de un comando en una variable con `$( )` y saber qué pasa con su código de salida
- Explicar por qué `local v=$(cmd)` oculta los errores y cómo evitarlo
- Escribir texto de varias líneas con un here-doc (con y sin expansión) y con una here-string
- Formatear con `printf` (anchos, decimales, `%s` repetido) y saber por qué es mejor que `echo`
- Leer un archivo línea a línea con `while IFS= read -r`

## 1. Qué problema resuelve

`snapshot` necesita el nombre del equipo (`uname -n`), la fecha, el kernel y
los pasa a un informe de once líneas. Sin captura habría que escribir las
salidas a archivos temporales y releerlas. Con `$( )` el resultado **entra
directamente en una variable**, y con un here-doc el informe se escribe como
se verá, con las variables dentro.

## 2. Cómo funciona

### 2.1 Sustitución de comandos `$( )`

```bash
fecha=$(date +%F)
echo "hoy: $fecha"
# hoy: 2026-10-25
```

Bash ejecuta el comando dentro de `$( )` en un **subshell**, captura su
`stdout` y **sustituye** la expresión por ese texto. Tres detalles:

1. **Quita los saltos de línea finales** (todos, no solo uno):

   ```bash
   n=$(printf "a\nb\n\n\n"); echo "[$n]"
   # [a
   # b]
   ```

2. **`$( )` se anida** sin escapar nada: `"$(dirname "$(readlink -f "$0")")"`.
   La forma antigua de comillas invertidas (`` `cmd` ``) no se anida bien
   y se confunde con comillas: **no la uses**, aunque la verás en scripts viejos.
3. **Va entre comillas dobles** como cualquier expansión: `"$(cmd)"`, si no el
   resultado se parte (archivo 03).

Para leer un archivo entero hay un atajo sin `cat`: `x=$(< archivo)` (la
Semana 05 explicó `<`). Con el archivo `uno\ndos` da `[uno` / `dos]`.

### 2.2 El código de salida de una sustitución

```bash
x=$(false); echo $?
# 1
echo "$(exit 4)"; echo $?
# 0
```

Una **asignación pura** (`x=$(cmd)`) devuelve el código de `cmd`: `set -e` la
detecta. Pero `echo "$(exit 4)"` devuelve el de `echo`: el `4` se pierde.
Mismo problema con `local` y `export`, que son comandos que **también** tienen
su propio código:

```bash
f() { local v=$(false); echo "codigo: $?"; }; f
# codigo: 0
g() { local v; v=$(false); echo "codigo: $?"; }; g
# codigo: 1
```

`local v=$(false)` salió con `0` (el de `local`): el fallo **desaparece**, y
con `set -e` no aborta. ShellCheck lo marca como SC2155. La regla: **declara
y asigna en dos líneas** (`local v` / `v=$(cmd)`). En el toolkit, `local
informe` y después `informe=$(cat <<EOF ...)`.

Y en una tubería, `set -o pipefail` (parte de `set -euo pipefail`) hace que el
código sea el del **primer** comando que falló, no el del último:

```bash
false | true; echo $?
# 0
set -o pipefail; false | true; echo $?
# 1
```

### 2.3 Here-docs: texto de varias líneas

```bash
v=hola
cat <<EOF
sin comillas: $v $(echo cmd)
EOF
# sin comillas: hola cmd
cat <<"EOF"
con comillas: $v $(echo cmd)
EOF
# con comillas: $v $(echo cmd)
```

| Forma | Efecto |
|---|---|
| `<<EOF` | Expande `$v`, `$( )`, `$(( ))`. Para escapar: `\$v` y `` \` `` |
| `<<"EOF"` o `<<'EOF'` | **Literal**: nada se expande. Para escribir scripts o configuración |
| `<<-EOF` | Igual que `<<EOF`, pero **quita los tabuladores** iniciales (no espacios): permite sangrar el bloque dentro de un `if` |

```bash
cat <<-EOT
	con tab quitado
	  espacios siguen
	EOT
# con tab quitado
#   espacios siguen
```

(El cuerpo y el cierre `EOT` van sangrados con **tabuladores**; con espacios
no funciona.) El delimitador de cierre debe estar **solo en su línea** y sin
nada detrás.

La salida de un here-doc se puede capturar en una variable: es lo que hace
`snapshot`:

```bash
informe=$(cat <<EOF
== toolkit snapshot ==
fecha: $(date +%F)
host: $(uname -n)
EOF
)
```

Para escribir un archivo: `cat > config.txt <<'EOF'`. Para **una sola
línea** hay la *here-string*: `cat <<< "texto $HOME"` imprime
`texto /root`.

### 2.4 Líneas opcionales con `${v:+...}`

En el informe, la línea `alerta: ...` debe salir **solo si hay alerta**,
no vacía. Dentro del here-doc:

```bash
alerta=""
cat <<EOF
disco: 25%
${alerta:+$alerta
}estado: ok
EOF
# disco: 25%
# estado: ok
```

Si `alerta` está vacía, `${alerta:+...}` es vacío y **no queda línea en
blanco**: el salto de línea va **dentro** de la expansión (archivo 02). Con
`alerta="alerta: disco al 95%"` aparece la línea.

### 2.5 `printf`: formato sin sorpresas

```bash
printf "%5s|%-5s|%05d|%.2f|%x\n" ab cd 42 3.14159 255
#    ab|cd   |00042|3.14|ff
printf "%s\n" a b c
# a
# b
# c
printf "%d%%\n" 50
# 50%
```

| Formato | Significa |
|---|---|
| `%s` | cadena (`%5s` ancho 5 a la derecha, `%-5s` a la izquierda) |
| `%d` | entero (`%05d` rellena con ceros) |
| `%.2f` | decimal con 2 cifras |
| `%x` | hexadecimal |
| `%q` | cadena escapada para el shell |
| `%%` | un `%` literal |
| `%b` | interpreta escapes (`\t`, `\n`) del argumento |

`printf` **reutiliza el formato** si hay más argumentos: `printf '%s\n' a b c`
imprime tres líneas. Por eso `printf '%s\n' "$informe"` es la forma de
imprimir una variable.

### 2.6 Por qué `printf` y no `echo`

`echo` cambia de comportamiento según la shell y las opciones (`-e`, `-n`,
y una variable que empiece por `-n` se lee como opción). `printf '%s\n'
"$x"` imprime **siempre lo mismo**: el valor, intacto, más un salto de línea.
`echo` es válido para texto fijo; con datos, `printf`.

### 2.7 Leer un archivo línea a línea

```bash
printf 'uno\ndos\n' > l.txt
while IFS= read -r linea; do
  echo "<$linea>"
done < l.txt
# <uno>
# <dos>
```

`IFS=` impide que se recorten los espacios del principio y del final, y
`-r` impide que `\` se interprete: **sin ellos se altera la línea**.
Sin `IFS=`: `<  c>` pierde sus dos espacios (`<c>`).

Atento a la **tubería**: cada comando de una tubería corre en un subshell, y
una variable asignada dentro del `while` muere con él:

```bash
printf "a\nb\n" | while read -r l; do n=$((n+1)); done; echo "n=${n:-0}"
# n=0
while read -r l; do n=$((n+1)); done < <(printf "a\nb\n"); echo "n=$n"
# n=2
```

`< <(comando)` (sustitución de procesos) alimenta el bucle **sin** subshell.
Es el remedio estándar; la Semana 14 vuelve sobre ello con los bucles.

## 3. Cómo se usa

El esqueleto de cualquier informe del toolkit:

```bash
local fecha host
fecha=$(date +%F)
host=$(uname -n)
printf '%s\n' "== informe ==" "fecha: $fecha" "host: $host"
```

Y la fecha dentro de un nombre de archivo, que usarás en `cron`:
`informe-$(date +%Y%m%d-%H%M%S).txt` (`date` acepta `+formato`; con `%F` es
`AAAA-MM-DD`).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `local v=$(cmd)` | El código de `cmd` se pierde (SC2155) | `local v` y luego `v=$(cmd)` |
| `` x=`cmd` `` | Se anida mal y se confunde con comillas simples | `x=$(cmd)` |
| `$(cat archivo)` | Un proceso de más | `$(< archivo)` |
| `for l in $(cat f)` | Parte por **palabras**, no por líneas | `while IFS= read -r l; do ...; done < f` |
| `echo -e "...$var..."` con datos | `-e` no es portable; un dato con `\c` se interpreta | `printf '%s\n' "$var"` |
| `cmd \| while read ...; do total=...; done` esperando usar `$total` fuera | La tubería corre en subshell | `done < <(cmd)` |
| Here-doc sin comillas con un script dentro | Bash expande **sus** `$` al escribirlo | `<<'EOF'` |
| Sangrar un here-doc con espacios y `<<-` | `<<-` solo quita tabuladores | Tabuladores, o no sangrar |

## 5. Trucos

- **`printf '%(%F %T)T\n' -1`** formatea la fecha **sin lanzar `date`** (bash
  4.2+). `-1` es "ahora". Comprobado: imprime `2026-10-25` con `%F`.
- **`$(( ))` dentro de un here-doc** funciona: `memoria: $(( memoria_kb / 1024 )) MiB`
  es la línea de `snapshot`.
- **`tee`** guarda y muestra a la vez (Semana 05): `printf '%s\n' "$informe" |
  tee informe.txt`.
- **`mktemp`** crea un archivo o directorio temporal único (`tmp=$(mktemp)`);
  la Semana 15 le añade el `trap` para borrarlo.

## 📚 Recursos Adicionales

- `man bash`, secciones *Command Substitution* y *Here Documents*
- `help printf`: el formato completo de `printf`

## ✅ Checklist de Verificación

- [ ] `n=$(printf "a\nb\n\n\n"); echo "[$n]"` imprime dos líneas y **no** líneas vacías al final
- [ ] Explicas la diferencia de código entre `local v=$(false)` y `local v; v=$(false)`
- [ ] Un here-doc con `<<"EOF"` imprime `$v` literal y el mismo here-doc con `<<EOF` lo expande
- [ ] `printf "%5s|%-5s|%05d\n" ab cd 42` imprime `   ab|cd   |00042`
- [ ] Reproduces el `n=0` frente a `n=2` con tubería y con `< <( )`

---

[← Condicionales: test y doble corchete](05-condicionales-test-y-doble-corchete.md) · [ShellCheck →](07-shellcheck.md)
