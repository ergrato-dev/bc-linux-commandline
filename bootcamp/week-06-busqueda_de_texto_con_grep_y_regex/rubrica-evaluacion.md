# Rúbrica de Evaluación — Semana 06

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
| 1 | ¿Por qué `grep -c "ERROR" archivo` puede dar un número menor que la cantidad real de veces que aparece `ERROR` en el archivo? |
| 2 | ¿Por qué `grep "10.0.0.1" config.conf` puede coincidir con una línea que no contiene esa IP exacta? |
| 3 | ¿Qué diferencia hay entre `grep "a{2,3}"` y `grep -E "a{2,3}"`, y por qué el primero no es un error de sintaxis? |
| 4 | ¿Por qué `grep -E "ha{2,3}"` y `grep -E "(ha){2,3}"` encuentran cosas distintas? |
| 5 | ¿Qué resuelve `\b` que `-w` no puede resolver? |
| 6 | ¿Qué ofrece `grep -P` que `grep -E` no tiene, más allá de las clases abreviadas `\d`, `\w`, `\s`? |
| 7 | ¿Por qué `grep -r "ERROR" directorio` sin `--include` puede dar falsos positivos que `grep -r --include="*.log"` no da? |
| 8 | ¿Qué diferencia hay entre `grep -rc` y `grep -rh | wc -l` como formas de contar coincidencias en un árbol de directorios? |
| 9 | ¿Por qué un `grep` sin coincidencias dentro de un pipeline, bajo `set -o pipefail`, puede hacer fallar un script aunque el resto del pipeline haya funcionado? |
| 10 | ¿Por qué `toolkit.sh logscan` necesita envolver su `grep` con `{ ... || true; }` antes de pasarlo a `wc -l`? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque `-c` cuenta **líneas** que contienen al menos una coincidencia,
   no el número total de ocurrencias — una línea con `ERROR` repetido dos
   veces cuenta como `1`, no como `2`. Para el total real de ocurrencias
   hace falta `grep -o "ERROR" archivo | wc -l`.

2. Porque `.` en una regex significa "cualquier carácter", no un punto
   literal — el patrón también coincide con variantes como `1030021` o
   `10x0y0z1`. Para un punto literal hace falta escaparlo: `10\.0\.0\.1`.

3. Porque en BRE (el dialecto por defecto de `grep`), `{` y `}` sin
   escapar **no son** un cuantificador: son caracteres literales. `grep
   "a{2,3}"` busca el texto exacto `a{2,3}`, llaves incluidas. Con `-E`
   (ERE), esos mismos caracteres son especiales por defecto y sí actúan
   como cuantificador.

4. Porque sin agrupar, un cuantificador repite solo el carácter
   inmediatamente anterior: `ha{2,3}` repite la `a` (2 a 3 veces),
   dejando la `h` suelta. `(ha){2,3}` agrupa el par completo, y el
   cuantificador repite ese par como unidad.

5. `\b` se puede colocar en cualquier punto de un patrón más largo, para
   anclar solo una parte de él — `-w` ancla automáticamente **todo** el
   patrón en ambos extremos. Si el límite de palabra solo aplica a una
   porción del patrón (como en `\bERROR\b.*disco`), `-w` no alcanza.

6. Principalmente, lookahead/lookbehind (`(?=...)`, `(?<=...)`) y
   cuantificadores perezosos (`.+?`, `.*?`) — ninguno de los dos existe en
   ERE estándar. Las clases abreviadas son una comodidad de escritura,
   pero no la razón de fondo para elegir `-P`.

7. Porque `-r` sin filtro revisa el contenido de **cualquier** archivo del
   árbol, sin importar su extensión — un archivo `.txt` o `.bak` que
   contenga la palabra `ERROR` por cualquier motivo ajeno a un log real
   también aparece en el resultado. `--include="*.log"` descarta esos
   archivos antes de buscar.

8. `grep -rc` reporta un conteo **por archivo**, en formato
   `archivo:N` — sumar ese total a mano requiere procesar esa salida.
   `grep -rh "$patron" "$dir" | wc -l` (ocultando el nombre de archivo
   con `-h`) da directamente el total de líneas coincidentes de todo el
   árbol en un solo número.

9. Porque `pipefail` hace que el código de salida del pipeline sea el del
   último comando que falló (de derecha a izquierda, el más a la
   derecha con código distinto de cero) — no necesariamente el del
   último comando de la cadena. Si `grep` no encuentra nada, sale con
   código `1`; aunque el comando siguiente (como `wc -l`) haya
   funcionado perfectamente, el pipeline completo reporta el `1` de
   `grep`.

10. Porque bajo `set -euo pipefail` (activo en todo `toolkit.sh`), un
    `grep` sin coincidencias haría fallar el script entero justo en el
    caso donde "no encontrar nada" es un resultado perfectamente válido
    (un árbol de logs limpio). El `|| true` dentro del grupo `{ ... ; }`
    absorbe ese código `1` antes de que el pipe hacia `wc -l` lo
    propague.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — grep básico y anclas | Distinguió `-c` de ocurrencias reales; validó formato completo con `^...$`; corrigió el antipatrón de `ps aux \| grep` | 10 |
| 02 — Regex extendida | Reprodujo el gotcha de `{n,m}` sin escape en BRE; agrupó correctamente con `(...)`; construyó el patrón de severidad | 10 |
| 03 — Límites de palabra y grep -P | Corrigió una coincidencia parcial con `-w`; extrajo datos con `grep -P` y un lookahead | 10 |
| 04 — logscan con pipes reales | Reprodujo el gotcha de `pipefail` con `grep \| wc -l` sin coincidencias, y lo corrigió | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, regresión de capas 1-5 sin romperse | 15 |
| `logscan` cuenta archivos `.log` y líneas coincidentes correctamente | 20 |
| `logscan` filtra por `--patron` y distingue archivos con/sin coincidencias | 15 |
| `logscan` usa los tres códigos de salida (0/1/2) correctamente | 10 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|---|
| Usa `grep -E` con alternancia real, no tres búsquedas separadas combinadas a mano | 10 |
| Protege cada `grep \| wc -l` del gotcha de `pipefail` sin desactivar `set -e` ni `pipefail` | 15 |
| Filtra por `.log` con `--include`, no revisa archivos de más | 10 |
| Distingue líneas coincidentes de archivos con coincidencias como dos números separados | 5 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor`/`inventory`/`organize`/`audit`/`logreport` de semanas anteriores | -30 pts (regresión) |
| Desactivar `pipefail` o `set -e` para "resolver" el gotcha del `grep \| wc -l` | -30 pts |
| Usar el mismo código de salida para "directorio inválido" y "coincidencias encontradas" | -20 pts |

## 🔗 Navegación

[← Proyecto: Capa 6 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
