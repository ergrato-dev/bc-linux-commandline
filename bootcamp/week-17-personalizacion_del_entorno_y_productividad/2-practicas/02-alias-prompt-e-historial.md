# Práctica 02 — Alias, prompt e historial

> Duración estimada: 60 min · Teoría de apoyo: archivos [03](../1-teoria/03-alias-y-funciones.md), [04](../1-teoria/04-el-prompt-ps1.md) y [05](../1-teoria/05-historial-y-readline.md)

Sigues **dentro de `ubuntu-lab`** (con `tmux`, `bash-completion` y `git` ya
instalados en la práctica 01). Todo lo interactivo (un prompt, el historial, una
tecla `Tab`) se prueba con **`tmux` sin terminal**: tú «tecleas» con `send-keys` y
«miras» con `capture-pane`. Es la técnica de la
[teoría 07](../1-teoria/07-sesiones-persistentes-tmux.md).

```bash
docker exec -it ubuntu-lab bash
mkdir -p /tmp/p17/h4 && cd /tmp/p17
```

## Paso 1: Alias que no se expanden

**Por qué**: la mitad de los «mi alias no funciona» son estos tres casos: un
script, la misma línea, y la segunda palabra.

**Comando**:

```bash
# 1. En un script: los alias son para la shell interactiva.
printf 'alias ll="ls -l"\nll /tmp/p17\n' > al.sh
bash al.sh 2>&1 | head -2
# al.sh: line 2: ll: command not found
# 2. En la misma linea donde se definen (con expand_aliases activo, linea a linea):
printf 'shopt -s expand_aliases\nalias zz="echo zz"; zz\nzz\n' > a3.sh
bash a3.sh 2>&1
# a3.sh: line 2: zz: command not found
# zz
# 3. Como segunda palabra: solo funciona si el alias anterior acaba en espacio.
alias ll="ls -d"
alias ve="env "
ve ll /tmp
# /tmp
alias ve2="env"
ve2 ll /tmp
# env: 'll': No such file or directory
unalias ll ve ve2
```

**Verifica**:

```bash
bash -c 'shopt -s expand_aliases
alias sal="echo alias-ok"
sal'
# alias-ok
```

## Paso 2: Funciones, precedencia y cómo saltarte un alias

**Por qué**: lo que necesita un argumento en medio, o cambiar **tu** directorio,
es una función. Y cuando un alias te estorba, `\cmd` y `command cmd` lo evitan.

**Comando**:

```bash
# mkcd: el cd cambia TU shell porque la funcion corre en ella.
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
mkcd /tmp/p17/m/n
pwd
# /tmp/p17/m/n
cd /tmp/p17
# local y return:
doble() { local n=$1; echo $(( n * 2 )); return 3; }
doble 4
# 8
echo "rc=$?"
# rc=3
# Un alias gana a una funcion del mismo nombre, hasta que lo borras:
f() { echo funcion; }
alias f="echo alias"
f
# alias
unalias f
f
# funcion
# Saltarse un alias:
alias date="echo ALIAS-date"
date +%Y
# ALIAS-date +%Y
\date +%Y >/dev/null && echo "con barra: ok"
# con barra: ok
command date +%Y >/dev/null && echo "con command: ok"
# con command: ok
unalias date
```

**Verifica**:

```bash
type -t mkcd doble f
# function
# function
# function
```

## Paso 3: Probar un `PS1` sin abrir otra terminal

**Por qué**: `${PS1@P}` expande una cadena **como si fuera un prompt**. Es la
forma más rápida de iterar. Se hace dentro de un subshell `( ... )` para no
cambiar el prompt de tu sesión.

**Comando**:

```bash
# Comillas SIMPLES: con dobles, bash se come la barra de \$ y siempre sale "$".
(cd /tmp; PS1='\u@\h:\w\$ '; echo "[${PS1@P}]")
# [root@ubuntu-lab:/tmp# ]
(cd /usr/share; PS1='\W \$ '; echo "[${PS1@P}]")
# [share # ]
# Color: \[ y \] rodean lo invisible. printf %q enseña los codigos reales.
(PS1='\[\e[32m\]\u\[\e[0m\]\$ '; printf '%q\n' "${PS1@P}")
# $'\E[32mroot\E[0m# '
```

**Verifica**:

```bash
(PS1='\u@\h'; echo "${PS1@P}")
# root@ubuntu-lab
```

## Paso 4: Un prompt vivo, dentro de `tmux`

**Por qué**: `$?` y `$(git ...)` en `PS1` solo se ven **cada vez que se pinta**,
y eso necesita una shell interactiva. Defines tres ayudas para arrancar una,
teclear y mirar.

**Comando**:

```bash
mkdir -p /tmp/p17/h4/proy/a/b/c/d /tmp/p17/h4/repo
git -C /tmp/p17/h4/repo init -q -b principal
cat > /tmp/p17/h4/rc << 'EOF'
cd /tmp/p17/h4
__rama() { git branch --show-current 2>/dev/null; }
PS1='[$?] \u@\h \W $(__rama)\$ '
PROMPT_DIRTRIM=2
EOF
# Una shell interactiva y LIMPIA (env -i) en tmux, con tu archivo de arranque:
nueva() {
  tmux kill-server 2>/dev/null
  tmux new-session -d -s p -x 80 -y 24 "env -i HOME=/tmp/p17/h4 TERM=xterm PATH=/usr/bin:/bin INPUTRC=${2:-/dev/null} bash --noprofile --rcfile $1 -i"
  sleep 0.6
}
teclea() { tmux send-keys -t p "$@"; sleep 0.4; }
ver() { tmux capture-pane -p -t p | sed '/^$/d' | tail -"${1:-1}"; }
nueva /tmp/p17/h4/rc
ver 1
# [0] root@ubuntu-lab ~ #
teclea "false" Enter; ver 1
# [1] root@ubuntu-lab ~ #
teclea "cd /tmp/p17/h4/repo" Enter; ver 1
# [0] root@ubuntu-lab repo principal#
teclea "cd /tmp/p17/h4/proy/a/b/c/d" Enter; ver 1
# [0] root@ubuntu-lab d #
teclea 'PS1="\w \$ "' Enter; ver 1
# ~/.../c/d $
tmux kill-server
```

El `[1]` aparece **después** de un `false`, y la rama solo dentro del repositorio.
El último prompt usa `\w` y `PROMPT_DIRTRIM=2` lo recorta a `~/.../c/d` (el
`HOME` de esta shell es `/tmp/p17/h4`, de ahí el `~`).

**Verifica**:

```bash
nueva /tmp/p17/h4/rc
teclea "false" Enter "true" Enter
ver 1 | grep -c '^\[0\]'
# 1
tmux kill-server
```

## Paso 5: Historial: qué se guarda y qué no

**Por qué**: con `ignorespace` una orden con un espacio delante **no entra** al
historial (el truco para una contraseña), `ignoredups` descarta repetidas y
`HISTIGNORE` filtra por patrón.

**Comando**:

```bash
cat > /tmp/p17/h4/rc2 << 'EOF'
PS1='$ '
HISTFILE=/tmp/p17/h4/hist
HISTCONTROL=ignorespace:ignoredups
HISTIGNORE='ls:pwd'
shopt -s histappend
EOF
rm -f /tmp/p17/h4/hist
nueva /tmp/p17/h4/rc2
teclea "echo uno" Enter " echo secreto" Enter "echo uno" Enter "ls" Enter "pwd" Enter "history" Enter
ver 3
# $ history
#     1  echo uno
#     2  history
teclea "exit" Enter; sleep 0.3
# El archivo se escribe AL SALIR, con permisos 600:
cat /tmp/p17/h4/hist
# echo uno
# history
# exit
stat -c %a /tmp/p17/h4/hist
# 600
```

La orden con espacio, la repetida y `ls`/`pwd` no están. Si **no** las ves así,
mira `echo $HISTCONTROL` en esa shell.

**Verifica**:

```bash
grep -c secreto /tmp/p17/h4/hist
# 0
```

## Paso 6: Compartir el historial entre dos terminales

**Por qué**: cada terminal guarda al salir; sin ayuda, no ves lo de la otra.
`history -a` escribe ya; `history -n` lee lo nuevo.

**Comando**:

```bash
rm -f /tmp/p17/h4/hist
for s in a b; do
  tmux new-session -d -s $s -x 80 -y 24 "env -i HOME=/tmp/p17/h4 TERM=xterm PATH=/usr/bin:/bin INPUTRC=/dev/null bash --noprofile --rcfile /tmp/p17/h4/rc2 -i"
done
sleep 0.6
tmux send-keys -t a "echo desde-a" Enter "history -a" Enter; sleep 0.5
tmux send-keys -t b "history -n" Enter "history" Enter; sleep 0.5
tmux capture-pane -p -t b | sed '/^$/d' | tail -5
#     1  history -n
#     2  echo desde-a
#     3  history -a
#     4  history
# $
tmux kill-server
```

**Verifica**:

```bash
tmux ls 2>&1
# no server running on /tmp/tmux-0/default
```

## Paso 7: `readline` con `~/.inputrc`

**Por qué**: tres líneas cambian cómo completas y cómo recuperas lo escrito. Lo
mides con directorios `Docs`, `Downloads` y `Music`.

**Comando**:

```bash
printf 'set completion-ignore-case on\nset show-all-if-ambiguous on\n"\\e[A": history-search-backward\n' > /tmp/p17/h4/inputrc
cat /tmp/p17/h4/inputrc
# set completion-ignore-case on
# set show-all-if-ambiguous on
# "\e[A": history-search-backward
mkdir -p /tmp/p17/h4/Docs /tmp/p17/h4/Downloads /tmp/p17/h4/Music
printf "PS1='\$ '\ncd /tmp/p17/h4\n" > /tmp/p17/h4/rc3
# Sin .inputrc, "cd mus<Tab>" no completa (distingue mayusculas):
nueva /tmp/p17/h4/rc3
teclea "cd mus" Tab; ver 1
# $ cd mus
# Con .inputrc, si:
nueva /tmp/p17/h4/rc3 /tmp/p17/h4/inputrc
teclea "cd mus" Tab; ver 1
# $ cd Music/
# Con varios candidatos, los lista a la primera:
teclea C-u "cd d" Tab; ver 2
# Docs/      Downloads/
# $ cd Do
# La flecha arriba busca lo que EMPIEZA por lo ya escrito:
teclea C-u "echo uno" Enter "echo dos" Enter "ls" Enter "echo " Up; ver 1
# $ echo dos
tmux kill-server
```

**Verifica**:

```bash
bash -ic 'bind -v | grep -E "completion-ignore-case|show-all-if-ambiguous"' 2>/dev/null
# set completion-ignore-case off
# set show-all-if-ambiguous off
```

Estos son los valores **por defecto**: el `.inputrc` solo los cambió en la shell de
`tmux`, no en la tuya.

## ✅ Resultado

- [ ] Reprodujiste los tres casos en que un alias no se expande y usaste el espacio final
- [ ] Escribiste `mkcd` y comprobaste que cambia **tu** directorio
- [ ] Demostraste que un alias gana a una función y saltaste el alias con `\cmd` y `command`
- [ ] Probaste un `PS1` con `${PS1@P}` y viste los códigos de color con `printf %q`
- [ ] Viste un prompt vivo con el código de salida y la rama de git, y el recorte de `PROMPT_DIRTRIM`
- [ ] Una orden con espacio delante no aparece en el historial; el archivo tiene permisos `600`
- [ ] Compartiste el historial entre dos terminales con `history -a` y `history -n`
- [ ] Comprobaste el efecto de `completion-ignore-case` y de la flecha arriba con prefijo

Siguiente: la [práctica 03](03-autocompletado-y-tmux.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ver` imprime una línea vacía o el prompt incompleto | El `sleep` es corto para tu máquina | Sube el `sleep` en `teclea` y `nueva` |
| `no server running` al hacer `capture-pane` | La sesión terminó (por ejemplo, un `exit`) | Vuelve a ejecutar `nueva ...` |
| El prompt muestra `$` en lugar de `#` | Usaste comillas dobles en `PS1` | Comillas simples: `PS1='\$ '` |
| `[0]` siempre, aunque falle el comando | `PS1` con comillas dobles: se evalúa una sola vez | Comillas simples |
| El historial sale vacío | La shell no salió con `exit` | El archivo se escribe al salir |
| `cd mus<Tab>` completa sin `.inputrc` | Tu `INPUTRC` real tiene la opción | Es el `INPUTRC=/dev/null` de `nueva` el que la desactiva; revisa el segundo argumento |
| `Up` no busca por prefijo | Falta la línea de `history-search-backward` o la secuencia de tu terminal es `\eOA` | Prueba con `"\eOA"` |

---

[← Práctica 01: el arranque de la shell y el `PATH`](01-arranque-de-la-shell-y-path.md) · [Práctica 03: autocompletado y `tmux` →](03-autocompletado-y-tmux.md)
