# Funciones de cadena y printf

> `print` muestra lo que hay. `printf` controla **cómo** se muestra —
> ancho de columna, decimales, ceros a la izquierda — el mismo `printf`
> de C, dentro de `awk`. Esta es la diferencia entre un resultado
> correcto y un reporte que de verdad se puede leer en una terminal.

## 🎯 Objetivos

- Formatear salida con `printf`: ancho, alineación y decimales
- Buscar, reemplazar y extraer substrings con `index`, `sub`, `gsub` y `substr`
- Concatenar strings y convertir entre texto y número implícitamente
- Elegir `sub` o `gsub` según si hace falta reemplazar una coincidencia o todas

## 1. Qué problema resuelve

`print $1, $2` separa los valores con un espacio, sin control sobre el
ancho de cada columna — si los valores tienen largos distintos, el
resultado no queda alineado. Un reporte real necesita columnas de ancho
fijo, montos con una cantidad exacta de decimales, números con ceros a
la izquierda — y para eso, `awk` trae `printf`, el mismo formato de C
usado en decenas de lenguajes.

## 2. Cómo funciona

### 2.1 Por qué `print` no alcanza para un reporte alineado

```bash
printf 'root %s\nadministrador %s\n' 150 42 | awk '{ print $1, $2 }'
```

```
root 150
administrador 42
```

`print` separa los valores con un solo espacio, sin importar el largo
de cada uno — con nombres de distinto largo, las columnas no quedan
alineadas visualmente. `printf` (sección 2.2) resuelve exactamente esto.

### 2.2 `printf`: control total del formato

```bash
awk 'BEGIN { printf "%-10s | %8.2f | %05d\n", "total", 42.5, 7 }'
```

```
total      |    42.50 | 00007
```

| Especificador | Significa |
|---|---|
| `%s` | string |
| `%d` | entero |
| `%f` | número con decimales |
| `%-10s` | string, ancho 10, alineado a la **izquierda** (`-`) |
| `%8.2f` | número con decimales, ancho 8, exactamente 2 decimales |
| `%05d` | entero, ancho 5, rellenado con **ceros** |

A diferencia de `print`, `printf` **no** agrega un salto de línea
automático — hay que incluir `\n` explícitamente donde corresponda.

### 2.3 `sub`: reemplazar la primera coincidencia

```bash
awk 'BEGIN { s = "a.b.c"; sub(/\./, "-", s); print s }'
# a-b.c
```

`sub(patrón, reemplazo, variable)` modifica la variable directamente
(no devuelve el string modificado, lo cambia en el lugar) y reemplaza
solo la **primera** coincidencia — el mismo comportamiento por defecto
de `sed 's///'` sin `g`, visto la semana pasada.

### 2.4 `gsub`: reemplazar todas las coincidencias

```bash
awk 'BEGIN { s = "a.b.c"; n = gsub(/\./, "-", s); print n, s }'
# 2 a-b-c
```

`gsub` es el equivalente de `sed 's///g'` — reemplaza **todas** las
coincidencias, y además **devuelve cuántas** reemplazó, que `sub` no
hace (siempre devuelve 0 o 1, según haya encontrado algo o no).

### 2.5 `index`: posición de un substring

```bash
awk 'BEGIN { print index("hola mundo", "mundo") }'
# 6
```

Devuelve la posición (contando desde 1) donde empieza el substring
buscado, o `0` si no aparece — útil para una comprobación simple de
"¿contiene esto?" sin necesitar una expresión regular completa.

### 2.6 `substr`: extraer una porción de un string

```bash
awk 'BEGIN { s = "Hola Mundo"; print substr(s, 1, 4) }'
# Hola

awk 'BEGIN { s = "Hola Mundo"; print substr(s, 6) }'
# Mundo
```

`substr(string, inicio, largo)` extrae `largo` caracteres desde
`inicio` (contando desde 1); sin el tercer argumento, extrae hasta el
final del string — el equivalente de `cut -c` de la semana pasada, pero
operando sobre una variable de `awk` en vez de una línea completa de
entrada.

### 2.7 Concatenación: sin operador, solo espacio en blanco

```bash
awk 'BEGIN { a = "ho"; b = "la"; print a b }'
# hola
```

A diferencia de bash (`"$a$b"`) o de otros lenguajes (`a + b`), `awk`
concatena strings simplemente poniéndolos uno junto al otro, sin ningún
operador — el espacio entre `a` y `b` en el código no aparece en el
resultado, es solo separación de la sintaxis.

### 2.8 `match`: encontrar dónde coincide una regex, no solo si coincide

```bash
awk 'BEGIN {
  s = "precio: 150 USD"
  if (match(s, /[0-9]+/)) print substr(s, RSTART, RLENGTH)
}'
# 150
```

`match(string, regex)` busca la primera coincidencia y, si la
encuentra, fija dos variables globales: `RSTART` (posición donde
empieza) y `RLENGTH` (largo de la coincidencia) — combinado con
`substr`, extrae exactamente el fragmento que coincidió, sin necesitar
un grupo de captura (que `awk`, a diferencia de `sed`, no tiene en su
forma POSIX estándar).

## 3. Cómo se usa

```bash
# Reporte alineado de ventas por region
awk -F: '{ printf "%-10s %8.2f\n", $1, $2 }' ventas.log

# Quitar todas las comas de miles antes de sumar (gsub como limpieza)
awk -F, '{ gsub(/,/, "", $2); total += $2 } END { print total+0 }' montos.csv

# Extraer el dominio de una direccion de correo con substr + index
awk -F@ '{ print $2 }' correos.txt

# Formatear un porcentaje con dos decimales
awk '{ printf "%.2f%%\n", ($1/$2)*100 }' proporciones.txt
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `sub` cuando la intención era reemplazar todas las coincidencias | Solo cambia la primera — el resto queda igual, sin ningún aviso | `gsub` cuando la intención es "todas", igual que `sed` con `g` |
| Olvidar el `\n` en `printf` | La salida de la siguiente línea se pega a la anterior, sin separación | Incluir `\n` explícitamente al final de cada `printf`, a diferencia de `print` |
| Usar `print $1, $2` para un reporte que necesita columnas alineadas | El espacio entre campos es fijo (un solo espacio), no se ajusta al ancho de cada valor | `printf` con anchos explícitos (`%-10s`, `%8.2f`) cuando la alineación visual importa |
| Concatenar un número y un string esperando un espacio automático | `awk` concatena sin separador — `a b` (con espacio en el código) y `a""b` dan resultados distintos a lo esperado si no se agrega el separador a mano | Agregar el separador explícitamente dentro de la concatenación: `a " " b` |

## 5. Trucos

- `toupper(substr(s,1,1)) substr(s,2)` pone en mayúscula solo la
  primera letra de un string, combinando `toupper`, `substr` y
  concatenación — no existe una función directa de "capitalizar" en
  `awk` estándar, pero se construye con las piezas ya vistas.
- `sprintf` es la versión de `printf` que **devuelve** el string
  formateado en vez de imprimirlo — útil para construir una variable con
  formato antes de usarla en otra parte del programa.
- `gsub(/,/, "", variable)` es la forma más directa de quitar
  separadores de miles (`"1,000"` → `"1000"`) antes de sumar una
  columna con comas.
- `length(string)` (sin argumento, sobre `$0`) da el largo de la línea
  actual — útil para filtrar líneas sospechosamente cortas o largas sin
  necesitar contar caracteres a mano.

## Resumen

`printf` controla el formato exacto de la salida (ancho, alineación,
decimales, ceros) con la misma sintaxis que `printf` de C; `print` no
tiene ese control. `sub` reemplaza la primera coincidencia y modifica la
variable en el lugar; `gsub` reemplaza todas y devuelve cuántas.
`substr`/`index`/`match` extraen y ubican substrings. La concatenación
no usa ningún operador — simplemente poner dos valores juntos.

## 📚 Recursos Adicionales

- [GNU Awk User's Guide — Printf](https://www.gnu.org/software/gawk/manual/gawk.html#Printf) — referencia completa de especificadores de formato.
- [GNU Awk User's Guide — String Functions](https://www.gnu.org/software/gawk/manual/gawk.html#String-Functions) — `sub`, `gsub`, `substr`, `index`, `sprintf`, `match` y el resto.
- `man 3 printf` — la referencia de C en la que se basa el formato de `printf` de `awk`, útil para especificadores menos comunes.

## ✅ Checklist de Verificación

- [ ] Formateaste una salida con `printf`, controlando ancho y decimales
- [ ] Reemplazaste texto con `sub` (primera coincidencia) y `gsub` (todas), y confirmaste la diferencia
- [ ] Extrajiste una porción de un string con `substr`
- [ ] Concatenaste dos valores sin ningún operador explícito
- [ ] Construiste un reporte con columnas alineadas usando anchos de `printf`
- [ ] Ubicaste una coincidencia con `match` y extrajiste ese fragmento con `RSTART`/`RLENGTH`
- [ ] Capitalizaste la primera letra de un string combinando `toupper`, `substr` y concatenación

---

[← 04 — Control de flujo: if, while y for](04-control-de-flujo-if-while-for.md) · [06 — BEGIN, END y la divergencia mawk/gawk →](06-begin-end-y-divergencia-mawk-gawk.md)
