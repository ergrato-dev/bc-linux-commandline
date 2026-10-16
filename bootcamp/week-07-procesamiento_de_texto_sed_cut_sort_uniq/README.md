# Semana 07 — Procesamiento de texto: sed, cut, sort, uniq, tr

> `grep` encuentra; esta semana transforma. Cinco herramientas de un solo
> propósito cada una — sustituir, recortar, ordenar, deduplicar,
> traducir — que combinadas resuelven en un pipeline lo que ninguna
> resuelve sola: un ranking real de los valores más frecuentes de una
> columna.

## 🎯 Objetivos de la Semana

- Sustituir y borrar texto con `sed`, con direcciones por línea, rango y patrón
- Editar archivos in-place con `sed -i`, con respaldo
- Extraer columnas con `cut`, por delimitador o por posición de carácter
- Ordenar con criterio (`sort -n`, `-r`, `-k`, `-u`) y deduplicar líneas adyacentes con `uniq`
- Traducir, borrar y comprimir caracteres con `tr`, entendiendo el gotcha de `-c` con saltos de línea
- Combinar las cinco en un pipeline de ranking de frecuencia

## 📋 Prerrequisitos

Semana 06 completada: `toolkit.sh logscan` funcionando, comodidad con
`grep -E`, clases POSIX, y el gotcha de `pipefail` con pipelines que
pueden devolver código distinto de cero sobre una entrada vacía.

## 🗂️ Estructura de la Semana

```
week-07-procesamiento_de_texto_sed_cut_sort_uniq/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: sed x2, cut, sort, uniq, tr, pipeline combinado
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 7 de toolkit: subcomando topcount
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-sed-anatomia-de-la-sustitucion.md) | sed: anatomía de la sustitución | 20 min |
| [02](1-teoria/02-sed-direcciones-multiples-comandos-y-edicion-in-place.md) | sed: direcciones, múltiples comandos y edición in-place | 25 min |
| [03](1-teoria/03-cut-extraer-campos-y-caracteres.md) | cut: extraer campos y caracteres | 20 min |
| [04](1-teoria/04-sort-ordenar-con-criterio.md) | sort: ordenar con criterio | 20 min |
| [05](1-teoria/05-uniq-duplicados-adyacentes.md) | uniq: duplicados adyacentes | 20 min |
| [06](1-teoria/06-tr-traducir-borrar-y-comprimir-caracteres.md) | tr: traducir, borrar y comprimir caracteres | 20 min |
| [07](1-teoria/07-combinando-el-pipeline-cut-tr-sort-uniq.md) | Combinando el pipeline: cut, tr, sort y uniq | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|---|
| [01](2-practicas/01-sed-sustitucion-y-direcciones.md) | Sustituciones acotadas por patrón, comentar líneas, edición in-place con respaldo | 45 min |
| [02](2-practicas/02-cut-y-sort-con-criterio.md) | Extraer columnas de un CSV, ordenar numérico y por frecuencia | 45 min |
| [03](2-practicas/03-uniq-y-tr.md) | Reproducir y corregir un conteo roto por mayúsculas, y el gotcha de `tr -c` | 45 min |
| [04](2-practicas/04-topcount-con-pipes-reales.md) | Construir a mano la lógica completa que después completas en el starter | 45 min |

Y la séptima capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `topcount`, que cierra el bloque de procesamiento de
texto (Semanas 05-08) combinando las cinco herramientas de esta semana
en un solo pipeline.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 30 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 7 de `toolkit` | 2 h 20 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `sed -n '$p'` imprime solo la última línea de un archivo, sin necesitar
  `tail`.
- `cut -d: -f2-` (rango abierto) extrae desde una columna hasta el final
  de la línea, sin saber cuántas columnas tiene en total.
- `sort -R` da un orden aleatorio — útil para elegir una muestra al azar
  de un archivo combinado con `head`.
- `tr -d '[:punct:]'` quita toda la puntuación de un texto de una sola
  vez, sin enumerar cada símbolo.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `topcount` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`,
   `logreport` y `logscan` de semanas anteriores siguen funcionando sin
   regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 07
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 06](../week-06-busqueda_de_texto_con_grep_y_regex/README.md) | Semana 07 | [Semana 08 →](../week-08-awk_y_pipelines_de_datos/README.md) |

[← Volver al índice del bootcamp](../README.md)
