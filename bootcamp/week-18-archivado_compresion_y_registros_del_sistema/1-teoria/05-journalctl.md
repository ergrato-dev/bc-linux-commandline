# `journalctl`: el diario de systemd

> `journald` guarda cada mensaje **con sus campos** (quién, cuándo, con qué prioridad) en un diario binario.
> `journalctl` es la única forma de leerlo, y filtrar vale más que ver todo.

## 🎯 Objetivos

- Explicar qué guarda el diario frente a un archivo de texto y por qué es binario
- Filtrar con `-t`, `-u`, `-p`, `--since`, `--until`, `-g`, `-b` y `-n`
- Cambiar el formato de salida (`-o cat`, `short-iso`, `json`, `verbose`) y ver los campos
- Medir y limitar el espacio del diario (`--disk-usage`, `--vacuum-*`, `journald.conf`)
- Saber si el diario sobrevive a un reinicio y cómo cambiarlo
- Leer una copia de un diario con `--file`

## 1. Qué problema resuelve

Con archivos de texto (archivo 04), para saber «qué hizo este servicio hace dos
horas» hay que adivinar en qué archivo, y buscar con `grep` en texto sin
estructura. El diario guarda cada mensaje **junto a sus metadatos**: el proceso,
el servicio, la prioridad, el arranque. No hace falta `grep` para filtrar por
ellos: `journalctl` consulta un índice.

El coste: el formato es binario. `cat /var/log/journal/...` no te sirve; solo
`journalctl` lo lee. Y a diferencia de texto, **no se puede editar con `sed`**.

## 2. Cómo funciona

### 2.1 Puesta a punto en el laboratorio

Un contenedor no arranca con `systemd`: no hay `journald` en marcha. Lo
arrancas a mano (en una máquina real ya está) y escribes con `systemd-cat`, que
manda su entrada estándar al diario con una etiqueta y una prioridad:

```bash
pgrep -x systemd-journal >/dev/null || { /usr/lib/systemd/systemd-journald & sleep 1.5; }
echo "uno"        | systemd-cat -t demo18 -p info
echo "dos aviso"  | systemd-cat -t demo18 -p warning
echo "tres error" | systemd-cat -t demo18 -p err
printf 'linea A\nlinea B\n' | systemd-cat -t otro18
journalctl -t demo18 --no-pager
# Oct 25 06:05:06 ubuntu-lab demo18[33492]: uno
# Oct 25 06:05:06 ubuntu-lab demo18[33494]: dos aviso
# Oct 25 06:05:06 ubuntu-lab demo18[33496]: tres error
```

`systemd-cat` no usa `/dev/log` (el socket de `logger` y `rsyslog`), sino el del
propio `journald`: por eso funciona aquí. Una línea es: fecha, máquina,
etiqueta con **PID** entre corchetes y el mensaje. `--no-pager` evita que
`journalctl` abra `less`, imprescindible en un script.

### 2.2 Filtrar

Cada filtro **estrecha** el resultado; se combinan.

```bash
journalctl -t demo18 -p warning -o cat --no-pager
# dos aviso
# tres error
```

| Opción | Filtra por |
|---|---|
| `-t ETIQUETA` | identificador (`SYSLOG_IDENTIFIER`) |
| `-u UNIDAD` | unidad de systemd (`-u ssh`, `-u cron`) |
| `-p NIVEL` | prioridad: `warning` incluye `warning`, `err`, `crit`… |
| `-p A..B` | un rango de prioridades |
| `--since`, `--until` | tiempo: `"1 hour ago"`, `"2026-10-25 06:00"`, `yesterday` |
| `-b` / `-b -1` | este arranque / el anterior (`--list-boots` los cuenta) |
| `-g PATRÓN` | el **mensaje** casa con la expresión regular |
| `-n N` | las últimas N líneas |
| `-r` | orden inverso (lo más reciente arriba) |
| `-k` | mensajes del kernel (como `dmesg`) |
| `-f` | sigue, como `tail -F` |

Las prioridades son las del archivo 04. Un `-p warning` **incluye** las más
graves; para solo una, el rango (`-p err..err`):

```bash
journalctl -t demo18 -p err..err -o cat --no-pager
# tres error
journalctl -t demo18 -g 'aviso|error' -o cat --no-pager
# dos aviso
# tres error
journalctl -t demo18 -n 2 -r -o cat --no-pager
# tres error
# dos aviso
journalctl -t demo18 --since "2 hours ago" --until "1 hour ago" --no-pager
# -- No entries --
```

(Un filtro sin resultados no es un error: imprime `-- No entries --`.) `-u` y
`-b` solo tienen sentido con un `systemd` real: en el contenedor no hay
unidades. En una máquina real: `journalctl -u ssh --since today -p warning`
es la primera orden de todo diagnóstico de un servicio.

### 2.3 Los campos: `-o` y `verbose`

Cada entrada es un conjunto de campos. `-o` cambia cómo se ven:

| `-o` | Sale |
|---|---|
| `short` (por defecto) | una línea estilo syslog |
| `short-iso` | igual, con fecha ISO 8601 (mejor para ordenar y para scripts) |
| `cat` | **solo el mensaje** |
| `json` | un objeto JSON por entrada |
| `verbose` | todos los campos |

```bash
journalctl -t otro18 -o short-iso --no-pager | head -2
# 2026-10-25T06:05:06+00:00 ubuntu-lab otro18[33498]: linea A
# 2026-10-25T06:05:06+00:00 ubuntu-lab otro18[33498]: linea B
journalctl -t demo18 -n 1 -o verbose --no-pager | grep -E '^\s+(PRIORITY|_UID|SYSLOG_IDENTIFIER|MESSAGE)='
#     _UID=0
#     SYSLOG_IDENTIFIER=demo18
#     PRIORITY=3
#     MESSAGE=tres error
```

Los campos que empiezan por `_` los pone el propio `journald` y **no se pueden
falsificar** desde el mensaje (`_UID`, `_PID`, `_COMM`); los demás (`MESSAGE`,
`PRIORITY`) los manda el programa. Se filtra por cualquiera con `CAMPO=valor`
(`journalctl _UID=1000`) y `journalctl -F CAMPO` lista los valores que existen:

```bash
journalctl -F SYSLOG_IDENTIFIER --no-pager | grep -E 'demo18|otro18'
# otro18
# demo18
```

### 2.4 Cuánto ocupa y cuánto debe ocupar

El diario crece con cada línea. Se mide y se recorta:

```bash
journalctl --disk-usage
# Archived and active journals take up 16.0M in the file system.
journalctl --verify | tail -2
# PASS: /run/log/journal/444d4abcdd164a55b73da857d87baf60/system.journal
# PASS: /var/log/journal/444d4abcdd164a55b73da857d87baf60/system.journal
journalctl --vacuum-time=1s
# Vacuuming done, freed 0B of archived journals from /var/log/journal/...
```

`--verify` comprueba la **integridad del propio diario**; `--vacuum-size=200M`
y `--vacuum-time=2weeks` borran los **archivados** más antiguos hasta cumplir el
límite (por eso, aquí, libera 0 B: no hay archivados). Para que el límite sea
permanente, en `/etc/systemd/journald.conf`:

```
[Journal]
Storage=persistent
SystemMaxUse=200M
MaxRetentionSec=1month
```

Las opciones vienen comentadas con sus valores por defecto: ve a
`/etc/systemd/journald.conf` y lee antes de cambiar.

### 2.5 ¿Sobrevive a un reinicio?

Depende de **`Storage=`**. Con `auto` (el valor por defecto) el diario se guarda
en `/var/log/journal` **solo si ese directorio existe**; si no, va a
`/run/log/journal`, que es memoria y se pierde al reiniciar. Se ve en el
laboratorio:

```bash
ls -d /var/log/journal /run/log/journal
# /run/log/journal
# /var/log/journal
```

En las imágenes de `ubuntu-lab`, `debian-lab` y `arch-lab` existen los dos
directorios; en `rhel-lab` **no hay `/var/log/journal`**, así que con
`Storage=auto` su diario sería volátil. Para hacerlo persistente en cualquier
distro: `mkdir -p /var/log/journal` y reiniciar `systemd-journald`, o
`Storage=persistent` (lo crea él).

## 3. Cómo se usa

### 3.1 Leer una copia del diario

Un `.journal` copiado se puede leer en **otra máquina**, con `--file`. Es útil
para analizar el diario de un servidor caído o formar parte de una copia de
seguridad (archivo 08):

```bash
mkdir /tmp/jcopy && cp /run/log/journal/*/system.journal /tmp/jcopy/
journalctl --file=/tmp/jcopy/system.journal -t demo18 -p warning -o cat --no-pager
# dos aviso
# tres error
```

(En una máquina real, el original está en `/var/log/journal/ID/system.journal`.
Cópialo mejor tras `journalctl --rotate`, que cierra el archivo activo y deja
lo anterior en archivos ya completos.)

### 3.2 Quién puede leerlo

Un usuario normal solo ve sus propios mensajes. Para leer todo hay que ser
`root` o estar en el grupo **`systemd-journal`** (o `adm`, que además lee los
archivos de texto del archivo 04): `usermod -aG systemd-journal <tu-usuario>`.

### 3.3 Desde un script

Para un script lo útil es que la salida sea estable: `--no-pager`, `-o cat` o
`-o short-iso`, y filtros por tiempo:

```bash
journalctl -t miscript --since "1 hour ago" -p err -o cat --no-pager | wc -l
```

Y para escribir en él desde un script: `systemd-cat -t miscript -p err` o
`logger -t miscript` (archivo 07).

### 3.4 Divergencia de distro

| | Ubuntu/Debian | RHEL/Rocky | Arch |
|---|---|---|---|
| `journalctl` | siempre (`systemd`) | siempre (`systemd`) | siempre (`systemd`) |
| `/var/log/journal` en la imagen del laboratorio | existe | **no existe** (diario volátil con `auto`) | existe |
| Además, texto con `rsyslog` | sí (Ubuntu) | sí (instalación normal) | **no** |

La orden es la misma en las tres: lo que cambia es **si hay además archivos de
texto** y si el diario aguanta un reinicio. Mira siempre `ls /var/log/journal`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `journalctl` sin filtros | Miles de líneas, y `less` bloquea un script | `-u`, `-p`, `--since`, `--no-pager` |
| Un script que parsea `journalctl` en formato `short` | El formato cambia con el idioma y la versión | `-o cat`, `-o json` o `short-iso` |
| Dejar crecer el diario sin límite | Llena `/var` | `SystemMaxUse=` y `--vacuum-size` |
| Suponer que sobrevive al reinicio | Con `Storage=auto` puede ser volátil | `ls /var/log/journal` o `Storage=persistent` |
| `-p err` para ver «todo lo malo» | Pierde los `warning` | `-p warning` |
| Borrar `/var/log/journal` a mano | Corrompe el diario activo | `journalctl --vacuum-*` |
| Buscar con `grep` sobre el binario | Salida mezclada y falsos negativos | `-g` o `-t`/`-u` |
| Confiar en `MESSAGE` para saber quién escribió | Lo manda el programa | Campos `_UID`, `_PID`, `_COMM` |

## 5. Trucos

- **`journalctl -o json -n 1 | python3 -m json.tool`** muestra un registro con
  todos sus campos legible; mejor para descubrir por qué campo filtrar.
- **`journalctl -u servicio -f`**: sigue un servicio en vivo.
- **`journalctl --since "10 min ago" -p warning -o short-iso --no-pager`** es
  un buen primer vistazo a «¿qué ha pasado hace un rato?».

## 📚 Recursos Adicionales

- `man journalctl`, `man systemd.journal-fields` y `man journald.conf`
- [systemd: journalctl](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)

## ✅ Checklist de Verificación

- [ ] Arrancas `journald` en el laboratorio y escribes con `systemd-cat -t etiqueta -p nivel`
- [ ] Filtras por etiqueta, prioridad, mensaje (`-g`) y tiempo, y combinas filtros
- [ ] Cambias de formato con `-o cat`, `short-iso` y `verbose`, y reconoces un campo `_`
- [ ] Mides con `--disk-usage` y compruebas con `--verify`
- [ ] Explicas `Storage=auto` y miras si tu diario es persistente
- [ ] Lees una copia del diario con `--file`
- [ ] Sabes qué grupo da acceso al diario sin ser `root`

---

[← `/var/log` y los registros clásicos](04-var-log-y-registros-clasicos.md) · [`logrotate` →](06-logrotate.md)
