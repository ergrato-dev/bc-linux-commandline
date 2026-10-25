# Práctica 03 — Temporizadores de systemd, sin systemd

> Duración estimada: 75 min · Teoría de apoyo: archivos [06](../1-teoria/06-temporizadores-de-systemd.md) y [07](../1-teoria/07-unidades-service-para-tareas.md)

Los contenedores del laboratorio no corren systemd, así que **no puedes**
activar un temporizador aquí (`systemctl enable`, `list-timers` y
`journalctl` necesitan un systemd en marcha). Lo que sí puedes es lo más
importante: **escribir las unidades y comprobarlas** con `systemd-analyze`,
que no necesita el demonio. Cada paso dice qué verías en un host real.

Trabajas **dentro de `ubuntu-lab`**:

```bash
docker exec -it ubuntu-lab bash
apt-get install -y -qq systemd        # solo aporta systemd-analyze; no arranca nada
rm -rf /tmp/p16c && mkdir -p /tmp/p16c && cd /tmp/p16c
```

## Paso 1: Leer cómo entiende systemd un calendario

**Por qué**: `OnCalendar=` tiene su propia sintaxis, y `systemd-analyze
calendar` es el «explicador» oficial: te devuelve la **forma normalizada** y
la próxima ejecución. Es tu herramienta de depuración de horarios.

**Comando**:

```bash
systemd-analyze --version | head -1
# systemd 255 (255.4-1ubuntu8.18)
for e in "hourly" "daily" "weekly" "Mon..Fri 09:00" "*:0/15" "02:30"; do
  printf '%s  ->  ' "$e"
  systemd-analyze calendar "$e" | sed -n 's/^Normalized form: //p'
done
# hourly  ->  *-*-* *:00:00
# daily  ->  *-*-* 00:00:00
# weekly  ->  Mon *-*-* 00:00:00
# Mon..Fri 09:00  ->  Mon..Fri *-*-* 09:00:00
# *:0/15  ->  *-*-* *:00/15:00
# 02:30  ->  *-*-* 02:30:00
```

Tres cosas a notar: `daily` es **medianoche**, no «una vez al día a una hora
razonable»; `weekly` es el **lunes** a medianoche; y `02:30` sin fecha
significa **todos los días**.

**Verifica**:

```bash
systemd-analyze calendar "daily" | grep -c '^Normalized form: \*-\*-\* 00:00:00$'
# 1
```

## Paso 2: Las próximas ejecuciones, no solo la primera

**Por qué**: la primera ejecución puede ser correcta y la tercera no (meses
con 31 días, días de la semana). `--iterations` enseña las siguientes.

**Comando**:

```bash
systemd-analyze calendar --iterations=4 "Mon..Fri 09:00" | grep -E 'Next|Iteration'
#     Next elapse: Mon 2026-10-26 09:00:00 UTC
#    Iteration #2: Tue 2026-10-27 09:00:00 UTC
#    Iteration #3: Wed 2026-10-28 09:00:00 UTC
#    Iteration #4: Thu 2026-10-29 09:00:00 UTC
```

(Las fechas son las del día en que lo ejecutes.)

**Verifica**:

```bash
systemd-analyze calendar --iterations=4 "Mon..Fri 09:00" | grep -c 'Iteration'
# 3
```

## Paso 3: Traducir cuatro expresiones de `cron` a mano

**Por qué**: es el ejercicio que `toolkit.sh schedule gen` automatiza. Hazlo
una vez a mano para entender cada decisión, y **contrasta con systemd** en
lugar de fiarte de tu traducción.

| `cron` | Frase | `OnCalendar` que propones |
|---|---|---|
| `30 2 * * 1-5` | 02:30, de lunes a viernes | `Mon..Fri 02:30` |
| `0 */6 * * *` | cada 6 horas en punto | `*-*-* 00/6:00:00` |
| `0 0 1,15 * *` | los días 1 y 15, a medianoche | `*-*-01,15 00:00:00` |
| `0 3 * * 0` | los domingos a las 03:00 | `Sun 03:00` |

**Comando**:

```bash
for e in "Mon..Fri 02:30" "*-*-* 00/6:00:00" "*-*-01,15 00:00:00" "Sun 03:00"; do
  printf '%s  ->  ' "$e"
  systemd-analyze calendar "$e" | sed -n 's/^Normalized form: //p'
done
# Mon..Fri 02:30  ->  Mon..Fri *-*-* 02:30:00
# *-*-* 00/6:00:00  ->  *-*-* 00/6:00:00
# *-*-01,15 00:00:00  ->  *-*-01,15 00:00:00
# Sun 03:00  ->  Sun *-*-* 03:00:00
```

Si una de tus propuestas **no se parsea**, `systemd-analyze` dice
`Failed to parse calendar specification`. Las cuatro de arriba son válidas;
comprueba que las próximas ejecuciones (`--iterations=3`) son las que
esperabas, sobre todo la segunda (`00/6` son las 0, 6, 12 y 18 h).

**Verifica**:

```bash
systemd-analyze calendar "*-*-* 00/6:00:00" >/dev/null && echo "valida"
# valida
```

## Paso 4: Escribir el `.service` y el `.timer` a mano y romperlos

**Por qué**: así reconoces los mensajes de error cuando aparezcan solos. Sale
el par `tarea.service` + `tarea.timer`, `verify` da el visto bueno, y luego
introduces cuatro fallos para ver qué detecta y qué **no**.

**Comando**:

```bash
cat > tarea.service <<'EOF'
[Unit]
Description=Tarea de practica

[Service]
Type=oneshot
ExecStart=/usr/bin/true
EOF
cat > tarea.timer <<'EOF'
[Unit]
Description=Temporizador de la tarea de practica

[Timer]
OnCalendar=Mon..Fri 02:30
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemd-analyze verify ./tarea.service ./tarea.timer; echo "codigo: $?"
# codigo: 0
```

Ahora rompes uno a uno. **Fallo 1**: hora imposible.

```bash
sed -i 's/^OnCalendar=.*/OnCalendar=Mon..Fri 25:30/' tarea.timer
systemd-analyze verify ./tarea.service ./tarea.timer; echo "codigo: $?"
# /tmp/p16c/tarea.timer:5: Failed to parse calendar specification, ignoring: Mon..Fri 25:30
# tarea.timer: Timer unit lacks value setting. Refusing.
# Unit tarea.timer has a bad unit file setting.
# codigo: 1
```

**Fallo 2**: una errata en la clave (`Persitent`). Es **grave y no aborta**:

```bash
sed -i 's/^OnCalendar=.*/OnCalendar=Mon..Fri 02:30/;s/^Persistent=true/Persitent=true/' tarea.timer
systemd-analyze verify ./tarea.service ./tarea.timer; echo "codigo: $?"
# /tmp/p16c/tarea.timer:6: Unknown key name 'Persitent' in section 'Timer', ignoring.
# codigo: 0
sed -i 's/^Persitent/Persistent/' tarea.timer       # lo arreglas
```

Código `0` con una directiva **tirada a la basura**: sin `Persistent=true` una
ejecución perdida por una máquina apagada no se recuperaría, y no te enterarías.

**Fallo 3**: el comando no es una ruta absoluta.

```bash
sed -i 's#^ExecStart=.*#ExecStart=mi-script#' tarea.service
systemd-analyze verify ./tarea.service ./tarea.timer; echo "codigo: $?"
# tarea.service: Command mi-script is not executable: No such file or directory
# codigo: 1
```

**Fallo 4**: un pipe en `ExecStart=`. `verify` **no se queja**:

```bash
sed -i 's#^ExecStart=.*#ExecStart=/usr/bin/echo hola | /usr/bin/tr a-z A-Z#' tarea.service
systemd-analyze verify ./tarea.service ./tarea.timer; echo "codigo: $?"
# codigo: 0
# Lo que systemd ejecutaria de verdad: echo recibe "|" y el resto como argumentos.
/usr/bin/echo hola '|' /usr/bin/tr a-z A-Z
# hola | /usr/bin/tr a-z A-Z
```

**Verifica**:

```bash
sed -i 's#^ExecStart=.*#ExecStart=/usr/bin/true#' tarea.service
systemd-analyze verify ./tarea.service ./tarea.timer; echo "codigo: $?"
# codigo: 0
```

En un **host** (no aquí) lo siguiente sería `sudo cp tarea.* /etc/systemd/system/`,
`sudo systemctl daemon-reload` y `sudo systemctl enable --now tarea.timer`.
Verías la próxima ejecución en `systemctl list-timers` y la salida de la tarea
en `journalctl -u tarea.service`.

## Paso 5: Un temporizador monotónico: «cada 7 minutos» de verdad

**Por qué**: `cron` no puede hacer `*/7` regular (práctica 02, paso 4). Un
temporizador monotónico cuenta **desde la última ejecución**, no desde el
reloj de pared.

**Comando**:

```bash
systemd-analyze timespan 15min 1h "2h 30min" 90 | grep -E 'Original|Human|μs'
# Original: 15min
#       μs: 900000000
#    Human: 15min
# Original: 1h
#       μs: 3600000000
#    Human: 1h
# Original: 2h 30min
#       μs: 9000000000
#    Human: 2h 30min
# Original: 90
#       μs: 90000000
#    Human: 1min 30s
printf '[Timer]\nOnBootSec=15min\nOnUnitActiveSec=7min\n' > rapido.timer
printf '[Service]\nExecStart=/usr/bin/true\n' > rapido.service
systemd-analyze verify ./rapido.timer ./rapido.service; echo "codigo: $?"
# codigo: 0
```

Un número **sin unidad** son segundos: `90` es `1min 30s`. La unidad dice:
«15 minutos después de arrancar, y luego 7 minutos después de la **última**
ejecución». En un host, `systemctl list-timers` mostraría `LAST` y `NEXT`
siempre 7 minutos aparte.

**Verifica**:

```bash
systemd-analyze timespan 7min | grep -c 'Human: 7min'
# 1
```

## Paso 6: «Y» frente a «O»: el viernes 13

**Por qué**: es la diferencia de fondo entre `cron` y systemd, y la razón de
que `schedule gen` se niegue a traducir una expresión con día del mes y día de
la semana a la vez. En systemd, `Fri *-*-13` es **solo los viernes 13**.

**Comando**:

```bash
systemd-analyze calendar --iterations=3 "Fri *-*-13" | grep -E 'Next|Iteration'
#     Next elapse: Fri 2026-11-13 00:00:00 UTC
#    Iteration #2: Fri 2027-08-13 00:00:00 UTC
#    Iteration #3: Fri 2028-10-13 00:00:00 UTC
```

Tres viernes 13 en **dos años**. `0 0 13 * 5` en `cron` correría **cada** día
13 y **cada** viernes (práctica 02, paso 3): unas sesenta veces al año.

**Verifica**:

```bash
systemd-analyze calendar --iterations=3 "Fri *-*-13" | grep -E 'Next|Iteration' | grep -c ' Fri '
# 3
```

## Paso 7: Limpieza

**Por qué**: son archivos de práctica, no unidades instaladas. Aun así, no
dejes basura en `/tmp`.

**Comando**:

```bash
cd / && rm -rf /tmp/p16c
```

**Verifica**:

```bash
ls /tmp/p16c 2>&1
# ls: cannot access '/tmp/p16c': No such file or directory
```

## ✅ Resultado

- [ ] Leíste la forma normalizada de seis calendarios con `systemd-analyze calendar`
- [ ] Viste las cuatro próximas ejecuciones de `Mon..Fri 09:00`
- [ ] Tradujiste cuatro expresiones de `cron` a `OnCalendar` y las contrastaste con systemd
- [ ] Escribiste `tarea.service` y `tarea.timer` y `verify` salió con `0`
- [ ] Provocaste cuatro fallos y anotaste cuál **no** detecta `verify` (el pipe y la errata con código `0`)
- [ ] Explicas por qué `OnUnitActiveSec=7min` resuelve lo que `*/7` no
- [ ] Viste que `Fri *-*-13` son solo viernes 13 (tres en dos años)

```bash
./scripts/verificar-semana.sh 16
```

(Esta práctica no tiene entregable propio: son las unidades que `schedule gen`
escribirá por ti en la práctica 04.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `systemd-analyze: command not found` | No instalaste `systemd` | `apt-get install -y systemd` |
| `Failed to parse calendar specification` | Sintaxis de `OnCalendar` inválida (hora fuera de rango, falta de `..`) | Comprueba con `systemd-analyze calendar "..."` hasta que se parsee |
| `systemctl` dice `System has not been booted with systemd as init system` | Es un contenedor: no hay systemd en marcha | Es lo esperado; usa `systemd-analyze`. `systemctl` solo en un host |
| `verify` no dice nada y el código es `0` | Unidad válida, pero puede hacer otra cosa de lo que crees | `verify` no ejecuta nada: léela de nuevo y, en un host, arráncala con `systemctl start` |
| Las fechas de `Next elapse` no coinciden con las del texto | Son las del día en que ejecutas el comando | Compara el **patrón** (días, horas), no la fecha |
| `Mon..Fri 25:30` te parece válido | `systemd-analyze` lo rechaza; revisa si usaste `sed` y reescribiste la línea correcta | `grep OnCalendar tarea.timer` |

---

[← Práctica 02: `cron.d`, `run-parts` y trampas](02-cron-d-run-parts-y-trampas.md) · [Práctica 04: `schedule` a mano →](04-schedule-a-mano.md)
