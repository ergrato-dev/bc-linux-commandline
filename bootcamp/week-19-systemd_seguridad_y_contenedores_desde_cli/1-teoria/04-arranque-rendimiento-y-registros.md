# Arranque, rendimiento y registros de una unidad

> «La máquina tarda en arrancar» y «el servicio falla a veces» se diagnostican con dos herramientas que ya casi conoces:
> `systemd-analyze` para el **tiempo** y `journalctl` filtrado por unidad para los **mensajes**.

## 🎯 Objetivos

- Medir cuánto tarda un arranque y qué unidades lo alargan (`blame`, `critical-chain`)
- Distinguir «lo más lento» de «lo que de verdad retrasa el arranque»
- Leer el diario de **una unidad** y de **un arranque concreto**
- Usar los campos `_SYSTEMD_UNIT` y `_SYSTEMD_CGROUP` del diario para atribuir cada línea a su servicio
- Saber qué ver cuando la causa está en el kernel (`journalctl -k`)

> **Requiere systemd en marcha**, como el archivo 02: ejecútalo en tu máquina.
> `ubuntu-lab` no arranca systemd. Las salidas vienen de una Ubuntu con systemd;
> las tuyas serán otras. Los comandos son de solo lectura.

## 1. Qué problema resuelve

Dos preguntas distintas se confunden a menudo. «¿Por qué tarda tanto el arranque?»
es una pregunta sobre **tiempo y orden**. «¿Por qué falló el servicio?» es una
pregunta sobre **mensajes**. systemd guarda ambas cosas porque supervisa cada
unidad: sabe cuándo empezó, cuándo terminó, de qué dependía y qué escribió.

## 2. Cómo funciona

### 2.1 El resumen: `systemd-analyze`

Sin argumentos da el total y el punto de llegada:

```bash
systemd-analyze
# Startup finished in 10.000s (userspace)
# graphical.target reached after 9.975s in userspace
```

En una máquina física verías también `(firmware)`, `(loader)` y `(kernel)` antes
de `userspace`; en una VM o en WSL2 hay menos fases. Lo que importa es el
`userspace`: el tiempo que tarda systemd en llegar al *target* por defecto.

### 2.2 `blame`: lo más lento, y por qué engaña

```bash
systemd-analyze blame --no-pager | head -3
# 12.320s apt-daily.service
#  5.832s docker.service
#  3.654s apt-daily-upgrade.service
```

`blame` ordena por **cuánto tardó cada unidad en activarse**. Pero ojo: la lista
no dice que esas unidades *retrasaran* el arranque. `apt-daily.service` tarda
12 s y, sin embargo, el sistema llegó a `graphical.target` en menos de 10: se
ejecutó **en paralelo**, sin que nada esperase por ella.

### 2.3 `critical-chain`: lo que de verdad retrasa

La cadena crítica muestra el camino de dependencias que **determinó** el tiempo
total: la ruta más larga.

```bash
systemd-analyze critical-chain --no-pager | sed -n 4,8p
# graphical.target @9.975s
# └─multi-user.target @9.974s
#   └─networkd-dispatcher.service @842ms +132ms
#     └─basic.target @825ms
#       └─sockets.target @825ms
```

Se lee de abajo arriba: `@` es el instante en que la unidad **se activó** y `+`
cuánto **tardó** en hacerlo. Fíjate en el salto entre las dos últimas líneas
reales: `networkd-dispatcher` se activó a los 0,84 s y `multi-user.target` no
llegó hasta los 9,97 s. Esos ~9 s son tiempo en que el target esperaba a unidades
que **no salen en la cadena**; `blame` te da los sospechosos (aquí, `apt-daily` y
`docker`). La cadena crítica no lo explica todo, solo marca el camino.

Con un nombre pide la cadena de **una** unidad:

```bash
systemd-analyze critical-chain cron.service --no-pager | tail -n +4 | head -5
# cron.service @828ms
# └─basic.target @825ms
#   └─sockets.target @825ms
#     └─uuidd.socket @823ms
#       └─sysinit.target @789ms
```

La regla de decisión: si quieres acelerar el arranque, **mira `critical-chain`,
no `blame`**. Acelerar una unidad que no está en la cadena crítica no cambia
nada.

### 2.4 El diario de una unidad

Ya usaste `journalctl -u` en la Semana 18. Cada línea del diario lleva campos
que dicen **qué unidad la escribió** (los pone systemd, no el programa, así que
no se pueden falsificar desde el servicio):

```bash
journalctl -u cron -o json -n 1 --no-pager | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(sorted(k for k in d if k.startswith("_SYSTEMD")))'
# ['_SYSTEMD_CGROUP', '_SYSTEMD_INVOCATION_ID', '_SYSTEMD_SLICE', '_SYSTEMD_UNIT']
```

| Campo | Contiene |
|---|---|
| `_SYSTEMD_UNIT` | La unidad que generó la línea |
| `_SYSTEMD_CGROUP` | Su cgroup (ruta en `/sys/fs/cgroup`) |
| `_SYSTEMD_SLICE` | El *slice* (grupo de recursos) al que pertenece |
| `_SYSTEMD_INVOCATION_ID` | Un identificador **por ejecución**: separa dos arranques de la misma unidad |

`-u NOMBRE` es un atajo para filtrar por `_SYSTEMD_UNIT=NOMBRE.service`; los
campos también se pueden filtrar directamente:

```bash
journalctl _SYSTEMD_UNIT=cron.service -n 1 -o short-iso --no-pager | cut -c1-90
# 2026-10-25T01:17:04-0500 host CRON[1644367]: pam_unix(cron:session): session closed ...
```

### 2.5 Por arranque: `-b`

El diario guarda **varios arranques** (si es persistente, Semana 18). Se listan y
se pide uno concreto:

```bash
journalctl --list-boots --no-pager | tail -2
#  -1 49a56b8f9c684743b5dad432c5d0fe1a Mon 2026-10-19 01:50:19 -05—Mon 2026-10-19 03:28:12 -05
#   0 88e8cd0d494b434f81bb69cf39886b30 Mon 2026-10-19 18:02:12 -05—Sun 2026-10-25 01:31:40 -05
journalctl -b -1 -n 1 --no-pager | cut -c1-90        # la última línea del arranque anterior
# Oct 19 03:28:12 host systemd[1]: Unmounted /run/docker/netns/9b63b54902db.
```

`-b` (o `-b 0`) es el arranque actual; `-b -1`, el anterior. Es lo que usas
cuando una máquina **se reinició sola** y quieres ver qué pasó justo antes de
caer: la última línea de `-b -1` y las anteriores.

Combinado con la prioridad (Semana 18) da la vista más útil de un arranque:

```bash
journalctl -b -p err --no-pager -q | wc -l       # cuántos errores desde que arrancó
# 701
```

(Una cifra alta no implica un problema: muchos son avisos de hardware o de
servicios opcionales. Lo útil es mirar **cuáles**, `| head`, y repetir tras un
cambio.)

### 2.6 El kernel: `journalctl -k`

Los mensajes del núcleo (discos, red, memoria agotada) entran en el mismo diario
y se filtran con `-k`, el equivalente moderno de `dmesg`:

```bash
journalctl -k -n 2 --no-pager | cut -c1-100
# Oct 25 01:28:52 host kernel: vethccedca0 (unregistering): left promiscuous mode
# Oct 25 01:28:52 host kernel: docker0: port 1(vethccedca0) entered disabled state
```

Los contenedores dejan huella aquí: las interfaces `veth...` son el extremo de
cada contenedor en el anfitrión (archivo 07).

## 3. Cómo se usa

### 3.1 «¿Por qué se reinició?»

1. `journalctl --list-boots` — ¿hay un arranque más reciente de lo esperado?
2. `journalctl -b -1 -n 50 --no-pager` — las últimas 50 líneas **antes** de caer.
3. `journalctl -b -1 -p err --no-pager` — ¿hubo errores antes del corte?
4. `journalctl -b -1 -k | tail` — ¿el kernel dijo algo (memoria, disco)?

Si el diario no es persistente (Semana 18) el arranque anterior **no existe**:
`--list-boots` solo mostrará el actual. Es una razón más para crear
`/var/log/journal`.

### 3.2 Un arranque lento

1. `systemd-analyze` — ¿cuánto es «lento»? Compara con un arranque anterior.
2. `systemd-analyze critical-chain` — ¿qué unidad está en el camino?
3. `systemd-analyze critical-chain NOMBRE` — la cadena de la sospechosa.
4. `journalctl -u NOMBRE -b` — qué hizo durante ese tiempo.

### 3.3 Divergencia de distro

`systemd-analyze` y `journalctl` son iguales en las cuatro familias. Lo que
cambia es la persistencia del diario: Debian y Ubuntu suelen tener
`/var/log/journal`; en `rhel-lab` no existe (Semana 18). Sin él, `-b -1` no
tiene datos.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Optimizar lo primero de `blame` | Puede no estar en el camino crítico | `critical-chain` primero |
| `journalctl \| grep nombre` para ver un servicio | Mezcla otros programas y es lento | `journalctl -u nombre` |
| Reiniciar para «ver si se arregla» sin mirar `-b -1` | Pierdes el contexto de la caída | Leer el arranque anterior primero |
| Fiarte de `dmesg` sin privilegios | En Ubuntu puede estar restringido (`kernel.dmesg_restrict`) | `journalctl -k` |
| Contar errores sin leerlos | La cifra no dice nada por sí sola | `head` y leer cuáles son |
| Confundir `-b` con `--since` | `-b` es por arranque, no por hora | Úsalos juntos si hace falta |

## 5. Trucos

- **`systemd-analyze plot > arranque.svg`** genera un diagrama de Gantt del
  arranque que abres en el navegador: ves de un vistazo qué corrió en paralelo.
- **`journalctl -u NOMBRE -b -o cat --no-pager`** da solo el texto de los
  mensajes de la unidad en este arranque, sin cabeceras.
- **`journalctl --since "10 min ago" -p warning -o short-iso`** responde «¿qué ha
  ido mal ahora mismo?» en una sola línea.

## 📚 Recursos Adicionales

- `man systemd-analyze`, `man journalctl`, `man systemd.journal-fields`
- [journalctl (freedesktop.org)](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)

## ✅ Checklist de Verificación

- [ ] En tu máquina, obtienes el tiempo de arranque con `systemd-analyze`
- [ ] Explicas por qué `blame` y `critical-chain` pueden decir cosas distintas
- [ ] Lees `@` y `+` en una cadena crítica
- [ ] Filtras el diario por unidad y por arranque anterior con `-b -1`
- [ ] Sabes qué campos `_SYSTEMD_*` identifican a la unidad que escribió una línea
- [ ] Ves los mensajes del kernel con `journalctl -k`

---

[← Escribir y verificar una unidad](03-escribir-y-verificar-una-unidad.md) · [Menor privilegio y permisos peligrosos →](05-menor-privilegio-y-permisos.md)
