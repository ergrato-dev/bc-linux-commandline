# Rúbrica de Evaluación — Semana 14

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. En una carpeta con `a b.txt` y `c.txt`, ¿por qué `for f in $(ls)` da tres iteraciones y `for f in *` da dos?

<details>
<summary>Ver respuesta</summary>

`$(ls)` devuelve **texto**, y la shell lo parte por espacios (*word
splitting*): `a b.txt` se convierte en `a` y `b.txt`, dos nombres que no
existen. `*` es un comodín (*glob*) que la shell expande a **una palabra por
archivo** y cuyo resultado no se vuelve a partir, así que `a b.txt` llega
intacto. `shellcheck` lo avisa antes de ejecutar (SC2045).

</details>

2. ¿Por qué `n=3; for i in {1..$n}` imprime `{1..3}` y qué alternativas hay?

<details>
<summary>Ver respuesta</summary>

La expansión de llaves ocurre **antes** que la de variables, así que cuando
bash intenta expandir `{1..$n}` todavía no sabe cuánto vale `$n` y deja el
texto literal. Con un límite en variable se usa `for ((i=1; i<=n; i++))` (en
bash puro) o `$(seq 1 "$n")` (un proceso externo). Con números fijos, `{1..3}`
sí funciona.

</details>

3. Un `while read` detrás de una tubería cuenta líneas y el contador sale `0`. ¿Por qué y cómo se arregla?

<details>
<summary>Ver respuesta</summary>

Cada comando de una tubería corre en un **subshell**, y los cambios de
variables en un subshell no vuelven al proceso padre. El bucle sí contó, pero
en una copia que muere al terminar. Se arregla para que el bucle corra en la
shell principal: `while read -r l; do ...; done < <(comando)` (sustitución
de procesos) o, si la fuente es un archivo, `done < archivo`.

</details>

4. ¿Qué imprime `v=global; show() { echo "$v"; }; f() { local v=local; show; }; f; show` y qué dice eso del ámbito en bash?

<details>
<summary>Ver respuesta</summary>

Imprime `local` y luego `global`. Bash tiene ámbito **dinámico**: una función
ve las variables `local` de **quien la llamó**, no solo las suyas y las
globales. `show` encuentra `v` en `f` cuando la llama `f`, y la global cuando
la llamas tú. Funcionar por casualidad así se rompe al cambiar el llamador;
la solución es pasar los datos como argumentos (`show "$v"`).

</details>

5. ¿Cómo "devuelve" una función un valor en bash y por qué `r=$(inc)` no cambia el contador `cnt` que `inc` incrementa?

<details>
<summary>Ver respuesta</summary>

`return` solo admite un código de 0 a 255 (un **estado**). Para devolver un
**dato** la función lo escribe en `stdout` y el llamador lo captura con
`$( )`. Pero `$( )` ejecuta la función en un **subshell**: el incremento de
`cnt` ocurre en la copia y se pierde, y `r` queda vacío porque `inc` no
imprimió nada. Una función que debe cambiar el estado del script se llama
directamente, sin `$( )` ni tubería.

</details>

6. Con `set -e`, `f() { false; echo seguia; }` aborta al llamar a `f`, pero `if f; then ...` imprime `seguia`. ¿Por qué importa a la hora de escribir `hc_check_*`?

<details>
<summary>Ver respuesta</summary>

`set -e` se **desactiva** en cualquier comando que forme parte de una
condición (`if`, `while`, `&&`, `||`, `!`), incluidos los de dentro de una
función llamada ahí. Una función que cuenta con `set -e` para parar a mitad
sigue ejecutando cuando la llaman desde un `if`. Por eso las `hc_check_*`
comprueban y hacen `return 1` **explícito**, y `cmd_healthcheck` las llama con
`if !` para contar el fallo sin abortar.

</details>

7. ¿En qué se diferencian `"${a[@]}"`, `${a[@]}` y `"${a[*]}"` con `a=(uno "dos tres" cuatro)`?

<details>
<summary>Ver respuesta</summary>

`"${a[@]}"` da **tres** palabras, una por elemento y con `dos tres` intacto:
es la forma correcta para recorrer o pasar un array. `${a[@]}` sin comillas
da **cuatro** (`uno`, `dos`, `tres`, `cuatro`): la shell vuelve a partir los
elementos por espacios. `"${a[*]}"` da **una** palabra, `uno dos tres cuatro`,
unida por el primer carácter de `IFS`. Es la misma diferencia que `"$@"` y
`"$*"`.

</details>

8. Dado `a=(uno dos tres cuatro)`, ¿qué valen `${#a[@]}` y `${!a[@]}` tras `unset "a[1]"`, y por qué no sirve entonces `for ((i=0; i<${#a[@]}; i++))`?

<details>
<summary>Ver respuesta</summary>

`${#a[@]}` vale `3` (cuántos elementos quedan) y `${!a[@]}` da `0 2 3`: `unset`
deja un **hueco** y no renumera. El `for` aritmético recorrería los índices
`0, 1, 2`: pasaría por el hueco (vacío) y se dejaría el `3`. Los arrays
pueden ser dispersos, así que se recorren por elementos (`for x in
"${a[@]}"`) o por sus índices reales (`for i in "${!a[@]}"`).

</details>

9. ¿Qué pasa si asignas `z[foo]=1; z[bar]=2` sin `declare -A` antes, y por qué `healthcheck` usa `local -A limite`?

<details>
<summary>Ver respuesta</summary>

Sin `declare -A`, `z` es un array **indexado** y lo que va entre corchetes se
evalúa como aritmética: `foo` y `bar` son variables sin definir, valen `0`.
Las dos asignaciones caen en `z[0]`; hay un elemento con valor `2` y ningún
error. `local -A` declara el array asociativo (y local a la función) antes de
usarlo, de modo que `limite[disk]` y `limite[mem]` son claves distintas.

</details>

10. ¿Por qué `"hc_check_${nombre}"` con una lista blanca es seguro y `eval "hc_check_$nombre"` no, y para qué sirve `[[ "${BASH_SOURCE[0]}" == "$0" ]]` al final del script?

<details>
<summary>Ver respuesta</summary>

Con `"hc_check_${nombre}"` bash trata el resultado como **un nombre de comando
y nada más**: no interpreta `;`, `$( )` ni redirecciones. Aun así, el nombre
se valida contra `disk | mem | procs` antes, para llamar solo a lo previsto y
dar un buen mensaje de error. `eval` vuelve a interpretar su argumento como
código, así que `nombre='x; rm ...'` ejecutaría lo que el usuario escriba.
La guarda compara el script que se lanzó (`$0`) con el archivo donde está la
línea (`BASH_SOURCE[0]`): si coinciden, se ejecuta `main`; con `source` no,
y las funciones quedan cargadas para probarlas una a una.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — bucles y control de flujo | Reproduce `for` con espacios, `{1..$n}` literal, el comodín sin coincidencias (con `nullglob` y con `-e`), `break 2`, el reintento con tope, `while IFS= read -r`, `n=0` frente a `n=3` y el fallo de `for f in $(ls)` | 10 |
| 02 — funciones y ámbito | Reproduce `$1` de función frente a script, `helper2: command not found`, `return 300` → `44`, `local`, el ámbito dinámico, `$( )` que pierde cambios y `set -e` dentro de `if f` | 10 |
| 03 — arrays y refactor de `snapshot` | Maneja índices, `"${a[@]}"`, huecos, `mapfile`, el asociativo con y sin `declare -A`; `snap2.sh` imprime lo mismo que `snapshot` (con `diff`) y queda limpio de `shellcheck` | 10 |
| 04 — `healthcheck` a mano | Rellena los ocho `TODO` por pasos: opciones y límites con código `1`, las tres comprobaciones sueltas con `source`, `--solo` con lista blanca, el bucle por nombre, fallo forzado sin cortar y `resumen` con código `2` | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores, `snapshot` incluido (6 checks) | 5 |
| `healthcheck`: resumen sin fallos y las líneas de disco, memoria y procesos (4 checks) | 6 |
| `healthcheck --solo` respeta el orden pedido (1 check) | 3 |
| `healthcheck`: `--solo` desconocido, límite inválido y opción desconocida con código `1` (3 checks) | 3 |
| `healthcheck`: código `2`, línea de `fallo`, las demás comprobaciones siguen y el resumen cuenta el fallo (4 checks) | 5 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| Cero `# shellcheck disable` sin justificar; toda variable de las funciones con `local`, separada de la asignación cuando hay `$( )` | 2 |
| Los límites en un array **asociativo** y el orden en uno **indexado**, sin variables sueltas por comprobación | 2 |
| Despacho por nombre con lista blanca previa (sin `eval`), `return 1` explícito en cada `hc_check_*` y `if !` que cuenta el fallo | 2 |
| Límites validados con `is_uint` antes de comparar, contadores con `x=$(( x + 1 ))` y errores de uso a `stderr` | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave o token con formato real comiteado | Grave |
| `rm -rf` con una variable sin proteger (`$dir/*` sin `${dir:?}`) o sin aviso ni respaldo | Grave |
| `eval` o `bash -c "$dato"` con datos de fuera del script (también para despachar funciones) | Grave |
| Script sin shebang, o con `#!/bin/sh` y funciones de bash | Moderada |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Una `hc_check_*` que hace `exit` en lugar de `return` | Moderada |
| `((x++))` bajo `set -e` | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 14 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
