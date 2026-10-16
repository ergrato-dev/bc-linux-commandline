# Rúbrica de Evaluación — Semana 10

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. ¿Por qué `kill -9` sobre un proceso zombie reporta éxito pero no cambia nada?

<details>
<summary>Ver respuesta</summary>

Un zombie ya terminó — no hay nada vivo que reciba la señal, el kernel
solo mantiene su entrada en la tabla de procesos hasta que el padre
llame a `wait()`. `kill` reporta éxito (el PID existe), pero no hay
proceso real sobre el que actuar.

</details>

2. ¿Qué hace que un proceso se vuelva huérfano, y quién lo adopta?

<details>
<summary>Ver respuesta</summary>

Su padre termina antes que él, sin esperarlo. El kernel reasigna su
PPID a `1` (init/systemd en un sistema real) — ese proceso adoptivo es
responsable de reaparentarlo, no de limpiarlo automáticamente.

</details>

3. ¿Por qué `pgrep` (sin `-f`) puede no encontrar un proceso que claramente está corriendo?

<details>
<summary>Ver respuesta</summary>

Por defecto compara contra `comm`, truncado a 15 caracteres — si el
patrón de búsqueda tiene más de 15 caracteres, o si busca algo que
solo aparece en los argumentos (no en el nombre del ejecutable), no va
a coincidir.

</details>

4. ¿Qué diferencia a `SIGTSTP` de `SIGSTOP` en un proceso en segundo plano sin control de trabajos activo?

<details>
<summary>Ver respuesta</summary>

`SIGSTOP` siempre detiene el proceso, sin excepción. `SIGTSTP` (la
señal de `Ctrl+Z`) puede ser descartada silenciosamente por el kernel
cuando el proceso está en un grupo sin asociación real de terminal/job
control — el comportamiento documentado para grupos de procesos
huérfanos.

</details>

5. ¿Por qué `trap ... EXIT` corre incluso cuando un script falla a mitad de camino bajo `set -e`?

<details>
<summary>Ver respuesta</summary>

El trap `EXIT` está diseñado para disparar en cualquier forma en que
el script termine, incluida la terminación anticipada por `set -e` —
es precisamente lo que lo hace confiable como mecanismo de limpieza
garantizada.

</details>

6. ¿Qué significa el código de salida 143 después de `wait` sobre un proceso terminado?

<details>
<summary>Ver respuesta</summary>

`128 + 15`: el proceso terminó por `SIGTERM` (señal número 15). La
convención `128+N` identifica, a partir del código de salida, qué
señal causó la terminación.

</details>

7. ¿Por qué `exec -a nombre-falso` no engaña a `pgrep` (sin `-f`)?

<details>
<summary>Ver respuesta</summary>

`exec -a` solo cambia `argv[0]`/la línea de comando mostrada, no el
campo `comm` del kernel — `pgrep` sin `-f` compara contra `comm`, que
sigue siendo el nombre real del binario, nunca el alias.

</details>

8. ¿Cuál es el riesgo real de `pkill -f "patron"` dentro de un script?

<details>
<summary>Ver respuesta</summary>

Si el patrón de búsqueda aparece, por coincidencia, en los propios
argumentos con los que se invocó el script, `pkill -f` puede
coincidir con el script mismo y terminarlo — sin ninguna advertencia
previa.

</details>

9. ¿Qué diferencia a `disown` de matar un proceso?

<details>
<summary>Ver respuesta</summary>

`disown` solo quita el trabajo de la lista de `jobs` de la shell
actual (y, sin argumentos adicionales, lo protege de recibir
`SIGHUP` al cerrar la terminal) — el proceso sigue corriendo
normalmente, no se le envía ninguna señal.

</details>

10. ¿Por qué `procwatch` clasifica cada PID por STAT antes de considerar cualquier señal?

<details>
<summary>Ver respuesta</summary>

Porque enviar una señal a un zombie "tiene éxito" sin ningún efecto
real — reportar el estado de cada PID antes de actuar evita confundir
"la señal no tuvo efecto" con "el proceso efectivamente respondió".

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — ps y estados de proceso | Lee columnas, cambia STAT con SIGSTOP/CONT, visualiza jerarquía | 10 |
| 02 — zombies, huérfanos y trabajos | Crea un zombie real, confirma que kill no tiene efecto, usa disown | 10 |
| 03 — señales y trap | Confirma TERM ignorable/KILL no, calcula 128+N, verifica trap EXIT | 10 |
| 04 — procwatch con pipes reales | Construye a mano el pipeline completo de búsqueda/clasificación/decisión | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| Regresión de subcomandos anteriores (1 check) | 2 |
| `procwatch`: validación de entrada y casos sin coincidencias (3 checks) | 6 |
| `procwatch`: detección de procesos vivos y zombies (3 checks) | 9 |
| `procwatch`: dry-run y `--apply` (2 checks) | 8 |

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `shellcheck` limpio sobre el starter completo | 3 |
| Usa `pgrep -a` sin `-f`, documentando por qué | 2 |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Enviar una señal real sin que el usuario pase `--apply` | Grave |
| Intentar enviar una señal a un zombie sin detectarlo primero | Grave |
| `sudo su -`/`sudo bash` en cualquier ejemplo | Grave |
| Comando destructivo sin aviso previo | Grave |
| Secreto comiteado (clave, token con formato real) | Grave |
| `shellcheck` con hallazgos sin justificar | Moderada |

---

[← Proyecto: Capa 10 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
