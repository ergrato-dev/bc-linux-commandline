# Arrays asociativos

> Un array asociativo guarda pares **clave → valor**: la clave es un texto, no
> una posición. Es la forma de bash de decir "el límite de `disk` es 90 y el de
> `mem` es 128" sin escribir una cadena de `if`.

## 🎯 Objetivos

- Declarar un array asociativo con `declare -A` y entender por qué es obligatorio
- Leer, asignar, comprobar la existencia y borrar claves
- Recorrer claves y valores, sabiendo que **el orden no está garantizado**
- Usar claves con espacios y pasar un array asociativo a una función
- Elegir entre array indexado, asociativo y un `case`

## 1. Qué problema resuelve

Cada comprobación de `healthcheck` tiene su límite (`disk` 90, `mem` 128,
`procs` 500) y `--umbral-disco 80` cambia uno. Con variables sueltas
(`limite_disk`, `limite_mem`...) hay que escribir un `case` para elegir la
variable según el nombre. Con un array asociativo, `"${limite[$nombre]}"`
**es** esa elección: la clave se calcula en tiempo de ejecución.

## 2. Cómo funciona

### 2.1 Declarar y usar

```bash
declare -A d=([disk]=90 [mem]=128)
d[procs]=500
echo "${d[disk]} ${#d[@]}"
# 90 3
echo "${d[nada]-sin}"
# sin
```

| Expresión | Significa |
|---|---|
| `declare -A d` | Crea un array asociativo (**sin esto, no lo es**) |
| `d[clave]=valor` | Asigna |
| `${d[clave]}` | Lee (vacío si no existe) |
| `${d[clave]-x}` | Lee, con `x` si la clave no existe |
| `${#d[@]}` | Cuántas claves hay |
| `${!d[@]}` | Las **claves** |
| `${d[@]}` | Los **valores** |
| `unset "d[clave]"` | Borra una clave |

Dentro de una función, `local -A d=(...)` lo hace local (es lo que usa
`cmd_healthcheck`).

### 2.2 Sin `declare -A` no es asociativo

```bash
bash -c 'z[foo]=1; z[bar]=2; echo ${#z[@]} ${z[0]}'
# 1 2
```

Sin `declare -A`, `z` es un array **indexado** y `foo` y `bar` se evalúan
como **aritmética** (variables sin definir, valen `0`): las dos asignaciones
escribieron en `z[0]`. Es un error silencioso. **Siempre `declare -A`
antes.**

### 2.3 Existencia de una clave

```bash
declare -A d=([disk]=90 [mem]=128)
[[ -v d[mem] ]] && echo tiene-mem
# tiene-mem
[[ -v d[x] ]] || echo no-x
# no-x
unset "d[mem]"
echo "${#d[@]}"
# 1
```

`[[ -v d[clave] ]]` pregunta si la clave **existe** (aunque su valor esté
vacío). Para "existe y no está vacía": `[[ -n "${d[clave]:-}" ]]`.

### 2.4 Recorrer y el orden

```bash
for k in "${!d[@]}"; do echo "$k=${d[$k]}"; done | sort
# disk=90
# procs=500
```

```bash
declare -A o; for k in z y x a b c; do o[$k]=1; done; echo "${!o[@]}"
# z y x c b a
```

El orden de `"${!d[@]}"` **no es el de inserción ni el alfabético**: lo
decide la tabla hash interna. Si el orden importa (un informe, el orden de
las comprobaciones), **recorre un array indexado de claves** y consulta el
asociativo con cada una:

```bash
local -a orden=(disk mem procs)
for nombre in "${orden[@]}"; do
  echo "$nombre=${limite[$nombre]}"
done
```

Por eso el toolkit tiene `orden` **y** `limite`: uno da el orden, el otro
los datos. O se ordena al vuelo: `printf '%s\n' "${!d[@]}" | sort`.

### 2.5 Claves con espacios, y pasar el array a una función

```bash
declare -A sp; sp["a b"]=1
for k in "${!sp[@]}"; do echo "<$k>"; done
# <a b>
declare -A lim=([disk]=90)
lm() { local -n t=$1; echo "${t[disk]}"; }
lm lim
# 90
```

Una clave puede tener espacios (con comillas al usarla). Para pasar un
array asociativo a una función hay que usar un **nameref**: `local -n t=$1`
hace que `t` sea un alias del array cuyo **nombre** llega en `$1`. No se
puede pasar con `"${d[@]}"` (se perderían las claves).

### 2.6 Ver y depurar

```bash
declare -p d
# declare -A d=([procs]="500" [disk]="90" )
```

`declare -p` muestra el tipo (`-A` asociativo, `-a` indexado) y el
contenido. **La salida no está ordenada**, como `${!d[@]}`.

## 3. Cómo se usa

El corazón del `healthcheck`: la clave es el nombre de la comprobación, y
la misma clave **elige la función** y **elige el límite**:

```bash
local -A limite=([disk]=90 [mem]=128 [procs]=500)
...
limite[disk]="$2"                       # --umbral-disco
...
"hc_check_${nombre}" "${limite[$nombre]}"
```

Sin asociativos serían tres variables y un `case` por cada sitio donde se
necesite el límite.

### ¿Indexado, asociativo o `case`?

| Necesitas | Usa |
|---|---|
| Una lista ordenada de valores | Array indexado |
| Buscar un valor por un nombre | **Asociativo** |
| Mapear **pocos** nombres a acciones, una sola vez | `case` (más legible) |
| Contar ocurrencias (`conteo[$palabra]++`) | Asociativo con aritmética: `conteo[$p]=$(( ${conteo[$p]:-0} + 1 ))` |

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Asignar `d[clave]=v` sin `declare -A` | Se vuelve un array indexado y las claves valen `0` | `declare -A d` primero |
| Confiar en el orden de `${!d[@]}` | Es arbitrario | Un array indexado de claves, o `sort` |
| `${d[@]}` esperando clave y valor | Solo da los valores | `for k in "${!d[@]}"; do ...${d[$k]}` |
| `((conteo[$p]++))` con `set -e` | Sale con `1` la primera vez (vale `0`) y aborta | `conteo[$p]=$(( ${conteo[$p]:-0} + 1 ))` |
| Pasar `"${d[@]}"` a una función | Se pierden las claves | *nameref* (`local -n`) |
| Claves sin comillas con caracteres especiales | `d[a b]` o `d[$x]` mal expandido | `d["$clave"]` |
| Usar asociativos para el estado de todo el script | Difíciles de seguir | Variables con nombre claro, y asociativos solo para tablas |

## 5. Trucos

- **`${!d[@]}` ordenadas**: `printf '%s\n' "${!d[@]}" | sort` da un orden
  estable para un informe.
- **Contador de frecuencias** (el `sort | uniq -c` en bash puro):

  ```bash
  declare -A veces
  for p in a b a c a; do veces[$p]=$(( ${veces[$p]:-0} + 1 )); done
  for p in "${!veces[@]}"; do echo "$p ${veces[$p]}"; done | sort
  # a 3
  # b 1
  # c 1
  ```

  Útil dentro de un script; para un archivo grande, `sort | uniq -c` o `awk`
  (Semanas 07 y 08) son más rápidos.
- **`[[ -v d[clave] ]]` frente a `-n`**: `-v` distingue "no existe" de
  "existe y está vacío", que `-n` mezcla.
- Los asociativos existen desde **bash 4**; en los cuatro contenedores del
  laboratorio hay 5.1 a 5.3.

## 📚 Recursos Adicionales

- `man bash`, sección *Arrays* (el apartado de arrays asociativos)
- `help declare`: la lista de opciones (`-A`, `-a`, `-n`, `-p`)

## ✅ Checklist de Verificación

- [ ] `declare -A d=([disk]=90 [mem]=128)` y `echo "${d[disk]} ${#d[@]}"` imprime `90 2`
- [ ] Reproduces el `1 2` de la asignación **sin** `declare -A` y explicas por qué
- [ ] `[[ -v d[mem] ]]` es verdadero y `[[ -v d[x] ]]` falso
- [ ] Recorres un asociativo en el orden que **tú** decides, con un array de claves
- [ ] Cuentas frecuencias con `veces[$p]=$(( ${veces[$p]:-0} + 1 ))`

---

[← Arrays indexados](04-arrays-indexados.md) · [Despacho dinámico y estructura de un script →](06-despacho-dinamico-y-estructura-de-un-script.md)
