# Semana 08 — awk y pipelines de datos

> Las cuatro semanas anteriores dieron herramientas de un solo
> propósito. Esta cierra la Fase 2 con `awk`: un lenguaje pequeño que
> hace lo que `cut`, `tr`, `sort`, `uniq` y a veces `sed` hacen juntos
> — más aritmética, más condicionales, más agrupación con valor
> asociado.

## 🎯 Objetivos de la Semana

- Acceder a campos (`$1`...`$N`, `$0`) y usar `NR`/`NF` como filtros
- Contar y acumular por clave con arrays asociativos (`array[clave]++`, `+=`)
- Validar datos numéricos antes de operar, entendiendo la coerción silenciosa de `awk`
- Ramificar con `if`/`else if`/`else` y recorrer campos con `for`
- Formatear salida con `printf`, y manipular texto con `sub`/`gsub`/`substr`
- Reconocer la divergencia `mawk`/`gawk` entre distros

## 📋 Prerrequisitos

Semana 07 completada: `toolkit.sh topcount` funcionando, comodidad con
el pipeline `cut | tr | sort | uniq -c | sort -rn` — esta semana lo
vuelve a usar como punto de comparación directo contra `awk`.

## 🗂️ Estructura de la Semana

```
week-08-awk_y_pipelines_de_datos/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: basico, arrays, validacion, control de flujo, strings/printf, BEGIN/END+divergencia, pipeline completo
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 8 de toolkit: subcomando sumfield
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-awk-basico-campos-nr-y-nf.md) | awk básico: campos, NR y NF | 25 min |
| [02](1-teoria/02-arrays-asociativos-y-agrupacion.md) | Arrays asociativos y agrupación | 25 min |
| [03](1-teoria/03-validacion-de-datos-con-awk.md) | Validación de datos con awk | 20 min |
| [04](1-teoria/04-control-de-flujo-if-while-for.md) | Control de flujo: if, while y for | 20 min |
| [05](1-teoria/05-funciones-de-cadena-y-printf.md) | Funciones de cadena y printf | 20 min |
| [06](1-teoria/06-begin-end-y-divergencia-mawk-gawk.md) | BEGIN, END y la divergencia mawk/gawk | 25 min |
| [07](1-teoria/07-awk-como-pipeline-completo.md) | awk como pipeline completo | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|---|
| [01](2-practicas/01-awk-basico-campos-y-filtros.md) | Campos, NF/NR, y el filtro por condición numérica que `cut` no puede hacer | 45 min |
| [02](2-practicas/02-arrays-asociativos-y-agrupacion.md) | Contar por clave, y el gotcha de crear una clave al compararla | 45 min |
| [03](2-practicas/03-validacion-y-control-de-flujo.md) | La coerción silenciosa en acción, y clasificación con if/else if/else | 45 min |
| [04](2-practicas/04-sumfield-con-awk-real.md) | Construir a mano la lógica completa que después completas en el starter | 45 min |

Y la octava capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `sumfield`, que cierra la Fase 2 del bootcamp sumando un
campo numérico agrupado por clave, algo que ninguna herramienta de las
cuatro semanas anteriores podía hacer sola.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 40 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 8 de `toolkit` | 2 h 10 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `awk 'NF'` (sin acción) imprime solo las líneas no vacías — `NF` es
  `0` en una línea vacía, que `awk` interpreta como falso.
- `awk '{ print $NF }'` imprime el último campo de cada línea, sin
  saber de antemano cuántos campos tiene.
- El operador ternario (`condicion ? si : sino`) evita un `if`/`else`
  completo para una decisión binaria simple dentro de una acción.
- `awk --version` (o `readlink -f "$(command -v awk)"` si falla)
  confirma en segundos si estás con `mawk` o `gawk`, antes de depurar
  un error de "función no definida".

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `sumfield` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`,
   `logreport`, `logscan` y `topcount` de semanas anteriores siguen
   funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 08
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 07](../week-07-procesamiento_de_texto_sed_cut_sort_uniq/README.md) | Semana 08 | [Semana 09 →](../week-09-busqueda_de_archivos_find_y_xargs/README.md) |

[← Volver al índice del bootcamp](../README.md)
