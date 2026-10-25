# Historial y `readline`

> Teclear menos es la mejora de productividad más barata que existe.
> bash guarda lo que escribes y `readline` te da atajos para recuperarlo y editarlo.

## 🎯 Objetivos

- Configurar cuánto, cómo y cuándo se guarda el historial
- Compartir el historial entre varias terminales
- Recuperar órdenes con `Ctrl-R`, `!!`, `!$`, `!cadena` y `fc`
- Usar los atajos de edición de `readline` y consultarlos con `bind -P`
- Cambiar el comportamiento de `readline` con `~/.inputrc`
- Evitar que una contraseña escrita en la línea de órdenes acabe en el archivo del historial

## 1. Qué problema resuelve

Dos problemas opuestos:

- Escribiste hace una hora una orden larga, y no recuerdas cómo era.
- Escribiste una contraseña en una orden, y ahora está en un archivo de texto.

El historial lo resuelve **si lo configuras**: bash guarda por defecto pocas
órdenes, y las guarda al salir, con lo que dos terminales se pisan.

## 2. Cómo funciona

### 2.1 Tres variables y un archivo

| Variable | Qué es | Valor en el `.bashrc` de Ubuntu |
|---|---|---|
| `HISTSIZE` | Órdenes que recuerda la shell **en memoria** | `1000` |
| `HISTFILESIZE` | Líneas que guarda el **archivo** | `2000` |
| `HISTFILE` | El archivo | `~/.bash_history` |

La shell **escribe el archivo al salir**, no antes. Y `shopt -s histappend` hace
que **añada** al archivo en lugar de sobrescribirlo (sin él, la última terminal
que cierras pisa a las demás). El `.bashrc` de Ubuntu ya lo activa.

El archivo se crea con permisos `600`, aunque tu `umask` sea abierto:

```bash
(umask 000; env -i HOME=/tmp/t17 PATH=/usr/bin:/bin HISTFILE=/tmp/t17/h2 bash --norc -i <<< "echo x" >/dev/null 2>&1; stat -c %a /tmp/t17/h2)
# 600
```

### 2.2 Qué se guarda

`HISTCONTROL` filtra lo que entra:

| Valor | Efecto |
|---|---|
| `ignorespace` | No guarda las órdenes que **empiezan por espacio** |
| `ignoredups` | No guarda una orden igual a la anterior |
| `ignoreboth` | Las dos anteriores |
| `erasedups` | Borra del historial las repetidas anteriores |

Con `HISTCONTROL=ignorespace:ignoredups`, en una sesión real:

```
$ echo uno
uno
$  echo secreto         <- empieza por espacio: no se guarda
secreto
$ echo uno              <- igual a la última guardada: no se guarda
uno
$ history
    1  echo uno
    2  history
```

Es el truco para **no guardar una contraseña**: escribe un espacio antes. Falla
si `HISTCONTROL` no está definido, así que compruébalo (`echo $HISTCONTROL`).

`HISTIGNORE` filtra por patrón: `HISTIGNORE="ls:cd:pwd"` descarta esas órdenes
(solo si son **exactamente** eso). Y `HISTTIMEFORMAT` añade la fecha a cada
entrada:

```
$ HISTTIMEFORMAT="%F %T  "
$ history 2
    1  2026-10-25 05:35:21  echo uno
    2  2026-10-25 05:35:25  history 2
```

Con `HISTTIMEFORMAT` definida al guardar, el archivo lleva una línea `#` con la
hora UNIX antes de cada orden (`#1792906374`).

### 2.3 Compartir entre terminales

El historial de una terminal no llega a las otras hasta que sale. Tres órdenes lo
manejan:

| Orden | Hace |
|---|---|
| `history -a` | **Añade** al archivo lo de esta sesión que aún no esté |
| `history -n` | **Lee** del archivo lo nuevo que escribieron otras |
| `history -r` | Relee el archivo entero |

Desde la terminal A (`echo desde-a` y `history -a`), la B pone al día con
`history -n`:

```
B$ history -n
B$ history
    1  history -n
    2  echo desde-a
    3  history -a
    4  history
```

Para que sea automático: `PROMPT_COMMAND='history -a'` en el `.bashrc`
(archivo [04](04-el-prompt-ps1.md)). Con eso cada orden queda en el archivo al
instante y otra terminal nueva la verá. La contrapartida es que el historial de
**cada** terminal ya no es suyo: se mezcla con el de las demás.

### 2.4 Recuperar lo escrito

**`Ctrl-R`** busca hacia atrás **mientras escribes**; otro `Ctrl-R` va a la
coincidencia anterior; `Enter` ejecuta, `→` o `Ctrl-E` te deja editarla:

```
(reverse-i-search)`desde-a': echo desde-a
```

(`Ctrl-S` busca hacia delante, pero en muchos terminales `Ctrl-S` **congela** la
pantalla, por el control de flujo `ixon`; `Ctrl-Q` la libera. Quítalo con
`stty -ixon`, y solo en una shell interactiva.)

**La expansión de historial** (con `!`):

| Escribes | Se convierte en |
|---|---|
| `!!` | la orden anterior entera |
| `!$` | el **último argumento** de la orden anterior |
| `!*` | todos los argumentos de la anterior |
| `!echo` | la última orden que **empezó** por `echo` |
| `!?xyz?` | la última que **contiene** `xyz` |
| `!42` | la orden número 42 del historial |
| `^uno^dos` | repite la anterior cambiando `uno` por `dos` |

```
$ echo uno dos tres
uno dos tres
$ echo !$
echo tres
tres
$ ^tres^cuatro
echo cuatro
cuatro
```

El caso más útil: `sudo !!` repite la orden anterior con privilegios (es decir,
`sudo` + la orden; sin `sudo` instalado en `ubuntu-lab` no lo probamos aquí).
Antes de pulsar Enter puedes ver el resultado con **`Alt-^`**
(`history-expand-line`) o añadir `:p` (`!!:p` solo lo **imprime**).

**`fc`** abre la última orden en tu `$EDITOR` y la ejecuta al cerrar; con `-l`
lista, y `-ln -2` lista las dos últimas sin números:

```
$ fc -ln -2
         echo otro
         echo xyz
```

Para borrar una entrada concreta (la contraseña que se coló): `history -d N`; y
`history -c` vacía la memoria (no el archivo hasta que se escriba).

### 2.5 `readline`: la edición de la línea

Todo lo anterior vive en la biblioteca `readline`, que usa también `python`,
`psql` o `mysql`. Por defecto va en modo **emacs**. Los atajos que de verdad se
usan (los lees con `bind -P`):

| Tecla | Hace | Nombre en `readline` |
|---|---|---|
| `Ctrl-A` / `Ctrl-E` | principio / fin de línea | `beginning-of-line` / `end-of-line` |
| `Alt-B` / `Alt-F` | palabra atrás / adelante | `backward-word` / `forward-word` |
| `Ctrl-W` | borra la palabra anterior | `unix-word-rubout` |
| `Ctrl-U` / `Ctrl-K` | borra hasta el principio / hasta el final | `unix-line-discard` / `kill-line` |
| `Ctrl-Y` | pega lo borrado | `yank` |
| `Alt-.` | pega el **último argumento** de la orden anterior | `yank-last-arg` |
| `Ctrl-L` | limpia la pantalla | `clear-screen` |
| `Ctrl-T` | intercambia dos caracteres | `transpose-chars` |
| `Ctrl-_` | deshace | `undo` |
| `Ctrl-X Ctrl-E` | edita la línea en `$EDITOR` | `edit-and-execute-command` |
| `Ctrl-O` | ejecuta y trae la **siguiente** del historial | `operate-and-get-next` |
| `Alt-*` | inserta **todas** las coincidencias del comodín | `insert-completions` |

`Ctrl-X Ctrl-E` es la salida cuando una orden se vuelve larga: la editas con
todo tu editor. Y `set -o vi` cambia a modo vi (`Esc` para ir a modo comando).

### 2.6 Cambiar `readline`: `~/.inputrc`

`readline` lee `~/.inputrc` (o el archivo de `$INPUTRC`) al arrancar. Con tres
líneas cambia tu forma de completar:

```
set completion-ignore-case on
set show-all-if-ambiguous on
"\e[A": history-search-backward
"\e[B": history-search-forward
```

Y mide la diferencia con directorios `Docs`, `Downloads` y `Music`:

```
sin .inputrc:   $ cd mus<Tab>        no pasa nada (sensible a mayúsculas)
con .inputrc:   $ cd mus<Tab>        $ cd Music/
                $ cd d<Tab>          Docs/      Downloads/    (lista a la primera)
```

Las dos últimas líneas hacen que **flecha arriba** busque en el historial lo que
**empieza** por lo que ya escribiste: con `echo ` escrito, `↑` salta a la última
orden `echo`. Es el cambio que más se nota. Los valores por defecto los ves así:

```bash
bind -v | grep -E 'completion-ignore-case|show-all-if-ambiguous'
# set completion-ignore-case off
# set show-all-if-ambiguous off
```

`bind` también cambia una tecla **en caliente**, sin editar el archivo:
`bind '"\C-p": history-search-backward'`.

## 3. Cómo se usa

### 3.1 Una configuración razonable

```bash
# ~/.bashrc
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE='ls:cd:pwd:clear'
HISTTIMEFORMAT='%F %T  '
shopt -s histappend
PROMPT_COMMAND='history -a'
stty -ixon 2>/dev/null
```

### 3.2 Que una contraseña no se guarde

1. Mejor: **no la escribas en la línea de órdenes**; `read -s` o un archivo `600`.
2. Si no hay más remedio, un **espacio delante** (con `ignorespace`).
3. Si ya se coló: `history -d N` y `history -w` para reescribir el archivo.

### 3.3 Divergencia de distro

`HISTSIZE` y `HISTCONTROL` se fijan en sitios distintos: en el `.bashrc` del
esqueleto (Ubuntu/Debian) o en `/etc/profile` (RHEL, que exporta
`HISTSIZE` y `HISTCONTROL`). Compruébalo con `echo $HISTSIZE $HISTCONTROL $HISTFILESIZE`
en cada máquina antes de asumir.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir una contraseña en la línea de órdenes | Queda en el historial **y** en `ps` | `read -s`, o un archivo `600` |
| `HISTSIZE=0` o `unset HISTFILE` «por seguridad» | Pierdes la herramienta más útil | `ignorespace` para lo sensible |
| Sin `histappend` y dos terminales abiertas | La última en cerrar borra lo de la otra | `shopt -s histappend` |
| `HISTCONTROL=erasedups` + `history -a` sin pensarlo | El historial deja de ser cronológico | Entender el compromiso o quitar `erasedups` |
| `!!` sin mirar | Ejecuta la última orden, que puede ser destructiva | `!!:p` primero, o `Alt-^` |
| `sudo !!` tras un `rm` | Repites el borrado como root | Mira la orden antes |
| Atajos de otra distro en un script | `readline` solo existe en interactivo | Nada: no es para scripts |
| Editar `/etc/inputrc` | Afecta a todos los usuarios | `~/.inputrc` |

## 5. Trucos

- **`!$` y `Alt-.`** hacen lo mismo; `Alt-.` te lo enseña **antes** de ejecutar.
  Repítelo para ir a argumentos más antiguos.
- **`Ctrl-X Ctrl-E`**: la orden larga, en tu editor.
- **`HISTTIMEFORMAT= history | awk '{print $2}' | sort | uniq -c | sort -rn | head`**:
  tus órdenes más usadas, candidatas a alias (la Semana 08 en acción). El
  `HISTTIMEFORMAT=` vacío quita las fechas solo para esa orden.
- **`HISTFILE=/dev/null bash`**: una shell cuyo historial no se guarda, sin tocar
  tu configuración.

## 📚 Recursos Adicionales

- `man bash`, secciones **HISTORY** y **READLINE**
- `man readline` y `bind -P` para la lista completa de funciones
- [GNU Readline: Init File](https://tiswww.case.edu/php/chet/readline/rluserman.html)

## ✅ Checklist de Verificación

- [ ] Compruebas `HISTSIZE`, `HISTFILESIZE` y `HISTCONTROL` en tu shell
- [ ] Una orden con espacio delante no aparece en `history`
- [ ] Compartes el historial entre dos terminales con `history -a` y `history -n`
- [ ] Recuperas una orden con `Ctrl-R`, `!$` y `^uno^dos`
- [ ] Consultas el nombre de un atajo con `bind -P`
- [ ] Cambias `completion-ignore-case` en `~/.inputrc` y ves el efecto

---

[← El prompt (`PS1`)](04-el-prompt-ps1.md) · [Autocompletado →](06-autocompletado.md)
