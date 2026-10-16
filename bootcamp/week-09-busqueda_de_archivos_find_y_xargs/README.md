# Semana 09 — Búsqueda de archivos y ejecución en lote

> Abre la Fase 3 del bootcamp: de procesar el **contenido** de archivos
> conocidos, a recorrer árboles completos sin saber de antemano qué hay
> ni dónde — y actuar sobre lo que se encuentra, en lote, sin romperse
> ante un nombre de archivo con un espacio.

## 🎯 Objetivos de la Semana

- Buscar archivos por nombre, tipo, profundidad, antigüedad y tamaño con `find`
- Combinar criterios con `-a`/`-o`/`-not`, agrupando con `\( \)`
- Actuar sobre resultados con `-exec`/`-delete`, entendiendo `\;` vs `+`
- Convertir resultados de `find` en argumentos de otro comando con `xargs`
- Proteger cualquier pipeline `find | xargs` con `-print0`/`-0` y `-r`
- Acelerar lotes independientes con `xargs -P`

## 📋 Prerrequisitos

Semana 08 completada: `toolkit.sh sumfield` funcionando, comodidad con
`awk`/`sort`/`uniq -d` — esta semana los reutiliza para agrupar hashes
de archivos en vez de valores de columna.

## 🗂️ Estructura de la Semana

```
week-09-busqueda_de_archivos_find_y_xargs/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: find basico, tiempo/tamano, logica/acciones, xargs basico, xargs seguro, xargs paralelo, capstone
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 9 de toolkit: subcomando finddupes
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-find-basico-criterios-de-busqueda.md) | find básico: criterios de búsqueda | 20 min |
| [02](1-teoria/02-find-por-tiempo-y-tamano.md) | find por tiempo y tamaño | 20 min |
| [03](1-teoria/03-find-logica-combinada-y-acciones.md) | find con lógica combinada y acciones directas | 25 min |
| [04](1-teoria/04-xargs-basico-y-el-gotcha-de-entrada-vacia.md) | xargs básico y el gotcha de entrada vacía | 20 min |
| [05](1-teoria/05-xargs-seguro-print0-y-nombres-peligrosos.md) | xargs seguro: -print0, -I y nombres peligrosos | 25 min |
| [06](1-teoria/06-xargs-paralelo-y-control-de-lote.md) | xargs en paralelo y control de lote | 20 min |
| [07](1-teoria/07-construyendo-finddupes-find-xargs-hashing.md) | Construyendo finddupes: find + xargs + hashing | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|---|
| [01](2-practicas/01-find-basico-y-criterios.md) | Búsquedas por nombre, tipo, profundidad y antigüedad, y el error de patrón sin comillas | 45 min |
| [02](2-practicas/02-find-avanzado-logica-y-acciones.md) | Agrupación con `-o`, exclusión con `-not -path`, `-exec` uno por uno vs en lote | 45 min |
| [03](2-practicas/03-xargs-seguro-y-en-paralelo.md) | Reproducir y corregir la ruptura por nombres con espacio, medir el paralelismo | 45 min |
| [04](2-practicas/04-finddupes-con-pipes-reales.md) | Construir a mano la lógica completa que después completas en el starter | 45 min |

Y la novena capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `finddupes`, que abre el bloque de sistema y procesos
(Semanas 09-12) encontrando archivos duplicados por contenido en un
árbol completo de directorios.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 30 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 9 de `toolkit` | 2 h 20 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `find . -maxdepth 1 -type d -empty` encuentra directorios vacíos de
  primer nivel, sin necesitar revisar cada uno a mano.
- `find /etc -iname "*.conf" 2>/dev/null` descarta los mensajes de
  "Permission denied" sin perder los resultados válidos.
- `xargs -t` imprime cada comando antes de ejecutarlo — confirma
  exactamente qué va a correr, antes de que corra de verdad.
- `nproc` da el número de núcleos disponibles, un punto de partida
  razonable para elegir un valor de `xargs -P`.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `finddupes` funcionando según
   los requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`,
   `logreport`, `logscan`, `topcount` y `sumfield` de semanas anteriores
   siguen funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 09
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 08](../week-08-awk_y_pipelines_de_datos/README.md) | Semana 09 | [Semana 10 →](../week-10-gestion_de_procesos_y_senales/README.md) |

[← Volver al índice del bootcamp](../README.md)
