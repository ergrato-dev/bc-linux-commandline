# Escribir en los registros desde tus scripts

> Un script que corre solo, de madrugada, tiene una única forma de contarte qué pasó: **escribirlo**.
> `logger` y `systemd-cat` lo mandan al registro del sistema, con prioridad y etiqueta, sin gestionar archivos.

## 🎯 Objetivos

- Enviar mensajes al registro con `logger` y `systemd-cat`, con etiqueta y prioridad
- Saber qué pasa cuando no hay nadie escuchando (`logger` falla en silencio)
- Redirigir toda la salida de un script al registro con `exec > >(logger ...)`
- Escribir una función `log` que lleve fecha, nivel y copia a `stderr`
- Evitar los dos errores de seguridad: mensajes con opciones y mensajes con saltos de línea

## 1. Qué problema resuelve

En la Semana 15 hiciste que `guard` escribiera un registro propio en un archivo; en
la Semana 16 lo programaste en `cron`. Un archivo propio exige decidir **dónde**
vive, **quién** puede leerlo y **cómo se rota**. Si en su lugar el script manda
sus mensajes al registro del sistema, hereda gratis todo eso: permisos, rotación
(archivo 06), filtrado por prioridad (archivo 05) y un único sitio donde mirar.

## 2. Cómo funciona

### 2.1 `logger`: el mensaje, la etiqueta y la prioridad

```bash
logger -t miscript -p user.err -- "no pude abrir la base de datos"
```

| Opción | Hace |
|---|---|
| `-t ETIQUETA` | el nombre con que aparecerá (por defecto, tu usuario) |
| `-p facility.nivel` | la prioridad (`user.notice` si no se indica) |
| `-i` | añade el PID del `logger` |
| `-s` | también escribe el mensaje en `stderr` |
| `-f ARCHIVO` | envía el contenido de un archivo |
| `--` | fin de opciones: lo siguiente es el mensaje |

Los ocho niveles son los del archivo 04, y llegan al diario con su número:

```bash
for p in emerg alert crit err warning notice info debug; do logger -p user.$p -t map "$p"; done
journalctl -t map -o json --no-pager | python3 -c "
import sys,json
print(' '.join(json.loads(l)['PRIORITY']+':'+json.loads(l)['MESSAGE'] for l in sys.stdin))"
# 0:emerg 1:alert 2:crit 3:err 4:warning 5:notice 6:info 7:debug
```

### 2.2 Cuando nadie escucha

`logger` escribe en el socket `/dev/log`. Si **nadie lo ha creado** (un
contenedor sin `rsyslog`, o un `journald` arrancado a mano sin el enlace), **no
hay error**: el mensaje se pierde y el código de salida es `0`.

```bash
rm -f /dev/log
logger -t t07 "sin socket"; echo "rc=$?"
# rc=0
journalctl -t t07 --no-pager
# -- No entries --
```

Es peligroso porque **parece que funciona**. En una máquina real systemd lo
resuelve enlazando `/dev/log` con el socket de `journald`; lo mismo se hace a mano:

```bash
ln -s /run/systemd/journal/dev-log /dev/log
logger -t t07b "con enlace"
journalctl -t t07b -o cat --no-pager
# con enlace
```

(`logger -u /run/systemd/journal/dev-log` apunta a ese socket sin crear el enlace.)
La lección para tus scripts: **comprueba una vez** que tu mensaje de prueba llega,
en la máquina donde va a correr.

### 2.3 `systemd-cat`: ejecutar un comando y recoger su salida

`systemd-cat` no usa `/dev/log`, sino el socket de *streams* de `journald`, y
puede **envolver una orden**: lo que escribe en `stdout` y en `stderr` va al diario.

```bash
systemd-cat -t t07c sh -c 'echo salida; echo error >&2'
journalctl -t t07c -o verbose --no-pager | grep -E '^\s+(PRIORITY|MESSAGE)='
#     PRIORITY=6
#     MESSAGE=salida
#     PRIORITY=6
#     MESSAGE=error
```

Por defecto **las dos salidas se registran con la misma prioridad** (`info`). Para
que `stderr` pese más, `--stderr-priority`:

```bash
systemd-cat -t t07d --stderr-priority=warning sh -c 'echo salida; echo avis >&2'
# journalctl -t t07d -o json -> 6 salida / 4 avis
```

Necesita `systemd`: en un sistema sin él (Alpine, un contenedor) no existe, y se
usa `logger`.

### 2.4 Todo el script al registro: `exec > >(logger ...)`

Para no cambiar cada `echo`, redirige la salida del script entero **una vez**,
al principio, con una sustitución de procesos:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec > >(logger -t s07 -p user.info) 2> >(logger -t s07 -p user.err)
echo "empiezo"
echo "algo fallo" >&2
echo "termino"
```

```bash
journalctl -t s07 -o json --no-pager | python3 -c "
import sys,json
for l in sys.stdin: d=json.loads(l); print(d['PRIORITY'], d['MESSAGE'])"
# 6 empiezo
# 6 termino
# 3 algo fallo
```

`stdout` va como `info` y `stderr` como `err`, y el script no sabe nada. Dos
advertencias: el `logger` de cada `>( )` corre **aparte** y puede escribir un
instante después de que el script termine (de ahí el orden `empiezo`,
`termino`, `algo fallo` del ejemplo: los dos flujos son canales distintos); y
**con `set -e`** un fallo del `logger` no detiene el script. Para depurar a mano,
añade `tee` o ejecuta con `-x`.

### 2.5 Una función `log`

Cuando quieres control del formato y copia a la pantalla (porque el script a veces
lo lanzas tú), una función pequeña:

```bash
log() {
  local nivel=$1; shift
  printf '%s %s %s\n' "$(date -Is)" "$nivel" "$*" >&2
  logger -t "${0##*/}" -p "user.${nivel}" -- "$*" || true
}
log info "arrancando"
log err "algo salio mal con 100% de CPU"
# 2026-10-25T06:07:54+00:00 info arrancando
# 2026-10-25T06:07:54+00:00 err algo salio mal con 100% de CPU
```

Detalles que importan: `date -Is` da fecha ISO con zona (ordenable y sin
ambigüedad), el `--` evita que un mensaje que empiece por `-` se tome como opción
y el `|| true` evita que un `logger` que falle tumbe un script con `set -e`
solo por no poder avisar. La etiqueta `${0##*/}` es el nombre del script.
`printf '%s'` y no `printf "$mensaje"`: el `%` de «100% de CPU» sería un formato.

## 3. Cómo se usa

### 3.1 En `cron` y en systemd

Un script de `cron` no tiene terminal: lo que escribe a `stdout` se manda por
correo (si hay `MAILTO`) o se pierde. Con `logger` el mensaje queda en el registro
**aunque nadie lo lea al momento**. Esa es la base del manejo de error de la
Semana 16: la línea de `cron` sigue redirigiendo `>> registro 2>&1`, y el script
**además** avisa con `logger -p user.err` cuando algo grave pasa.

En una unidad `service`, lo que el programa escribe a `stdout`/`stderr` ya va
**solo** al diario (`StandardOutput=journal` es el valor por defecto): `journalctl
-u mi-servicio` basta, sin `logger`.

### 3.2 Qué escribir

| Nivel | Cuándo | Ejemplo |
|---|---|---|
| `err` | falló algo que debía funcionar | «copia de /home fallida: disco lleno» |
| `warning` | funcionó, pero hay que mirarlo | «solo 3 copias; se esperaban 7» |
| `info` | un hito normal | «copia creada: /backup/proy-...tar.gz» |
| `debug` | detalle para depurar | «excluyendo cache/» |

Un registro útil responde: **qué** hizo, **sobre qué**, **cuándo** y **con qué
resultado**. Y dice **una vez** cada cosa: un bucle que escribe una línea por
archivo en una copia de un millón es ruido.

### 3.3 Dos errores de seguridad

**Un mensaje que empieza por `-`** se toma como opción de `logger` y falla (o hace
algo inesperado). El remedio es el `--` de antes:

```bash
logger -t inj2 "-x"; echo "rc=$?"
# logger: invalid option -- 'x'
# rc=1
logger -t inj2 -- "-x"
```

**Un mensaje con datos de fuera** (un nombre de usuario, una ruta) puede llevar
un salto de línea y **fabricar una línea falsa**:

```bash
logger -t inj $'ok\nFAKE: admin login ok'
journalctl -t inj -o cat --no-pager
# ok
# FAKE: admin login ok
```

Quien lee ve dos líneas; la segunda la ha escrito el atacante. Sustituye los
saltos de línea de lo que no controlas antes de registrarlo:

```bash
v=$'ok\nFAKE'
logger -t inj3 -- "${v//$'\n'/ }"
# ok FAKE
```

Y nunca registres **contraseñas, tokens ni claves**: un registro lo lee mucha
más gente que la variable de entorno de la que salió.

### 3.4 Divergencia de distro

`logger` viene de `util-linux` en las cuatro familias, con las mismas opciones.
Lo que cambia es **adónde llega**: a `/var/log/syslog` (Ubuntu con `rsyslog`),
a `/var/log/messages` (RHEL con `rsyslog`) o solo al diario (Arch, y todo lo
que no tenga `rsyslog`). Escribe siempre con `logger` y **lee con `journalctl`**
cuando puedas: así tu script no depende de qué archivo de texto toque.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir en `/var/log/miscript.log` a mano | Permisos, rotación y propietario son cosa tuya | `logger -t miscript` |
| `logger` sin comprobar que llega | Sin socket, se pierde con código `0` | Un mensaje de prueba, y `journalctl -t` |
| `logger "$mensaje"` | Un mensaje que empieza por `-` falla | `logger -- "$mensaje"` |
| Registrar datos externos sin limpiar | Un salto de línea fabrica una línea falsa | `${v//$'\n'/ }` |
| Escribir todo con la misma prioridad | No se puede filtrar con `-p` | `err`, `warning`, `info`, `debug` |
| `printf "$mensaje"` | Un `%` en el texto rompe la salida | `printf '%s' "$mensaje"` |
| Registrar contraseñas «por si acaso» | Quedan en el diario y en las copias | No registrarlas nunca |
| Mensajes sin fecha ni etiqueta (en un archivo propio) | No se puede ordenar ni filtrar | `date -Is` y una etiqueta fija |

## 5. Trucos

- **`logger -s`**: el mensaje va al registro **y** a `stderr`; en un script que
  lanzas a mano ves lo mismo que quedará guardado.
- **`systemd-cat -t etiqueta orden`** envuelve cualquier orden: la forma más
  rápida de «que lo que haga ese programa vaya al diario».
- **`journalctl -t miscript -p err --since today -o cat --no-pager | wc -l`**:
  cuántos errores ha registrado tu script hoy; una comprobación de una línea
  para un `healthcheck`.

## 📚 Recursos Adicionales

- `man logger`, `man systemd-cat`
- [RFC 5424: el protocolo syslog](https://www.rfc-editor.org/rfc/rfc5424) (facilities y severidades)

## ✅ Checklist de Verificación

- [ ] Escribes con `logger -t -p --` y lees el mensaje con `journalctl -t`
- [ ] Compruebas que, sin `/dev/log`, `logger` pierde el mensaje con código `0`
- [ ] Envuelves una orden con `systemd-cat` y distingues `stdout` de `stderr`
- [ ] Rediriges un script entero con `exec > >(logger ...)`
- [ ] Escribes una función `log` con `date -Is`, `--` y `|| true`
- [ ] Demuestras el salto de línea falso y lo neutralizas
- [ ] Sabes qué nivel usar para cada tipo de mensaje

---

[← `logrotate`](06-logrotate.md) · [Construyendo `backup` →](08-construyendo-backup.md)
