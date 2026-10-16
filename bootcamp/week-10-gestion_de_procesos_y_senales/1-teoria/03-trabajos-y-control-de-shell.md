# Trabajos y control de shell

> `&` manda un comando a segundo plano. `jobs`, `fg`, `bg` y `disown`
> son el vocabulario para seguir manejándolo después — y `Ctrl+Z`
> (técnicamente, la señal `SIGTSTP`) tiene una sutileza real que
> sorprende a quien nunca la vio fallar.

## 🎯 Objetivos

- Lanzar procesos en segundo plano con `&` y capturar su PID con `$!`
- Listar, pausar y reanudar trabajos con `jobs`, `bg`, `fg`
- Desvincular un proceso de la sesión de shell con `disown` y `nohup`
- Explicar por qué `SIGTSTP` puede no detener un proceso, a diferencia de `SIGSTOP`

## 1. Qué problema resuelve

Lanzar un comando largo y seguir usando la terminal mientras corre, sin
perder la capacidad de pausarlo, retomarlo, o dejarlo corriendo aunque
cierres la sesión — ninguna de estas necesidades se resuelve con un
comando en primer plano simple. El control de trabajos de bash existe
exactamente para esto.

## 2. Cómo funciona

### 2.1 `&`: segundo plano, y `$!` para capturar el PID

```bash
sleep 100 &
echo "PID: $!"
```

`&` lanza el comando sin bloquear la terminal; `$!` contiene
inmediatamente el PID del último proceso lanzado en segundo plano —
útil para referenciarlo después sin tener que buscarlo con `ps`.

### 2.2 `jobs`: ver los trabajos de la sesión actual

```bash
sleep 100 &
jobs -l
```

```
[1]+  3918 Running                 sleep 100 &
```

`jobs` lista los procesos en segundo plano de **esta sesión de shell
en particular** — no todos los procesos del sistema, solo los que esta
sesión lanzó. El número entre corchetes (`%1`) es una referencia corta
que `kill`, `fg` y `bg` pueden usar en vez del PID completo.

```bash
kill %1
```

### 2.3 `fg`/`bg`: requieren control de trabajos activo

```bash
sleep 100 &
fg %1
```

```
bash: line 1: fg: no job control
```

En una shell sin control de trabajos activo (el caso por defecto de un
**script**, a diferencia de una sesión interactiva), `fg`/`bg` fallan
con este error — el control de trabajos (`job control`) no está
habilitado automáticamente fuera de una sesión interactiva.

```bash
set -m
sleep 100 &
bg %1
```

```
bash: line 1: bg: job 1 already in background
```

`set -m` habilita control de trabajos explícitamente dentro de un
script — con eso activo, `bg`/`fg` funcionan (aunque `fg` todavía
necesita una terminal real para traer algo a primer plano de verdad).

### 2.4 `SIGSTOP` siempre detiene; `SIGTSTP` no siempre

```bash
sleep 10 & p=$!
kill -STOP "$p"
ps -p "$p" -o pid,stat
```

```
   PID STAT
  3950 T
```

```bash
sleep 10 & p=$!
kill -TSTP "$p"
ps -p "$p" -o pid,stat
```

```
   PID STAT
  3953 S
```

¡El mismo intento de pausar, dos señales distintas, dos resultados
distintos! `SIGSTOP` detiene **siempre**, sin excepción. `SIGTSTP` (la
señal que genera `Ctrl+Z` en una terminal real) tiene una excepción
documentada: si el proceso corre en un grupo de procesos sin una
terminal de control real (exactamente la situación de un `&` dentro de
un script, o de una sesión sin control de trabajos activo), el kernel
**descarta** la señal en vez de aplicarla.

```bash
set -m
sleep 10 & p=$!
kill -TSTP "$p"
ps -p "$p" -o pid,stat
```

```
   PID STAT
  3963 T
```

Con `set -m` activo, el proceso en segundo plano sí tiene un grupo de
procesos "normal" (asociado al control de trabajos), y `SIGTSTP` vuelve
a comportarse como se esperaría.

### 2.5 `disown`: sacar un trabajo de la lista, sin matarlo

```bash
sleep 100 &
disown
jobs
# (vacio - ya no aparece)
ps -p "$!" -o pid,cmd
#   PID CMD
#  3920 sleep 100
```

`disown` quita el trabajo de la tabla de `jobs` de la sesión actual
—pero el proceso sigue corriendo, solo que esta shell deja de
"supervisarlo". Es distinto de matar el proceso: simplemente deja de
aparecer en `jobs`/`fg`/`bg`.

### 2.6 `nohup`: sobrevivir al cierre de la sesión

```bash
nohup comando-largo &
```

Por defecto, cuando una sesión de terminal se cierra, bash envía
`SIGHUP` a sus procesos en segundo plano (archivo 04 de esta semana
profundiza en esa señal) — `nohup` hace que el proceso **ignore**
`SIGHUP` específicamente, para que sobreviva al cierre de la terminal
que lo lanzó. Es el patrón estándar para lanzar algo largo y poder
cerrar la sesión sin matarlo.

## 3. Cómo se usa

```bash
# Lanzar un proceso largo que sobreviva al cierre de la terminal
nohup ./respaldo-completo.sh &> respaldo.log &
disown

# Pausar y reanudar un proceso en una sesion interactiva real
# (Ctrl+Z para pausar, "bg" para reanudar en segundo plano, "fg" para traerlo de vuelta)

# Verificar que trabajos tiene activos la sesion actual
jobs -l
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Esperar que `kill -TSTP` pause un proceso igual que `Ctrl+Z` en cualquier contexto | Fuera de una sesión interactiva con control de trabajos, `SIGTSTP` puede descartarse sin ningún efecto | Usar `SIGSTOP`/`SIGCONT` cuando el objetivo es pausar de forma garantizada, sin depender del contexto de terminal |
| Cerrar una terminal asumiendo que un proceso en segundo plano sigue vivo | Sin `nohup`, el cierre de la sesión envía `SIGHUP` a los procesos en segundo plano, que por defecto termina el proceso | `nohup comando &` (o `disown` después de lanzarlo) para procesos que deben sobrevivir al cierre de la sesión |
| Confundir `disown` con `nohup` | `disown` solo afecta si el trabajo aparece en `jobs`; no cambia qué señal recibe al cerrar la terminal | `nohup` específicamente para sobrevivir a `SIGHUP`; `disown` para dejar de verlo en `jobs` (a veces se usan juntos) |
| Usar `fg`/`bg` dentro de un script esperando que funcionen como en una sesión interactiva | Sin `set -m`, fallan con "no job control" — el control de trabajos no está activo por defecto en scripts | `set -m` si un script realmente necesita control de trabajos, aunque en la mayoría de los casos hay una forma más directa de lograr lo mismo |

## 5. Trucos

- `jobs -l` (con `-l`) incluye el PID de cada trabajo, no solo el
  número de referencia — útil cuando después hace falta pasarlo a otro
  comando que no entiende `%1`.
- `kill %1` acepta la referencia de trabajo directamente, sin necesitar
  buscar el PID primero con `jobs`.
- `disown -a` desvincula **todos** los trabajos de la sesión actual de
  una sola vez, en vez de uno por uno.

## Resumen

`&` lanza en segundo plano; `$!` captura su PID. `jobs` lista los
trabajos de la sesión actual; `fg`/`bg` requieren control de trabajos
activo (`set -m` en un script, automático en una sesión interactiva).
`SIGSTOP` siempre pausa; `SIGTSTP` (el equivalente de `Ctrl+Z`) puede
no tener efecto fuera de una sesión con control de trabajos real.
`disown` desvincula un trabajo de `jobs` sin matarlo; `nohup` protege
contra `SIGHUP` al cerrar la sesión.

## 📚 Recursos Adicionales

- [GNU Bash Manual — Job Control](https://www.gnu.org/software/bash/manual/bash.html#Job-Control) — referencia completa de `jobs`, `fg`, `bg`, `disown`.
- [man7.org — signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html) — el comportamiento exacto de `SIGTSTP`/`SIGTTIN`/`SIGTTOU` sobre grupos de procesos sin terminal de control.
- `man nohup` — disponible sin conexión en cualquier distro.

## ✅ Checklist de Verificación

- [ ] Lanzaste un proceso en segundo plano con `&` y capturaste su PID con `$!`
- [ ] Listaste los trabajos de tu sesión con `jobs -l`
- [ ] Reprodujiste por qué `fg`/`bg` fallan sin `set -m` en un script
- [ ] Reprodujiste la diferencia entre `SIGSTOP` (siempre pausa) y `SIGTSTP` (puede no hacer nada) en segundo plano
- [ ] Usaste `disown` para quitar un trabajo de `jobs` sin matar el proceso

---

[← 02 — Estados de proceso: zombies y huérfanos](02-estados-de-proceso-zombies-y-huerfanos.md) · [04 — Señales fundamentales →](04-senales-fundamentales.md)
