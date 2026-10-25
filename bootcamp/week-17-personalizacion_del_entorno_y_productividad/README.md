# Semana 17 — Personalización del entorno y productividad

> Tu terminal es donde pasas el día: cada alias, cada atajo y cada `Tab` que la shell aprende se te devuelven en horas.
> Esta semana entiendes qué archivo configura qué, y aprendes a llevarlo todo contigo a cualquier máquina.

## 🎯 Objetivos de la Semana

- Predecir qué archivos lee bash según sea de login, interactiva o ninguna de las dos, y dónde poner cada cosa
- Controlar variables de entorno y `PATH`: `export`, herencia, orden, caché de `hash` y adición sin duplicar
- Escribir alias y funciones, sabiendo cuándo cada uno falla y cómo saltarte un alias
- Construir un `PS1` con color, código de salida y rama de git, y probarlo sin abrir otra terminal
- Manejar el historial (`HISTCONTROL`, `history -a`, `Ctrl-R`) y configurar `readline` con `~/.inputrc`
- Escribir un autocompletado programable para tu propio script y cargarlo de forma perezosa
- Mantener programas vivos con `tmux` aunque se corte la conexión, y probarlo sin terminal
- Construir `dotfiles`: enlaza un repositorio de configuración a tu home, con respaldo y vuelta atrás

## 📋 Prerrequisitos

Semana 16 completada: `toolkit.sh` con `schedule` funcionando y `shellcheck`
instalado en `ubuntu-lab`. Semana 16 (programaste tareas en el entorno mínimo de
`cron`: aquí ves cómo se construye el **tuyo**), Semana 15 (`shellcheck`,
`set -euo pipefail` y los códigos de salida), Semana 14 (funciones, `local`,
`case` y `source`), Semana 13 (comillas y variables), Semana 04 (permisos: el
historial se crea `600`) y Semana 01 (qué es una shell y qué es un terminal).

## 🗂️ Estructura de la Semana

```
week-17-personalizacion_del_entorno_y_productividad/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 8 archivos: arranque de bash, variables y PATH, alias y funciones, PS1, historial y readline, autocompletado, tmux, dotfiles
├── 2-practicas/           # 4 prácticas dentro de ubuntu-lab
├── 3-proyecto/            # Capa 17 de toolkit: subcomando dotfiles
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, cada uno para algo que la prosa cuenta mal: **qué archivo lee
cada tipo de shell** (una tabla de decisión que se entiende de un vistazo) y
**cómo `dotfiles` enlaza el repositorio con tu home** (qué apunta a qué). El
resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-como-arranca-bash.md) | Cómo arranca bash: login, interactiva y los archivos que lee | 25 min |
| [02](1-teoria/02-variables-de-entorno-y-path.md) | Variables de entorno y `PATH` | 25 min |
| [03](1-teoria/03-alias-y-funciones.md) | Alias y funciones | 20 min |
| [04](1-teoria/04-el-prompt-ps1.md) | El prompt: `PS1` | 20 min |
| [05](1-teoria/05-historial-y-readline.md) | Historial y `readline` | 25 min |
| [06](1-teoria/06-autocompletado.md) | Autocompletado | 20 min |
| [07](1-teoria/07-sesiones-persistentes-tmux.md) | Sesiones persistentes con `tmux` | 25 min |
| [08](1-teoria/08-dotfiles-y-construyendo-dotfiles.md) | Dotfiles y `toolkit dotfiles` | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-arranque-de-la-shell-y-path.md) | Los cuatro arranques con un `HOME` de juguete, la trampa del `.bash_profile`, `export`, orden del `PATH`, `hash` y `~/bin` | 60 min |
| [02](2-practicas/02-alias-prompt-e-historial.md) | Alias que no se expanden, funciones, `PS1` con `${PS1@P}` y en vivo, historial y `~/.inputrc` | 60 min |
| [03](2-practicas/03-autocompletado-y-tmux.md) | `compgen`, `_toolkit`, carga perezosa, sesiones de `tmux` que sobreviven y `tmux.conf` | 60 min |
| [04](2-practicas/04-dotfiles-a-mano.md) | Rellenar los ocho `TODO` de `dotfiles` paso a paso y probar un alias del repositorio en una shell real | 120 min |

Y la decimoséptima capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `dotfiles`: `status` compara el repositorio con tu home, `link`
enlaza (con `--force` respaldando y `--dry-run` enseñando el plan) y `unlink`
deshace; sale con `0`, `1` (uso) o `2` (estado a corregir).

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 3 h |
| Prácticas (4 archivos) | 5 h |
| Proyecto: Capa 17 de `toolkit` | 1 h |
| Rúbrica de conocimiento (10 preguntas) | 50 min |
| Repaso, glosario y recursos | 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `echo "${PS1@P}"` expande una cadena **como si fuera el prompt**: iteras un
  `PS1` con colores y `\w` sin abrir otra terminal. Usa comillas simples al
  asignar `PS1`, o bash se come las barras.
- `env -i HOME=/tmp/h TERM=xterm PATH=/usr/bin:/bin bash --noprofile --rcfile mi-rc -i`
  arranca una shell interactiva **limpia**, sin tus archivos reales. Dentro de
  `tmux`, con `send-keys` y `capture-pane -p`, es la forma de probar un prompt,
  un historial o un `Tab` desde un script.
- `find ~ -maxdepth 1 -type l -printf '%f -> %l\n'` lista los enlaces de tu home
  y a dónde apuntan: quién cuelga de tu repositorio de dotfiles, de un vistazo.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `dotfiles` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck`, `netcheck`, `snapshot`, `healthcheck`, `guard` y `schedule` de
   semanas anteriores siguen funcionando sin regresiones, y `shellcheck
   ~/bin/toolkit.sh` sale limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 17
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 16](../week-16-automatizacion_y_tareas_programadas/README.md) | Semana 17 | [Semana 18 →](../week-18-archivado_compresion_y_registros_del_sistema/README.md) |

[← Volver al índice del bootcamp](../README.md)
