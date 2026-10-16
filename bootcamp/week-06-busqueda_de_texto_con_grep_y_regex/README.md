# Semana 06 — Búsqueda de texto con grep y regex

> `grep` sin regex ya resuelve la mayoría de las búsquedas. Esta semana
> suma las formas que un patrón literal no puede expresar — y las aplica
> a un problema real: encontrar qué archivos de log, entre cientos, tienen
> algo que mirar.

## 🎯 Objetivos de la Semana

- Buscar patrones literales y usar las banderas esenciales de `grep` (`-i`, `-v`, `-c`, `-n`, `-l`)
- Anclar patrones (`^`, `$`) y construir clases de caracteres (`[...]`, `[[:alpha:]]`)
- Distinguir BRE de ERE, y usar cuantificadores (`*`, `+`, `?`, `{n,m}`) en ambos dialectos
- Combinar alternancia (`|`) y agrupación (`(...)`) para patrones de varias opciones
- Usar límites de palabra (`-w`, `\b`) y `grep -P` para extracción con PCRE
- Buscar recursivamente en un árbol de directorios, filtrado por nombre de archivo

## 📋 Prerrequisitos

Semana 05 completada: `toolkit.sh logreport` funcionando, `pipefail`
entendido (esta semana lo vuelve a poner a prueba, ahora con `grep`
dentro de un pipe), y comodidad con redirecciones y pipes básicos.

## 🗂️ Estructura de la Semana

```
week-06-busqueda_de_texto_con_grep_y_regex/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: basico, anclas/clases, BRE/ERE, alternancia, limites/PCRE, recursivo, contexto
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 6 de toolkit: subcomando logscan
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-grep-basico-y-patrones-literales.md) | grep básico y patrones literales | 20 min |
| [02](1-teoria/02-anclas-clases-y-clases-posix.md) | Anclas, clases de caracteres y clases POSIX | 20 min |
| [03](1-teoria/03-cuantificadores-y-bre-vs-ere.md) | Cuantificadores y BRE vs ERE | 20 min |
| [04](1-teoria/04-grep-extendido-y-alternancia.md) | grep extendido, alternancia y agrupación | 25 min |
| [05](1-teoria/05-limites-de-palabra-y-grep-perl.md) | Límites de palabra y `grep -P` | 20 min |
| [06](1-teoria/06-grep-recursivo-y-por-nombre-de-archivo.md) | grep recursivo y por nombre de archivo | 25 min |
| [07](1-teoria/07-contexto-color-y-extraccion-con-grep-o.md) | Contexto, color y extracción con `grep -o` | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|---|
| [01](2-practicas/01-grep-basico-y-anclas.md) | Banderas esenciales, anclas, y el antipatrón de `ps aux \| grep` | 45 min |
| [02](2-practicas/02-regex-extendida-cuantificadores-y-alternancia.md) | El gotcha de `{n,m}` sin escape, agrupación, y el patrón de severidad de `logscan` | 45 min |
| [03](2-practicas/03-limites-de-palabra-grep-perl-y-busqueda-recursiva.md) | `-w`, `\b`, extracción con `grep -P`, primeros pasos con `-r` | 45 min |
| [04](2-practicas/04-logscan-con-pipes-y-regex-reales.md) | Construir a mano la lógica completa que después completas en el starter | 45 min |

Y la sexta capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `logscan`, que busca `ERROR`/`WARN`/`CRIT` en todo un
árbol de archivos `.log`, en una sola pasada.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 30 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 6 de `toolkit` | 2 h 20 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `grep -f patrones.txt archivo` lee los patrones a buscar desde un
  archivo (uno por línea) en vez de escribirlos todos en la línea de
  comandos — útil con listas largas de palabras prohibidas o IPs
  bloqueadas.
- `zgrep "patron" archivo.log.gz` busca directo dentro de un log
  comprimido con `gzip`, sin descomprimirlo primero a mano.
- `GREP_COLORS="mt=01;34"` (antes del comando) cambia el color de
  resaltado de la coincidencia — útil cuando el rojo/verde por defecto se
  confunde con el esquema de color de tu terminal.
- `grep -z` trata el archivo completo como registros separados por `NUL`
  en vez de por salto de línea — permite que `.` y patrones multilínea
  cuenten un registro completo como una sola "línea" lógica.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `logscan` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit` y
   `logreport` de semanas anteriores siguen funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 06
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 05](../week-05-redireccion_pipes_y_flujo_de_datos/README.md) | Semana 06 | [Semana 07 →](../week-07-procesamiento_de_texto_sed_cut_sort_uniq/README.md) |

[← Volver al índice del bootcamp](../README.md)
