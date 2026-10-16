# Rúbrica de Evaluación — Semana 09

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
| 1 | ¿Por qué `find . -name *.txt` (sin comillas) puede fallar con "paths must precede expression"? |
| 2 | ¿Qué diferencia hay entre `-mtime +7` y `-mtime -7`? |
| 3 | ¿Por qué `find . -type f -name "a.txt" -o -name "b.txt"` puede dar un resultado distinto al esperado sin agrupar con `\( \)`? |
| 4 | ¿Qué diferencia hay entre `-exec comando {} \;` y `-exec comando {} +`? |
| 5 | ¿Por qué `find . -type f \| xargs ls` puede romperse con un archivo llamado `informe final.pdf`? |
| 6 | ¿Qué hace `xargs` por defecto cuando su entrada está completamente vacía, y por qué eso puede ser peligroso? |
| 7 | ¿Qué resuelve `xargs -I{}` que no se puede expresar sin esa bandera? |
| 8 | ¿Por qué `xargs -P4` con cuatro tareas de distinta duración puede terminarlas en un orden distinto al que las lanzó? |
| 9 | ¿Qué significa, y qué no significa, que dos archivos tengan el mismo hash `sha256sum`? |
| 10 | ¿Por qué `toolkit.sh finddupes` cuenta archivos con `grep -c . \|\| true` en vez de `wc -l` directo? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque, sin comillas, es la **shell** la que expande `*.txt` a la
   lista de archivos que coinciden en el directorio actual, antes de
   que `find` vea nada — si hay más de un archivo `.txt` ahí, `find`
   recibe varios nombres sueltos donde esperaba un patrón único.

2. `-mtime +7` significa "modificado hace **más** de 7 días"; `-mtime
   -7` significa "modificado hace **menos** de 7 días" — son casi
   opuestos, y el signo es fácil de leer al revés si no se presta
   atención.

3. Porque la precedencia por defecto hace que `-type f` (si estuviera
   antes) solo se aplique al primer `-name`, no al resultado completo
   de la alternancia — un directorio que coincide con el segundo
   `-name` puede aparecer en el resultado aunque se pidiera `-type f`.

4. `\;` ejecuta el comando **una vez por cada resultado** (un proceso
   nuevo cada vez); `+` agrupa tantos resultados como pueda en **una
   sola** invocación — más eficiente cuando el comando acepta múltiples
   archivos como argumentos.

5. Porque, sin `-print0`/`-0`, tanto `find` como `xargs` separan
   resultados por espacios y saltos de línea — un nombre con espacio se
   divide en varios "nombres" falsos, ninguno de los cuales existe
   realmente.

6. Por defecto, `xargs` ejecuta el comando **una vez, sin argumentos**,
   aunque no haya recibido ninguna línea de entrada. Es peligroso
   porque comandos que leen de stdin cuando no reciben archivos (como
   `sha256sum`, `cat`) producen un resultado que parece válido pero es
   completamente falso.

7. `xargs -I{}` permite ubicar el argumento en **cualquier parte** del
   comando, incluso repetido más de una vez — sin `-I`, `xargs` solo
   puede agregar los argumentos al final.

8. Porque con `-P` mayor a 1, las tareas corren en simultáneo — la que
   lanzó primero no necesariamente termina primero si tarda más que
   otra lanzada después. El orden de la salida refleja cuándo terminó
   cada tarea, no cuándo se lanzó.

9. Significa que el contenido es **exactamente idéntico**, byte por
   byte. No significa que los archivos sean "parecidos" ni da ninguna
   medida de cuánto difieren dos archivos con hashes distintos —
   cualquier diferencia, aunque sea mínima, da un hash completamente
   distinto.

10. Porque `wc -l` sobre una variable vacía todavía cuenta `1` línea (la
    línea vacía que `echo`/`printf` agrega) — `grep -c .` cuenta
    correctamente `0` en ese caso. El `|| true` protege la asignación
    de que `set -e` corte el script, porque `grep -c` sale con código
    `1` cuando no encuentra ninguna línea no vacía.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — find básico y criterios | Usó `-maxdepth`, `-mtime` y `-name` correctamente; reprodujo el error de patrón sin comillas | 10 |
| 02 — find avanzado | Agrupó una alternancia con `\( \)`; confirmó la diferencia entre `-exec \;` y `-exec +`; previsualizó antes de `-delete` | 10 |
| 03 — xargs seguro y en paralelo | Reprodujo y corrigió la ruptura por nombres con espacio; midió con `time` la diferencia de `-P` | 10 |
| 04 — finddupes con pipes reales | Construyó a mano la lógica completa que después completó en el starter | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, regresión de capas 1-8 sin romperse | 15 |
| `finddupes` cuenta archivos y detecta grupos duplicados correctamente | 20 |
| `finddupes` respeta `--ext` y maneja un directorio vacío sin error | 15 |
| `finddupes` usa los tres códigos de salida (0/1/2) correctamente | 10 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|---|
| Usa `-print0`/`xargs -r0`, nunca sin protección | 15 |
| Agrupa hashes con `sort \| uniq -d`, no una estructura reconstruida a mano | 10 |
| Protege cada conteo con `grep -c . \|\| true`, no `wc -l` directo | 10 |
| Distingue "directorio inválido" de "duplicados encontrados" con códigos distintos | 5 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor`/`inventory`/`organize`/`audit`/`logreport`/`logscan`/`topcount`/`sumfield` de semanas anteriores | -30 pts (regresión) |
| Usar `find \| xargs` sin `-print0`/`-0` en algún punto del pipeline | -25 pts |
| Omitir `-r` en `xargs`, permitiendo un hash falso sobre entrada vacía | -20 pts |

## 🔗 Navegación

[← Proyecto: Capa 9 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
