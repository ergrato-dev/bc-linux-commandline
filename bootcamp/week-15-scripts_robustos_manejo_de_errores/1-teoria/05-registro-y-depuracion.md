# Registro y depuración

> Un script que corre solo (Semana 16) no tiene a nadie mirando la pantalla.
> Lo que escribe a `stderr` y a un archivo de registro **es** su único
> testimonio. Y cuando falla, `set -x` y `bash -n` te dicen qué pasó sin
> reescribirlo.

## 🎯 Objetivos

- Escribir una función `log` con nivel y marca de tiempo, a `stderr`, que no contamine `stdout`
- Redirigir la salida de un script a un archivo (`exec >> archivo 2>&1`) y duplicarla con `tee`
- Depurar con `set -x`, un `PS4` informativo y `bash -n`
- Obtener la línea y la función de un fallo con `LINENO`, `FUNCNAME`, `caller` y `trap ERR`
- Saber cuándo `logger` sirve y cuándo no (en el laboratorio no)

## 1. Qué problema resuelve

El script del lunes a las 3:00 falló. ¿Qué hizo antes? ¿Con qué argumentos?
¿Cuánto tardó? Sin registro, la respuesta es "no lo sé". Y cuando **tú**
depuras un script que no funciona, `echo "aqui"` por todas partes es lento y
ensucia el código. Bash trae las herramientas de las dos cosas.

## 2. Cómo funciona

### 2.1 Una función `log` mínima

```bash
cat > l.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG_LEVEL=${LOG_LEVEL:-INFO}
log() {
  local nivel=$1; shift
  case "$nivel" in
    DEBUG) [[ "$LOG_LEVEL" == DEBUG ]] || return 0 ;;
  esac
  printf '%(%FT%T)T %-5s %s\n' -1 "$nivel" "$*" >&2
}
log INFO "inicio"
log DEBUG "detalle interno"
log WARN "algo raro"
echo "dato"
EOS
bash l.sh
# 2026-10-25T10:15:02 INFO  inicio
# 2026-10-25T10:15:02 WARN  algo raro
# dato
LOG_LEVEL=DEBUG bash l.sh
# 2026-10-25T10:15:02 INFO  inicio
# 2026-10-25T10:15:02 DEBUG detalle interno
# 2026-10-25T10:15:02 WARN  algo raro
# dato
```

Tres decisiones:

- **A `stderr` (`>&2`)**, no a `stdout`: el registro no se mezcla con los
  **datos** que el script produce. `bash l.sh 2>/dev/null` imprime solo
  `dato`; `bash l.sh 2>err.log >out.txt` separa ambos flujos.
- **`printf '%(%FT%T)T' -1`** da la fecha y hora **actuales** sin lanzar
  `date`: `%FT%T` es el formato ISO (`2026-10-25T10:15:02`), que se ordena
  alfabéticamente y lo leen todas las herramientas.
- **Niveles** (`DEBUG`, `INFO`, `WARN`, `ERROR`): quien lee filtra por
  nivel; `DEBUG` se silencia salvo que lo pidas con una variable de entorno.

`guard` usa la misma idea con `date +%FT%T` y la decisión **archivo o
`stderr`**: `echo "$linea" >> "$GUARD_LOG"` si hay `-l`, `>&2` si no.

### 2.2 Redirigir todo un script a un archivo

```bash
cat > r.sh <<'EOS'
exec >>/tmp/todo.log 2>&1
echo "salida normal"
echo "error" >&2
EOS
bash r.sh; cat /tmp/todo.log
# salida normal
# error
```

`exec` **sin comando** aplica la redirección a **todo el resto del script**:
`>>` añade (no pisa) y `2>&1` envía `stderr` al mismo sitio. Es lo que hace
falta cuando `cron` lanza el script y no quieres depender de su correo.

Para **ver y guardar** a la vez, `tee`:

```bash
(echo uno; echo dos >&2) 2>&1 | tee -a /tmp/tee.log
# uno
# dos
```

(`-a` añade en vez de sobrescribir.)

### 2.3 `set -x`: ver lo que ejecuta bash

```bash
printf 'x=1\necho "$x"\n' > v.sh
bash -x v.sh
# + x=1
# + echo 1
# 1
bash -v v.sh
# x=1
# echo "$x"
# 1
```

`-x` imprime cada comando **ya expandido** (con `+` delante); `-v` imprime
cada línea **tal como está escrita**, antes de ejecutarla. Para trazar solo un
tramo, `set -x` ... `set +x` dentro del script. Para que el propio `set +x`
no aparezca en la traza:

```bash
cat > t.sh <<'EOS'
set -x
a=1
{ set +x; } 2>/dev/null
echo "sin traza"
EOS
bash t.sh
# + a=1
# sin traza
```

### 2.4 `PS4`: la traza con archivo, línea y función

```bash
cat > ps.sh <<'EOS'
PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '
set -x
f() { local x=1; echo "$x"; }
f
set +x
EOS
bash ps.sh
# + ps.sh:4:main: f
# + ps.sh:3:f: local x=1
# + ps.sh:3:f: echo 1
# 1
# + ps.sh:5:main: set +x
```

`PS4` es el prefijo de cada línea de traza. Con `BASH_SOURCE`, `LINENO` y
`FUNCNAME` la traza dice **dónde** está cada comando. (Como en la Semana 13:
va **dentro** del script, no como variable de entorno delante de `bash -x`.)

Si no quieres que la traza vaya a `stderr`, `BASH_XTRACEFD` la envía a otro
descriptor, que debes **abrir antes**:

```bash
exec 7>/tmp/traza.out; BASH_XTRACEFD=7; set -x; echo hola >/dev/null; set +x; exec 7>&-
cat /tmp/traza.out
# + echo hola
# + set +x
```

### 2.5 `bash -n`: comprobar la sintaxis sin ejecutar

```bash
printf 'if true; then\n echo x\n' > bad.sh
bash -n bad.sh; echo "codigo: $?"
# bad.sh: line 3: syntax error: unexpected end of file
# codigo: 2
bash -n ps.sh; echo "codigo: $?"
# codigo: 0
```

`-n` lee el script y **no ejecuta nada**: sirve para detectar un `fi` olvidado
en un script que borra cosas, antes de lanzarlo. `shellcheck` hace eso y más
(Semana 13).

### 2.6 ¿Dónde falló? `LINENO`, `FUNCNAME`, `caller` y `ERR`

```bash
cat > c.sh <<'EOS'
trace() { echo "linea $(caller 0 | cut -d' ' -f1) en ${FUNCNAME[1]:-main}"; }
f() { trace; }
f
trace
EOS
bash c.sh
# linea 2 en f
# linea 4 en main
```

`caller 0` imprime `LINEA FUNCION ARCHIVO` de **quien llamó** a la función
actual; `${FUNCNAME[1]}` es esa función. Lo más cómodo es un `trap ERR`
(archivo 03) que lo hace automáticamente:

```bash
cat > e.sh <<'EOS'
set -eEuo pipefail
trap 'echo "ERROR linea $LINENO: $BASH_COMMAND (codigo $?)" >&2' ERR
f() { false; }
echo antes
f
echo nunca
EOS
bash e.sh; echo "codigo: $?"
# antes
# ERROR linea 3: false (codigo 1)
# codigo: 1
```

El fallo ocurrió en la línea 3, dentro de `f` (con `-E`, el trap salta en
funciones), y el script salió con el código original.

### 2.7 `logger`: al registro del sistema

```bash
logger -s -t mi-script "hola"
# logger: socket /dev/log: No such file or directory
```

`logger` envía un mensaje al **registro del sistema** (`syslog` o el
`journal` de systemd, Semana 18). En una máquina normal aparece en
`journalctl -t mi-script`. En los contenedores del laboratorio **no hay
demonio de registro**, así que falla; por eso esta semana el registro va a un
archivo propio. (Existe en las cuatro distribuciones del laboratorio, de
`util-linux`.)

## 3. Cómo se usa

Un esquema que combina lo de la semana:

```bash
LOG=/tmp/mi-script.log
exec >>"$LOG" 2>&1                       # todo al archivo (si lo lanza cron)
PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '   # por si hay que trazar
trap 'log ERROR "linea $LINENO: $BASH_COMMAND"' ERR
log INFO "inicio"
```

Y para depurar un script ajeno: `bash -x script.sh 2> traza.txt` y leer la
**última** línea de la traza antes del fallo.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Mensajes de registro a `stdout` | Se mezclan con los datos y rompen las tuberías | `>&2` |
| Registro sin fecha | No sabes **cuándo** pasó | `printf '%(%FT%T)T'` o `date +%FT%T` |
| `echo "aqui1"`, `echo "aqui2"` | Ensucia el código y se olvida quitarlos | `set -x` con `PS4` |
| `set -x` en producción con secretos | La traza imprime las variables **expandidas** (tokens incluidos) | Trazar solo en depuración y nunca con `<TOKEN>` real |
| Registro que crece sin límite | Llena el disco | Rotación (Semana 18, `logrotate`) |
| Registrar solo los errores | Sin el contexto de lo que **sí** funcionó, no se entiende | Un `INFO` al empezar y al terminar |
| `exec > archivo` (sin `>>`) | Pisa el registro anterior | `exec >> archivo` |
| Fiar la depuración a leer el código | Lento y propenso a error | `bash -x` y `bash -n` |

## 5. Trucos

- **`bash -x script.sh 2>&1 | tail -20`** muestra los **últimos** comandos
  antes del fallo, que es casi siempre lo que buscas.
- **`PS4='+ $(date +%T) '`** añade la hora a cada comando trazado (más lento,
  pero útil para ver **dónde se va el tiempo**).
- **`set -o xtrace`** y **`set -o verbose`** son los nombres largos de `-x` y
  `-v`.

## 📚 Recursos Adicionales

- `man bash`, sección *PS4* y la opción `-x` de *set*
- [BashFAQ 105 — qué hace realmente `set -e`](https://mywiki.wooledge.org/BashFAQ/105)

## ✅ Checklist de Verificación

- [ ] `bash l.sh 2>/dev/null` imprime solo `dato`
- [ ] `LOG_LEVEL=DEBUG bash l.sh` añade la línea `DEBUG`
- [ ] `bash -x v.sh` y `bash -v v.sh` muestran formas distintas de la misma ejecución
- [ ] `bash ps.sh` imprime `archivo:línea:función` en cada comando
- [ ] `bash -n bad.sh` sale con `2` sin ejecutar nada
- [ ] `bash e.sh` imprime la línea del fallo y sale con `1`

---

[← Archivos temporales y escritura atómica](04-archivos-temporales-y-escritura-atomica.md) · [Concurrencia, bloqueos y reintentos →](06-concurrencia-bloqueos-y-reintentos.md)
