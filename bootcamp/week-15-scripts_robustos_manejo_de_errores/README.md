# Semana 15 — Scripts robustos: manejo de errores

> Un script que falla a gritos se arregla en cinco minutos; uno que falla en silencio, a las tres de la madrugada, se descubre un mes después.
> Esta semana aprendes a hacer que tus scripts fallen cuando deben, avisen de por qué y limpien lo que dejan.

## 🎯 Objetivos de la Semana

- Explicar qué hacen `set -e`, `-u` y `pipefail`, y reproducir sus excepciones sin sorpresas
- Dar a un script códigos de salida con significado y leer `126`, `127` y `128 + N`
- Limpiar con `trap` en `EXIT`, `INT` y `TERM`, y entender por qué `kill -9` no se atrapa
- Crear archivos temporales con `mktemp` y escribir de forma atómica con `mv`
- Dejar un registro con niveles y depurar con `set -x`, `PS4`, `bash -n` y `trap ERR`
- Evitar ejecuciones solapadas (`flock`), colgadas (`timeout`) y reintentos sin tope
- Procesar opciones con `getopts` y validar cada dato antes de usarlo
- Construir `guard`: una envoltura que da a cualquier comando todas esas defensas

## 📋 Prerrequisitos

Semana 14 completada: `toolkit.sh` con `snapshot` y `healthcheck` funcionando
en `~/bin` y `shellcheck` instalado en `ubuntu-lab`. Semana 14 (funciones,
`local`, el patrón `if !` que cuenta fallos sin abortar y `main` con su guarda),
Semana 13 (`set -euo pipefail`, comillas y `shellcheck`, que aquí se
estudian con sus excepciones), Semana 10 (señales, `kill`, zombis y `wait`:
la base de `trap` y de `guard_interrupt`) y Semana 05 (redirecciones y
descriptores, que aquí se usan con `exec`).

## 🗂️ Estructura de la Semana

```
week-15-scripts_robustos_manejo_de_errores/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 8 archivos: modo estricto, códigos de salida, trap, temporales, registro, concurrencia, getopts, guard
├── 2-practicas/           # 4 prácticas dentro de ubuntu-lab
├── 3-proyecto/            # Capa 15 de toolkit: subcomando guard
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, uno por idea difícil de ver en prosa: **todas las salidas de un
script pasan por `exit`** (y por eso un solo `trap EXIT` basta para limpiar) y
el **flujo de `guard`**, de la validación al código de salida. El resto se
enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-modo-estricto-set-euo-pipefail.md) | El modo estricto: `set -euo pipefail` y sus excepciones | 20 min |
| [02](1-teoria/02-codigos-de-salida-y-errores-explicitos.md) | Códigos de salida y errores explícitos | 20 min |
| [03](1-teoria/03-trap-senales-y-limpieza.md) | `trap`: señales y limpieza | 20 min |
| [04](1-teoria/04-archivos-temporales-y-escritura-atomica.md) | Archivos temporales y escritura atómica | 15 min |
| [05](1-teoria/05-registro-y-depuracion.md) | Registro y depuración | 20 min |
| [06](1-teoria/06-concurrencia-bloqueos-y-reintentos.md) | Concurrencia, bloqueos y reintentos | 20 min |
| [07](1-teoria/07-getopts-y-validacion-de-entradas.md) | `getopts` y validación de entradas | 20 min |
| [08](1-teoria/08-construyendo-guard.md) | Construyendo `guard` | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-modo-estricto-y-sus-agujeros.md) | Excepciones de `set -e`, `-u`, `pipefail`, `((i++))`, funciones y códigos de salida | 45 min |
| [02](2-practicas/02-trap-y-archivos-temporales.md) | `trap` con `EXIT`/señales/`ERR`, el trap retrasado, `mktemp`, limpieza y escritura atómica | 60 min |
| [03](2-practicas/03-registro-getopts-y-concurrencia.md) | Registro, `set -x` y `PS4`, `getopts`, `flock`, `timeout` y reintentos | 75 min |
| [04](2-practicas/04-guard-a-mano.md) | Rellenar los ocho `TODO` de `guard` paso a paso | 90 min |

Y la decimoquinta capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `guard`, que ejecuta un comando con bloqueo, límite de
tiempo, reintentos, registro y limpieza, y sale con `0`, `1`, `2`, `3`, `4`,
`130` o `143`.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 40 min |
| Prácticas (4 archivos) | 4 h 30 min |
| Proyecto: Capa 15 de `toolkit` | 1 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 20 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `flock -n -E 9 archivo.lock comando` elige **tú** el código de salida cuando
  el bloqueo está ocupado (aquí `9`), en lugar del `1` por defecto, que se
  confunde con un fallo del propio comando. En el laboratorio dio `9` en las
  cuatro distribuciones.
- `wait -n` espera al **primero** de los trabajos en segundo plano que
  termine y devuelve su código: con `sleep 1 & sleep 2 & wait -n` vuelve a
  1 s, no a 2. Sirve para lanzar varias tareas y reaccionar a la primera que
  acabe o falle.
- `$EPOCHREALTIME` da la hora en segundos con microsegundos (`1761387302.481213`)
  sin lanzar ningún proceso: restando dos lecturas mides cuánto tardó un
  trozo del script con más precisión que `$SECONDS`.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `guard` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck`, `netcheck`, `snapshot` y `healthcheck` de semanas anteriores
   siguen funcionando sin regresiones, y `shellcheck ~/bin/toolkit.sh` sale
   limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 15
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 14](../week-14-control_de_flujo_y_funciones_en_bash/README.md) | Semana 15 | [Índice del bootcamp →](../README.md) |

[← Volver al índice del bootcamp](../README.md)
