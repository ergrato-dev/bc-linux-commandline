# Control de flujo: if, while y for

> Hasta ahora, cada regla de `awk` fue "patrón, acción". Esta vez el
> control de flujo vive **dentro** de la acción — `awk` no es solo un
> filtro con esteroides, tiene las mismas estructuras de un lenguaje de
> programación completo, aunque pequeño.

## 🎯 Objetivos

- Ramificar lógica con `if`/`else if`/`else` y operadores lógicos
- Recorrer campos de una línea con `for`, usando `NF` como límite
- Saltar al resto de las líneas con `next`, y salir de un bucle con `break`/`continue`
- Elegir entre `while`, `do-while` y `for` según la forma del problema

## 1. Qué problema resuelve

Clasificar un valor en más de dos categorías ("chico/mediano/grande"),
procesar cada campo de una línea sin saber cuántos tiene, o saltear el
resto del procesamiento de una línea bajo cierta condición — ninguno de
estos casos se resuelve con un solo patrón y una acción lineal. `awk`
trae las mismas estructuras de control que cualquier lenguaje de
programación, dentro de cada acción.

## 2. Cómo funciona

### 2.1 `if` / `else if` / `else`

```bash
printf '5\n50\n500\n' | awk '{
  if ($1 < 10) print "chico"
  else if ($1 < 100) print "mediano"
  else print "grande"
}'
```

```
chico
mediano
grande
```

Idéntico en estructura a `if`/`elif`/`else` de bash — cada condición se
evalúa en orden, y la primera que resulta verdadera ejecuta su bloque,
descartando el resto.

### 2.2 Operadores lógicos: `&&`, `||`, `!`

```bash
printf '5 10\n20 30\n' | awk '{
  if ($1 > 10 && $2 > 20) print "ambos"
  else print "no"
}'
```

```
no
ambos
```

`&&` (y), `||` (o) y `!` (no) combinan condiciones, igual que en
cualquier lenguaje — útil para filtros de más de una columna que un
patrón simple no puede expresar.

### 2.3 `for` sobre un rango numérico, o sobre los campos de una línea

```bash
awk 'BEGIN { for (i = 1; i <= 3; i++) print i }'
```

```bash
printf 'a b c\n' | awk '{ for (i = 1; i <= NF; i++) print i, $i }'
```

```
1 a
2 b
3 c
```

El segundo uso es específico de procesar texto por columnas: recorrer
`$1` a `$NF` sin saber de antemano cuántos campos tiene la línea — algo
que no tiene equivalente directo en `cut`/`sed` de la semana pasada.

### 2.4 `next`: saltar al resto de las reglas para esta línea

```bash
printf '1\n2\n3\n4\n' | awk '{
  if ($1 % 2 == 0) next
  print $1, "impar"
}'
```

```
1 impar
3 impar
```

`next` interrumpe el procesamiento de la línea **actual** y pasa
directo a la siguiente línea de entrada — equivalente a "si esto no me
interesa, no sigas evaluando el resto de las reglas para esta línea en
particular". No es lo mismo que `continue` (sección 2.5): `next` opera
sobre el ciclo principal de líneas de `awk`, no sobre un `for`/`while`
interno.

### 2.5 `break` y `continue` dentro de un bucle

```bash
awk 'BEGIN {
  for (i = 1; i <= 5; i++) {
    if (i == 3) continue
    if (i == 5) break
    print i
  }
}'
```

```
1
2
4
```

`continue` salta el resto del cuerpo del bucle para esa iteración y
sigue con la próxima; `break` termina el bucle por completo. Ambos
operan sobre el `for`/`while` donde están escritos — a diferencia de
`next`, que opera sobre el ciclo de líneas de entrada.

### 2.6 `while` y `do-while`

```bash
awk 'BEGIN { i = 1; while (i <= 3) { print i; i++ } }'
```

```bash
awk 'BEGIN { i = 1; do { print i; i++ } while (i <= 3) }'
```

Ambos dan el mismo resultado para este caso — la diferencia real es que
`do-while` ejecuta el cuerpo **al menos una vez**, incluso si la
condición ya es falsa desde el principio; `while` puede no ejecutarlo
nunca.

## 3. Cómo se usa

```bash
# Clasificar lineas de un log por el valor del campo 2
awk -F: '{
  if ($2 > 1000) print "alto:", $0
  else if ($2 > 100) print "medio:", $0
  else print "bajo:", $0
}' metricas.log

# Saltar lineas de cabecera o resumen antes de procesar datos reales
awk -F, '{
  if (NR == 1) next
  total += $3
}
END { print total+0 }' reporte.csv

# Imprimir solo los campos no vacios de una linea con columnas irregulares
awk -F, '{
  for (i = 1; i <= NF; i++) {
    if ($i != "") print $i
  }
}' datos-irregulares.csv
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Confundir `next` con `continue` | `next` salta a la siguiente línea de entrada; `continue` salta a la siguiente iteración de un bucle interno — usar el equivocado no da el error esperado, da un resultado silenciosamente distinto | Usar `next` para "esta línea no me interesa más", `continue`/`break` solo dentro de un `for`/`while` |
| Encadenar muchos `if` independientes cuando se quería `if`/`else if` | Sin `else`, cada `if` se evalúa por separado — una línea puede entrar en más de una rama a la vez, no solo en la primera que matchea | Usar `else if` cuando las condiciones son mutuamente excluyentes |
| Usar `for (i=1; i<=NF; i++)` sin verificar `NF==0` primero | En una línea vacía, el bucle simplemente no itera (no es un error), pero puede ocultar que esa línea se saltó por completo sin aviso | Agregar un filtro explícito (`NF==0 { next }`) si las líneas vacías necesitan un tratamiento distinto a "ignorar en silencio" |
| Usar `do-while` por costumbre cuando la condición debería evitar la primera ejecución | `do-while` siempre ejecuta el cuerpo al menos una vez, incluso con una condición inicial falsa — puede procesar un dato que no debía tocarse | `while` cuando la condición debe poder evitar la primera ejecución |

## 5. Trucos

- `{ next }` como acción de un patrón (sin nada más) es la forma más
  directa de "descartar estas líneas, seguir con el resto" — más legible
  que invertir la condición de todo el resto del programa con `!`.
- Un `for` sin inicialización ni incremento explícitos (`for (;;) {
  ...; if (condicion) break }`) es un bucle infinito controlado — útil
  cuando la condición de salida no se ajusta naturalmente a la forma de
  un `while`.
- `BEGIN { } ` con solo validaciones (por ejemplo, confirmar que `-v` se
  pasó) corre antes de leer ninguna línea — útil para fallar rápido si
  falta una variable que el resto del programa necesita.

## Resumen

`awk` tiene las mismas estructuras de control que cualquier lenguaje:
`if`/`else if`/`else`, `&&`/`||`/`!`, `for`, `while`, `do-while`. `next`
salta al resto de las líneas de entrada; `break`/`continue` operan
dentro de un bucle. `for (i=1; i<=NF; i++)` es el patrón específico de
`awk` para recorrer los campos de una línea sin saber de antemano
cuántos tiene.

## 📚 Recursos Adicionales

- [GNU Awk User's Guide — Statements](https://www.gnu.org/software/gawk/manual/gawk.html#Statements) — referencia completa de `if`, `while`, `for`, `do-while`, `break`, `continue`, `next`.
- [GNU Awk User's Guide — The next Statement](https://www.gnu.org/software/gawk/manual/gawk.html#Next-Statement) — detalle de cuándo usar `next` frente a otras formas de control.

## ✅ Checklist de Verificación

- [ ] Ramificaste lógica con `if`/`else if`/`else` en tres o más categorías
- [ ] Combinaste dos condiciones con `&&`/`||`
- [ ] Recorriste los campos de una línea con `for (i=1; i<=NF; i++)`
- [ ] Usaste `next` para saltar líneas, y confirmaste que es distinto de `continue`
- [ ] Reprodujiste la diferencia entre `while` y `do-while` con una condición inicial falsa

---

[← 03 — Validación de datos con awk](03-validacion-de-datos-con-awk.md) · [05 — Funciones de cadena y printf →](05-funciones-de-cadena-y-printf.md)
