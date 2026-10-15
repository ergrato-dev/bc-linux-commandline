# Semana 03 — Manipulación de archivos y directorios

> Crear, copiar, mover y borrar parecen cuatro verbos simples. Esta semana
> los convierte en hábitos que no se arrepienten de sí mismos.

## 🎯 Objetivos de la Semana

- Crear archivos y árboles de directorios completos sin esfuerzo
- Copiar preservando (o no) metadatos y enlaces, a propósito
- Mover y renombrar entendiendo por qué unas veces es instantáneo y otras no
- Borrar con criterio, sabiendo que no hay papelera por defecto
- Leer metadatos completos con `stat` y aplicar patrones seguros en lote

## 📋 Prerrequisitos

Semana 02 completada: `toolkit.sh inventory` funcionando, cuenta de
archivos/directorios/enlaces correcta.

## 🗂️ Estructura de la Semana

```
week-03-manipulacion_de_archivos_y_directorios/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 6 archivos: crear, copiar, mover, eliminar, stat, patrones seguros
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 3 de toolkit: subcomando organize
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-crear-archivos-y-directorios.md) | Crear archivos y directorios | 20 min |
| [02](1-teoria/02-copiar-archivos-y-directorios.md) | Copiar archivos y directorios | 25 min |
| [03](1-teoria/03-mover-y-renombrar.md) | Mover y renombrar | 20 min |
| [04](1-teoria/04-eliminar-con-criterio.md) | Eliminar con criterio | 25 min |
| [05](1-teoria/05-stat-y-metadatos.md) | `stat` y metadatos | 20 min |
| [06](1-teoria/06-patrones-seguros-para-operaciones-destructivas.md) | Patrones seguros para operaciones destructivas | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-crear-archivos-y-directorios.md) | Construir la estructura de prueba de toda la semana | 40 min |
| [02](2-practicas/02-copiar-archivos-y-directorios.md) | Comparar copia simple, `-p`, `-a` y enlaces con/sin `-d` | 50 min |
| [03](2-practicas/03-mover-y-eliminar-con-criterio.md) | Medir `mv`, ver la protección de `rm -rf /`, usar `-I` | 50 min |
| [04](2-practicas/04-operaciones-seguras-por-lotes.md) | Dry-run manual, respaldo con fecha, probar `organize` | 50 min |

Y la tercera capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `organize`, que agrupa archivos por extensión con dry-run
por defecto.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (6 archivos) | 2 h 15 min |
| Prácticas (4 archivos) | 3 h 10 min |
| Proyecto: Capa 3 de `toolkit` | 2 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 5 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `cp --backup=numbered` respalda el destino existente antes de
  sobrescribirlo, en vez de perderlo sin rastro.
- `rm -I` pregunta una sola vez en borrados masivos — más seguro que `-f`,
  menos tedioso que `-i`.
- `touch -r modelo destino` copia la fecha de un archivo a otro sin
  calcularla a mano.
- `stat -c '%Y %n' * | sort -rn` ordena archivos por fecha real de
  modificación, más preciso que fiarse del orden visual de `ls -lt`.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `organize` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor` e `inventory` de semanas anteriores siguen
   funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 03
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 02](../week-02-navegacion_y_sistema_de_archivos/README.md) | Semana 03 | [Semana 04 →](../week-04-permisos_y_propiedad/README.md) |

[← Volver al índice del bootcamp](../README.md)
