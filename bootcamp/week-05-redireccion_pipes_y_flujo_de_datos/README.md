# Semana 05 — Redirección, pipes y flujo de datos

> Esta semana abre la segunda fase del bootcamp: de explorar y organizar
> archivos, a procesar su contenido. Todo empieza con tres flujos, cómo
> redirigirlos, y cómo encadenar comandos entre sí.

## 🎯 Objetivos de la Semana

- Distinguir stdin, stdout y stderr, y redirigir cada uno con precisión
- Construir pipelines de varios comandos, entendiendo qué fluye entre ellos
- Usar `tee` para ver y guardar al mismo tiempo, incluido `sudo tee`
- Interpretar códigos de salida más allá de "0 bien, otra cosa mal"
- Encadenar comandos con `&&`, `||` y `;` con intención

## 📋 Prerrequisitos

Semana 04 completada: `toolkit.sh audit` funcionando, usuario `estudiante`
disponible para pruebas que necesiten un usuario sin privilegios.

## 🗂️ Estructura de la Semana

```
week-05-redireccion_pipes_y_flujo_de_datos/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 6 archivos: flujos, redirecciones, pipes, tee, codigos de salida, encadenamiento
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 5 de toolkit: subcomando logreport
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-stdin-stdout-stderr.md) | stdin, stdout y stderr: los tres flujos | 20 min |
| [02](1-teoria/02-redirecciones-de-entrada-y-salida.md) | Redirecciones de entrada y salida | 25 min |
| [03](1-teoria/03-pipes-encadenar-comandos.md) | Pipes: encadenar comandos | 25 min |
| [04](1-teoria/04-tee-ver-y-guardar-al-mismo-tiempo.md) | `tee`: ver y guardar al mismo tiempo | 20 min |
| [05](1-teoria/05-codigos-de-salida-y-dolar-interrogacion.md) | Códigos de salida y `$?` | 20 min |
| [06](1-teoria/06-encadenar-comandos-and-or-punto-y-coma.md) | Encadenar comandos: `&&`, `||`, `;` | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-redirecciones-de-entrada-y-salida.md) | Separar stdout/stderr, reproducir y corregir el truncado accidental | 45 min |
| [02](2-practicas/02-pipes-y-tee.md) | Construir pipelines paso a paso, `pipefail`, `tee` y `sudo tee` | 50 min |
| [03](2-practicas/03-encadenar-comandos-y-codigos-de-salida.md) | Códigos 126/127/señales, encadenamiento con `&&`/`||` | 45 min |
| [04](2-practicas/04-logreport-con-pipes-reales.md) | Construir a mano la lógica que después completas en el starter | 50 min |

Y la quinta capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `logreport`, que abre el bloque de semanas 05-09
(procesamiento de contenido de archivos).

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (6 archivos) | 2 h 15 min |
| Prácticas (4 archivos) | 3 h 10 min |
| Proyecto: Capa 5 de `toolkit` | 2 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 5 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `</dev/null` fuerza un EOF inmediato — útil para confirmar si un comando
  "colgado" está esperando stdin.
- `: > archivo` vacía un archivo sin borrarlo y recrearlo.
- `${PIPESTATUS[@]}` da el código de salida de cada comando de un pipeline,
  no solo el del último.
- `comando | sudo tee archivo` escribe con privilegios donde `sudo comando
  > archivo` falla.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `logreport` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize` y `audit` de semanas
   anteriores siguen funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 05
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 04](../week-04-permisos_y_propiedad/README.md) | Semana 05 | [Semana 06 →](../week-06-busqueda_de_texto_con_grep_y_regex/README.md) |

[← Volver al índice del bootcamp](../README.md)
