# Inspeccionar servicios con `systemctl`

> `systemctl` responde a tres preguntas: ¿está corriendo?, ¿arrancará solo? y ¿por qué falló?
> Aprender a leer su salida (y sus códigos de salida) es la mitad del diagnóstico de una máquina desconocida.

## 🎯 Objetivos

- Leer las líneas de `systemctl status` sin perderte
- Usar `is-active`, `is-enabled` y `is-failed` en scripts, conociendo sus códigos de salida
- Pedir propiedades exactas con `systemctl show -p`
- Listar unidades por tipo y estado, y encontrar las que han fallado
- Ver qué depende de qué con `list-dependencies` y cuándo se disparan los temporizadores

> **Estos comandos necesitan systemd en marcha.** `ubuntu-lab` no lo tiene (archivo
> 01), así que **ejecútalos en tu propia máquina**: una VM Linux, un servidor, o
> WSL2 con `systemd=true`. Son de **solo lectura**, no cambian nada. Las salidas
> de este archivo vienen de una Ubuntu con systemd; las tuyas tendrán otros
> nombres, fechas y PIDs, pero la misma forma.

## 1. Qué problema resuelve

Llegas a una máquina que no conoces y alguien dice «el servicio se cae». Sin
una herramienta común tendrías que adivinar si es un demonio, un `cron`, qué
usuario lo lanza y dónde escribe sus errores. `systemctl` reúne todo en un solo
punto porque systemd **es** quien arrancó y vigila cada proceso.

## 2. Cómo funciona

### 2.1 `status`: la ficha de una unidad

```bash
systemctl status cron --no-pager
# ● cron.service - Regular background program processing daemon
#      Loaded: loaded (/lib/systemd/system/cron.service; enabled; vendor preset: enabled)
#      Active: active (running) since Mon 2026-10-19 18:02:12 -05; 5 days ago
#        Docs: man:cron(8)
#    Main PID: 1204 (cron)
#       Tasks: 1 (limit: 11921)
#      Memory: 1.7M
#      CGroup: /system.slice/cron.service
#              └─1204 /usr/sbin/cron -f -P
#
# Oct 25 01:17:04 host CRON[1644368]: (root) CMD (   cd / && run-parts ...
```

Cada línea responde algo concreto:

| Línea | Qué te dice |
|---|---|
| `●` (punto) | Verde: activa. Rojo: fallada. Blanco/hueco: parada |
| `Loaded:` | Qué **archivo** se leyó, si está `enabled`, y el *preset* del vendedor |
| `Active:` | El estado (`active (running)`, `inactive (dead)`, `failed`) y **desde cuándo** |
| `Main PID:` | El PID del proceso principal, el que mirarías con `ps` o `strace` |
| `CGroup:` | El árbol de procesos de **esa unidad** (systemd los agrupa en un cgroup) |
| Últimas líneas | Las últimas del diario de la unidad (archivo 04 de la Semana 18) |

El código de salida de `status` también habla: `0` unidad activa, `3` inactiva
o fallada, `4` no existe.

```bash
systemctl status no-such.service; echo "rc=$?"
# Unit no-such.service could not be found.
# rc=4
```

### 2.2 `is-active`, `is-enabled`, `is-failed`: preguntas de una palabra

Son las que usan los scripts. Imprimen **una palabra** y devuelven un código:

```bash
systemctl is-active cron; echo "rc=$?"
# active
# rc=0
systemctl is-active no-such.service; echo "rc=$?"
# inactive
# rc=3
systemctl is-enabled cron; echo "rc=$?"
# enabled
# rc=0
systemctl is-failed cron; echo "rc=$?"
# active
# rc=1
```

| Orden | Código `0` | Código distinto de `0` |
|---|---|---|
| `is-active` | está activa | `3`: inactiva o fallada |
| `is-enabled` | `enabled`, `static`, `alias`… (arranca o se puede activar) | `1`: `disabled` o no existe |
| `is-failed` | **sí está** fallada | `1`: no está fallada |

La última fila es la que confunde: `is-failed` devuelve `0` cuando **hay** un
fallo. Con varias unidades a la vez, el código es `0` si **alguna** cumple:

```bash
systemctl is-active cron ssh docker; echo "rc=$?"
# active
# inactive
# active
# rc=0
```

Aquí `ssh` está parado y el código sigue siendo `0`. Para exigir que **todas**
estén activas, comprueba una a una.

### 2.3 `show -p`: propiedades exactas

`status` es para humanos; `show` imprime `Clave=valor`, ideal para extraer un
dato. `-p` filtra:

```bash
systemctl show -p MainPID,ActiveState,SubState,FragmentPath systemd-journald
# MainPID=60
# ActiveState=active
# SubState=running
# FragmentPath=/lib/systemd/system/systemd-journald.service
systemctl show cron -p Restart,User,NoNewPrivileges
# Restart=on-failure
# User=
# NoNewPrivileges=no
```

`User=` vacío significa que **corre como root**, y `NoNewPrivileges=no` que no
tiene esa protección: justo lo que mide `toolkit harden unit`. Para ver el valor
sin la clave: `systemctl show -p MainPID --value cron`.

### 2.4 Listar: `list-units` y `list-unit-files`

Dos listas distintas, que conviene no mezclar:

| Orden | Lista | Pregunta que responde |
|---|---|---|
| `list-units` | Unidades **cargadas en memoria** | ¿qué hay ahora mismo? |
| `list-unit-files` | Archivos **instalados** en disco | ¿qué podría arrancar? |

```bash
systemctl list-units --type=service --state=running --no-pager --no-legend | head -3
#   containerd.service   loaded active running containerd container runtime
#   cron.service         loaded active running Regular background program processing daemon
#   dbus.service         loaded active running D-Bus System Message Bus
systemctl --failed --no-pager --no-legend
#                                  (vacío: no hay ninguna fallada)
systemctl list-unit-files --state=enabled --no-pager | head -3
# UNIT FILE                               STATE   VENDOR PRESET
# snap-bare-5.mount                       enabled enabled
```

`--failed` es **la primera orden** al conectarte a una máquina que «va rara».
`--no-legend` quita cabeceras y pies, y `--no-pager` evita que `less` espere una
tecla dentro de un script.

### 2.5 Dependencias y temporizadores

`list-dependencies` muestra el árbol de lo que una unidad **necesita**; con
`--reverse`, lo que la necesita **a ella**:

```bash
systemctl list-dependencies --reverse cron --no-pager | head -3
# cron.service
# ● └─multi-user.target
# ●   └─graphical.target
```

`list-timers` es la agenda de la máquina (Semana 16): cuándo salta cada
temporizador, cuándo lo hizo por última vez y qué activa.

```bash
systemctl list-timers --no-pager | head -3 | cut -c1-120
# NEXT                        LEFT          LAST                        PASSED        UNIT                  ACTIVATES
# Sun 2026-10-25 03:10:03 -05 1h 46min left Mon 2026-10-19 01:51:52 -05 5 days ago    e2scrub_all.timer     e2scrub_all.service
```

## 3. Cómo se usa

### 3.1 Un recorrido de diagnóstico

Ante un servicio sospechoso, siempre el mismo orden, de lo general a lo concreto:

```bash
systemctl --failed --no-pager --no-legend      # 1. ¿algo ha fallado?
systemctl status NOMBRE --no-pager -n 20       # 2. ficha y últimas 20 líneas
journalctl -u NOMBRE -n 50 --no-pager          # 3. el diario completo de la unidad
systemctl cat NOMBRE                           # 4. qué se le pidió exactamente
```

El punto 4 resuelve la pregunta «¿por qué arranca con ese usuario?»: lo ves en
la unidad y en sus drop-ins.

### 3.2 En un script

```bash
# is-active --quiet: sin salida, solo el codigo. Ideal en un if.
if ! systemctl is-active --quiet cron; then
  echo "cron parado" >&2
fi
```

### 3.3 Divergencia de distro

`systemctl` es el mismo en Debian, Ubuntu, RHEL y Arch. Lo que cambia es el
**nombre de la unidad**: el servidor SSH es `ssh.service` en Debian/Ubuntu y
`sshd.service` en RHEL y Arch; el planificador es `cron.service` en Debian/Ubuntu
y `crond.service` en RHEL. Si dudas, `systemctl list-unit-files | grep -i ssh`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `systemctl status X \| grep running` | El texto cambia entre versiones | `systemctl is-active --quiet X` |
| Usar `status` en un script sin `--no-pager` | `less` se queda esperando | `--no-pager`, o `SYSTEMD_PAGER=` |
| Fiarte de que «enabled» significa «corriendo» | Puede estar parado ahora | Mira `is-active` también |
| Leer `is-failed` como «está bien» si devuelve `0` | `0` significa que **sí** ha fallado | Interpreta el código con la tabla del apartado 2.2 |
| `sudo systemctl status` «por si acaso» | `status` no necesita privilegios | Sin `sudo`; solo para cambiar estado |
| Reiniciar para «arreglar» sin leer el diario | Pierdes la evidencia del fallo | `journalctl -u X` primero |

## 5. Trucos

- **`systemctl list-units --state=failed --plain --no-legend | awk '{print $1}'`**
  saca solo los nombres de las unidades falladas, para un `healthcheck`. `--plain`
  quita el `●` que de otro modo ocupa la primera columna.
- **`systemctl show -p MainPID --value NOMBRE`** da el PID limpio, listo para
  `ps -p $(...)` o `ls /proc/$(...)/`.
- **`systemctl --user ...`** gestiona las unidades de **tu** usuario (`~/.config/systemd/user/`)
  sin `sudo`: la forma de probar unidades propias sin tocar el sistema.

## 📚 Recursos Adicionales

- `man systemctl` (códigos de salida de cada verbo en la sección «Exit status»)
- `man systemd.exec` (qué significan `User=`, `NoNewPrivileges=`…)

## ✅ Checklist de Verificación

- [ ] En tu máquina, `systemctl status` de un servicio y localizas `Loaded`, `Active`, `Main PID` y el `CGroup`
- [ ] Obtienes `rc=3` con `is-active` de una unidad inexistente y `rc=4` con `status`
- [ ] Explicas por qué `is-failed` devuelve `0` cuando algo ha fallado
- [ ] Extraes `MainPID` y `User` con `systemctl show -p`
- [ ] Distingues `list-units` de `list-unit-files`
- [ ] Listas las unidades falladas y los temporizadores
- [ ] Sabes qué unidad es el servidor SSH en tu distribución

---

[← systemd: unidades, rutas y precedencia](01-systemd-unidades-y-rutas.md) · [Escribir y verificar una unidad →](03-escribir-y-verificar-una-unidad.md)
