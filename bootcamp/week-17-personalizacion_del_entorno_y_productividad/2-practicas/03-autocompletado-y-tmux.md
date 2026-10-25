# Práctica 03 — Autocompletado y `tmux`

> Duración estimada: 60 min · Teoría de apoyo: archivos [06](../1-teoria/06-autocompletado.md) y [07](../1-teoria/07-sesiones-persistentes-tmux.md)

Sigues **dentro de `ubuntu-lab`**, con `tmux` y `bash-completion` instalados
(práctica 01). `Tab` solo funciona en una shell interactiva, así que el
autocompletado se prueba como en la práctica 02: una shell dentro de `tmux`,
`send-keys` para teclear y `capture-pane` para mirar.

```bash
docker exec -it ubuntu-lab bash
mkdir -p /tmp/p17/h5/.local/share/bash-completion/completions && cd /tmp/p17
```

## Paso 1: Preparar las ayudas y una shell de pruebas

**Por qué**: necesitas arrancar una shell limpia (`env -i`) que cargue
`bash-completion` y tu `HOME` de juguete, teclear en ella y leer la pantalla.
Son las mismas tres funciones de la práctica 02; si cerraste la terminal,
vuelve a definirlas.

**Comando**:

```bash
cat > /tmp/p17/h5/rc << 'EOF'
PS1='$ '
source /usr/share/bash-completion/bash_completion
EOF
nueva() {
  tmux kill-server 2>/dev/null
  tmux new-session -d -s p -x 80 -y 24 "env -i HOME=/tmp/p17/h5 TERM=xterm PATH=/usr/bin:/bin INPUTRC=/dev/null bash --noprofile --rcfile $1 -i"
  sleep 0.8
}
teclea() { tmux send-keys -t p "$@"; sleep 0.5; }
ver() { tmux capture-pane -p -t p | sed '/^$/d' | tail -"${1:-1}"; }
nueva /tmp/p17/h5/rc
ver 1
# $
```

**Verifica**:

```bash
tmux has-session -t p && echo viva
# viva
```

## Paso 2: `complete -W` y `compgen`

**Por qué**: la forma más simple de autocompletado es una lista fija. `compgen`
es la pieza que filtra por prefijo; la verás dentro de la función del paso 3.

**Comando**:

```bash
compgen -W "alfa beta bravo" -- b
# beta
# bravo
compgen -d -- /tm
# /tmp
compgen -c -- tmu | sort -u
# tmux
# Ahora, dentro de la shell de pruebas:
teclea "complete -W 'start stop status' svc" Enter
teclea "svc st" Tab Tab; ver 2
# start   status  stop
# $ svc st
teclea C-u "complete -r svc" Enter "complete -p svc" Enter; ver 1
# bash: complete: svc: no completion specification
```

Con tres candidatos que comparten `st`, el primer `Tab` no completa nada más y el
segundo **los lista**.

**Verifica**:

```bash
compgen -W "start stop status" -- sto
# stop
```

## Paso 3: Una función `_toolkit` con `COMP_WORDS`

**Por qué**: el primer argumento, el segundo y las opciones tienen candidatos
distintos. Una función los separa por `COMP_CWORD` y por la palabra anterior.

**Comando**:

```bash
cat > /tmp/p17/h5/comp << 'EOF'
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
EOF
# -s bash: el archivo no tiene shebang, shellcheck necesita saber el dialecto.
shellcheck -s bash /tmp/p17/h5/comp && echo limpio
# limpio
# Sin cargarlo, "sch<Tab>" no completa nada:
teclea C-u "toolkit.sh sch" Tab; ver 1
# $ toolkit.sh sch
# Cargandolo a mano con source (un punto):
teclea C-u ". /tmp/p17/h5/comp" Enter "toolkit.sh sch" Tab; ver 1
# $ toolkit.sh schedule
teclea C-u "toolkit.sh dotfiles l" Tab; ver 1
# $ toolkit.sh dotfiles link
teclea C-u "toolkit.sh dotfiles link --" Tab Tab; ver 2
# $ toolkit.sh dotfiles link --
# --dry-run  --force    --home     --repo
teclea C-u "toolkit.sh dotfiles link --repo /tm" Tab; ver 1
# $ toolkit.sh dotfiles link --repo /tmp/
```

**Verifica**:

```bash
tmux send-keys -t p C-u "complete -p toolkit.sh" Enter; sleep 0.5
ver 2 | head -1
# complete -F _toolkit toolkit.sh
```

(En la última línea de `/tmp` puede aparecer `/tmp` sin barra o con ella según
haya subdirectorios; lo importante es que completó.)

## Paso 4: Carga perezosa en el directorio de tu usuario

**Por qué**: así no cargas nada en cada arranque y el autocompletado aparece
solo la primera vez que lo necesitas. Es el sitio donde vive el de cualquier
herramienta tuya.

**Comando**:

```bash
cp /tmp/p17/h5/comp /tmp/p17/h5/.local/share/bash-completion/completions/toolkit.sh
nueva /tmp/p17/h5/rc
# Antes del primer Tab, nada registrado:
teclea "complete -p toolkit.sh" Enter; ver 2
# bash: complete: toolkit.sh: no completion specification
teclea C-u "toolkit.sh sch" Tab; ver 1
# $ toolkit.sh schedule
# Despues del primer Tab, ya esta cargado:
teclea C-u "complete -p toolkit.sh" Enter; ver 2
# complete -F _toolkit toolkit.sh
tmux kill-server
```

**Verifica**:

```bash
ls /tmp/p17/h5/.local/share/bash-completion/completions/
# toolkit.sh
```

El archivo se llama **igual que la orden**; con otro nombre el cargador no lo
encuentra.

## Paso 5: Sesiones que sobreviven a la conexión

**Por qué**: es el problema para el que existe `tmux`. Lo compruebas en dos
llamadas distintas a `docker exec`: la primera «muere», la segunda encuentra la
sesión.

**Comando**:

```bash
# Desde el host, FUERA del contenedor interactivo (otra terminal), o con docker exec:
docker exec ubuntu-lab tmux new-session -d -s trabajo "sleep 600"
# Otra conexion distinta:
docker exec ubuntu-lab tmux ls
# trabajo: 1 windows (created Sun Oct 25 05:33:35 2026)
docker exec ubuntu-lab tmux list-panes -t trabajo -F "#{pane_current_command}"
# sleep
```

**Verifica**:

```bash
docker exec ubuntu-lab tmux has-session -t trabajo && echo existe
# existe
```

## Paso 6: Dirigir `tmux` con órdenes

**Por qué**: lo que haces con atajos se puede escribir y automatizar. Aquí
creas ventanas y paneles y las cuentas.

**Comando**:

```bash
docker exec ubuntu-lab tmux kill-server
tmux new-session -d -s y
tmux split-window -t y -h
tmux list-panes -t y | wc -l
# 2
tmux new-window -t y -n logs
tmux list-windows -t y -F "#{window_index}:#{window_name}"
# 0:bash
# 1:logs
tmux kill-session -t y
```

Si usas la shell interactiva del contenedor, el servidor `tmux` es **el mismo** que
el de `docker exec`: ambos corren como `root` y usan el mismo socket.

**Verifica**:

```bash
tmux ls 2>&1
# no server running on /tmp/tmux-0/default
```

## Paso 7: Un `tmux.conf` con prefijo propio

**Por qué**: `Ctrl-a` es más cómodo que `Ctrl-b`. Aquí no pulsas teclas: lees la
configuración efectiva con `show-options` y `list-keys`.

**Comando**:

```bash
mkdir -p /tmp/t17
cat > /tmp/t17/tmux.conf << 'EOF'
set -g prefix C-a
unbind C-b
bind C-a send-prefix
set -g mouse on
set -g history-limit 20000
set -g base-index 1
bind r source-file /tmp/t17/tmux.conf \; display "recargado"
EOF
tmux -f /tmp/t17/tmux.conf new-session -d -s x "sleep 600"
tmux show-options -g prefix
# prefix C-a
tmux show-options -g mouse
# mouse on
tmux show-options -g history-limit
# history-limit 20000
tmux list-windows -t x -F "#{window_index}: #{window_name}"
# 1: sleep
tmux list-keys | grep source-file
# bind-key -T prefix r source-file /tmp/t17/tmux.conf \; display-message recargado
tmux kill-server
```

**Verifica**:

```bash
tmux -f /tmp/t17/tmux.conf start-server \; show-options -g prefix
# prefix C-a
tmux kill-server
```

## Paso 8: `screen`, por si te lo encuentras

**Por qué**: servidores antiguos solo traen `screen`; con tres órdenes sabes
usarlo.

**Comando**:

```bash
apt-get install -y -qq screen
screen -dmS prueba sleep 300
screen -ls | grep prueba
# 	28852.prueba	(10/25/26 05:33:43)	(Detached)
screen -S prueba -X quit
```

**Verifica**:

```bash
screen -ls | grep -c prueba
# 0
```

## ✅ Resultado

- [ ] Registraste y borraste un `complete -W`, y viste los candidatos con doble `Tab`
- [ ] `_toolkit` pasa `shellcheck -s bash` y completa subcomandos, acciones de `dotfiles`, opciones y directorios
- [ ] Dejaste el autocompletado en `~/.local/share/bash-completion/completions/` y viste que se carga al primer `Tab`
- [ ] Una sesión de `tmux` creada en una llamada sobrevivió a la siguiente
- [ ] Creaste ventanas y paneles con órdenes, y los contaste
- [ ] Leíste el prefijo, el ratón y el atajo de recarga de un `tmux.conf` sin pulsar teclas
- [ ] Creaste y mataste una sesión de `screen`

Cuando termines, pasa a la [práctica 04](04-dotfiles-a-mano.md), donde se
verifica el trabajo con `verificar-semana.sh`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `shellcheck: command not found` | No instalado (Semana 13) | `apt-get install -y -qq shellcheck` |
| `Tab` no completa nada | La función no está cargada o falta `bash-completion` | `. /tmp/p17/h5/comp` o revisa el `rc` |
| `complete: toolkit.sh: no completion specification` | Aún no pulsaste `Tab` (carga perezosa) | Pulsa `Tab` una vez |
| El autocompletado perezoso no carga | El archivo no se llama como la orden | Debe ser `toolkit.sh` |
| Candidatos con espacios partidos | Usaste `COMPREPLY=($(...))` | `mapfile -t COMPREPLY < <(...)` |
| `no server running` tras crear la sesión | La orden de la sesión terminó | Usa `sleep 600` o termina con `; bash` |
| `prefix C-b` en vez de `C-a` | El servidor ya estaba vivo con otra configuración | `tmux kill-server` y arranca con `-f` |
| `ver` va un paso por detrás | `sleep` corto | Súbelo en `teclea` |

---

[← Práctica 02: alias, prompt e historial](02-alias-prompt-e-historial.md) · [Práctica 04: dotfiles a mano →](04-dotfiles-a-mano.md)
