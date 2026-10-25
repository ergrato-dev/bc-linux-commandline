# Rúbrica de Evaluación — Semana 15

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. `set -e` no aborta en `false || echo x`, en `if false`, ni en `! true`. ¿Cuál es la regla común y por qué `true && false` sí aborta?

<details>
<summary>Ver respuesta</summary>

`set -e` no actúa sobre un comando cuyo fallo **se está comprobando**: la
condición de un `if`/`while`, cualquier parte de una lista `&&`/`||` **salvo la
última**, y un comando precedido por `!`. En `true && false` el `false` es el
**último** de la lista: nadie lo comprueba, y el estado de la lista es `1`, así
que aborta. De ahí que nunca debas confiar en `set -e` para "parar a mitad" una
función que alguien pueda llamar desde un `if`.

</details>

2. ¿Qué diferencia hay entre `x=$(false)` y `local x=$(false)` bajo `set -e`, y cómo se escribe sin perder el código?

<details>
<summary>Ver respuesta</summary>

`x=$(false)` es una asignación y toma el estado de la sustitución: aborta.
`local x=$(false)` es la **orden `local`**, que termina bien y se traga el
código del `$( )`: no aborta y el fallo se pierde (además es el aviso SC2155
de `shellcheck`). Se separa: `local x` y después `x=$(comando)`, de modo que el
estado de la asignación sí cuente.

</details>

3. Con `set -o pipefail`, ¿por qué `yes | head -1` termina con `141` y qué significa ese número?

<details>
<summary>Ver respuesta</summary>

`head -1` lee una línea y cierra su entrada; la siguiente escritura de `yes` en
la tubería rota recibe `SIGPIPE`, y un proceso muerto por señal sale con
`128 + N`: `SIGPIPE` es la 13, `128 + 13 = 141`. Sin `pipefail` solo cuenta el
último comando (`head`, `0`); con él cuenta el primero que falló, y con `set
-e` además aborta. Con un escritor finito y un lector que lee todo no ocurre.

</details>

4. Un `trap` sobre `EXIT` ¿se ejecuta con `exit 3`, con un `set -e` que aborta y con `kill -9`? ¿Qué vale `$?` dentro y cómo no perderlo?

<details>
<summary>Ver respuesta</summary>

Se ejecuta con `exit 3` y con el aborto de `set -e`, pero **no** con `kill -9`
(`KILL` no se puede atrapar, ni siquiera avisa). Dentro del trap `$?` es el
código con el que el script va a salir, pero cualquier comando lo pisa, así que
la primera línea es `local rc=$?`. El código de salida no cambia por lo que
haga el trap, salvo que él mismo llame a `exit`.

</details>

5. ¿Por qué `guard` ejecuta el comando con `&` y `wait` en lugar de en primer plano?

<details>
<summary>Ver respuesta</summary>

Si bash espera a un comando en **primer plano**, el trap de una señal que llega
mientras tanto **se retrasa** hasta que el comando acabe: un `TERM` a `guard`
con un `sleep 30` esperaría 30 s. `wait` sí se interrumpe al llegar una señal
atrapada, así que el trap actúa al instante; además da el PID del hijo
(`$!`) para que el manejador pueda matarlo y recogerlo.

</details>

6. ¿Por qué `GUARD_TMP` y `GUARD_PID` son variables globales y no `local` de `cmd_guard`?

<details>
<summary>Ver respuesta</summary>

Un manejador de `trap` se ejecuta en el momento de la salida o de la señal,
**fuera del contexto** de la función que lo instaló, y las variables `local`
de `cmd_guard` pueden no verse (o, tras `exit`, ya no existir). El temporal a
borrar y el PID del hijo deben vivir a nivel de script. El resto, que solo usa
`cmd_guard`, sigue siendo `local`.

</details>

7. ¿Qué riesgo tiene crear un temporal como `/tmp/guard.$$` y qué hace `mktemp` para evitarlo?

<details>
<summary>Ver respuesta</summary>

El nombre es **predecible**: otro usuario puede crear antes un enlace simbólico
con ese nombre hacia un archivo tuyo, y tu `>` escribe a través del enlace. 
`mktemp` genera un nombre aleatorio, crea el archivo de forma que **falla si
ya existe** y con permisos `600` (o `700` para un directorio). Además hay que
crear el temporal en el mismo sistema de archivos que el destino si luego se
hace `mv`, para que el renombrado sea atómico.

</details>

8. `flock -n` sobre un descriptor abierto con `exec {fd}>archivo`: ¿cuándo se libera el bloqueo y qué pasa si `guard` muere con `kill -9`?

<details>
<summary>Ver respuesta</summary>

El bloqueo pertenece al **descriptor abierto**: dura mientras el proceso lo
tenga abierto, es decir, hasta que `guard` termine. El kernel lo libera cuando
el proceso muere, también con `kill -9`, así que no hay bloqueos obsoletos
como con un archivo de PID. (Una excepción: un hijo que heredó el descriptor y
sigue vivo lo mantiene.) `-n` hace que, si está ocupado, falle al instante en
lugar de esperar; `guard` sale entonces con `3`.

</details>

9. En `getopts ':l:k:t:'`, ¿qué hace el `:` inicial, qué valen `opt` y `OPTARG` ante `-z` y ante `-t` sin valor, y por qué se necesita `local OPTIND=1`?

<details>
<summary>Ver respuesta</summary>

El `:` inicial es el modo **silencioso**: `getopts` no imprime sus mensajes y
los gestionas tú. Ante una opción desconocida pone `opt` en `?` y `OPTARG` en
la letra (`z`); ante `-t` sin valor, `opt` en `:` y `OPTARG` en `t`. `OPTIND` es
global y recuerda por dónde va: una función que se llama dos veces empezaría la
segunda con el valor de la primera y no procesaría nada. `local OPTIND=1` lo
reinicia en cada llamada.

</details>

10. `timeout 5 comando` devuelve `124`; ¿qué devuelve si el comando ignora `TERM`, qué añade `-k`, y por qué `guard` reintenta con un tope y una espera?

<details>
<summary>Ver respuesta</summary>

Si el comando ignora `TERM`, `timeout` espera indefinidamente salvo que se use
`-k DURACIÓN`, que envía `KILL` tras ese plazo y entonces el código es `137`.
Reintentar sin **tope** convierte un fallo en un bucle infinito, y sin
**espera** martillea el servicio que quizá está caído: por eso `guard` suma
`reintentos + 1` intentos como máximo y duerme `espera` **entre** ellos (no
tras el último). Y solo es seguro reintentar comandos **idempotentes**.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — el modo estricto y sus agujeros | Reproduce las excepciones de `set -e` (`if`, `\|\|`, `&&`, `!`), `local x=$(false)` frente a `x=$(false)` con `inherit_errexit`, `${dir:?}`, `PIPESTATUS`, el `141`, `((i++))` y `grep` sin coincidencias, `f` suelta y dentro de `if`, y los códigos `126`/`127`/`143`/`44` | 10 |
| 02 — `trap` y archivos temporales | Reproduce `trap EXIT` con `exit 3` y `set -e`, `term`/`limpio` con `143`, el reemplazo de traps, el retraso de `3s` frente a `1s`, `ERR` con `set -E`, `mktemp` y el ataque del enlace, `cd.sh` que limpia y la escritura atómica | 10 |
| 03 — registro, `getopts` y concurrencia | `log` a `stderr` con niveles, `exec >>` y `tee -a`, traza con `PS4` y `bash -n`, `getopts` en modo silencioso con `--` y `local OPTIND=1`, `flock` con `kill -9`, `timeout` con `-k` y `retry` con espera creciente | 10 |
| 04 — `guard` a mano | Rellena los ocho `TODO` por pasos con su verificación: opciones y validación con `1`, `guard_cleanup` y temporal, ejecución con `0`/`2`/`4`, bloqueo con `3`, reintentos registrados, `TERM` con `143` y `shellcheck` limpio | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (6 checks) | 5 |
| `guard`: ejecuta el comando y muestra su salida, y sale con `2` si el comando falla (2 checks) | 4 |
| `guard`: sale con `1` sin comando, con opción desconocida y con límite de tiempo inválido (3 checks) | 3 |
| `guard`: sale con `4` por timeout y con `3` por bloqueo ocupado (2 checks) | 4 |
| `guard`: registra cada intento, registra el código final y reintenta las veces pedidas (3 checks) | 3 |
| `guard`: no deja el temporal aunque el comando falle (1 check) | 1 |
| `guard`: sale con `143` al recibir `TERM` (1 check) | 2 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `guard_cleanup` guarda `$?` en la primera línea; `GUARD_TMP`, `GUARD_PID` y `GUARD_LOG` globales para los traps y el resto con `local` | 2 |
| Traps instalados **después** de validar y en el orden `EXIT`, `INT`, `TERM`; el manejador mata **y recoge** al hijo | 2 |
| Comando en segundo plano con `wait`, `\|\| rc=$?` en la llamada y espera solo entre intentos | 2 |
| Cero `# shellcheck disable` sin justificar, validación con `is_uint` antes de usar los números, errores de uso a `stderr`, sin `eval` | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave o token con formato real comiteado | Grave |
| `rm -rf` con una variable sin proteger (`$dir/*` sin `${dir:?}`) o sin aviso ni respaldo | Grave |
| `eval` o `bash -c "$dato"` con datos de fuera del script (el comando de `guard` se ejecuta como `"$@"`) | Grave |
| Un ejemplo de `cron`/systemd sin manejo de error ni registro | Grave |
| Temporal con nombre predecible (`/tmp/algo.$$`) en lugar de `mktemp` | Moderada |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| `trap` que se ejecuta antes de validar y deja temporal o registro en un error de uso | Moderada |
| `((x++))` bajo `set -e` | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 15 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
