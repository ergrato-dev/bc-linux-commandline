# Rúbrica de Evaluación — Semana 17

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. Entras por SSH y tus alias no existen, pero al abrir otra `bash` dentro sí. ¿Qué pasa y cómo se arregla?

<details>
<summary>Ver respuesta</summary>

SSH abre una shell de **login**, que lee `~/.bash_profile`, `~/.bash_login` o
`~/.profile` (el **primero que exista**) y **no** `~/.bashrc`. La `bash` que
abres dentro es interactiva sin login, y esa sí lee `~/.bashrc`. En Ubuntu el
`.profile` ya carga `.bashrc`; el fallo típico es crear un `~/.bash_profile` «para
el `PATH`», que tapa al `.profile` y rompe esa cadena. Se arregla haciendo que el
`.bash_profile` cargue `~/.profile` (o `~/.bashrc`).

</details>

2. ¿Por qué una variable sin `export` no llega a un script que lanzas, y por qué lo que el script cambia no vuelve a tu shell?

<details>
<summary>Ver respuesta</summary>

Cada proceso hijo recibe una **copia** del entorno del padre, y solo de las
variables marcadas con `export`. Una variable normal es local a la shell. La
copia es de ida: el hijo modifica la suya y al terminar desaparece, así que el
padre sigue viendo su valor original. Para fijarla solo en un comando se usa
`VAR=valor comando`, que no deja rastro en la shell.

</details>

3. Instalaste una versión nueva de un programa delante en el `PATH` y la shell sigue ejecutando la vieja. ¿Por qué y qué haces?

<details>
<summary>Ver respuesta</summary>

Bash guarda en una caché (`hash`) dónde encontró cada comando y no vuelve a
buscarlo. `hash -t nombre` enseña la ruta recordada y `hash -r` la borra (volver
a asignar `PATH` también la limpia). `type -a nombre` lista todas las
candidatas por orden de `PATH`, que es el orden de prioridad.

</details>

4. ¿Por qué `ll` funciona en tu terminal pero no en un script, y qué usarías en su lugar?

<details>
<summary>Ver respuesta</summary>

Los alias se expanden solo en shells interactivas (en un script hace falta
`shopt -s expand_aliases`, y aun así no se expanden en la misma línea donde se
definen). Para un script se usa una **función** o la orden completa. Cuando algo
necesita argumentos en medio o cambiar tu directorio (`mkcd`), también es una
función. Para saltarte un alias existente: `\cmd` o `command cmd`.

</details>

5. ¿Qué diferencia hay entre `PS1="[$?] \$ "` y `PS1='[$?] \$ '`?

<details>
<summary>Ver respuesta</summary>

Con comillas **dobles** la shell expande `$?` **una vez, al asignar**, y la
barra de `\$` se consume: el prompt queda congelado. Con comillas **simples** el
texto llega literal a `PS1` y bash lo expande **cada vez que pinta el prompt**,
por eso `$?` y `$(git ...)` reflejan el estado actual. Los colores se rodean con
`\[` y `\]` para que `readline` no cuente los caracteres invisibles y calcule bien
el ancho de la línea.

</details>

6. ¿Cómo evitas que una contraseña escrita en una orden entre al historial, y qué hace `history -a`?

<details>
<summary>Ver respuesta</summary>

Con `HISTCONTROL=ignorespace` una orden que empieza por un espacio no se guarda
(o `HISTIGNORE` para patrones concretos). El historial en memoria se escribe a
`~/.bash_history` **al salir** de la shell; con varias terminales gana la última.
`history -a` añade ya las líneas nuevas al archivo y `history -n` lee las de las
otras; junto a `shopt -s histappend` repartes el historial entre sesiones. El
archivo se crea con permisos `600`.

</details>

7. En una función de autocompletado, ¿qué contienen `COMP_WORDS`, `COMP_CWORD` y `COMPREPLY`, y por qué se rellena con `mapfile`?

<details>
<summary>Ver respuesta</summary>

`COMP_WORDS` es el array con las palabras de la línea, `COMP_CWORD` el índice de
la que tiene el cursor y `COMPREPLY` es la salida: lo que **tú** rellenas con los
candidatos. `mapfile -t COMPREPLY < <(compgen -W "..." -- "$cur")` conserva un
elemento por línea; `COMPREPLY=($(compgen ...))` parte por espacios y `shellcheck`
lo marca (SC2207). El `-- "$cur"` filtra por lo ya escrito.

</details>

8. ¿Qué ventaja tiene dejar el autocompletado en `~/.local/share/bash-completion/completions/` frente a un `complete -F` en el `.bashrc`?

<details>
<summary>Ver respuesta</summary>

Es **carga perezosa**: con `bash-completion` cargado, la primera vez que pulsas
`Tab` en una orden, el cargador busca un archivo con **su nombre** y lo carga.
No se paga por lo que no usas: cada arranque de la shell no ejecuta cientos de
definiciones. Antes del primer `Tab`, `complete -p orden` dice que no hay
especificación. El nombre del archivo tiene que ser el de la orden.

</details>

9. Se cae tu conexión SSH en mitad de una copia de una hora. ¿Qué habría que haber hecho y por qué funciona?

<details>
<summary>Ver respuesta</summary>

Lanzarla dentro de `tmux` (`tmux new-session -A -s trabajo`). Al cerrarse la
conexión, el kernel manda `SIGHUP` a la shell y esta a sus hijos; pero el servidor
de `tmux` es un proceso aparte que **no depende de tu terminal**, así que la
sesión y lo que corre dentro siguen vivos. Al reconectar, `tmux attach` (o el
mismo `-A`) te devuelve a ella. No sustituye a `cron` o a un temporizador para
tareas que deban sobrevivir a un reinicio.

</details>

10. `toolkit dotfiles link` encuentra que `~/.gitconfig` ya existe como archivo real. ¿Qué hace sin `--force`, con `--force` y por qué no enlaza los demás archivos mientras tanto?

<details>
<summary>Ver respuesta</summary>

Sin `--force` imprime el conflicto, sale con código `2` y **no cambia nada**: ni
siquiera enlaza los archivos que sí podría, porque `dotfiles_link_check` valida
**todo antes de tocar nada** y un `link` a medias dejaría el home en un estado
difícil de explicar y de deshacer. Con `--force` mueve el original a
`.gitconfig.toolkit-bak` y crea el enlace, salvo que ya exista ese respaldo
(entonces también se niega: no se pisa un respaldo) o que el destino sea un
directorio (nunca se reemplaza). `unlink` quita los enlaces propios y devuelve el
respaldo a su sitio.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — El arranque de la shell y el `PATH` | Distingue login e interactiva, reproduce los cuatro arranques con su archivo, el «solo el primero» y `.bash_logout`, la trampa del `.bash_profile`, `export` y herencia, el orden del `PATH`, la caché de `hash`, `~/bin` solo en el login y la adición sin duplicar | 10 |
| 02 — Alias, prompt e historial | Reproduce los tres casos en que un alias no se expande, `mkcd` y la precedencia alias/función, prueba un `PS1` con `${PS1@P}` y en vivo (código de salida, rama), `ignorespace`, `history -a`/`-n` y `~/.inputrc` | 10 |
| 03 — Autocompletado y `tmux` | `complete -W`/`compgen`, `_toolkit` con `COMP_WORDS` limpio de `shellcheck`, carga perezosa, sesión que sobrevive a otra llamada, `tmux.conf` leído con `show-options` y `screen` | 10 |
| 04 — `dotfiles` a mano | Rellena los ocho `TODO` por pasos con su verificación: `dotfiles_list`, `dotfiles_state` con `-L` primero, `dotfiles_parse`, `dotfiles_prepare` con `pwd -P`, `status` con código `2`, `link_check`, `link` con respaldo y `--dry-run` y `unlink`; cierra con `shellcheck` y un alias en una shell real | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (6 checks) | 4 |
| `dotfiles status`: cuenta 2 que faltan ignorando README y ocultos, y sale con `2` (2 checks) | 2 |
| `dotfiles` sale con `1` si el repositorio no existe (1 check) | 1 |
| `dotfiles link` crea los enlaces simbólicos al repositorio (1 check) | 2 |
| `dotfiles link` es idempotente (1 check) | 2 |
| `dotfiles status` informa `ok=2` y sale con `0` (1 check) | 1 |
| `link` con un archivo real sale con `2` sin `--force` (1 check) | 2 |
| Con un conflicto, `link` no crea nada ni modifica el archivo real (1 check) | 2 |
| `link --force` guarda el original como `.toolkit-bak` y enlaza (1 check) | 2 |
| `link --dry-run` no crea ningún enlace (1 check) | 2 |
| `unlink` quita los enlaces y restaura el original (1 check) | 1 |
| `unlink` no borra un archivo real que no es un enlace del repositorio (1 check) | 1 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `dotfiles_link_check` se ejecuta antes de cualquier `mv` o `ln`; directorios nunca reemplazados y respaldos existentes nunca pisados | 2 |
| `dotfiles_state` pregunta por `-L` primero y compara con la ruta física (`pwd -P`); `unlink` borra solo el estado `ok` | 2 |
| `--dry-run` imprime las mismas líneas con prefijo y no llama a `mv` ni a `ln`; opciones inválidas rechazadas con `1` y a `stderr` | 2 |
| Cero `# shellcheck disable` sin justificar, asignación y `local` separados donde se captura una salida, sin `eval` ni `export` innecesarios | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave o token con formato real comiteado (también dentro de un «dotfile» de ejemplo) | Grave |
| Probar `link --force` contra tu home real sin `--dry-run` ni respaldo previo | Grave |
| `rm -rf` o `kill` sobre algo real sin aviso ni respaldo | Grave |
| `link` que deja el home a medias cuando hay un conflicto | Moderada |
| `unlink` que borra algo que no es un enlace a este repositorio | Grave |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Pegar un `bash_completion` o un `.bashrc` ajeno sin leerlo | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 17 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
