# Validación de datos con awk

> `awk` nunca se queja de un valor no numérico donde esperaba un
> número — lo convierte en `0` en silencio y sigue. Eso es exactamente
> lo que hace que validar los datos **antes** de confiar en una suma sea
> parte del trabajo, no un paso opcional.

## 🎯 Objetivos

- Explicar por qué un valor no numérico en una operación aritmética de `awk` no produce ningún error
- Validar que un campo cumple un formato numérico con una expresión regular
- Distinguir cuándo `awk` compara dos campos como números y cuándo como texto
- Construir un reporte que separe "datos procesados" de "datos descartados por inválidos"

## 1. Qué problema resuelve

Sumar una columna de un archivo con datos reales casi nunca es tan
limpio como el ejemplo de clase: un valor vacío, un texto donde se
esperaba un número, un error de tipeo. `awk`, por diseño, no falla ante
esto — sigue corriendo, con un resultado que **parece** válido pero no
lo es, salvo que se valide explícitamente.

## 2. Cómo funciona

### 2.1 La coerción silenciosa: texto no numérico se vuelve `0`

```bash
awk 'BEGIN { x = "abc"; print x + 0 }'
# 0
```

Cualquier operación aritmética sobre un valor no numérico lo trata como
`0`, sin ningún error ni advertencia. Esto significa que sumar una
columna con un valor corrupto (`"abc"` en vez de un número) no rompe el
script — simplemente suma `0` ahí, dando un total que **parece**
correcto pero excluye silenciosamente ese dato.

### 2.2 Parsing parcial: el prefijo numérico cuenta, el resto se ignora

```bash
awk 'BEGIN { x = "42abc"; print x + 0 }'
# 42

awk 'BEGIN { x = "  42"; print x + 0 }'
# 42
```

`awk` no exige que **todo** el string sea numérico — toma el prefijo
numérico válido (ignorando espacios iniciales) y descarta el resto. Esto
es todavía más engañoso que el caso anterior: `"42abc"` contribuye `42`
a una suma, como si fuera un dato limpio, cuando en realidad tiene
basura al final que debería haber sido motivo de rechazo.

### 2.3 Validar con una expresión regular antes de operar

```bash
printf '150\nabc\n42xyz\n-30\n3.5\n' | awk '$0 ~ /^-?[0-9]+([.][0-9]+)?$/ { print "valido:", $0 }'
```

```
valido: 150
valido: -30
valido: 3.5
```

`~` compara contra una expresión regular (el mismo motor ERE que `grep
-E`); anclar con `^...$` exige que la línea (o el campo) **completo**
cumpla el formato numérico, no solo un prefijo — así `"42xyz"` queda
afuera, a diferencia de la coerción silenciosa de la sección 2.2.

```bash
printf '150\nabc\n42xyz\n-30\n3.5\n' | awk '$0 !~ /^-?[0-9]+([.][0-9]+)?$/ { print "invalido:", $0 }'
```

```
invalido: abc
invalido: 42xyz
```

`!~` es la negación — el mismo patrón, invertido, separa lo que **no**
cumple el formato. `toolkit.sh sumfield` usa exactamente este patrón
para contar `valores no numericos` por separado del total.

### 2.4 Comparación numérica vs. comparación de texto

```bash
printf '10 9\n' | awk '{ if ($1 > $2) print "numerico: 10>9 verdadero" }'
# numerico: 10>9 verdadero

printf '10x 9\n' | awk '{ if ($1 > $2) print "texto: verdadero"; else print "texto: falso" }'
# texto: falso
```

Cuando ambos campos **parecen** completamente numéricos, `awk` los
compara como números (`10 > 9` es verdadero). En cuanto uno de los dos
tiene cualquier carácter no numérico (`"10x"`), la comparación cae a
texto — y como cadena, `"10x"` es menor que `"9"` (compara carácter por
carácter: `'1' < '9'`), dando el resultado contrario al que la mayoría
esperaría a simple vista.

### 2.5 Distinguir "vacío" de "inválido" de "válido", los tres por separado

```bash
awk -F: '
  $2 == "" { vacios++; next }
  $2 !~ /^-?[0-9]+(\.[0-9]+)?$/ { invalidos++; next }
  { validos++; suma += $2 }
  END {
    print "validos:", validos+0
    print "vacios:", vacios+0
    print "invalidos:", invalidos+0
    print "suma:", suma+0
  }
' mixto.log
```

```
validos: 2
vacios: 1
invalidos: 1
suma: 240
```

Un campo vacío y un campo con texto basura son dos problemas distintos,
y vale la pena contarlos por separado: un campo vacío suele significar
"no se registró ese dato", mientras que un campo con texto donde se
esperaba un número suele significar "algo se escribió mal". `next` en
cada regla de validación evita que una línea que ya se clasificó como
vacía o inválida también sume al total.

## 3. Cómo se usa

```bash
# Separar lineas validas de invalidas en un reporte
awk '{
  if ($2 ~ /^-?[0-9]+([.][0-9]+)?$/) print > "validos.txt"
  else print > "invalidos.txt"
}' datos.csv

# Sumar solo los valores que pasan la validacion, ignorando el resto
awk -F: '$2 ~ /^-?[0-9]+$/ { suma += $2 } END { print suma+0 }' ventas.log

# Contar cuantas lineas tienen el campo 3 vacio (otro tipo de dato invalido)
awk -F, '$3 == "" { contador++ } END { print contador+0 }' datos.csv
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Sumar una columna sin validar primero que sea numérica | Un valor corrupto se convierte en `0` en silencio — el total "funciona" pero está mal, sin ningún error que lo señale | Validar con `~ /^-?[0-9]+([.][0-9]+)?$/` y reportar cuántas líneas fallaron, por separado del total |
| Asumir que `"42abc"` es "casi válido" porque empieza con un número | `awk` lo trata como `42` completo al sumarlo — el error queda invisible, no solo el valor es menos preciso | Anclar la validación con `^...$`, exigiendo que **toda** la cadena sea numérica, no solo el inicio |
| Comparar dos campos esperando orden numérico sin confirmar que ambos sean números | Si alguno tiene texto, la comparación cae a orden de texto, con resultados contraintuitivos (`"10x" < "9"`) | Validar ambos campos como numéricos antes de comparar, o forzar la comparación numérica explícita con `+0` en ambos lados |
| Reportar solo el total, sin mencionar cuántos datos se descartaron | Un total "limpio" pero basado en datos parcialmente ignorados es más peligroso que un error visible — nadie sabe que falta revisar algo | Reportar siempre los dos números juntos: el resultado y cuántas entradas no se pudieron procesar |

## 5. Trucos

- El operador ternario (`condicion ? valor_si : valor_sino`) es útil
  para una validación de una sola línea: `awk '{ print ($0 ~
  /^[0-9]+\.[0-9]+\.[0-9]+$/) ? "version valida" : "no es version" }'`
  evita un `if`/`else` completo para una decisión binaria simple.
- `$0 == $0+0` es una forma rápida de preguntar "¿esta línea completa es
  puramente numérica?" — si la línea tiene cualquier carácter no
  numérico, la coerción cambia el valor y la comparación falla.
- Separar los datos válidos de los inválidos en dos archivos distintos
  (`print > "validos.txt"`) permite revisar después exactamente qué se
  descartó, en vez de perder esa información en un conteo agregado.
- `awk -v OFMT='%.2f' '{ print $1+0 }'` controla cuántos decimales
  imprime `awk` al convertir un número a texto — útil para reportes con
  montos de dinero, donde una suma con más decimales de los esperados
  se ve como un error de cálculo (aunque sea solo de formato).

## Resumen

`awk` convierte cualquier valor no numérico a `0` en una operación
aritmética, sin error — y toma solo el prefijo numérico de un string
mixto (`"42abc"` → `42`), descartando el resto en silencio. Validar con
una expresión regular anclada (`~ /^-?[0-9]+([.][0-9]+)?$/`) antes de
sumar es la única forma de distinguir un dato limpio de uno corrupto. La
comparación entre dos campos es numérica solo si ambos parecen
completamente numéricos; en cuanto uno no lo es, cae a comparación de
texto.

## 📚 Recursos Adicionales

- [GNU Awk User's Guide — Comparison Operators](https://www.gnu.org/software/gawk/manual/gawk.html#Comparison-Operators) — cuándo una comparación es numérica y cuándo de texto.
- [GNU Awk User's Guide — String Functions](https://www.gnu.org/software/gawk/manual/gawk.html#String-Functions) — conversión de tipos y sus reglas exactas.

## ✅ Checklist de Verificación

- [ ] Reprodujiste la coerción silenciosa de un valor no numérico a `0`
- [ ] Reprodujiste cómo `"42abc"` aporta `42` a una suma, sin ningún error
- [ ] Validaste un campo numérico con una expresión regular anclada (`^...$`)
- [ ] Separaste datos válidos de inválidos en dos conteos distintos, no uno solo
- [ ] Reprodujiste por qué `"10x" > "9"` da falso, comparando como texto en vez de número
- [ ] Clasificaste entradas en válidas, vacías e inválidas como tres conteos separados

---

[← 02 — Arrays asociativos y agrupación](02-arrays-asociativos-y-agrupacion.md) · [04 — Control de flujo: if, while y for →](04-control-de-flujo-if-while-for.md)
