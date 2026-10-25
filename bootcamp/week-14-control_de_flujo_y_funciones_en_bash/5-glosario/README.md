# Glosario — Semana 14

**ámbito dinámico** (*dynamic scope*): regla por la que una función ve las
variables `local` de quien la llamó, además de las suyas y las globales. Por
eso conviene pasar los datos como argumentos.

**array asociativo** (*associative array*): variable que guarda pares
clave → valor. Se declara con `declare -A` (o `local -A`); sin esa
declaración, las claves se evalúan como aritmética y valen `0`.

**array disperso** (*sparse array*): array indexado con huecos, por ejemplo
tras `unset "a[1]"`. `${#a[@]}` cuenta elementos, no la posición del último.

**array indexado** (*indexed array*): variable con varios valores
numerados desde `0`: `a=(uno "dos tres")`. Se recorre con `"${a[@]}"`.

**BASH_SOURCE**: array con los archivos desde los que se ejecuta cada
función. Comparar `${BASH_SOURCE[0]}` con `$0` distingue ejecutar un script
de cargarlo con `source`.

**break** / **continue**: sentencias de bucle. `break` sale (`break 2`, de
dos bucles anidados); `continue` salta a la siguiente iteración.

**bucle** (*loop*): estructura que repite un bloque. En bash: `for`, `while`,
`until` y `for ((...))`.

**despacho dinámico** (*dynamic dispatch*): llamar a una función cuyo nombre
se construye en tiempo de ejecución, como `"hc_check_${nombre}"`. Requiere
validar el nombre antes.

**FUNCNAME**: array con la pila de llamadas a funciones: `${FUNCNAME[0]}` es
la función actual y `${FUNCNAME[1]}`, quien la llamó.

**función** (*function*): bloque con nombre que se llama como un comando.
Recibe argumentos (`$1`, `$#`), escribe en `stdout` y sale con un código.

**glob** (*globbing*): expansión de comodines (`*`, `?`, `[ab]`) a nombres de
archivo. Si no hay coincidencias, el patrón queda literal salvo con `nullglob`.

**guarda de ejecución** (*source guard*): la comprobación
`[[ "${BASH_SOURCE[0]}" == "$0" ]]` que ejecuta `main` solo cuando el script
se lanza, no cuando se carga con `source`.

**lista blanca** (*allowlist*): conjunto cerrado de valores admitidos, que se
comprueba antes de usar un dato. Evita llamar a funciones o comandos no
previstos.

**local**: declara una variable limitada a la función que la contiene (y a
las que esta llame). Sin `local`, una variable asignada en una función es
global.

**mapfile** / **readarray**: orden interna que carga las líneas de un archivo
o de un comando en un array: `mapfile -t lineas < archivo`.

**nameref** (*name reference*): variable que es un alias de otra, creada con
`local -n ref=$1`. Permite a una función modificar una variable o un array
del llamador.

**nullglob**: opción de `shopt` por la que un comodín sin coincidencias se
expande a nada en lugar de quedarse como texto.

**recursión** (*recursion*): función que se llama a sí misma. En bash cada
llamada tiene sus propias variables `local`.

**return**: sale de una función con un código de 0 a 255. Sin número,
devuelve el código del último comando. No devuelve datos: para eso, `stdout`.

**subshell**: copia de la shell que ejecuta `$( )`, cada comando de una
tubería y `( ... )`. Los cambios de variables que hace no vuelven al padre.

**until**: bucle que se repite **hasta** que su condición sea verdadera; el
inverso de `while`.

**while**: bucle que se repite **mientras** su condición sea verdadera.
`while IFS= read -r línea` lee un archivo sin perder espacios.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 15 →](../../week-15-scripts_robustos_manejo_de_errores/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
