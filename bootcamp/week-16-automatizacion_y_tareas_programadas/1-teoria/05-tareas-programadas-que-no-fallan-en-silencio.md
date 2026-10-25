# Tareas programadas que no fallan en silencio

> `cron` ejecuta tu comando y se olvida de él: no mira el código de salida,
> no reintenta, no avisa. Todo lo que quieras saber de una tarea nocturna lo
> tienes que haber dejado escrito **tú**, antes.

## 🎯 Objetivos

- Nombrar los cuatro fallos típicos de una tarea programada: silencio, solapamiento, cuelgue y olvido
- Envolver una tarea con `guard` y leer en el registro qué le pasó
- Detectar una tarea que **dejó de ejecutarse** (no solo la que falla) con un archivo «latido»
- Mantener el `crontab` bajo control de versiones y detectar la deriva con `diff`
- Probar una tarea como la ejecutaría `cron` antes de programarla

## 1. Qué problema resuelve

La regla de seguridad n.º 5 de este bootcamp dice: **todo ejemplo de
automatización lleva manejo de error explícito**. Esta es la razón. Una tarea
programada pasa semanas sin que nadie la mire, y puede fallar de cuatro
maneras:

| Fallo | Qué pasa | Defensa (Semana 15) |
|---|---|---|
| **Silencio** | Falla y el error se pierde (sin MTA, sin terminal) | Redirigir a un registro (`>> log 2>&1`) |
| **Solapamiento** | La ejecución de las 3:00 aún corre cuando llega la de las 3:05 | `flock` (`guard -k`) |
| **Cuelgue** | Un comando de red no responde nunca y se acumulan los lanzamientos | `timeout` (`guard -t`) |
| **Olvido** | La tarea **dejó de ejecutarse** (cron parado, línea borrada) y no hay nada que falle | Un latido que alguien vigile |

`guard` (Semana 15) cubre las tres primeras. El cuarto es el más traicionero
porque **no deja ningún rastro**: un error se ve; la ausencia de una
ejecución, no.

## 2. Cómo funciona

### 2.1 La línea completa

```
M H D M W  RUTA/toolkit.sh guard -k BLOQUEO -t SEGUNDOS -- COMANDO ARGS >> REGISTRO 2>&1
```

Es lo que genera `toolkit.sh schedule gen`. Cada pieza resuelve un fallo:
`guard` envuelve, `-k` evita el solapamiento, `-t` el cuelgue, y la
redirección guarda **todo**: la salida del comando, el registro de `guard`
(que va a `stderr`) y los errores de uso del propio `guard`.

### 2.2 Qué deja escrito: cuatro tareas reales

Programé las cuatro en `ubuntu-lab` para que corrieran cada minuto y las dejé
dos minutos. Las cuatro envueltas en `guard`, cada una con su registro:

```bash
cat > /tmp/n.cron <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/n-largo.lock -- /usr/bin/sleep 75 >> /var/tmp/n-largo.log 2>&1
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/n-falla.lock -r 1 -w 1 -- /usr/bin/ls /no/existe >> /var/tmp/n-falla.log 2>&1
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/n-cuelga.lock -t 2 -- /usr/bin/sleep 30 >> /var/tmp/n-cuelga.log 2>&1
* * * * * /root/bin/toolkit.sh guard -k /var/tmp/n-ok.lock -- /usr/bin/true >> /var/tmp/n-ok.log 2>&1 && /usr/bin/touch /var/tmp/n.ok
EOF
crontab /tmp/n.cron
```

**El solapamiento** (`sleep 75` dura más que el minuto entre lanzamientos):

```bash
cat /var/tmp/n-largo.log
# 2026-10-25T04:42:04 INFO intento 1/1: /usr/bin/sleep 75
# 2026-10-25T04:43:04 ERROR bloqueado: otra ejecucion tiene /var/tmp/n-largo.lock
# 2026-10-25T04:43:04 INFO fin: codigo de salida 3
```

La segunda ejecución vio el bloqueo, se negó a empezar y lo dejó escrito, con
código `3`. Sin `-k` habría habido dos `sleep` a la vez.

**El fallo con reintento** (`ls` de una ruta que no existe, una espera de 1 s):

```bash
cat /var/tmp/n-falla.log
# 2026-10-25T04:43:04 INFO intento 1/2: /usr/bin/ls /no/existe
# 2026-10-25T04:43:04 WARN fallo con codigo 2
# 2026-10-25T04:43:05 INFO intento 2/2: /usr/bin/ls /no/existe
# 2026-10-25T04:43:05 WARN fallo con codigo 2
# /usr/bin/ls: cannot access '/no/existe': No such file or directory
# 2026-10-25T04:43:05 INFO salida: /usr/bin/ls: cannot access '/no/existe': No such file or directory
# 2026-10-25T04:43:05 INFO fin: codigo de salida 2
```

Aparecen **el mensaje de error del comando y la línea `salida:`** con sus
últimas líneas: a las 3 de la madrugada no hay otra pista. (La línea sin
fecha es la salida del comando que `guard` imprime al final.)

**El cuelgue** (`sleep 30` con límite de 2 s) y la tarea que va bien:

```bash
cat /var/tmp/n-cuelga.log
# 2026-10-25T04:43:04 INFO intento 1/1: /usr/bin/sleep 30
# 2026-10-25T04:43:06 WARN timeout tras 2s
# 2026-10-25T04:43:06 INFO fin: codigo de salida 4
cat /var/tmp/n-ok.log
# 2026-10-25T04:43:04 INFO intento 1/1: /usr/bin/true
# 2026-10-25T04:43:04 INFO ok
# 2026-10-25T04:43:04 INFO fin: codigo de salida 0
crontab -r
```

Dentro del registro, **el código final de cada ejecución está en la línea
`fin: codigo de salida N`**: `0` bien, `2` falló, `3` bloqueada, `4` agotó el
tiempo. Es un formato fácil de buscar:

```bash
grep -c 'codigo de salida [^0]' /var/tmp/n-falla.log
# 2
```

### 2.3 El latido: detectar la tarea que no corrió

Los registros solo cuentan lo que **ocurrió**. Si `cron` se paró, o alguien
borró la línea, no habrá registro nuevo y nada te lo dirá. La técnica es el
**latido** (*dead man's switch*): la tarea, cuando **tiene éxito**, toca un
archivo; otro proceso comprueba que el archivo es **reciente**.

La última tarea del ejemplo anterior lo hace con `&& touch`: el `touch` solo
corre si `guard` salió con `0`.

```bash
# Comprobacion: ¿hubo un exito en las ultimas 24 h (1440 minutos)?
latido=/var/tmp/n.ok
[[ -n $(find "$latido" -mmin -1440 2>/dev/null) ]] && echo "OK: exito en las ultimas 24 h" || echo "ALERTA: sin exito en 24 h"
# OK: exito en las ultimas 24 h
touch -d "2 days ago" "$latido"
[[ -n $(find "$latido" -mmin -1440 2>/dev/null) ]] && echo "OK: exito en las ultimas 24 h" || echo "ALERTA: sin exito en 24 h"
# ALERTA: sin exito en 24 h
rm "$latido"
[[ -n $(find "$latido" -mmin -1440 2>/dev/null) ]] && echo "OK" || echo "ALERTA: sin exito en 24 h"
# ALERTA: sin exito en 24 h
```

`find -mmin -N` selecciona archivos modificados hace **menos** de N minutos
(Semana 09). Si el archivo no existe, `find` falla con un error (silenciado
con `2>/dev/null`) y no imprime nada: también es «alerta». Quien hace esa
comprobación no puede ser la tarea que vigila (si no corre, tampoco
comprobaría): tiene que ser **otra** cosa, otra tarea, otra máquina o un
servicio de monitorización externo.

### 2.4 Versionar el `crontab` y detectar la deriva

El `crontab` instalado vive en un archivo del sistema que nadie respalda.
Guarda el **`.cron`** en un repositorio, instálalo con `crontab archivo` y
compara con `diff` lo instalado contra el archivo:

```bash
/root/bin/toolkit.sh schedule gen demo --cron '0 3 * * *' --salida /tmp -- /usr/bin/true >/dev/null
crontab /tmp/demo.cron
diff <(crontab -l) /tmp/demo.cron && echo "sin deriva"
# sin deriva
crontab -l | sed 's/^0 3/0 4/' | crontab -     # alguien edita a mano la tabla
diff <(crontab -l) /tmp/demo.cron
# 6c6
# < 0 4 * * * /root/bin/toolkit.sh guard -k /var/tmp/toolkit-demo.lock -t 300 -- /usr/bin/true >> /var/tmp/toolkit-demo.log 2>&1
# ---
# > 0 3 * * * /root/bin/toolkit.sh guard -k /var/tmp/toolkit-demo.lock -t 300 -- /usr/bin/true >> /var/tmp/toolkit-demo.log 2>&1
crontab -r
```

`diff` sale con `1` si hay deriva: se puede usar en un script de
comprobación. (`<(...)` es sustitución de procesos de `bash`, Semana 05.)

### 2.5 Probarla como la ejecutaría `cron`

No esperes a las 3:00 para ver si funciona. Dos pasos, de menos a más
esfuerzo (la emulación la viste en el [archivo 03](03-el-entorno-minimo-de-cron.md)):

1. **Emulación inmediata**: copia la parte del comando (sin los cinco campos)
   y ejecútala con el entorno de `cron`:

   ```bash
   env -i HOME="$HOME" LOGNAME="$LOGNAME" PATH=/usr/bin:/bin SHELL=/bin/bash \
     /bin/bash -c 'cd "$HOME" && /root/bin/toolkit.sh guard -- /usr/bin/true'
   ```

2. **Prueba real**: la misma línea con `* * * * *`, esperar un minuto, mirar
   el registro y **quitarla**.

## 3. Cómo se usa

La plantilla completa de una tarea programada responsable:

1. Un script o subcomando que hace **una cosa**, es idempotente (Semana 15) y
   sale con un código con significado.
2. Una línea de `crontab` que lo ejecuta con `guard` (bloqueo + límite de
   tiempo + reintentos si procede) y **redirige todo a un registro**.
3. Un latido, si la tarea es importante: `&& touch /var/tmp/NOMBRE.ok`.
4. Alguien que vigila el latido y los códigos de `fin:` distintos de `0`.
5. El `.cron` en un repositorio y un `diff` contra lo instalado.
6. Rotación del registro (`>>` crece sin límite): se aborda en la Semana 18.

`toolkit.sh schedule gen` produce los puntos 2 y 5 de una sola vez.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `MAILTO=""` sin redirigir la salida | Silencia también los errores | `>> registro 2>&1` primero |
| `> /dev/null 2>&1` «para que cron no mande correo» | Tira el error junto con el ruido | Registrar en un archivo |
| Tarea sin `flock` ni `timeout` | Un cuelgue acumula procesos hasta agotar la máquina | `guard -k -t` |
| Fiarse de que «si fallase, me enteraría» | Una tarea que no corre no falla | Latido vigilado por **otro** |
| `crontab -e` como única copia | Una reinstalación lo borra | `.cron` en el repositorio + `diff` |
| `guard ... ; touch ok` | Con `;` el latido se toca **aunque la tarea falle** | `guard ... && touch ok` |
| Registro sin rotar | Crece hasta llenar el disco | `logrotate` (Semana 18) |
| Programar y no probar | El primer fallo es a las 3:00 | Emulación con `env -i`; prueba real cada minuto |

## 5. Trucos

- **`grep -c 'codigo de salida [^0]' registro`** cuenta las ejecuciones que
  terminaron mal. Con `tail -n 1` y `awk`, tienes un resumen de salud.
- **`flock -n` desde el propio `crontab`** (`* * * * * flock -n /var/tmp/x.lock
  comando`) es la forma corta de no solaparse si no quieres `guard`. Pierdes
  el registro y el límite de tiempo.
- **`systemd-cat`** y `logger` mandan líneas al registro del sistema desde
  un script (`logger -t mi-tarea "fallo"`); en un host con `journald` las
  recoges con `journalctl -t mi-tarea`. No puedes probarlo en el laboratorio
  (no hay `journald`).

## 📚 Recursos Adicionales

- `man flock`, `man timeout`, `man find` (opción `-mmin`)

## ✅ Checklist de Verificación

- [ ] Programaste una tarea con `guard` y leíste su `fin: codigo de salida`
- [ ] Viste con tus ojos una ejecución `bloqueado` (código `3`) y una `timeout` (código `4`)
- [ ] Hiciste la comprobación del latido con un archivo reciente, uno viejo y uno ausente
- [ ] `diff <(crontab -l) archivo.cron` muestra la deriva tras editar a mano
- [ ] Explicas por qué `> /dev/null 2>&1` es peor que registrar
- [ ] Probaste una línea con `env -i` antes de programarla

---

[← `cron` en el sistema y `at`](04-cron-en-el-sistema-y-at.md) · [Temporizadores de systemd →](06-temporizadores-de-systemd.md)
