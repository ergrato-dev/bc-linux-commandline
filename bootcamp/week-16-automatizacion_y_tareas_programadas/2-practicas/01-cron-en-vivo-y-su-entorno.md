# Práctica 01 — `cron` en vivo y su entorno

> Duración estimada: 60 min · Teoría de apoyo: archivos [01](../1-teoria/01-cron-y-crontab.md), [02](../1-teoria/02-expresiones-de-cron-y-sus-trampas.md) y [03](../1-teoria/03-el-entorno-minimo-de-cron.md)

Trabajas **dentro de `ubuntu-lab`**. Esta práctica usa `cron` de verdad, así
que tendrás que **esperar hasta un minuto** en varios pasos: cada espera lleva
su propio comando, que termina en cuanto el archivo aparece.

```bash
docker exec -it ubuntu-lab bash
mkdir -p /tmp/p16 && cd /tmp/p16
```

## Paso 1: Instalar y arrancar `cron`

**Por qué**: la imagen mínima de Ubuntu no trae `cron`, y un contenedor no
tiene `init`, así que nadie lo arranca por ti. Sin el demonio, `crontab`
acepta tus tareas y **no se ejecutan nunca**, sin ningún error.

**Comando**:

```bash
# -qq: casi sin salida. systemd lo necesitaras en la practica 03 (systemd-analyze).
apt-get update -qq
apt-get install -y -qq cron systemd
# "cron" sin argumentos se lanza solo en segundo plano.
pgrep -x cron >/dev/null || cron
# Respaldo de tu tabla actual (vacia en un laboratorio nuevo): los pasos usan crontab -r.
crontab -l > /tmp/p16/crontab.orig 2>/dev/null || true
```

**Verifica**:

```bash
pgrep -x cron >/dev/null && echo "cron corre"
# cron corre
```

## Paso 2: Tu primera tarea programada

**Por qué**: antes de entender el entorno, hay que ver que `cron` hace algo.
La tarea escribe la hora cada minuto. Fíjate en el `\%`: `date +%T` sin
escapar **no funcionaría** (lo ves en el paso 5).

**Comando**:

```bash
echo '* * * * * date +\%T >> /tmp/p16/tic.log' | crontab -
crontab -l
# * * * * * date +\%T >> /tmp/p16/tic.log
# Espera hasta 130 s a que aparezca el primer registro (devuelve 0 si llega):
timeout 130 bash -c 'until [ -s /tmp/p16/tic.log ]; do sleep 2; done'; echo "espera: $?"
# espera: 0
cat /tmp/p16/tic.log
# 04:49:04
crontab -r                       # quitala: sin esto sigue corriendo cada minuto
```

**Verifica**:

```bash
[ -s /tmp/p16/tic.log ] && echo "hay registro"
# hay registro
crontab -l
# no crontab for root
```

## Paso 3: El entorno que ve `cron`

**Por qué**: la tarea que funciona en tu terminal y no en `cron` casi siempre
es una diferencia de entorno. En vez de adivinar, **mídelo**: vuelca el
entorno desde `cron` y compáralo con el tuyo.

**Comando**:

```bash
env | sort > /tmp/p16/env-shell.txt
echo '* * * * * env | sort > /tmp/p16/env-cron.txt; pwd >> /tmp/p16/env-cron.txt' | crontab -
timeout 130 bash -c 'until grep -q "^/" /tmp/p16/env-cron.txt 2>/dev/null; do sleep 2; done'; echo "espera: $?"
# espera: 0
crontab -r
cat /tmp/p16/env-cron.txt
# HOME=/root
# LANG=C.UTF-8
# LOGNAME=root
# PATH=/usr/bin:/bin
# PWD=/root
# SHELL=/bin/sh
# /root
# Las variables clave que difieren entre tu shell y cron:
diff <(grep -E '^(PATH|SHELL|PWD|HOME)=' /tmp/p16/env-shell.txt) <(grep -E '^(PATH|SHELL|PWD|HOME)=' /tmp/p16/env-cron.txt)
# 2,3c2,4
# < PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# < PWD=/tmp/p16
# ---
# > PATH=/usr/bin:/bin
# > PWD=/root
# > SHELL=/bin/sh
```

Tres diferencias: el `PATH` es más corto, el directorio es `HOME` (no donde
estás tú) y `SHELL` es `/bin/sh` (que en Ubuntu es `dash`). La última línea de
`env-cron.txt` es el `pwd`: `/root`.

**Verifica**:

```bash
grep -E '^PATH=' /tmp/p16/env-cron.txt
# PATH=/usr/bin:/bin
grep -c '^SHELL=/bin/sh$' /tmp/p16/env-cron.txt
# 1
```

## Paso 4: El `PATH` mínimo: «not found» que no ves

**Por qué**: un programa de `/usr/local/bin` existe en tu terminal y no para
`cron`. Primero lo **emulas** (rápido, sin esperar), luego lo arreglas de las
dos formas posibles y lo compruebas con `cron` de verdad.

**Comando**:

```bash
printf '#!/bin/sh\necho hola desde usr-local\n' > /usr/local/bin/hola-cron
chmod +x /usr/local/bin/hola-cron
command -v hola-cron
# /usr/local/bin/hola-cron
# 1) Emular cron: env -i arranca con el entorno VACIO.
env -i HOME=/root PATH=/usr/bin:/bin SHELL=/bin/sh /bin/sh -c 'hola-cron'; echo "rc=$?"
# /bin/sh: 1: hola-cron: not found
# rc=127
# 2) Arreglo A: ruta absoluta.
env -i HOME=/root PATH=/usr/bin:/bin SHELL=/bin/sh /bin/sh -c '/usr/local/bin/hola-cron'; echo "rc=$?"
# hola desde usr-local
# rc=0
# 3) Arreglo B: fijar PATH en el crontab (y comprobarlo con cron de verdad).
cat > /tmp/p16/v.cron <<'EOF'
PATH=/usr/local/bin:/usr/bin:/bin
* * * * * hola-cron > /tmp/p16/v1.txt 2>&1
EOF
crontab /tmp/p16/v.cron
timeout 130 bash -c 'until [ -s /tmp/p16/v1.txt ]; do sleep 2; done'; echo "espera: $?"
# espera: 0
cat /tmp/p16/v1.txt
# hola desde usr-local
crontab -r
```

El código `127` es el de «comando no encontrado». En `cron`, sin redirección,
**no lo habrías visto** (paso 6).

**Verifica**:

```bash
grep -q 'hola desde usr-local' /tmp/p16/v1.txt && echo "PATH arreglado"
# PATH arreglado
```

## Paso 5: `%` y `sh`: dos trampas silenciosas

**Por qué**: las dos fallan **sin ningún mensaje**. Un `%` sin escapar parte la
línea y un `[[ ]]` con `dash` no existe. Las provocas a propósito para
reconocerlas cuando aparezcan solas.

**Comando**:

```bash
cat > /tmp/p16/t.cron <<'EOF'
* * * * * date +%T >> /tmp/p16/pct1.log
* * * * * date +\%T >> /tmp/p16/pct2.log
* * * * * [[ 1 -eq 1 ]] && echo ok > /tmp/p16/sh1.txt || echo fallo > /tmp/p16/sh1.txt
EOF
crontab /tmp/p16/t.cron
timeout 130 bash -c 'until [ -s /tmp/p16/pct2.log ] && [ -s /tmp/p16/sh1.txt ]; do sleep 2; done'; echo "espera: $?"
# espera: 0
ls /tmp/p16/pct1.log
# ls: cannot access '/tmp/p16/pct1.log': No such file or directory
cat /tmp/p16/pct2.log
# 04:52:07
cat /tmp/p16/sh1.txt
# fallo
crontab -r
```

`pct1.log` **no existe**: el `%` partió el comando. `sh1.txt` dice `fallo`:
`dash` no entiende `[[`, y el `|| echo fallo` lo ocultó. Ahora arregla el
segundo con `SHELL=/bin/bash` al principio del `crontab`:

```bash
sed -i '1i SHELL=/bin/bash' /tmp/p16/t.cron
rm -f /tmp/p16/sh1.txt
crontab /tmp/p16/t.cron
timeout 130 bash -c 'until [ -s /tmp/p16/sh1.txt ]; do sleep 2; done'
cat /tmp/p16/sh1.txt
# ok
crontab -r
```

**Verifica**:

```bash
cat /tmp/p16/sh1.txt; [ ! -e /tmp/p16/pct1.log ] && echo "pct1.log no existe"
# ok
# pct1.log no existe
```

## Paso 6: Un error que no se ve frente a uno que queda registrado

**Por qué**: en el laboratorio no hay servidor de correo ni registro del
sistema, así que la salida de una tarea sin redirigir **desaparece**. Es el
fallo n.º 1 de las tareas programadas (teoría 05). Programas dos tareas
idénticas, una sin redirigir y otra con `>> archivo 2>&1`.

**Comando**:

```bash
cat > /tmp/p16/e.cron <<'EOF'
* * * * * ls /no/existe
* * * * * ls /no/existe >> /tmp/p16/err.log 2>&1
EOF
crontab /tmp/p16/e.cron
timeout 130 bash -c 'until [ -s /tmp/p16/err.log ]; do sleep 2; done'; echo "espera: $?"
# espera: 0
cat /tmp/p16/err.log
# ls: cannot access '/no/existe': No such file or directory
crontab -r
```

Las dos tareas fallaron igual. **Solo la segunda dejó rastro.** De la primera
no queda nada en ningún sitio que puedas consultar.

**Verifica**:

```bash
grep -q 'No such file' /tmp/p16/err.log && echo "error registrado"
# error registrado
```

## Paso 7: Limpieza

**Por qué**: una tarea de prueba olvidada se ejecuta cada minuto para siempre.

> **Aviso**: `crontab -r` borra tu tabla entera **sin pedir confirmación**. El
> respaldo del paso 1 (`crontab.orig`) es lo que te permite restaurarla. En una
> máquina real, haz siempre `crontab -l > respaldo` antes de nada.

**Comando**:

```bash
crontab -r 2>/dev/null
# Si tenias una tabla antes de empezar, la restauras desde el respaldo del paso 1:
if [ -s /tmp/p16/crontab.orig ]; then crontab /tmp/p16/crontab.orig; fi
rm -rf /tmp/p16 /usr/local/bin/hola-cron
```

**Verifica**:

```bash
crontab -l 2>&1; ls /tmp/p16 2>&1
# no crontab for root
# ls: cannot access '/tmp/p16': No such file or directory
```

## ✅ Resultado

- [ ] `cron` está instalado y corriendo en `ubuntu-lab` (`pgrep -x cron`)
- [ ] Una tarea cada minuto dejó su hora en un archivo, y la quitaste
- [ ] Comparaste el entorno de `cron` con el tuyo: `PATH=/usr/bin:/bin`, `SHELL=/bin/sh`, directorio `HOME`
- [ ] Reprodujiste `hola-cron: not found` (código `127`) y lo arreglaste de dos formas
- [ ] Viste que `date +%T` sin escapar no escribe nada y que `[[` falla bajo `dash`
- [ ] Comprobaste que una tarea sin redirección **no deja rastro** y otra con `>> archivo 2>&1` sí
- [ ] Dejaste el laboratorio sin tareas ni archivos de prueba

```bash
./scripts/verificar-semana.sh 16
```

(Esta práctica no tiene entregable propio: son los hechos sobre los que
descansa `schedule`.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| La espera devuelve `124` | `cron` no corre, o escribiste mal la ruta | `pgrep -x cron || cron`; revisa `crontab -l` |
| `crontab: command not found` | Falta el paquete | `apt-get install -y cron` |
| `crontab` dice `errors in crontab file, can't install` | Un campo inválido o falta un salto de línea final | Lee el mensaje (`bad minute`, `bad day-of-week`…) y corrige esa línea |
| El archivo del paso 2 sale con **dos** horas | Dejaste la tarea corriendo más de un minuto | Normal; `crontab -r` y sigue |
| `hola-cron` funciona en el paso 4 sin arreglo | Tu `crontab` anterior seguía con un `PATH` | `crontab -r` y repite |
| `pct1.log` sí existe | Escribiste `\%` en la primera línea | Quita la barra: debe ir **sin** escapar para ver el fallo |
| `sh1.txt` dice `ok` antes del `SHELL=/bin/bash` | Tu `/bin/sh` es `bash` (no es Ubuntu) | Comprueba con `ls -l /bin/sh`; en RHEL y Arch es `bash` y el `[[ ]]` funciona |
| `apt-get install` falla | Sin red o sin `apt-get update` | Repite el `update`; comprueba la red del laboratorio |

---

[← Construyendo `schedule`](../1-teoria/08-construyendo-schedule.md) · [Práctica 02: `cron.d`, `run-parts` y trampas →](02-cron-d-run-parts-y-trampas.md)
