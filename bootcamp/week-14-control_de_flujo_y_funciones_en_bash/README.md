# Semana 14 — Control de flujo y funciones en bash

> La semana pasada un script era una lista de órdenes; esta semana repite, parte en piezas y guarda listas.
> Bucles, funciones y arrays son lo que separa un script de veinte líneas de uno que aguanta doscientas.

## 🎯 Objetivos de la Semana

- Recorrer listas, rangos y archivos con `for`, `while` y `until`, y salir con `break`/`continue`
- Evitar las trampas de los bucles: comodines sin coincidencias, `{1..$n}`, `for f in $(ls)` y el contador que muere en una tubería
- Definir funciones, pasarles argumentos y devolver un estado con `return` y un dato por `stdout`
- Usar `local` y explicar el ámbito **dinámico** de bash
- Manejar arrays indexados y asociativos sin que las comillas los rompan
- Llamar a una función por su nombre con una lista blanca, y estructurar un script con `main` y una guarda de ejecución
- Refactorizar `snapshot` en funciones sin cambiar su salida
- Construir `healthcheck`: tres comprobaciones, límites configurables, resumen y código de salida

## 📋 Prerrequisitos

Semana 13 completada: `toolkit.sh` con `snapshot` funcionando en `~/bin` y
`shellcheck` instalado en `ubuntu-lab`. Semana 13 (comillas, `"$@"`,
`$( )`, `local` y `shellcheck`, que aquí se aplican a funciones y arrays),
Semana 12 (por qué `-gt` evalúa aritmética y la validación va antes), Semana 10
(procesos hijo: la base del subshell de las tuberías) y Semana 09 (`find
-print0`, que aquí se combina con `read -d ''`).

## 🗂️ Estructura de la Semana

```
week-14-control_de_flujo_y_funciones_en_bash/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: bucles, funciones, ámbito, arrays indexados, asociativos, despacho, healthcheck
├── 2-practicas/           # 4 prácticas dentro de ubuntu-lab
├── 3-proyecto/            # Capa 14 de toolkit: subcomando healthcheck
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, uno por idea difícil de ver en prosa: el **ámbito dinámico**
(una función ve las variables `local` de quien la llama) y **cómo `healthcheck`
va del array de datos al código de salida** (bucle, despacho por nombre y
resumen). El resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-bucles-for-while-until.md) | Bucles: `for`, `while` y `until` | 20 min |
| [02](1-teoria/02-funciones-definicion-y-uso.md) | Funciones: definición y uso | 25 min |
| [03](1-teoria/03-ambito-y-valores-de-retorno.md) | Ámbito y valores de retorno | 30 min |
| [04](1-teoria/04-arrays-indexados.md) | Arrays indexados | 25 min |
| [05](1-teoria/05-arrays-asociativos.md) | Arrays asociativos | 25 min |
| [06](1-teoria/06-despacho-dinamico-y-estructura-de-un-script.md) | Despacho dinámico y estructura de un script | 25 min |
| [07](1-teoria/07-construyendo-healthcheck.md) | Construyendo `healthcheck` | 30 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-bucles-y-control-de-flujo.md) | `for` con espacios, rangos, comodín sin coincidencias, `until` con tope, `while read` y el contador de la tubería | 45 min |
| [02](2-practicas/02-funciones-y-ambito.md) | Argumentos, `return`, `local`, ámbito dinámico, `$( )` que pierde cambios y `set -e` dentro de funciones | 45 min |
| [03](2-practicas/03-arrays-y-refactor-de-snapshot.md) | Arrays indexados y asociativos, y refactor de `snapshot` en funciones comprobado con `diff` | 45 min |
| [04](2-practicas/04-healthcheck-a-mano.md) | Rellenar los ocho `TODO` de `healthcheck` paso a paso | 90 min |

Y la decimocuarta capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `healthcheck`, que ejecuta tres comprobaciones contra límites
configurables y sale con `0`, `1` o `2`.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 3 h |
| Prácticas (4 archivos) | 3 h 45 min |
| Proyecto: Capa 14 de `toolkit` | 1 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 45 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `shopt -s lastpipe` hace que el **último** comando de una tubería corra en la
  shell actual: `printf 'a\nb\n' | while read -r l; do n=$((n+1)); done`
  deja `n=2` en lugar de `0`. Solo funciona en scripts (sin control de
  trabajos); en el laboratorio dio `n=2` en las cuatro distribuciones.
- `"${a[@]@Q}"` entrecomilla **cada elemento** de forma que se pueda pegar de
  vuelta en bash: con `a=(uno "dos tres" "it's")` imprime `'uno' 'dos tres'
  'it'\''s'`. Es la forma limpia de mostrar un array en un mensaje de error.
- `mapfile -d '' -t archivos < <(find . -name '*.txt' -print0)` carga en un
  array nombres de archivo **con cualquier carácter** (el separador es el byte
  nulo): es `read -d ''` sin el bucle.
- `echo ${!hc_*}` expande a los **nombres** de las variables que empiezan por
  `hc_` (`hc_a hc_b`): para depurar "qué variables dejó mi script" sin
  `declare -p` entero.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `healthcheck` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck`, `netcheck` y `snapshot` de semanas anteriores siguen
   funcionando sin regresiones, y `shellcheck ~/bin/toolkit.sh` sale limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 14
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 13](../week-13-fundamentos_de_bash_scripting/README.md) | Semana 14 | [Semana 15 →](../week-15-scripts_robustos_manejo_de_errores/README.md) |

[← Volver al índice del bootcamp](../README.md)
