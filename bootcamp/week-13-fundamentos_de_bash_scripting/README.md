# Semana 13 — Fundamentos de bash scripting

> Hasta ahora ejecutabas comandos; esta semana los guardas, les pasas argumentos
> y haces que decidan. Los errores clásicos (comillas, `[ ]`, `$?`) se aprenden una vez.

## 🎯 Objetivos de la Semana

- Escribir un script con shebang, ejecutarlo de tres formas y explicar qué hace el kernel con `#!`
- Usar variables, valores por defecto (`${v:-x}`, `${v:?}`) y recortes (`${v##*/}`) sin lanzar procesos
- Aplicar las reglas de quoting: saber cuándo la división en palabras y el globbing rompen un script
- Leer argumentos con `$1`, `"$@"` y `shift`, y devolver códigos de salida con significado
- Decidir con `if`, `[[ ]]`, `case` y `&&`/`||`, sin confundir texto con número
- Capturar salidas con `$( )`, construir informes con here-docs y formatear con `printf`
- Dejar un script limpio de `shellcheck` y entender cada aviso
- Construir `snapshot`, una foto del sistema con umbral y código de salida

## 📋 Prerrequisitos

Semana 12 completada: `toolkit.sh` con `netcheck` funcionando en `~/bin`, y
`apt` para instalar herramientas en la imagen mínima de `ubuntu-lab`.
Semana 05 (redirección, `$?`, `&&`, `||`, `pipefail` y here-docs, que aquí se
profundizan), Semana 04 (el bit `x` y `chmod +x`), Semana 10 (procesos hijo y
`fork`, base de por qué un script no cambia tu shell) y Semana 12 (por qué
`-ge` evalúa aritmética y la regex va antes).

## 🗂️ Estructura de la Semana

```
week-13-fundamentos_de_bash_scripting/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 8 archivos: shebang, variables, quoting, argumentos, condicionales, $( )/here-docs, shellcheck, snapshot
├── 2-practicas/           # 4 prácticas dentro de ubuntu-lab
├── 3-proyecto/            # Capa 13 de toolkit: subcomando snapshot
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, uno por idea difícil de ver en prosa: el **orden de las siete
expansiones de bash** y qué comillas impiden cada una (la base del quoting), y
**cómo `snapshot` convierte seis fuentes del sistema en un informe** con
código de salida. El resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-shebang-y-ejecucion.md) | Shebang y ejecución de un script | 20 min |
| [02](1-teoria/02-variables-y-expansion-de-parametros.md) | Variables y expansión de parámetros | 25 min |
| [03](1-teoria/03-quoting-comillas-y-expansiones.md) | Quoting: comillas y expansiones | 25 min |
| [04](1-teoria/04-argumentos-y-codigos-de-salida.md) | Argumentos y códigos de salida | 25 min |
| [05](1-teoria/05-condicionales-test-y-doble-corchete.md) | Condicionales: `test`, `[[ ]]` y `case` | 25 min |
| [06](1-teoria/06-sustitucion-de-comandos-heredocs-y-printf.md) | Sustitución de comandos, here-docs y `printf` | 25 min |
| [07](1-teoria/07-shellcheck.md) | ShellCheck | 25 min |
| [08](1-teoria/08-construyendo-snapshot.md) | Construyendo `snapshot` | 30 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-primer-script-y-shellcheck.md) | Escribir y ejecutar un script, provocar `Permission denied`, `CRLF` y `[[: not found`, y dejarlo limpio de `shellcheck` | 45 min |
| [02](2-practicas/02-variables-quoting-y-argumentos.md) | Variables, valores por defecto, quoting con un nombre con espacio, `"$@"` y un procesador de opciones | 45 min |
| [03](2-practicas/03-condicionales-heredocs-y-printf.md) | `[ ]` frente a `[[ ]]`, texto frente a número, `A && B \|\| C`, `local v=$(cmd)` y here-docs | 45 min |
| [04](2-practicas/04-snapshot-a-mano.md) | Construir `snapshot` por fragmentos y sus códigos de salida | 45 min |

Y la decimotercera capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `snapshot`, que imprime o guarda un informe de la máquina y
sale con `0`, `1` o `2` según el uso del disco frente a un umbral.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 3 h 20 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 13 de `toolkit` | 1 h 40 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- Dentro de un script, `PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '` antes de `set -x`
  hace que cada línea trazada lleve `archivo:línea`: `+ ps4b.sh:4: x=5`.
  (Como variable de entorno delante de `bash -x`, no surtió efecto en la
  prueba del laboratorio: va **dentro** del script.)
- `shellcheck -f diff script.sh | patch -p1 script.sh` **aplica** los
  arreglos que `shellcheck` sabe hacer solo (comillas, `cd ... || exit`). La imagen
  mínima no trae `patch`: `apt-get install -y patch`. Revisa el resultado
  con `git diff` o `diff` antes de fiarte.
- `printf -v variable 'formato' args` guarda el resultado **en una variable**
  sin subshell ni `$( )`: `printf -v fecha '%(%F)T' -1` deja `2026-10-25` en
  `$fecha`.
- `: "${DIR:?falta DIR}"` exige una variable **sin ejecutar nada más**: `:`
  es un comando que no hace nada y su argumento se expande, así que
  `${DIR:?}` aborta el script con el mensaje. Mensaje en `stderr` y código
  `1`, y una sola línea al principio del script para sus requisitos.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `snapshot` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck` y `netcheck` de semanas anteriores siguen funcionando sin
   regresiones, y `shellcheck ~/bin/toolkit.sh` sale limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 13
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 12](../week-12-redes_desde_la_linea_de_comandos/README.md) | Semana 13 | [Índice del bootcamp →](../README.md) |

[← Volver al índice del bootcamp](../README.md)
