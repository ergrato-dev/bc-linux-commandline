# Rúbrica de Evaluación — Semana 08

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
| 1 | ¿Por qué `awk 'NF==3'` puede reemplazar a `sed '/^#/d; /^$/d'` de la semana pasada para el mismo archivo? |
| 2 | ¿Qué diferencia hay entre `array[clave]++` y usar `sort \| uniq -c` para contar por clave? |
| 3 | ¿Por qué comparar `array["clave"] == ""` puede crear una clave que nunca se asignó a propósito? |
| 4 | ¿Por qué `awk 'BEGIN{print "abc"+0}'` imprime `0` en vez de dar un error? |
| 5 | ¿Por qué `"42abc"+0` da `42` en vez de `0` o un error? |
| 6 | ¿Cuándo compara `awk` dos campos como números, y cuándo los compara como texto? |
| 7 | ¿Qué diferencia hay entre `next` y `continue` dentro de un programa de `awk`? |
| 8 | ¿Qué hace `gsub` que `sub` no hace? |
| 9 | ¿Qué es `mawk` y por qué importa saber que es el `awk` por defecto de `ubuntu-lab`? |
| 10 | ¿Por qué `toolkit.sh sumfield` reporta "valores no numericos" y "suma total" como dos números separados, en vez de un solo resultado? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque una línea de comentario (`#...`) o una línea vacía, al
   dividirse por `:`, no llega a tener 3 campos — `NF==3` las excluye
   de la misma forma que `sed` las borraba, pero como filtro en vez de
   como edición previa del archivo.

2. `array[clave]++` acumula el conteo directamente mientras se lee el
   archivo, sin necesitar que los datos estén ordenados antes — `sort
   | uniq -c` sí necesita ese orden previo para que las repeticiones
   queden adyacentes.

3. Porque en `awk`, **leer** el valor de una clave (incluso solo para
   compararlo) crea esa clave en el array si no existía, con valor
   vacío — es un efecto secundario del acceso, no de la comparación en
   sí. `"clave" in array` evita esto porque comprueba sin acceder al
   valor.

4. Porque `awk` convierte cualquier valor no numérico a `0` en una
   operación aritmética, en vez de fallar — es un comportamiento
   intencional del lenguaje, no un bug, pero significa que un dato
   corrupto no se nota solo mirando el resultado de una suma.

5. Porque `awk` no exige que **todo** el string sea numérico para la
   conversión — toma el prefijo numérico válido (`42`) y descarta el
   resto (`abc`) en silencio, sin verificar que no haya nada después.

6. Cuando **ambos** campos parecen completamente numéricos (sin ningún
   carácter no numérico), `awk` los compara como números. En cuanto
   uno de los dos tiene cualquier carácter no numérico, la comparación
   completa cae a orden de texto (lexicográfico).

7. `next` interrumpe el procesamiento de la línea actual y pasa a la
   siguiente línea de **entrada** (afecta el ciclo principal de
   `awk`); `continue` salta a la siguiente iteración de un `for`/`while`
   **interno** al programa, sin afectar qué línea de entrada se está
   procesando.

8. `sub` reemplaza solo la primera coincidencia; `gsub` reemplaza
   **todas** las coincidencias de la cadena, y además devuelve cuántas
   reemplazó (algo que `sub` no hace — siempre devuelve 0 o 1).

9. `mawk` es la implementación de `awk` que Ubuntu y Debian usan por
   defecto — rápida y conforme a POSIX, pero sin las extensiones
   propias de `gawk` (como `gensub` o `asort`). Importa porque un
   script escrito y probado con `gawk` (el default en RHEL/Fedora y
   Arch) puede fallar en `ubuntu-lab` si usa alguna de esas extensiones
   sin saberlo.

10. Porque un total que silenciosamente excluyó datos corruptos (vía la
    coerción a `0`) "parece" correcto sin serlo — reportar cuántas
    entradas fueron descartadas, junto al resultado, es la única forma
    de que quien lee el reporte sepa si puede confiar en el total tal
    como está, o si hace falta revisar los datos de origen primero.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — awk básico | Filtró por condición numérica sobre una columna; usó `NR`/`NF` correctamente | 10 |
| 02 — Arrays asociativos | Reprodujo y corrigió el gotcha de crear una clave al compararla; usó `delete` correctamente | 10 |
| 03 — Validación y control de flujo | Reprodujo la coerción silenciosa; clasificó datos en tres categorías con `if`/`else if`/`else` | 10 |
| 04 — sumfield con awk real | Construyó a mano la lógica completa que después completó en el starter | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, regresión de capas 1-7 sin romperse | 15 |
| `sumfield` cuenta no numéricos y suma por grupo correctamente | 20 |
| `sumfield` respeta `--campo`, `--delim` y `--grupo` | 15 |
| `sumfield` usa los tres códigos de salida (0/1/2) correctamente | 10 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|---|
| Valida el campo numérico con una regex anclada (`^...$`) | 15 |
| Usa un array asociativo para agrupar, no un pipeline reconstruido a mano | 10 |
| Reporta no numéricos y suma total como dos números separados | 10 |
| Ordena la tabla final con `sort`, sin depender del orden de `for...in` | 5 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor`/`inventory`/`organize`/`audit`/`logreport`/`logscan`/`topcount` de semanas anteriores | -30 pts (regresión) |
| Sumar sin validar, confiando en la coerción silenciosa como si fuera validación | -25 pts |
| Usar el mismo código de salida para "archivo inválido" y "valores no numéricos" | -20 pts |

## 🔗 Navegación

[← Proyecto: Capa 8 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
