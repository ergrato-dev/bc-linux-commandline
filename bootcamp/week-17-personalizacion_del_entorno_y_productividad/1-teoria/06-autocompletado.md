# Autocompletado

> `Tab` es la tecla que más ahorra, y casi nadie sabe que es **programable**.
> Cualquier orden puede enseñarle a bash qué viene después de ella.

## 🎯 Objetivos

- Explicar qué hace bash al pulsar `Tab` y qué es el paquete `bash-completion`
- Usar `compgen` para generar candidatos y `complete` para registrarlos
- Escribir una función de autocompletado con `COMP_WORDS`, `COMP_CWORD` y `COMPREPLY`
- Dejar un autocompletado cargado de forma **perezosa** para tu usuario
- Saber qué paquete instalar en cada familia de distribuciones

## 1. Qué problema resuelve

Sin ayuda, `Tab` completa **nombres de archivo** y **órdenes**. Pero `git ch<Tab>`
sabe que quieres `checkout`, `systemctl st<Tab>` te propone `start`, `status` y
`stop`, y `ssh ser<Tab>` completa un servidor de tu `known_hosts`. Eso lo hace
**autocompletado programable**: para cada orden hay una función que decide
qué proponer según lo que ya escribiste. Y puedes darle uno a tu propio script.

## 2. Cómo funciona

### 2.1 El mecanismo

Al pulsar `Tab`, bash mira la **primera palabra** de la línea y busca una
«especificación de autocompletado» registrada para ella. Si hay una, la usa; si
no, completa archivos. Las especificaciones se registran con `complete`:

```bash
complete -W "start stop status" svc
complete -p svc
# complete -W 'start stop status' svc
complete -r svc
complete -p svc
# bash: complete: svc: no completion specification
```

`-W` es la forma más simple: una lista fija de palabras. `-p` imprime lo
registrado y `-r` lo quita.

### 2.2 `compgen`: generar candidatos

`compgen` es la herramienta que **produce** los candidatos, que luego tú filtras.
Con `-W` filtra una lista por un prefijo; con otras letras, genera directorios,
órdenes, alias...

```bash
compgen -W "alfa beta bravo" -- b
# beta
# bravo
compgen -d -- /tm
# /tmp
compgen -c -- tmu | sort -u
# tmux
```

| Opción | Genera |
|---|---|
| `-W "lista"` | palabras de la lista |
| `-d` | directorios |
| `-f` | archivos |
| `-c` | órdenes (ejecutables, alias, funciones) |
| `-A function` / `-A alias` | funciones / alias |
| `-A hostname` | nombres de `HOSTFILE` |

El `--` evita que un prefijo que empiece por `-` se tome como opción.

### 2.3 Una función de autocompletado

Para decisiones que dependen de lo escrito (`-F`), bash llama a **una función**
tuya y le deja tres variables:

| Variable | Qué tiene |
|---|---|
| `COMP_WORDS` | array con **todas las palabras** de la línea |
| `COMP_CWORD` | índice de la palabra en la que está el cursor |
| `COMPREPLY` | **tú lo rellenas**: los candidatos |

La función de `toolkit.sh`, que sugiere el subcomando en la primera posición, la
acción de `dotfiles` en la segunda, y sus opciones o directorios después:

```bash
_toolkit() {
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
  local subs="doctor inventory snapshot guard schedule dotfiles"
  if [[ $COMP_CWORD -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$subs" -- "$cur")
  elif [[ ${COMP_WORDS[1]} == dotfiles && $COMP_CWORD -eq 2 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "status link unlink" -- "$cur")
  elif [[ ${COMP_WORDS[1]} == dotfiles && $cur == -* ]]; then
    mapfile -t COMPREPLY < <(compgen -W "--repo --home --force --dry-run" -- "$cur")
  elif [[ $prev == --repo || $prev == --home ]]; then
    mapfile -t COMPREPLY < <(compgen -d -- "$cur")
  fi
}
complete -F _toolkit toolkit.sh
```

Dos detalles de la función. **Rellena `COMPREPLY` con `mapfile`** y no con
`COMPREPLY=($(compgen ...))`: la forma con `$( )` rompe los candidatos con
espacios y `shellcheck` la marca (SC2207). Y compara siempre con el **prefijo**
(`-- "$cur"`), que es lo que ya escribió quien pulsa `Tab`.

Con ella cargada, en una terminal real:

```
$ toolkit.sh sch<Tab>                      →  toolkit.sh schedule
$ toolkit.sh dotfiles l<Tab>               →  toolkit.sh dotfiles link
$ toolkit.sh dotfiles link --<Tab><Tab>    →  --dry-run  --force  --home  --repo
```

Cuando hay **varios** candidatos con prefijo común, `Tab` solo completa el
prefijo, y un segundo `Tab` los lista (con `show-all-if-ambiguous` del
[archivo 05](05-historial-y-readline.md), a la primera).

### 2.4 Carga perezosa

Registrar cientos de autocompletados al arrancar haría lento cada bash. Por eso
existe el paquete **`bash-completion`**: no registra cada uno, sino un cargador
(`_completion_loader`) que **la primera vez** que pulsas `Tab` en una orden busca
un archivo con ese nombre en estos directorios y lo carga:

```bash
bash -c 'source /usr/share/bash-completion/bash_completion; complete -p -D'
# complete -F _completion_loader -D
```

Ese `-D` es «la especificación por defecto»: sirve para cualquier orden sin una
propia. Los directorios donde busca incluyen el **de tu usuario**,
`~/.local/share/bash-completion/completions/`:

```bash
mkdir -p ~/.local/share/bash-completion/completions
cp comp ~/.local/share/bash-completion/completions/toolkit.sh
```

Con eso, en una terminal nueva:

```
$ complete -p toolkit.sh
bash: complete: toolkit.sh: no completion specification
$ toolkit.sh sch<Tab>                       →  toolkit.sh schedule
$ complete -p toolkit.sh
complete -F _toolkit toolkit.sh
```

Antes del primer `Tab`, nada registrado; después, la función cargada. Es la forma
de **no pagar** por lo que no usas, y el sitio correcto para el autocompletado de
tus propias herramientas: un archivo por orden, con **el nombre de la orden**.

### 2.5 Activar `bash-completion`

El paquete se llama **`bash-completion`** en las cuatro familias; cambia el gestor:

| Ubuntu/Debian | RHEL/Fedora | Arch |
|---|---|---|
| `apt install bash-completion` | `dnf install bash-completion` | `pacman -S bash-completion` |

Hay que **cargarlo** desde el `.bashrc`. El del esqueleto de Ubuntu ya lo
hace, y con una condición: no cargarlo si la shell va en modo POSIX.

```bash
sed -n 111,117p /etc/skel/.bashrc
# if ! shopt -oq posix; then
#   if [ -f /usr/share/bash-completion/bash_completion ]; then
#     . /usr/share/bash-completion/bash_completion
#   elif [ -f /etc/bash_completion ]; then
#     . /etc/bash_completion
#   fi
# fi
```

Si tu `.bashrc` no lo tiene (porque lo escribiste tú, o porque es el de una
imagen mínima de contenedor), añade ese bloque. Es lo que hacemos a mano en las
prácticas.

## 3. Cómo se usa

### 3.1 Un autocompletado para tu script

1. Escribe la función `_nombre` (2.3).
2. Guárdala en `~/.local/share/bash-completion/completions/NOMBRE`.
3. Abre una terminal nueva o `source` el archivo.

El archivo no necesita permisos de ejecución ni shebang: es código que se
**carga**. Y si tu herramienta tiene muchas acciones, el patrón es el de la
función de arriba: decidir por `COMP_CWORD` y por la palabra anterior (`prev`).

### 3.2 Qué hace `-o` en `complete`

| Opción | Efecto |
|---|---|
| `-o default` | Si tu función no da nada, completa **archivos** |
| `-o filenames` | Trata los candidatos como nombres de archivo (barra a los directorios, escapa espacios) |
| `-o nospace` | No añade el espacio tras completar (para continuar `--repo=`) |

### 3.3 Divergencia de distro

El paquete se llama igual en las cuatro familias. Lo que cambia es **quién trae
cada autocompletado**; en `ubuntu-lab` lo ves con `dpkg -S`:

```bash
dpkg -S /usr/share/bash-completion/completions/git /usr/share/bash-completion/completions/ssh
# git: /usr/share/bash-completion/completions/git
# bash-completion: /usr/share/bash-completion/completions/ssh
```

El de `git` lo trae el paquete `git`; el de `ssh`, `bash-completion`. Si falta
uno, mira primero si falta el paquete de la herramienta o `bash-completion`.
(En RHEL se consulta con `rpm -qf`, en Arch con `pacman -Qo`.)

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `COMPREPLY=($(compgen ...))` | Rompe candidatos con espacios (SC2207) | `mapfile -t COMPREPLY < <(...)` |
| Candidatos sin filtrar por `$cur` | `Tab` propone todo siempre | `compgen -W "..." -- "$cur"` |
| Un `complete -F` en el `.bashrc` por cada herramienta | Arranque lento | Archivo en `~/.local/share/bash-completion/completions/` |
| Autocompletado que ejecuta la orden (`ssh`, `git`, un `curl`) | Lento o con efectos secundarios en cada `Tab` | Solo leer archivos locales |
| Instalar `bash-completion` y no cargarlo | No hace nada | Descomentar el bloque del `.bashrc` |
| Nombre del archivo ≠ nombre de la orden | El cargador no lo encuentra | `toolkit.sh` para la orden `toolkit.sh` |
| Esperar completado en `sh`/`dash` | Es una función de bash/`readline` | Cambiar de shell |
| Dar la ruta de `~` entre comillas | No se expande | Sin comillas o `$HOME` |

## 5. Trucos

- **`complete -p`** (sin nombre) lista todo lo registrado; **`complete -p orden`**
  la especificación de una.
- **`set -x` dentro de la función** (o `echo ... >&2`) es la forma de depurarla:
  corre en cada `Tab`, así que su salida a `stderr` ensucia tu línea; quítalo después.
- **`COMP_LINE`** y **`COMP_POINT`** tienen la línea entera y la posición del
  cursor, por si necesitas algo más fino que `COMP_WORDS`.

## 📚 Recursos Adicionales

- `man bash`, sección **Programmable Completion**
- [`bash-completion`: README y FAQ](https://github.com/scop/bash-completion)

## ✅ Checklist de Verificación

- [ ] Registras un `complete -W` y lo quitas con `complete -r`
- [ ] Generas candidatos con `compgen -W`, `-d` y `-c`
- [ ] Escribes `_toolkit` y compruebas `Tab` en `toolkit.sh sch`
- [ ] Rellenas `COMPREPLY` con `mapfile` y explicas por qué
- [ ] Dejas el autocompletado en `~/.local/share/bash-completion/completions/` y ves que se carga al primer `Tab`
- [ ] Sabes el nombre del paquete en cada familia

---

[← Historial y `readline`](05-historial-y-readline.md) · [Sesiones persistentes con tmux →](07-sesiones-persistentes-tmux.md)
