# Rúbrica de Evaluación — Semana 16

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. Una tarea de `cron` funciona a mano y falla programada. ¿Qué tres diferencias del entorno explican casi siempre el fallo?

<details>
<summary>Ver respuesta</summary>

`cron` arranca el comando con un entorno mínimo: `PATH=/usr/bin:/bin` (sin
`/usr/local/bin` ni `~/bin`), `SHELL=/bin/sh` (que en Debian y Ubuntu es `dash`,
así que `[[ ]]` y los arrays fallan) y el directorio de trabajo es tu `HOME`,
sin terminal. Tu sesión interactiva trae además variables de `~/.bashrc` que
`cron` nunca lee. La defensa es fijar `SHELL`, `PATH` y rutas absolutas en el
propio crontab, y redirigir la salida a un registro para ver el error.

</details>

2. ¿Qué hace un `%` sin escapar en una línea de crontab y cómo se arregla?

<details>
<summary>Ver respuesta</summary>

En `cron` el `%` es un **salto de línea**: lo que va antes es el comando y lo
que va después se le entrega por la entrada estándar. `date +%F` se corta en
`date +` y el resto llega a `stdin`; el comando falla y, si la redirección
estaba en la parte cortada, **ni siquiera se crea el registro**. Se escapa
como `\%`. En una unidad de systemd el mismo carácter es el inicio de un
especificador y se escribe `%%`: cada formato tiene su regla.

</details>

3. En la expresión `0 0 13 * 5`, ¿cuándo se ejecuta en `cron` y cuándo lo haría el `OnCalendar` equivalente `Fri *-*-13`?

<details>
<summary>Ver respuesta</summary>

Cuando **ambos** campos, día del mes y día de la semana, están restringidos,
`cron` los une con **OR**: se ejecuta cada día 13 **y** cada viernes. systemd
usa **AND**: solo los viernes que caen en día 13. Son semánticas opuestas para
lo que parece la misma regla; por eso `schedule gen` se niega (código `2`) a
generar ambos formatos desde esa expresión.

</details>

4. ¿Cuántas veces al día corre `*/7 * * * *` y por qué no es «cada siete minutos»?

<details>
<summary>Ver respuesta</summary>

El paso se aplica **dentro de cada hora**, empezando en 0: `0,7,14,…,56`. Son
9 valores por hora, y entre el `56` y el `0` de la hora siguiente pasan 4
minutos, no 7. Si necesitas un intervalo real, el temporizador monotónico de
systemd (`OnUnitActiveSec=7min`) cuenta desde la última activación y no se
reinicia cada hora.

</details>

5. ¿Qué diferencia práctica hay entre `Persistent=true` en un temporizador y la tarea de `cron` equivalente cuando la máquina estaba apagada a la hora prevista?

<details>
<summary>Ver respuesta</summary>

`cron` solo ejecuta en el minuto exacto: si la máquina estaba apagada, esa
ejecución **se pierde** (para recuperarla se necesita `anacron`). Con
`Persistent=true`, systemd guarda cuándo se disparó el temporizador por
última vez y, al arrancar, lanza la ejecución que se perdió. Solo aplica a
`OnCalendar`, no a los temporizadores monotónicos.

</details>

6. ¿Por qué el `.cron` generado por `schedule gen` envuelve el comando en `guard` en lugar de ponerlo directo?

<details>
<summary>Ver respuesta</summary>

Una tarea programada corre sin nadie mirando, y los fallos silenciosos son el
antipatrón que este bootcamp combate. `guard` aporta lo de la Semana 15:
`flock` (no se solapa si la anterior sigue viva), `timeout` (no se cuelga para
siempre), un registro con el código final y un código de salida con
significado. Sin eso, una ejecución lenta se solapa con la siguiente y se van
acumulando procesos.

</details>

7. ¿Por qué `schedule gen` valida el nombre con una regex anclada **antes** de construir ninguna ruta, y por qué usa una lista blanca para el resto de valores?

<details>
<summary>Ver respuesta</summary>

El nombre forma parte de la ruta de salida: sin validar, `../x` o `/etc/x`
escribirían fuera del directorio pedido. La regex anclada (`^[a-z][a-z0-9-]{0,39}$`)
lo impide por construcción. Los valores que acaban en un archivo que **otro
programa interpretará** (`cron` o systemd) se comprueban con una lista blanca
de caracteres porque es más seguro enumerar lo permitido que intentar
adivinar todo lo peligroso (`;`, `$`, comillas, espacios, saltos de línea).

</details>

8. ¿Por qué `type -P` y no `which` ni el nombre a secas para resolver el comando programado?

<details>
<summary>Ver respuesta</summary>

El archivo generado lo ejecutará un entorno con otro `PATH`, así que necesita
una **ruta absoluta**. `type -P` devuelve solo la ruta de un ejecutable en el
`PATH`: ignora alias y funciones (que no existen en `cron`) y es una orden
interna de bash, mientras que `which` es un programa externo que cambia de
comportamiento entre distribuciones. Un `ExecStart=mi-script` a secas lo
rechaza systemd: pide una ruta absoluta.

</details>

9. `systemd-analyze verify` devolvió `0` para un `.service` con una tubería en `ExecStart`. ¿Significa que funcionará?

<details>
<summary>Ver respuesta</summary>

No. `verify` comprueba la **sintaxis** y que el binario exista, no la semántica
de lo que se ejecuta. systemd no usa un shell para `ExecStart`: una tubería, una
redirección o un `&&` se pasan como **argumentos literales** al primer
ejecutable. Si necesitas shell, se escribe explícitamente
`ExecStart=/bin/bash -c '...'` (con sus problemas de comillas), o mejor, se
programa un script. Tampoco detecta un `User=` inexistente.

</details>

10. Dame un criterio para elegir entre `cron` y un temporizador de systemd para una tarea nueva.

<details>
<summary>Ver respuesta</summary>

`cron` gana en portabilidad y sencillez: una línea, existe en todo servidor y
no depende de systemd (contenedores, sistemas mínimos). El temporizador gana
cuando necesitas **registro integrado** (`journalctl -u`), `Persistent=true`,
dependencias entre unidades, límites de recursos o un intervalo monotónico
real; a cambio son dos archivos y más sintaxis. La respuesta honesta es «el
que ya use esa máquina», y saber leer ambos, que es lo que `schedule` genera.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — `cron` en vivo y su entorno | Instala y arranca `cron`, respalda y restaura el crontab, reproduce el `PATH` mínimo, `dash` frente a `bash`, el `%` que corta el comando y la redirección al registro | 10 |
| 02 — `cron.d`, `run-parts` y trampas | Reproduce el campo de usuario de `/etc/cron.d`, los nombres con punto ignorados, `run-parts` con archivos no ejecutables, el OR de día del mes y día de la semana, el `*/7` y el crontab inválido que conserva el anterior | 10 |
| 03 — temporizadores de systemd sin systemd | Usa `systemd-analyze calendar`, `timespan` y `verify`, interpreta `OnCalendar` y `Persistent`, compara el calendario con el monotónico y reproduce los errores de `ExecStart` | 10 |
| 04 — `schedule` a mano | Rellena los ocho `TODO` por pasos con su verificación: `cron_expand`, `cron_parse` con el domingo, `schedule_check` con `1`/`2`, `schedule_calendar`, las validaciones, el `.cron` con `\%`, el `.service`/`.timer` con `%%`, y una ejecución real por `cron` | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (6 checks) | 4 |
| `schedule check`: 36 ejecuciones al día y `0`/`7` como el mismo domingo (2 checks) | 3 |
| `schedule check`: código `2` con valor fuera de rango y con menos de 5 campos (2 checks) | 2 |
| `schedule gen`: crea `.cron`, `.service` y `.timer` (1 check) | 2 |
| La línea de cron envuelve en `guard` con bloqueo y redirige a un registro (1 check) | 2 |
| El `%` sale como `\%` en el `.cron` (1 check) | 2 |
| El `.timer` lleva `OnCalendar` laborable y `Persistent=true` (1 check) | 2 |
| `systemd-analyze verify` acepta el `.service` y el `.timer` (1 check) | 1 |
| `gen` sale con `1` si los archivos existen sin `--force` (1 check) | 1 |
| `gen` rechaza con `1` un nombre que sale del directorio (1 check) | 2 |
| `gen` sale con `2` si restringes día del mes y día de la semana (1 check) | 1 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `cron_expand` devuelve valores ordenados y sin duplicados (`local -A`), usa `10#` en cada conversión y unifica `0`/`7` solo en el día de la semana | 2 |
| Nada se escribe hasta que todo es válido: nombre con regex anclada antes de la ruta, `type -P`, lista blanca y comprobación de existencia de los tres archivos | 2 |
| El `%` se escapa por sustitución y de forma distinta en cada formato (`\%` en cron, `%%` en systemd); el `.cron` fija `SHELL`, `PATH` y redirige siempre al registro | 2 |
| Cero `# shellcheck disable` sin justificar, errores de uso a `stderr` con `1` y expresiones inválidas con `2`, sin `eval` | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave o token con formato real comiteado | Grave |
| `crontab -r` o un `crontab archivo` que reemplaza el crontab sin respaldo previo (`crontab -l`) ni aviso | Grave |
| `eval` o `bash -c "$dato"` con datos de fuera del script | Grave |
| Una tarea de `cron`/systemd de ejemplo sin manejo de error ni registro | Grave |
| `gen` que deja archivos a medias cuando falla una validación | Moderada |
| `%` sin escapar en un `.cron` o con barra en un `.service` | Moderada |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Comando sin ruta absoluta en el archivo generado | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 16 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
