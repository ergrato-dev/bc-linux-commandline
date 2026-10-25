# Semana 16 — Automatización y tareas programadas

> Un script que solo corre cuando tú lo lanzas es una herramienta; uno que corre solo a las 3:00 es un servicio.
> Esta semana aprendes a programarlo con `cron` y con temporizadores de systemd, y a que no falle en silencio.

## 🎯 Objetivos de la Semana

- Escribir y leer expresiones de `cron` (listas, rangos, pasos) y predecir cuándo se ejecutan
- Explicar el entorno mínimo de `cron` (`PATH`, `SHELL`, sin terminal) y depurar «funciona a mano, falla programado»
- Evitar las trampas: el `%` que corta el comando, el OR entre día del mes y día de la semana, el `*/7`
- Distinguir `crontab` de usuario, `/etc/crontab`, `/etc/cron.d` y `cron.daily`, y programar algo de una sola vez con `at`
- Escribir un par `.service` + `.timer` y validarlo con `systemd-analyze` (`calendar`, `timespan`, `verify`)
- Elegir entre `cron` y un temporizador con criterio, sabiendo qué aporta `Persistent=true`
- Programar tareas envueltas en `guard` para que dejen registro, no se solapen y no se cuelguen
- Construir `schedule`: valida expresiones de cron y genera las tres configuraciones a la vez

## 📋 Prerrequisitos

Semana 15 completada: `toolkit.sh` con `guard` funcionando en `~/bin` y
`shellcheck` instalado en `ubuntu-lab`. Semana 15 (`guard`, `trap`, `flock`,
`timeout` y los códigos de salida, que aquí se **programan**), Semana 14
(funciones, `local` y `source` sin ejecutar `main`), Semana 13 (comillas y
variables), Semana 10 (procesos, señales y demonios: `cron` es uno) y
Semana 05 (redirecciones: sin `>> log 2>&1` una tarea programada es muda).

## 🗂️ Estructura de la Semana

```
week-16-automatizacion_y_tareas_programadas/
├── 0-assets/              # 3 diagramas SVG
├── 1-teoria/              # 8 archivos: cron, expresiones, entorno, cron del sistema y at, tareas que no fallan en silencio, timers, service, schedule
├── 2-practicas/           # 4 prácticas dentro de ubuntu-lab
├── 3-proyecto/            # Capa 16 de toolkit: subcomando schedule
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Tres diagramas, cada uno para algo que la prosa cuenta mal: la **anatomía de
una línea de cron** (qué es cada campo y dónde acaba el comando), la
**comparación de cron y temporizador** (qué hace cada uno ante los mismos
problemas) y el **flujo de `schedule`** (de una expresión a tres archivos). El
resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-cron-y-crontab.md) | `cron` y `crontab`: ejecutar cosas sin estar delante | 20 min |
| [02](1-teoria/02-expresiones-de-cron-y-sus-trampas.md) | Expresiones de `cron` y sus trampas | 25 min |
| [03](1-teoria/03-el-entorno-minimo-de-cron.md) | El entorno mínimo de `cron` | 20 min |
| [04](1-teoria/04-cron-en-el-sistema-y-at.md) | `cron` en el sistema y `at` | 20 min |
| [05](1-teoria/05-tareas-programadas-que-no-fallan-en-silencio.md) | Tareas programadas que no fallan en silencio | 20 min |
| [06](1-teoria/06-temporizadores-de-systemd.md) | Temporizadores de systemd | 25 min |
| [07](1-teoria/07-unidades-service-para-tareas.md) | Unidades `service` para tareas | 20 min |
| [08](1-teoria/08-construyendo-schedule.md) | Construyendo `schedule` | 30 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-cron-en-vivo-y-su-entorno.md) | Arrancar `cron`, respaldar el crontab, el `PATH` mínimo, `dash`, el `%` y la redirección | 60 min |
| [02](2-practicas/02-cron-d-run-parts-y-trampas.md) | `/etc/cron.d`, `run-parts`, el OR de día del mes y de la semana, `*/7` y el crontab inválido | 60 min |
| [03](2-practicas/03-temporizadores-de-systemd-sin-systemd.md) | `systemd-analyze` `calendar`, `timespan` y `verify` sobre unidades escritas por ti | 60 min |
| [04](2-practicas/04-schedule-a-mano.md) | Rellenar los ocho `TODO` de `schedule` paso a paso, con una ejecución real por `cron` | 90 min |

Y la decimosexta capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `schedule`: `check` valida una expresión y cuenta sus
ejecuciones al día; `gen` escribe un `.cron`, un `.service` y un `.timer`
envueltos en `guard`, y sale con `0`, `1` (uso) o `2` (expresión inválida o
ambigua).

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 3 h |
| Prácticas (4 archivos) | 4 h 30 min |
| Proyecto: Capa 16 de `toolkit` | 1 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 50 min |
| Repaso, glosario y recursos | 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `run-parts --test /etc/cron.daily` lista qué scripts ejecutaría el
  directorio **sin ejecutarlos**, ya filtrados por las reglas de `run-parts`
  (no ejecutables y nombres con punto, descartados). Es la forma de saber por
  qué «no corre» un script antes de esperar a las 6:25.
- `env -i SHELL=/bin/sh PATH=/usr/bin:/bin HOME=/root /bin/sh -c '...'`
  reproduce en tu terminal el entorno vacío de `cron`, sin esperar un minuto.
  Si el comando falla ahí con `not found`, ya sabes qué le pasa en `cron`.
- `systemd-analyze calendar 'Mon..Fri *-*-* 09:00' --iterations=3` enseña las
  **próximas ejecuciones reales** de un calendario. Úsalo para contrastar
  cualquier expresión de `cron` que hayas traducido.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `schedule` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck`, `netcheck`, `snapshot`, `healthcheck` y `guard` de semanas
   anteriores siguen funcionando sin regresiones, y `shellcheck
   ~/bin/toolkit.sh` sale limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 16
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 15](../week-15-scripts_robustos_manejo_de_errores/README.md) | Semana 16 | [Índice del bootcamp →](../README.md) |

[← Volver al índice del bootcamp](../README.md)
