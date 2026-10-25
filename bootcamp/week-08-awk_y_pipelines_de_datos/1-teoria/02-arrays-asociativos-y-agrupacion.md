# Arrays asociativos y agrupación

> `sort | uniq -c` cuenta ocurrencias, pero no puede sumar un valor
> asociado a cada clave, ni acumular por grupo mientras lee el archivo
> una sola vez. Los arrays asociativos de `awk` sí — y son, literalmente,
> cómo `toolkit.sh sumfield` suma por categoría en esta capa del proyecto.

## 🎯 Objetivos

- Usar un array asociativo de `awk` para contar o acumular por clave
- Recorrer un array con `for (clave in array)`, sabiendo que el orden no está garantizado
- Verificar si una clave existe con `in`, sin crear la clave por accidente
- Borrar una clave de un array con `delete`

## 1. Qué problema resuelve

"¿Cuánto vendió cada región?", "¿cuántos eventos generó cada usuario?" —
agrupar y acumular por una clave que no se conoce de antemano. Un array
normal (indexado por número) no sirve para esto: hace falta un array
indexado por **texto** — el nombre de la región, el usuario — y eso es
exactamente un array asociativo.

## 2. Cómo funciona

### 2.1 Contar por clave: el patrón más común

```bash
printf 'root\nadmin\nroot\nroot\n' | awk '{ conteo[$1]++ } END { for (k in conteo) print k, conteo[k] }'
```

```
root 3
admin 1
```

`conteo[$1]++` usa el valor del primer campo como **clave** del array —
cada clave nueva arranca en `0` automáticamente (no hace falta
inicializarla), y `++` la incrementa. Al final (`END`), recorrer el
array da el conteo por cada valor distinto que apareció — el mismo
resultado que `sort | uniq -c`, pero sin necesitar que la entrada esté
ordenada primero.

### 2.2 Acumular una suma, no solo contar

```bash
printf 'norte:150\nsur:200\nnorte:120\n' | awk -F: '{ suma[$1] += $2 } END { for (k in suma) print k, suma[k] }'
```

```
norte 270
sur 200
```

`suma[$1] += $2` es la misma idea que `conteo[$1]++`, pero acumulando un
valor en vez de contar apariciones — esto es exactamente lo que
`cut`/`sort`/`uniq` de la semana pasada **no podían hacer**: ninguno de
esos comandos suma un valor asociado a una clave mientras agrupa.

### 2.3 El orden de `for (k in array)` no está garantizado

```bash
awk 'BEGIN { a["norte"]=1; a["sur"]=2; a["centro"]=3; for (k in a) print k }'
```

El orden en que aparecen las claves al recorrer con `for...in` depende
de la implementación interna de `awk` (tabla hash), **no** del orden en
que se insertaron. Si el orden importa (alfabético, por valor), hay que
ordenar la salida explícitamente — por eso `sumfield` pasa la tabla por
`sort -rn` después de armarla, en vez de confiar en el orden del
`for...in`.

### 2.4 `in`: verificar existencia sin crear la clave

```bash
awk 'BEGIN {
  a["x"] = 1
  if ("y" in a) print "existe y"; else print "no existe y"
}'
# no existe y
```

`"clave" in array` comprueba si la clave existe, **sin** crearla si no
existe — distinto de acceder directamente al valor.

```bash
awk 'BEGIN {
  a["x"] = 1
  if (a["z"] == "") print "vacio"
  for (k in a) print "clave:", k
}'
```

```
vacio
clave: x
clave: z
```

Este es un gotcha real: **leer** `a["z"]` para compararlo, aunque sea
solo para ver si está vacío, **crea** la clave `"z"` en el array (con
valor vacío) como efecto secundario. Si después se recorre el array con
`for...in`, `"z"` aparece, aunque nunca se haya asignado a propósito.
`in` evita exactamente este problema, porque no accede al valor.

### 2.5 `delete`: borrar una clave

```bash
awk 'BEGIN {
  a["x"] = 1
  a["y"] = 2
  delete a["x"]
  for (k in a) print k
}'
# y
```

`delete array[clave]` quita esa entrada del array por completo — no es
lo mismo que asignarle un valor vacío (`a["x"] = ""`), que deja la clave
existente con un valor vacío, en vez de eliminarla.

### 2.6 Por qué `conteo[$1]++` funciona sin inicializar nada

```bash
awk 'BEGIN { print x + 1 }'
# 1
```

Una variable de `awk` que nunca se asignó vale `""` (string vacío), que
en contexto numérico se comporta como `0` — la misma coerción silenciosa
del archivo 03 de esta semana, pero jugando a favor esta vez. Por eso
`conteo[$1]++` funciona para una clave nueva sin ningún paso de
inicialización explícita: la primera vez que se usa esa clave, su valor
es `0`, y `++` lo lleva a `1`.

### 2.7 Contar cuántas claves distintas tiene un array

```bash
awk 'BEGIN { a["x"]=1; a["y"]=2; a["z"]=3; n=0; for (k in a) n++; print n }'
# 3
```

`length(array)` (sección 5) ya resuelve esto directamente — pero
recorrer el array incrementando un contador a mano es la forma de
llegar al mismo número sin depender de ninguna función en particular,
útil para un resumen ("se encontraron N categorías distintas") cuando
se prefiere no asumir nada sobre qué funciones están disponibles.

## 3. Cómo se usa

```bash
# Total de bytes transferidos por IP, en un log de acceso
awk '{ total[$1] += $10 } END { for (ip in total) print total[ip], ip }' acceso.log | sort -rn

# Contar cuantas veces aparece cada codigo de respuesta HTTP
awk '{ codigo[$9]++ } END { for (c in codigo) print c, codigo[c] }' acceso.log

# El mismo patron, aplicado por toolkit.sh sumfield
toolkit.sh sumfield ventas.log --campo 2 --grupo 1
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Comparar `array[clave]` directamente para "ver si existe" | Crea la clave como efecto secundario, aunque el valor comparado sea vacío | Usar `"clave" in array`, que comprueba sin crear |
| Confiar en el orden de `for (k in array)` | El orden depende de la tabla hash interna, no de la inserción — puede variar entre ejecuciones o versiones de `awk` | Ordenar explícitamente con `sort` después, si el orden de salida importa |
| Usar `delete array[clave]` cuando la intención era vaciar el valor, no quitar la clave | Si después se recorre con `for...in`, la clave borrada ya no aparece — distinto de una clave con valor vacío | Asignar `array[clave] = ""` si la clave debe seguir existiendo con valor vacío |
| Reimplementar un contador a mano con `if`/`else` en vez de `array[clave]++` | Más código, mismo resultado — los arrays asociativos ya resuelven "incrementar si existe, crear en 1 si no" automáticamente | `array[clave]++` siempre que la necesidad sea "contar por clave" |

## 5. Trucos

- `length(array)` da la cantidad de claves de un array asociativo, sin
  necesitar recorrerlo — funciona tanto en `mawk` como en `gawk`.
- `asort`/`asorti` ordenan un array por valor o por clave directamente
  dentro del programa, sin depender de un `sort` externo — pero son
  extensiones de `gawk`, ausentes en `mawk` (el `awk` por defecto de
  `ubuntu-lab`; ver la divergencia completa en el archivo 06 de esta
  semana). Confirma con `awk --version` antes de depender de ellas.
- Para depurar un array asociativo, `for (k in a) print k, "=", a[k]`
  siempre funciona, sin importar qué `awk` esté instalado.

## Resumen

Un array asociativo de `awk` (`array[clave]`) permite contar
(`array[clave]++`) o acumular (`array[clave] += valor`) agrupado por
cualquier texto, en una sola pasada por el archivo — algo que
`cut`/`sort`/`uniq` no pueden hacer solos. El orden de `for (k in
array)` no está garantizado; `in` comprueba existencia sin crear la
clave; `delete` la quita de verdad. Esto es, literalmente, el motor de
`toolkit.sh sumfield`.

## 📚 Recursos Adicionales

- [GNU Awk User's Guide — Arrays](https://www.gnu.org/software/gawk/manual/gawk.html#Arrays) — referencia completa de arrays asociativos.
- [GNU Awk User's Guide — Scanning All Elements](https://www.gnu.org/software/gawk/manual/gawk.html#Scanning-an-Array) — el comportamiento de `for...in` y por qué el orden no está garantizado.

## ✅ Checklist de Verificación

- [ ] Contaste ocurrencias por clave con `array[$1]++`
- [ ] Acumulaste una suma por clave con `array[$1] += $2`
- [ ] Reprodujiste el gotcha de crear una clave por accidente al compararla, y lo corregiste con `in`
- [ ] Borraste una clave con `delete`, distinguiéndolo de asignarle un valor vacío
- [ ] Ordenaste la salida de un `for (k in array)` con `sort`, sin confiar en su orden interno

---

[← 01 — awk básico: campos, NR y NF](01-awk-basico-campos-nr-y-nf.md) · [03 — Validación de datos con awk →](03-validacion-de-datos-con-awk.md)
