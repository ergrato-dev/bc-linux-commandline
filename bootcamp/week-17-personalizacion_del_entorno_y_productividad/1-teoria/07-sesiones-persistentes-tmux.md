# Sesiones persistentes con `tmux`

> Una conexión SSH que se cae mata todo lo que lanzaste desde ella.
> `tmux` mantiene tus programas vivos en el servidor y te deja volver a entrar cuando quieras.

## 🎯 Objetivos

- Explicar por qué una sesión de SSH al caerse mata sus procesos y cómo lo evita `tmux`
- Distinguir servidor, sesión, ventana y panel
- Crear, listar, entrar, salir y matar sesiones, también **sin terminal**
- Usar los atajos con el prefijo `Ctrl-b` y consultarlos con `tmux list-keys`
- Escribir un `~/.tmux.conf` mínimo y recargarlo
- Reconocer `screen` y saber qué paquete instalar en cada familia

## 1. Qué problema resuelve

Lanzas una copia de seguridad de una hora, por SSH. A los diez minutos se cae la
Wi-Fi. Al cerrarse la conexión, el kernel envía `SIGHUP` (colgar) a la shell y
ésta a sus hijos: la copia muere a medias. `nohup` y `&` lo evitan para **un**
proceso, pero no te dejan **volver a verlo**. `tmux` sí: el programa corre dentro
de un servidor que no depende de tu conexión, y tú te **desconectas y
reconectas** a él.

## 2. Cómo funciona

### 2.1 Cuatro niveles

| Nivel | Qué es | Analogía |
|---|---|---|
| **Servidor** | Un único proceso `tmux` por usuario que sobrevive a todo | el escritorio |
| **Sesión** | Un conjunto de ventanas con nombre (`trabajo`, `logs`) | un proyecto |
| **Ventana** | Una pantalla completa dentro de la sesión | una pestaña |
| **Panel** | Una división de una ventana | un trozo de pestaña |

Cuando haces **detach** (te desconectas), el servidor, la sesión y todo lo que
corre dentro siguen vivos. Al hacer **attach**, vuelves a verlos tal cual.

### 2.2 Sin terminal: la forma de probarlo aquí

`ubuntu-lab` recibe tus órdenes con `docker exec`, sin un terminal interactivo, y
aun así puedes comprobarlo todo con `-d` («desconectada»). Crea una sesión que
ejecuta un `sleep` largo:

```bash
tmux new-session -d -s trabajo "sleep 600"
```

Y ahora, **en otra llamada** (otro `docker exec`: la «conexión» anterior ya
terminó), la sesión sigue ahí:

```bash
tmux ls
# trabajo: 1 windows (created Sun Oct 25 05:33:35 2026)
tmux has-session -t trabajo && echo existe
# existe
tmux list-windows -t trabajo
# 0: sleep* (1 panes) [80x24] [layout b25d,80x24,0,0,0] @0 (active)
tmux list-panes -t trabajo -F "#{pane_pid} #{pane_current_command}"
# 28666 sleep
tmux kill-session -t trabajo
tmux ls
# no server running on /tmp/tmux-0/default
```

Eso es **exactamente** lo de la Wi-Fi que se cae: la conexión que lo lanzó murió y
el `sleep` sigue. El último mensaje es normal: sin sesiones, el servidor se apaga.

### 2.3 Controlarla con órdenes

Las mismas órdenes que usarías con atajos, escritas, sirven para **automatizar**:

```bash
tmux new-session -d -s y
sleep 0.6
tmux send-keys -t y "echo hola-tmux" Enter
sleep 0.5
tmux capture-pane -p -t y | grep hola
# root@ubuntu-lab:/# echo hola-tmux
# hola-tmux
tmux split-window -t y -h
tmux list-panes -t y | wc -l
# 2
tmux new-window -t y -n logs
tmux list-windows -t y -F "#{window_index}:#{window_name}"
# 0:bash
# 1:logs
tmux kill-server
```

Los `sleep` dan tiempo a que la shell dibuje su prompt. `send-keys` teclea por ti
(con `Enter` para el salto de línea) y `capture-pane -p` imprime lo que **se ve** en el panel. Es la forma de probar programas
interactivos desde un script, y la que usamos en las prácticas de esta semana
para probar un prompt o un autocompletado sin teclado.

### 2.4 Con un terminal real: el prefijo

Dentro de `tmux`, todas las acciones empiezan con el **prefijo** `Ctrl-b`
(se pulsa, se suelta, y después la tecla). Los atajos de uso diario, comprobados
con `tmux list-keys`:

| Tras `Ctrl-b` | Hace |
|---|---|
| `d` | **detach**: te desconectas y todo sigue |
| `c` | ventana nueva |
| `n` / `p` | ventana siguiente / anterior |
| `w` / `s` | lista de ventanas / de sesiones |
| `%` | divide el panel en **dos columnas** |
| `"` | divide el panel en **dos filas** |
| `x` | cierra el panel (pide confirmación) |
| `[` | modo copia: te mueves por el historial con las flechas |
| `,` / `$` | renombra la ventana / la sesión |
| `?` | lista todos los atajos |

Y desde la shell, para volver: **`tmux attach -t trabajo`** (o `tmux a`). El idioma
más práctico, que crea la sesión si no existe y entra si existe:

```bash
tmux new-session -A -s trabajo
```

> `-A` necesita un terminal real para enlazarse, así que no lo podemos comprobar en
> el laboratorio con `docker exec` sin `-t`: pruébalo en tu máquina.

### 2.5 Cada panel es una shell de login

Comprobado dentro de `tmux`:

```
$ shopt login_shell; echo $0
login_shell     on
-bash
```

Es una **shell de login**: lee `~/.profile` (que en Ubuntu carga `~/.bashrc`; ver
[archivo 01](01-como-arranca-bash.md)). Consecuencia: una variable exportada solo
en `~/.profile` **sí** llega a tus ventanas de `tmux`, pero tiene el valor de
**cuando arrancó el servidor**, no el de tu sesión actual.

### 2.6 `~/.tmux.conf`

`tmux` lee `~/.tmux.conf` **al arrancar el servidor** (no al abrir una sesión nueva
con el servidor ya vivo). Un archivo mínimo y útil:

```
set -g prefix C-a
unbind C-b
bind C-a send-prefix
set -g mouse on
set -g history-limit 20000
set -g base-index 1
bind r source-file ~/.tmux.conf \; display "recargado"
```

Las líneas, de arriba a abajo: cambia el prefijo a `Ctrl-a` (más cómodo; es el de
`screen`), conserva `Ctrl-a Ctrl-a` para enviar un `Ctrl-a` real, activa el ratón,
amplía el historial y numera las ventanas desde 1. La última añade un atajo para
**recargar** sin reiniciar. Se comprueba sin terminal:

```bash
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
```

`tmux -f archivo` usa **ese** archivo. `show-options -g` lee un valor y
`list-keys` enseña los atajos activos. Para recargar en una sesión viva:
`tmux source-file ~/.tmux.conf`.

### 2.7 `screen`

`screen` es el anterior, aún presente en servidores antiguos. Hace lo mismo con
otras teclas (`Ctrl-a`), y también se prueba sin terminal:

```bash
screen -dmS prueba sleep 300
screen -ls
# There is a screen on:
# 	28852.prueba	(10/25/26 05:33:43)	(Detached)
# 1 Socket in /run/screen/S-root.
screen -S prueba -X quit
```

| `tmux` | `screen` |
|---|---|
| `tmux new -d -s x` | `screen -dmS x` |
| `tmux ls` | `screen -ls` |
| `tmux attach -t x` | `screen -r x` |

## 3. Cómo se usa

### 3.1 El flujo de trabajo

1. Conecta por SSH y entra en tu sesión: `tmux new-session -A -s trabajo`.
2. Lanza lo largo y desconecta con `Ctrl-b d`; cierra tranquilo el portátil.
3. Más tarde, vuelve a conectar y repite el mismo `tmux new-session -A -s trabajo`:
   todo está donde lo dejaste.

### 3.2 Lo largo, sin terminal

Para algo que no necesita que lo mires, ni siquiera hace falta entrar:

```bash
tmux new-session -d -s copia "tar czf /tmp/copia.tgz /etc 2>/dev/null; echo fin"
```

Y revisas después con `tmux ls` o `tmux capture-pane -p -t copia`. Ojo: si la
orden **termina**, la sesión también se cierra y pierdes el panel. Para que se
quede, termina con `; bash`, o mejor, que **escriba un registro** (Semana 15).

### 3.3 Divergencia de distro

`tmux` se llama igual en todas (`apt`, `dnf`, `pacman`), pero **la versión
cambia**: en las imágenes del laboratorio, Ubuntu 24.04 trae `tmux` 3.4, Debian 12
trae 3.3a y Rocky/RHEL 9 trae 3.2a. Las opciones de esta semana funcionan en todas.
Para `screen`, en RHEL **no está en el repositorio base**, sino en **EPEL**
(`dnf install epel-release` antes), igual que `shellcheck` en la Semana 13.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Lanzar un proceso largo directo en SSH | Muere si se cae la conexión | `tmux`, o `systemd-run`/`cron` si es periódico |
| Un tmux dentro de otro (SSH desde tmux a un servidor que ya usa tmux) | Los atajos del primero se «comen» al segundo | Otro prefijo en el servidor (`Ctrl-a`) |
| Dejar sesiones de meses sin nombre | No sabes cuál es cuál | `-s nombre` y `tmux ls` de vez en cuando |
| Pegar contraseñas en un `send-keys` | Quedan en el historial del panel | Variables de entorno desde un archivo `600` |
| Editar `~/.tmux.conf` y esperar que cambie solo | Solo se lee al arrancar el servidor | `tmux source-file ~/.tmux.conf` |
| Fiarse de `tmux` para tareas críticas programadas | Si la máquina se reinicia, la sesión muere | `cron` o un temporizador (Semana 16) |
| Usar `kill-server` por costumbre | Mata **todas** tus sesiones | `kill-session -t nombre` |

## 5. Trucos

- **`tmux ls -F '#{session_name} #{session_windows}'`**: el listado con el formato
  que tú quieras (`-F` acepta cualquier variable de `tmux`).
- **`tmux capture-pane -p -S -50 -t nombre`**: las últimas 50 líneas del historial
  del panel, no solo lo visible.
- **`Ctrl-b z`**: pone un panel a pantalla completa, y otra vez para volver.

## 📚 Recursos Adicionales

- `man tmux`: largo pero completo; busca **KEY BINDINGS** y **FORMATS**
- [tmux wiki (GitHub)](https://github.com/tmux/tmux/wiki)

## ✅ Checklist de Verificación

- [ ] Creas una sesión con `tmux new-session -d -s trabajo` y la ves desde **otra** llamada con `tmux ls`
- [ ] Tecleas en un panel con `send-keys` y lo lees con `capture-pane -p`
- [ ] Localizas con `tmux list-keys` el atajo de **detach**
- [ ] Cargas un `tmux.conf` con `-f` y compruebas el prefijo con `show-options -g`
- [ ] Explicas por qué un panel de `tmux` es una shell de login
- [ ] Citas el paquete de `tmux` y de `screen` en cada familia

---

[← Autocompletado](06-autocompletado.md) · [Dotfiles y `toolkit dotfiles` →](08-dotfiles-y-construyendo-dotfiles.md)
