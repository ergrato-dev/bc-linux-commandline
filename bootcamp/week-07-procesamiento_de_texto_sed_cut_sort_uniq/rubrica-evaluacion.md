# Rúbrica de Evaluación — Semana 07

## 📊 Distribución de Evidencias

| Evidencia | Peso |
|---|:--:|
| 🧠 Conocimiento | 30% |
| 💪 Desempeño | 40% |
| 📦 Producto | 30% |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | ¿Por qué `sed 's/a/b/'` sin `g` solo cambia la primera coincidencia de cada línea? |
| 2 | ¿Qué diferencia hay entre una dirección de `sed` por número de línea y una por patrón, y cuándo conviene cada una? |
| 3 | ¿Por qué `cut -d: -f2` sobre una línea sin `:` imprime la línea completa en vez de vacío o un error? |
| 4 | ¿Por qué `sort` sin `-n` ordena `10` antes de `2`? |
| 5 | ¿Por qué `uniq -c` sobre datos no ordenados puede dar un conteo partido en varios grupos para el mismo valor? |
| 6 | ¿Qué hace distinto `tr -t` del comportamiento por defecto de `tr` cuando los dos sets tienen largos distintos? |
| 7 | ¿Por qué `tr -c SET repl` puede fusionar dos líneas en una sola si se combina con `-s`? |
| 8 | En el pipeline `sed | tr -s | cut | tr | sort | uniq -c | sort -rn`, ¿por qué la normalización de mayúsculas tiene que ir antes del primer `sort`? |
| 9 | ¿Qué diferencia hay entre `sort -k2,2` y `sort -k2` cuando la línea tiene más de dos columnas? |
| 10 | ¿Por qué `toolkit.sh topcount` calcula la dominancia como `top1_count * 2 > total` en vez de dividir y comparar con `0.5`? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque ese es el comportamiento por defecto de `s///` en `sed`: procesa
   cada línea buscando la primera coincidencia y se detiene ahí, salvo
   que se indique lo contrario. `g` (global, pero solo dentro de esa
   línea) cambia ese comportamiento a "todas las coincidencias".

2. Una dirección por número de línea (`5s/.../.../ `) depende de una
   posición fija, que deja de tener sentido si el archivo cambia. Una
   dirección por patrón (`/texto/s/.../.../ `) depende del contenido, no
   de dónde está — más robusta cuando no se puede garantizar que algo
   esté siempre en la misma línea.

3. Porque, técnicamente, una línea sin el delimitador tiene un solo
   campo (ella misma) — pedir el campo 2 cuando solo existe el 1 no se
   considera un error para `cut`, así que imprime lo que tiene: la línea
   completa. `-s` corrige esto omitiendo esas líneas en vez de dejarlas
   pasar.

4. Porque el orden por defecto de `sort` es lexicográfico (como
   diccionario), comparando carácter por carácter: `"1"` es menor que
   `"2"` sin mirar el resto de `"10"`. `-n` le dice a `sort` que
   interprete el texto como número antes de comparar.

5. Porque `uniq` solo compara cada línea con la **inmediatamente
   anterior** — si dos apariciones del mismo valor no son adyacentes
   (porque los datos no están ordenados), `uniq` las cuenta como dos
   grupos separados en vez de uno solo.

6. Por defecto, si `SET2` es más corto que `SET1`, `tr` repite el último
   carácter de `SET2` para completar la traducción de todo `SET1`. Con
   `-t`, en cambio, `tr` trunca `SET1` al largo de `SET2`, dejando sin
   traducir lo que sobra de `SET1`.

7. Porque `-c` invierte el set: todo lo que **no** está en él entra en
   el complemento, y el salto de línea (`\n`) casi nunca se incluye
   explícitamente en el set — así que también cae en el complemento. Con
   `-s` comprimiendo repeticiones consecutivas del complemento, una
   secuencia que incluye el `\n` junto con otros caracteres se colapsa a
   un solo carácter de reemplazo, borrando la separación entre líneas.

8. Porque el `sort` agrupa valores iguales de forma adyacente para que
   `uniq` pueda contarlos — si `ROOT` y `root` todavía son cadenas
   distintas en ese momento, `sort` los deja en posiciones separadas, y
   `uniq` los cuenta como dos valores diferentes en vez de uno repetido.

9. `-k2,2` ordena usando **solo** el campo 2 como clave. `-k2` (sin
   cerrar el rango) ordena usando "desde el campo 2 hasta el final de la
   línea" como clave — con más de dos columnas, el resultado puede ser
   distinto, porque las columnas siguientes también entran en la
   comparación.

10. Porque evita aritmética de punto flotante en bash (que no la soporta
    de forma nativa) y evita un error de redondeo en el límite exacto:
    `top1_count * 2 > total` es equivalente a `top1_count / total >
    0.5`, pero usando solo números enteros, que es lo único que bash
    puede comparar de forma directa y exacta con `(( ... ))`.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — sed, sustitución y direcciones | Acotó una sustitución a una línea por patrón; comentó una línea sin borrarla; usó `-i.bak` con respaldo real | 10 |
| 02 — cut y sort con criterio | Extrajo columnas no consecutivas; ordenó numéricamente por columna, ascendente y descendente | 10 |
| 03 — uniq y tr | Reprodujo y corrigió el conteo roto por mayúsculas; reprodujo y corrigió el gotcha de `tr -c` con saltos de línea | 10 |
| 04 — topcount con pipes reales | Construyó a mano la lógica completa que después completó en el starter | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, regresión de capas 1-6 sin romperse | 15 |
| `topcount` cuenta entradas válidas y normaliza mayúsculas correctamente | 20 |
| `topcount` respeta `--campo` y `--delim` | 15 |
| `topcount` usa los tres códigos de salida (0/1/2) correctamente | 10 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|---|
| Limpia comentarios y líneas vacías con `sed` en una sola pasada | 10 |
| Normaliza mayúsculas con `tr` antes del `sort` que alimenta a `uniq` | 15 |
| Separa conteo y valor con `read`, no con parseo manual | 10 |
| Distingue "archivo inválido" de "un valor domina" con códigos distintos | 5 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor`/`inventory`/`organize`/`audit`/`logreport`/`logscan` de semanas anteriores | -30 pts (regresión) |
| Normalizar mayúsculas después del `sort` en vez de antes | -20 pts |
| Usar el mismo código de salida para "archivo inválido" y "un valor domina" | -20 pts |

## 🔗 Navegación

[← Proyecto: Capa 7 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
