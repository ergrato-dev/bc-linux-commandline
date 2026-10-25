# Arrays indexados

> Un array es una variable con varios valores. Resuelve el problema que las
> comillas no podían: guardar una **lista de palabras con espacios** sin que se
> parta, y pasarla intacta a un bucle o a una función.

## 🎯 Objetivos

- Crear, leer, ampliar y recorrer un array indexado
- Distinguir `"${a[@]}"` de `"${a[*]}"` y saber por qué solo la primera es segura
- Contar elementos, ver índices y cortar rangos (`${#a[@]}`, `${!a[@]}`, `${a[@]:1:2}`)
- Llenar un array desde un archivo o un comando sin partir por espacios (`mapfile`, `read -a`)
- Pasar un array a una función

## 1. Qué problema resuelve

`healthcheck` recorre `disk mem procs`; con `--solo mem,disk` esa lista
la decide el usuario. ¿Dónde se guarda? Una cadena `"disk mem procs"` se
parte por espacios (y falla si un elemento tiene uno); una variable por
elemento no se puede recorrer. Un **array** guarda cada elemento aparte,
con comillas y todo.

## 2. Cómo funciona

### 2.1 Crear y leer

```bash
a=(uno "dos tres" cuatro)
echo "${a[1]} ${#a[@]} ${#a[1]}"
# dos tres 3 8
echo "${a[-1]}"
# cuatro
echo "${a[@]:1:2}"
# dos tres cuatro
```

| Expresión | Significa |
|---|---|
| `a=(x y "z w")` | Crea un array de 3 elementos |
| `${a[1]}` | El elemento de índice 1 (se cuenta desde **0**) |
| `${a[-1]}` | El último |
| `${#a[@]}` | **Cuántos** elementos hay |
| `${#a[1]}` | Longitud del elemento 1 (`dos tres` son 8) |
| `${a[@]:1:2}` | Dos elementos desde el índice 1 (rebanada) |
| `${!a[@]}` | Los **índices** |

**Siempre llaves**: `$a[1]` no es lo que parece (es `$a` seguido de `[1]`).

### 2.2 `"${a[@]}"` y `"${a[*]}"`

```bash
a=(uno "dos tres" cuatro)
for x in "${a[@]}"; do echo "<$x>"; done
# <uno>
# <dos tres>
# <cuatro>
for x in ${a[@]}; do echo -n "<$x>"; done; echo
# <uno><dos><tres><cuatro>
for x in "${a[*]}"; do echo "<$x>"; done
# <uno dos tres cuatro>
```

Es **exactamente** la diferencia entre `"$@"` y `"$*"` de la Semana 13:

| Forma | Resultado |
|---|---|
| `"${a[@]}"` | Un elemento = una palabra, **intactos**: **la correcta** |
| `${a[@]}` (sin comillas) | Parte `"dos tres"` en dos |
| `"${a[*]}"` | Todo en **una** palabra, unido por el primer carácter de `IFS` |

Un array vacío con `"${a[@]}"` produce **cero** palabras, que es lo que
quieres (y con `set -u` en bash 5 no da error; en versiones antiguas, sí).

### 2.3 Añadir, borrar y huecos

```bash
a=(uno "dos tres" cuatro)
a+=(cinco)
a[7]=siete
echo "${#a[@]} ${!a[@]}"
# 5 0 1 2 3 7
unset "a[1]"
echo "${#a[@]} ${!a[@]}"
# 4 0 2 3 7
echo "${a[1]-vacio}"
# vacio
```

`a+=(x)` **añade al final**. Asignar a un índice lejano crea un array
**disperso**: `${#a[@]}` cuenta elementos (5), no la posición del último
(8), y `unset "a[1]"` deja un hueco **sin renumerar**. Por eso se recorre
con `"${a[@]}"` y no con `for ((i=0; i<${#a[@]}; i++))` si el array pudo
tener huecos. (Las comillas en `unset "a[1]"` evitan que el shell
interprete `[1]` como un glob.)

Una variable normal es un array de un elemento, y se puede ampliar:

```bash
arr=x; arr+=(y); echo "${arr[@]}"
# x y
```

### 2.4 Llenar un array desde fuera

```bash
IFS=, read -ra p <<< "x,y z,w"
echo "${#p[@]}"
# 3
printf 'l1\nl2\n\nl4\n' > m.txt
mapfile -t lineas < m.txt
echo "${#lineas[@]} [${lineas[2]}]"
# 4 []
readarray -t l2 < <(printf 'q\nr\n')
echo "${l2[@]}"
# q r
touch "a b.txt" c.txt
fs=(*.txt)
printf '<%s>\n' "${fs[@]}"
# <a b.txt>
# <c.txt>
```

| Origen | Instrucción |
|---|---|
| Una cadena separada por un carácter | `IFS=, read -ra arr <<< "$cadena"` |
| Las **líneas** de un archivo | `mapfile -t arr < archivo` (`-t` quita el `\n`) |
| Las líneas que imprime un comando | `mapfile -t arr < <(comando)` |
| Los archivos de un patrón | `arr=(*.txt)` |

`readarray` es sinónimo de `mapfile`. **Nunca** `arr=($(comando))`: parte
por palabras y expande comodines:

```bash
bad=($(echo "a b" "c")); echo "${#bad[@]}"
# 3
```

(Eran dos líneas lógicas, y salen tres elementos.)

### 2.5 Pasar un array a una función

La función recibe **palabras**, no el array. Se pasa expandido, con comillas:

```bash
f() { local x; for x in "$@"; do echo "-$x"; done; }
f "${a[@]}" | head -2
# -uno
# -cuatro
```

Y se devuelve por `stdout` (una línea por elemento) capturando con `mapfile`:

```bash
ra() { printf '%s\n' a "b c"; }
mapfile -t res < <(ra)
echo "${#res[@]} ${res[1]}"
# 2 b c
```

Una copia: `b=("${a[@]}")` (los índices se renumeran: `0 1 2 3`).

### 2.6 Unir, buscar y ordenar

```bash
j=$(IFS=,; echo "${p[*]}"); echo "$j"
# x,y z,w
b=(x y z); w=y
for e in "${b[@]}"; do [[ $e == "$w" ]] && echo found; done
# found
b=(1 2 3 4 5); echo "${b[@]: -2}" "${b[@]:1:2}"
# 4 5 2 3
printf '%s\n' 10 9 100 | sort -n | tr '\n' ' '; echo
# 9 10 100
```

Para **unir** con un separador, `"${a[*]}"` dentro de un subshell con `IFS`
cambiado (el `IFS` modificado no sale del `$( )`). Para **buscar**, un
bucle con `[[ ]]`. Para **ordenar**, `printf` + `sort` (bash no ordena arrays).

## 3. Cómo se usa

En el toolkit, el array `orden` fija qué comprobaciones hay y en qué orden, y
`--solo` lo sustituye:

```bash
local -a orden=(disk mem procs)
local -a pedidos=("${orden[@]}")
if [[ "$solo_dado" -eq 1 ]]; then
  IFS=, read -ra pedidos <<< "$solo"
fi
for nombre in "${pedidos[@]}"; do ...; done
```

`local -a` declara un array local (no es obligatorio, pero deja claro el
tipo).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `lista="a b c"; for x in $lista` | Se parte por espacios; falla con un elemento con espacio | `lista=(a "b c")` y `"${lista[@]}"` |
| `${a[@]}` sin comillas | Parte los elementos con espacios | `"${a[@]}"` |
| `arr=($(comando))` | Parte por palabras y expande comodines | `mapfile -t arr < <(comando)` |
| `for ((i=0; i<${#a[@]}; i++))` con huecos | Los índices no son contiguos | `for x in "${a[@]}"` o recorrer `"${!a[@]}"` |
| `echo $a` esperando todo el array | Imprime solo el elemento 0 | `echo "${a[@]}"` |
| `unset b[1]` sin comillas | Si existe un archivo `b1`, el glob `b[1]` se expande a él y **no borra nada** del array | `unset "b[1]"` |
| Usar arrays para datos grandes | Bash es lento con miles de elementos | `sort`/`awk` sobre el archivo |

## 5. Trucos

- **`${#a[@]}` en una condición**: `[[ ${#a[@]} -eq 0 ]]` es "array vacío"
  (el `healthcheck` lo usa tras partir `--solo ""`).
- **`declare -p a`** muestra el array con sus índices:
  `declare -a a=([0]="uno" [2]="cuatro" ...)`. La mejor forma de depurar.
- **`printf '%s\n' "${a[@]}"`** imprime **uno por línea**, ideal para
  inspeccionar o para tuberías (`... | sort | uniq -c`).
- **`"${a[@]/#/--}"`** antepone `--` a cada elemento (expansión de
  parámetros aplicada al array entero).

## 📚 Recursos Adicionales

- `man bash`, sección *Arrays*
- `help mapfile` y `help declare`

## ✅ Checklist de Verificación

- [ ] `a=(uno "dos tres" cuatro); echo "${#a[@]}"` imprime `3`
- [ ] Recorres `a` con y sin comillas y ves `<dos tres>` frente a `<dos><tres>`
- [ ] `a[7]=siete` y `unset "a[1]"` dejan índices `0 2 3 7`, y lo explicas
- [ ] `mapfile -t` carga las líneas de un archivo (incluida la vacía)
- [ ] `bad=($(echo "a b" "c"))` da 3 elementos, y sabes por qué es un antipatrón

---

[← Ámbito y valores de retorno](03-ambito-y-valores-de-retorno.md) · [Arrays asociativos →](05-arrays-asociativos.md)
