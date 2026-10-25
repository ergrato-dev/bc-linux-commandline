# Práctica 02 — `cron.d`, `run-parts` y trampas

> Duración estimada: 75 min · Teoría de apoyo: archivos [02](../1-teoria/02-expresiones-de-cron-y-sus-trampas.md), [04](../1-teoria/04-cron-en-el-sistema-y-at.md) y [05](../1-teoria/05-tareas-programadas-que-no-fallan-en-silencio.md)

Trabajas **dentro de `ubuntu-lab`**, con `cron` instalado y corriendo (práctica
01, paso 1) y con tu `toolkit.sh` de la Semana 15 en `/root/bin` (la tarea
usa su subcomando `guard`).

```bash
docker exec -it ubuntu-lab bash
pgrep -x cron >/dev/null || cron
/root/bin/toolkit.sh guard -- true; echo "codigo: $?"
# 2026-10-25T04:55:16 INFO intento 1/1: true
# 2026-10-25T04:55:16 INFO ok
# 2026-10-25T04:55:16 INFO fin: codigo de salida 0
# codigo: 0
rm -rf /tmp/p16b && mkdir -p /tmp/p16b && cd /tmp/p16b
crontab -l > /tmp/p16b/crontab.orig 2>/dev/null || true   # respaldo de tu tabla
```

## Paso 1: Cuatro archivos en `/etc/cron.d`, uno solo funciona

**Por qué**: `cron.d` ignora **sin avisar** los nombres con punto, las líneas
sin usuario y los archivos escribibles por todos. Cuando una tarea de sistema
«no corre», casi siempre es una de las tres. Creas cuatro casi iguales para
ver cuál sobrevive.

**Comando**:

```bash
# Cada tarea escribe la hora en /tmp/p16b/cd-NOMBRE.txt cada minuto.
for n in cronok cron.dot cronperm; do
  printf '* * * * * root date +\%%T >> /tmp/p16b/cd-%s.txt\n' "$n" > "/etc/cron.d/$n"
done
printf '* * * * * date +\%%T >> /tmp/p16b/cd-cronnouser.txt\n' > /etc/cron.d/cronnouser
chmod 666 /etc/cron.d/cronperm     # escribible por todos: a proposito, solo en el laboratorio
ls -l /etc/cron.d
# -rw-r--r-- 1 root root  49 Oct 25 04:39 cron.dot
# -rw-r--r-- 1 root root  42 Oct 25 04:39 cronnouser
# -rw-r--r-- 1 root root  47 Oct 25 04:39 cronok
# -rw-rw-rw- 1 root root  49 Oct 25 04:39 cronperm
# -rw-r--r-- 1 root root 201 Apr  8  2024 e2scrub_all
cat /etc/cron.d/cronok
# * * * * * root date +\%T >> /tmp/p16b/cd-cronok.txt
# Espera a que aparezca el primero (devuelve 0), y un poco mas para dar margen a los demas:
timeout 130 bash -c 'until [ -s /tmp/p16b/cd-cronok.txt ]; do sleep 2; done'; echo "espera: $?"
# espera: 0
sleep 5
ls /tmp/p16b/cd-*.txt
# /tmp/p16b/cd-cronok.txt
```

Solo `cronok` corrió: `cron.dot` por el punto, `cronnouser` por faltarle el
campo de usuario, `cronperm` por ser escribible por todos.

**Verifica**:

```bash
ls /tmp/p16b/cd-*.txt | wc -l
# 1
```

Limpia ya, para que no sigan corriendo cada minuto:

```bash
rm -f /etc/cron.d/cronok /etc/cron.d/cron.dot /etc/cron.d/cronperm /etc/cron.d/cronnouser
ls /etc/cron.d
# e2scrub_all
```

## Paso 2: `run-parts` y los nombres que se saltan

**Por qué**: `cron.daily` no lee líneas de `crontab`: lanza **scripts
ejecutables** con un nombre válido. Un script con extensión o sin permiso de
ejecución simplemente **no se ejecuta**. `run-parts --test` te lo enseña sin
ejecutar nada.

**Comando**:

```bash
cd /etc/cron.daily
touch p16-ok p16-con.punto p16-noexec p16-conmas~
chmod 755 p16-ok p16-con.punto p16-conmas~
chmod 644 p16-noexec
run-parts --test /etc/cron.daily | grep p16
# /etc/cron.daily/p16-ok
cd /tmp/p16b
```

Cuatro archivos y solo **uno** entra: `p16-con.punto` se salta por el punto,
`p16-noexec` por no ser ejecutable y `p16-conmas~` por la tilde (resto de un
editor).

**Verifica**:

```bash
run-parts --test /etc/cron.daily | grep -c p16
# 1
rm -f /etc/cron.daily/p16-*          # limpieza
ls /etc/cron.daily | grep -c p16
# 0
```

(La lista completa de `cron.daily` puede traer más archivos, como `apt-compat`
o `dpkg`: no son tuyos, no los toques.)

## Paso 3: La regla del O, comprobada

**Por qué**: la teoría dice que día del mes **y** día de la semana restringidos
se unen con **O**. Es difícil de creer hasta que lo ves: eliges un día del
mes que **no es hoy**, el día de la semana **de hoy**, y la tarea **corre**.

**Comando**:

```bash
dom=$(( 10#$(date +%d) % 28 + 1 ))      # un dia del mes que NO es hoy
dow=$(date +%w)                         # el dia de la semana de HOY
echo "hoy es dia $(date +%d); programas dia del mes $dom y dia de la semana $dow"
echo "* * ${dom} * ${dow} date +\%T >> /tmp/p16b/or.log" | crontab -
crontab -l
# * * 26 * 0 date +\%T >> /tmp/p16b/or.log        (con hoy = domingo 25)
timeout 130 bash -c 'until [ -s /tmp/p16b/or.log ]; do sleep 2; done'; echo "espera: $?"
# espera: 0
cat /tmp/p16b/or.log
# 04:57:01
crontab -r
```

Corrió aunque hoy **no** es el día `${dom}`. Con `Y` no habría corrido nunca
hoy. (Si repites a medianoche, el día del mes cambia: usa el valor que
imprime tu primera línea.)

**Verifica**:

```bash
[ -s /tmp/p16b/or.log ] && echo "corrio por el dia de la semana"
# corrio por el dia de la semana
```

Y para contrastar, `systemd-analyze` los une con **Y** (la próxima ejecución
estará lejos):

```bash
systemd-analyze calendar "$(date +%a) *-*-$dom" | grep -E 'Normalized|Next'
# Normalized form: Sun *-*-26 00:00:00
#     Next elapse: Sun 2027-09-26 00:00:00 UTC
```

(Tu fecha será otra. Lo importante: **no** es mañana.)

## Paso 4: `*/7` no es «cada 7 minutos»

**Por qué**: es la trampa de los pasos que no dividen a 60. No hace falta
esperar para verla: calcula los minutos que cubre.

**Comando**:

```bash
for m in $(seq 0 7 59); do printf '%s ' "$m"; done; echo
# 0 7 14 21 28 35 42 49 56
# Diferencia entre el ultimo minuto de una hora y el primero de la siguiente:
echo $(( 60 - 56 ))
# 4
```

**Verifica**:

```bash
seq 0 7 59 | wc -l
# 9
```

Nueve ejecuciones por hora, con un hueco de **4** minutos al pasar de hora y
no de 7: por eso `*/7` **no** es un intervalo regular. Para uno exacto
necesitas `OnUnitActiveSec=7min` (práctica 03).

## Paso 5: Tres tareas bajo `guard`: bloqueo, fallo y límite de tiempo

**Por qué**: es el patrón de la teoría 05. Tres tareas con tres problemas
distintos, todas envueltas en `guard` y con la salida redirigida. Luego lees
**en el registro** qué les pasó: es lo único que tendrías a las 3:00.

**Comando**:

```bash
rm -f /var/tmp/p16-*.log /var/tmp/p16-*.lock
cat > /tmp/p16b/g.cron <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/p16-largo.lock -- /usr/bin/sleep 75 >> /var/tmp/p16-largo.log 2>&1
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/p16-falla.lock -r 1 -w 1 -- /usr/bin/ls /no/existe >> /var/tmp/p16-falla.log 2>&1
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/p16-cuelga.lock -t 2 -- /usr/bin/sleep 30 >> /var/tmp/p16-cuelga.log 2>&1
EOF
crontab /tmp/p16b/g.cron
# El bloqueo solo se ve en la SEGUNDA ejecucion de "largo": espera hasta 3 minutos.
timeout 200 bash -c 'until grep -q bloqueado /var/tmp/p16-largo.log 2>/dev/null; do sleep 3; done'; echo "espera: $?"
# espera: 0
crontab -r
cat /var/tmp/p16-largo.log
# 2026-10-25T04:42:04 INFO intento 1/1: /usr/bin/sleep 75
# 2026-10-25T04:43:04 ERROR bloqueado: otra ejecucion tiene /var/tmp/p16-largo.lock
# 2026-10-25T04:43:04 INFO fin: codigo de salida 3
tail -n 4 /var/tmp/p16-falla.log
# 2026-10-25T04:43:05 INFO intento 2/2: /usr/bin/ls /no/existe
# 2026-10-25T04:43:05 WARN fallo con codigo 2
# 2026-10-25T04:43:05 INFO salida: /usr/bin/ls: cannot access '/no/existe': No such file or directory
# 2026-10-25T04:43:05 INFO fin: codigo de salida 2
tail -n 3 /var/tmp/p16-cuelga.log
# 2026-10-25T04:43:04 INFO intento 1/1: /usr/bin/sleep 30
# 2026-10-25T04:43:06 WARN timeout tras 2s
# 2026-10-25T04:43:06 INFO fin: codigo de salida 4
```

(Las horas serán las tuyas. En `p16-falla.log` hay además una línea sin fecha
con el mensaje de `ls`: es la salida del comando que `guard` imprime al
final.)

**Verifica**:

```bash
grep -h 'fin: codigo de salida' /var/tmp/p16-largo.log /var/tmp/p16-falla.log /var/tmp/p16-cuelga.log | awk '{print $NF}' | sort -u
# 2
# 3
# 4
```

Tres códigos distintos, tres historias: `3` bloqueada, `2` falló, `4` agotó el
tiempo. La tercera «ejecución» de cada tarea la comprobarás en el registro
cuando pase el siguiente minuto: no hace falta.

## Paso 6: El latido y la deriva del `crontab`

**Por qué**: los registros solo cuentan lo que **ocurrió**. Si la tarea deja de
ejecutarse, no hay nada que leer. Necesitas dos cosas: un **latido** que
alguien compruebe, y una forma de saber que el `crontab` instalado sigue
siendo el que guardaste.

**Comando**:

```bash
latido=/var/tmp/p16-tarea.ok
touch "$latido"
comprobar() { [[ -n $(find "$latido" -mmin -1440 2>/dev/null) ]] && echo "OK: exito en las ultimas 24 h" || echo "ALERTA: sin exito en 24 h"; }
comprobar
# OK: exito en las ultimas 24 h
touch -d "2 days ago" "$latido"; comprobar
# ALERTA: sin exito en 24 h
rm "$latido"; comprobar
# ALERTA: sin exito en 24 h
# Deriva: instalas un archivo, alguien edita la tabla, diff lo detecta.
printf '0 3 * * * /usr/bin/true\n' > /tmp/p16b/guardado.cron
crontab /tmp/p16b/guardado.cron
diff <(crontab -l) /tmp/p16b/guardado.cron && echo "sin deriva"
# sin deriva
crontab -l | sed 's/^0 3/0 4/' | crontab -
diff <(crontab -l) /tmp/p16b/guardado.cron; echo "codigo: $?"
# 1c1
# < 0 4 * * * /usr/bin/true
# ---
# > 0 3 * * * /usr/bin/true
# codigo: 1
```

**Verifica**:

```bash
diff <(crontab -l) /tmp/p16b/guardado.cron >/dev/null; echo "codigo: $?"
# codigo: 1
crontab /tmp/p16b/guardado.cron; diff <(crontab -l) /tmp/p16b/guardado.cron >/dev/null; echo "codigo: $?"
# codigo: 0
```

## Paso 7: Limpieza

**Por qué**: nada de esto debe seguir ejecutándose.

> **Aviso**: `crontab -r` borra tu tabla entera sin confirmar; la restauras con
> el respaldo que hiciste al empezar.

**Comando**:

```bash
crontab -r 2>/dev/null
if [ -s /tmp/p16b/crontab.orig ]; then crontab /tmp/p16b/crontab.orig; fi
rm -rf /tmp/p16b /var/tmp/p16-*
```

**Verifica**:

```bash
ls /tmp/p16b /var/tmp/p16-* 2>&1 | head -2
# ls: cannot access '/tmp/p16b': No such file or directory
# ls: cannot access '/var/tmp/p16-*': No such file or directory
```

## ✅ Resultado

- [ ] Solo `cronok` corrió de los cuatro archivos de `/etc/cron.d`, y sabes explicar por qué fallan los otros tres
- [ ] `run-parts --test` omite el script con punto, el no ejecutable y el que termina en `~`
- [ ] Viste que una tarea con día del mes (que no es hoy) y día de la semana (de hoy) **corre**
- [ ] Calculaste el hueco de 4 minutos de `*/7`
- [ ] Leíste en el registro un código `3`, un `2` y un `4` de tres tareas reales bajo `guard`
- [ ] Hiciste la comprobación del latido con un archivo reciente, uno viejo y uno ausente
- [ ] `diff <(crontab -l) archivo` detecta una edición a mano

```bash
./scripts/verificar-semana.sh 16
```

(Esta práctica no tiene entregable propio: son las piezas que `schedule`
automatiza.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| Ningún `cd-*.txt` aparece | `cron` no corre | `pgrep -x cron \|\| cron` |
| Corren también `cron.dot` o `cronnouser` | Dejaste archivos de una prueba anterior o la distribución es otra | Borra `/etc/cron.d/cron*` y repite; en Ubuntu deben ignorarse |
| `printf` imprime `\%` con la barra en el archivo | Es lo correcto: la barra va **dentro** del archivo | `cat /etc/cron.d/cronok` debe mostrar `+\%T` |
| El paso 3 no escribe nada | Hoy es el día `${dom}` o cambiaste de día a mitad | Repite el comando; recalcula `dom` y `dow` |
| El registro de `largo` no tiene `bloqueado` | Espera menos de dos minutos, o `guard` sin `-k` | Espera más (`timeout 200`) y revisa `crontab -l` |
| `/root/bin/toolkit.sh: No such file` | Lab recreado: `/root/bin` se borra | `docker cp` el `toolkit.sh` de la Semana 15 de nuevo (`docs/setup-entorno.md`, sección 5) |
| `find: ... No such file` aparece en pantalla | Olvidaste el `2>/dev/null` | Añádelo dentro de la función `comprobar` |

---

[← Práctica 01: `cron` en vivo y su entorno](01-cron-en-vivo-y-su-entorno.md) · [Práctica 03: temporizadores de systemd sin systemd →](03-temporizadores-de-systemd-sin-systemd.md)
