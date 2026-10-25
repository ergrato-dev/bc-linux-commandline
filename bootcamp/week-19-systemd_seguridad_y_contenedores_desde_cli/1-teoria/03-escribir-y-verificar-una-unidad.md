# Escribir y verificar una unidad

> Una unidad es un archivo de texto de tres secciones. Escribirla es fácil; lo valioso es **comprobarla antes** de que systemd la cargue.
> `systemd-analyze verify` y `calendar` funcionan sin systemd en marcha, así que se practican en `ubuntu-lab`.

## 🎯 Objetivos

- Leer y escribir las secciones `[Unit]`, `[Service]` e `[Install]` de una unidad
- Elegir el `Type=` correcto y entender `Restart=`
- Distinguir un **error** de un **aviso** en la salida de `systemd-analyze verify`
- Probar expresiones de calendario con `systemd-analyze calendar` y duraciones con `timespan`
- Reconocer la unidad que genera `toolkit schedule gen` y saber qué le falta

## 1. Qué problema resuelve

Una unidad mal escrita falla **al arrancar**, a las 3 de la madrugada, y el
único síntoma es un `failed` en `systemctl`. Casi todos los errores son de tres
familias: una ruta que no existe, una directiva escrita con una errata (systemd
la ignora con un aviso) y una expresión de calendario que no significa lo que
creías. Las tres se detectan **antes**, con herramientas que solo leen el archivo.

## 2. Cómo funciona

### 2.1 Las tres secciones

```ini
[Unit]
Description=Copia nocturna de /etc
After=network-online.target

[Service]
Type=oneshot
User=backup
ExecStart=/usr/local/bin/toolkit.sh backup create /etc --dest /var/backups/toolkit --name etc

[Install]
WantedBy=multi-user.target
```

| Sección | Para qué sirve | Directivas habituales |
|---|---|---|
| `[Unit]` | Describe la unidad y su orden respecto a otras | `Description=`, `After=`, `Wants=`, `Requires=` |
| `[Service]` | Qué se ejecuta y cómo | `ExecStart=`, `Type=`, `User=`, `Restart=`, `WorkingDirectory=` |
| `[Install]` | Qué hace `enable` | `WantedBy=` (qué target la arrastra) |

Dos reglas que ahorran fallos:

- **`ExecStart=` lleva ruta absoluta.** No hay `PATH` como en tu shell: usa
  `/usr/bin/sleep`, no `sleep`.
- **No es una shell.** Las tuberías, `&&`, `$VAR` y `~` no se interpretan. Si
  los necesitas: `ExecStart=/bin/bash -c '...'` o, mejor, un script.

### 2.2 `Type=`: cuándo se considera «arrancado»

| Type | systemd considera la unidad arrancada cuando… | Úsalo para |
|---|---|---|
| `simple` (por defecto) | el proceso se ha lanzado | un demonio que se queda en primer plano |
| `oneshot` | el proceso **termina** | tareas puntuales (copias, limpiezas) |
| `notify` | el programa avisa «estoy listo» | demonios que lo soportan (`ssh.service` lo usa) |
| `forking` | el proceso padre sale y queda un hijo | demonios antiguos que se «demonizan» solos |

`oneshot` es el que corresponde a todo lo que programaste en la Semana 16: la
tarea corre, termina, y systemd la da por completada.

### 2.3 `Restart=`: qué hacer si muere

| Valor | Reinicia si… |
|---|---|
| `no` (por defecto) | nunca |
| `on-failure` | sale con error, por señal o por tiempo agotado |
| `always` | siempre, incluso tras una salida limpia |

`ssh.service` usa `Restart=on-failure` (con `RestartPreventExitStatus=255` para
no reintentar una configuración inválida). Un servicio que cae en bucle consume
CPU: systemd limita los reintentos por defecto (`StartLimitBurst=`).

### 2.4 `systemd-analyze verify`: error o aviso

`verify` carga la unidad como lo haría systemd y avisa de lo que no encaja. Hay
una distinción importante: **un aviso no cambia el código de salida**.

```bash
docker exec ubuntu-lab bash -c '
mkdir -p /tmp/sd3 && cd /tmp/sd3
printf "[Service]\nExecStart=/usr/local/bin/no-existe --x\n" > miss.service
systemd-analyze verify ./miss.service; echo "rc=$?"'
# miss.service: Command /usr/local/bin/no-existe is not executable: No such file or directory
# rc=1
```

Ese es un **error**: la ruta no existe y el código es `1`. Compara con una errata
en una directiva:

```bash
docker exec ubuntu-lab bash -c '
cd /tmp/sd3
printf "[Unit]\nDescription=Bad\n[Service]\nExecStart=/usr/bin/sleep 100\nTypo=1\n" > bad.service
systemd-analyze verify ./bad.service; echo "rc=$?"'
# /tmp/sd3/bad.service:5: Unknown key name 'Typo' in section 'Service', ignoring.
# rc=0
```

Un **aviso**: systemd ignora la clave y sigue, con código `0`. Si lo usas en un
script de comprobación, no basta con mirar `rc`: lee también la salida. Para un
usuario que no debería usarse:

```bash
docker exec ubuntu-lab bash -c '
printf "[Service]\nExecStart=/usr/bin/sleep 100\nUser=nobody\n" > /tmp/sd3/nobody.service
systemd-analyze verify /tmp/sd3/nobody.service'
# /tmp/sd3/nobody.service:3: Special user nobody configured, this is not safe!
```

`nobody` lo comparten muchos servicios: si uno se compromete, tiene los permisos
de todos. Se usa un usuario propio o `DynamicUser=yes` (archivo 06).

### 2.5 Temporizadores: `calendar` y `timespan`

Un `.timer` se programa con `OnCalendar=` (hora de reloj) u `OnUnitActiveSec=`
(intervalo). `systemd-analyze calendar` traduce y **calcula la próxima ejecución**:

```bash
docker exec ubuntu-lab systemd-analyze calendar 'Mon..Fri *-*-* 09:00'
#   Original form: Mon..Fri *-*-* 09:00
# Normalized form: Mon..Fri *-*-* 09:00:00
#     Next elapse: Mon 2026-10-26 09:00:00 UTC
#        From now: 1 day 2h left
docker exec ubuntu-lab systemd-analyze calendar --iterations=2 daily | grep -E 'Normalized|Iteration'
# Normalized form: *-*-* 00:00:00
#    Iteration #2: Tue 2026-10-27 00:00:00 UTC
docker exec ubuntu-lab systemd-analyze calendar 'Mon..Fri 25:00'; echo "rc=$?"
# Failed to parse calendar specification 'Mon..Fri 25:00': Invalid argument
# rc=1
```

(Las fechas serán las de tu «ahora».) `timespan` hace lo mismo con duraciones:

```bash
docker exec ubuntu-lab systemd-analyze timespan '1h 30min 15s'
# Original: 1h 30min 15s
#       μs: 5415000000
#    Human: 1h 30min 15s
```

`Persistent=true` en un temporizador hace que, si la máquina estaba apagada a la
hora prevista, la tarea se ejecute **al volver a arrancar**; es lo que en `cron`
resolvías con `anacron`.

### 2.6 Un `.timer` y su `.service` juntos

```bash
docker exec ubuntu-lab bash -c '
cd /tmp/sd3
printf "[Service]\nType=oneshot\nExecStart=/usr/bin/true\n" > job.service
printf "[Timer]\nOnCalendar=Mon..Fri *-*-* 09:00\nPersistent=true\n[Install]\nWantedBy=timers.target\n" > job.timer
systemd-analyze verify ./job.timer ./job.service; echo "rc=$?"'
# rc=0
```

Sin salida y `rc=0`: ambos archivos y su relación son coherentes.

## 3. Cómo se usa

### 3.1 Verificar lo que genera `toolkit schedule gen`

La Semana 16 construyó un generador de unidades. Ahora puedes comprobar lo que
produce, y de paso ver qué **no** pone:

```bash
docker exec ubuntu-lab bash -c '
rm -rf /tmp/sg && mkdir /tmp/sg && cd /tmp/sg
~/bin/toolkit.sh schedule gen copias --cron "30 2 * * *" --salida /tmp/sg \
  -- /root/bin/toolkit.sh backup create /etc --dest /var/backups/toolkit --name etc >/dev/null
cat copias.service
systemd-analyze verify ./copias.service ./copias.timer; echo "rc=$?"'
# [Unit]
# Description=toolkit schedule: copias
#
# [Service]
# Type=oneshot
# ExecStart=/root/bin/toolkit.sh guard -k /var/tmp/toolkit-copias.lock -t 300 -- /root/bin/toolkit.sh backup create /etc --dest /var/backups/toolkit --name etc
# rc=0
```

Es una unidad **válida**: `verify` no dice nada. Pero no tiene `User=` (corre como
root) ni ninguna directiva de aislamiento. Validar y proteger son cosas distintas:
lo segundo es el [archivo 06](06-endurecer-unidades-y-ssh.md).

### 3.2 Probar antes de instalar

Un flujo seguro para una unidad nueva, sin tocar `/etc`:

1. Escríbela en un directorio de trabajo.
2. `systemd-analyze verify ./mi.service` (y el `.timer` si lo hay).
3. `systemd-analyze security --offline=true ./mi.service` para ver su exposición.
4. Cópiala a `/etc/systemd/system/`, `sudo systemctl daemon-reload`.
5. `sudo systemctl start mi.service` y `systemctl status` + `journalctl -u`.
6. Solo entonces `enable`.

### 3.3 Divergencia de distro

El lenguaje de las unidades es idéntico en todas. Cambian las **rutas** donde
dejar las tuyas (`/etc/systemd/system/` en las cuatro) y el nombre del target de
red: `network-online.target` existe en todas, pero el servicio que lo hace
efectivo (`systemd-networkd-wait-online`, `NetworkManager-wait-online`) depende de
cómo se configure la red (Semana 12).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `ExecStart=sleep 100` | Sin ruta absoluta, systemd no usa tu `PATH` | `ExecStart=/usr/bin/sleep 100` |
| Tuberías o `&&` en `ExecStart=` | No es una shell: se pasan como argumentos | Un script o `/bin/bash -c '...'` |
| Dar por bueno un `verify` con `rc=0` | Los avisos (claves desconocidas) no cambian el código | Leer también la salida |
| `User=nobody` | Lo comparte medio sistema | Usuario propio o `DynamicUser=yes` |
| Servicio de tarea puntual con `Type=simple` | systemd lo da por «arrancado» y el orden con otras unidades se rompe | `Type=oneshot` |
| `Restart=always` en una tarea que termina | La relanza sin parar | `Restart=on-failure` o un `.timer` |
| Probar la unidad directamente en `/etc` | Una errata se carga con el sistema | Escribirla fuera y verificarla primero |

## 5. Trucos

- **`systemd-analyze verify` acepta varias unidades**: pásale el `.service` **y**
  su `.timer` para comprobar que se corresponden.
- **`systemd-analyze calendar 'weekly' 'monthly' '*-*-01 03:00'`** compara varias
  expresiones en una sola llamada; la forma de no equivocarte con `OnCalendar=`.
- **`systemctl cat NOMBRE`** antes de editar enseña la unidad efectiva y de dónde
  viene cada línea (archivo 01).

## 📚 Recursos Adicionales

- `man systemd.service`, `man systemd.timer`, `man systemd.time` (formato de calendario)
- `man systemd-analyze` (verbos `verify`, `calendar`, `timespan`)

## ✅ Checklist de Verificación

- [ ] Escribes una unidad `oneshot` con `ExecStart=` de ruta absoluta
- [ ] Obtienes el **error** de `verify` con una ruta inexistente (`rc=1`)
- [ ] Obtienes el **aviso** de una clave desconocida y comprendes que da `rc=0`
- [ ] Calculas la próxima ejecución de una expresión con `calendar`
- [ ] Verificas un `.service` y su `.timer` a la vez
- [ ] Generas una unidad con `schedule gen` y localizas lo que no declara (`User=`, aislamiento)

---

[← Inspeccionar servicios con `systemctl`](02-systemctl-inspeccionar-servicios.md) · [Arranque, rendimiento y registros →](04-arranque-rendimiento-y-registros.md)
