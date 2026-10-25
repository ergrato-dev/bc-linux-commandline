# Capa 8 de `toolkit`: el subcomando `sumfield`

## 🎯 Objetivo

Agregar a `toolkit.sh` un octavo subcomando, `sumfield`, que suma un
campo numérico de un archivo delimitado, agrupado por otro campo, y
detecta cuántas entradas tienen un valor no numérico donde se esperaba
un número.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan` y
`topcount` siguen intactos. `sumfield` cierra la Fase 2 del bootcamp
(Semanas 05-08, procesamiento de contenido de archivos): donde
`topcount` contaba frecuencias con `cut`/`tr`/`sort`/`uniq`, `sumfield`
hace algo que ninguna de esas herramientas puede hacer sola — sumar un
valor numérico agrupado por clave, en una sola pasada por el archivo,
con `awk`.

Esta capa reutiliza, de forma explícita, dos patrones ya vistos:

- **Tres códigos de salida con significado** (`0` datos limpios, `1`
  archivo inválido, `2` valores no numéricos encontrados) — el mismo
  patrón de `audit`, `logreport`, `logscan` y `topcount`, aplicado ahora
  a la validez numérica de una columna.
- **El array asociativo como reemplazo de `sort | uniq -c`**: en vez de
  ordenar y contar, `sumfield` acumula directamente por clave con
  `suma[$grupo] += $campo`, y solo ordena al final para mostrar el
  resultado — el mismo mecanismo que el archivo 02 de teoría de esta
  semana enseña a fondo.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan` y `topcount` siguen funcionando (regresión)
3. `sumfield` cuenta correctamente los valores no numéricos del campo
4. `sumfield` agrupa por la clave y suma el campo numérico correctamente
5. `sumfield` calcula la suma total de todos los grupos
6. `sumfield` sale con código `2` si hay valores no numéricos en el campo
7. `sumfield` sale con código `0` si todos los valores del campo son numéricos
8. `sumfield` sale con código `1` si el archivo no existe
9. `sumfield` usa `--campo`, `--delim` y `--grupo` en vez de los valores por defecto

## 🎨 Criterios de calidad

- Valida el campo numérico con una expresión regular **anclada**
  (`^...$`), no con una comparación parcial que aceptaría `"42abc"`
  como si fuera `42` limpio
- Usa un array asociativo (`suma[$grupo] += $campo`) para agrupar, no
  un `cut | sort | uniq` reconstruido a mano dentro de `awk`
- Reporta el conteo de valores no numéricos **y** la suma total como
  dos números separados, nunca mezclados en un solo resultado
- Ordena la tabla final con `sort`, sin confiar en el orden interno de
  `for (k in array)`

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `sumfield` (no evaluado esta semana) |
|---|---|
| Administras varios servidores con métricas numéricas | Agregar un modo que sume varias columnas a la vez, no solo una |
| Te importan los reportes legibles | Formatear la tabla final con `printf` y columnas alineadas, en vez de `print` simple |
| Trabajas con montos de dinero | Validar también que el valor no tenga más de dos decimales, no solo que sea numérico |
| Prefieres separar los datos descartados para revisión | Guardar las líneas no numéricas en un archivo aparte con `print > archivo`, no solo contarlas |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-08-awk_y_pipelines_de_datos/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO de cmd_sumfield
./scripts/verificar-semana.sh 08
```

## 🧯 Errores comunes

- Validar el campo con una regex sin anclar (`[0-9]+` en vez de
  `^-?[0-9]+([.][0-9]+)?$`), dejando pasar valores como `"42abc"` como
  si fueran completamente numéricos.
- Sumar el campo sin validar primero, confiando en la coerción
  silenciosa de `awk` (que convierte cualquier texto no numérico en
  `0`) como si fuera una validación real.
- Confiar en el orden de `for (k in suma)` al imprimir la tabla, sin
  pasarla por `sort` — el orden de un array asociativo no está
  garantizado.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-sumfield-con-awk-real.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
