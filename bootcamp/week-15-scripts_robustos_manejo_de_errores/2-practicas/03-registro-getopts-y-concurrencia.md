# Práctica 03 — Registro, `getopts` y concurrencia

> Duración estimada: 75 min · Teoría de apoyo: archivos [05](../1-teoria/05-registro-y-depuracion.md), [06](../1-teoria/06-concurrencia-bloqueos-y-reintentos.md) y [07](../1-teoria/07-getopts-y-validacion-de-entradas.md)

Trabajas **dentro de `ubuntu-lab`**:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p15/r && mkdir -p ~/p15/r && cd ~/p15/r
```

## Paso 1: Una función `log` que no contamina `stdout`

**Por qué**: el registro va a `stderr` para que no se mezcle con los datos del
script. Se comprueba separando los dos flujos.

**Comando**:

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
bash l.sh 2>/dev/null
# dato
bash l.sh 2>err.log >out.txt; cat out.txt; wc -l < err.log
# dato
# 2
LOG_LEVEL=DEBUG bash l.sh 2>&1 >/dev/null | wc -l
# 3
```

**Verifica**:

```bash
grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8} (INFO |WARN ) ' err.log
# 2
```

## Paso 2: Redirigir todo un script a un archivo, y `tee`

**Por qué**: un script lanzado por `cron` no tiene terminal: todo lo que
imprime debe acabar en un archivo. `exec` sin comando redirige **el resto del
script**; `tee` guarda **y** muestra.

**Comando**:

```bash
cat > r.sh <<'EOS'
exec >>todo.log 2>&1
echo "salida normal"
echo "error" >&2
EOS
bash r.sh; bash r.sh; cat todo.log
# salida normal
# error
# salida normal
# error
(echo uno; echo dos >&2) 2>&1 | tee -a tee.log
# uno
# dos
```

Las dos ejecuciones **añadieron** al archivo (`>>`); con `>` la segunda
habría borrado la primera.

**Verifica**:

```bash
wc -l < tee.log
# 2
```

## Paso 3: Depurar con `set -x`, `PS4` y `bash -n`

**Por qué**: `set -x` enseña lo que ejecuta bash; con un `PS4` informativo,
**dónde**. Y `bash -n` detecta un `fi` olvidado sin ejecutar nada.

**Comando**:

```bash
printf 'x=1\necho "$x"\n' > v.sh
bash -x v.sh
# + x=1
# + echo 1
# 1
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
printf 'if true; then\n echo x\n' > bad.sh
bash -n bad.sh; echo "codigo: $?"
# bad.sh: line 3: syntax error: unexpected end of file
# codigo: 2
```

**Verifica**:

```bash
bash -n ps.sh; echo "codigo: $?"
# codigo: 0
```

## Paso 4: Dónde falló: `trap ERR` con la línea

**Por qué**: un `trap ERR` con `$LINENO` y `$BASH_COMMAND` convierte "falló
algo" en "falló `false` en la línea 3".

**Comando**:

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

**Verifica**:

```bash
bash e.sh 2>&1 | grep -c 'linea 3'
# 1
```

## Paso 5: `getopts` en modo silencioso

**Por qué**: es el procesador estándar de opciones. El `:` inicial desactiva
sus mensajes (en inglés) para escribir los tuyos.

**Comando**:

```bash
cat > go.sh <<'EOS'
uso() { echo "uso: go.sh [-v] [-n NUM] ARCHIVO" >&2; exit 1; }
verbose=0 num=1
while getopts ':vn:' opt; do
  case "$opt" in
    v) verbose=1 ;;
    n) num=$OPTARG ;;
    :) echo "falta valor para -$OPTARG" >&2; uso ;;
    \?) echo "opcion desconocida: -$OPTARG" >&2; uso ;;
  esac
done
shift $((OPTIND - 1))
echo "v=$verbose n=$num resto=[$*]"
EOS
bash go.sh -v -n 3 arch.txt
# v=1 n=3 resto=[arch.txt]
bash go.sh -vn3 a b
# v=1 n=3 resto=[a b]
bash go.sh -n; echo "codigo: $?"
# falta valor para -n
# uso: go.sh [-v] [-n NUM] ARCHIVO
# codigo: 1
bash go.sh -x 2>&1 | sed -n 1p
# opcion desconocida: -x
bash go.sh -- -v
# v=0 n=1 resto=[-v]
bash go.sh a -v
# v=0 n=1 resto=[a -v]
```

El `--` y el **primer argumento que no es opción** detienen el procesado.

**Verifica**:

```bash
bash go.sh -n -5
# v=0 n=-5 resto=[]
```

## Paso 6: `OPTIND` en funciones y validar el valor

**Por qué**: una función con `getopts` llamada dos veces necesita
`local OPTIND=1`. Y el valor recibido se valida **antes** de usarlo.

**Comando**:

```bash
cat > go2.sh <<'EOS'
f() { local opt; while getopts 'a' opt; do echo "opt $opt"; done; }
f -a; f -a
g() { local OPTIND=1 opt; while getopts 'a' opt; do echo "gopt $opt"; done; }
g -a; g -a
EOS
bash go2.sh
# opt a
# gopt a
# gopt a
x="5; echo pwned"; [[ $x =~ ^[0-9]+$ ]] || echo "rechazado"
# rechazado
v="12 "; [[ $v =~ ^[0-9]+$ ]] || echo "con espacio no"
# con espacio no
realpath -m /tmp/../etc/./x
# /etc/x
```

La segunda llamada a `f` **no imprime nada**: `OPTIND` quedó en 2.

**Verifica**:

```bash
bash go2.sh | grep -c gopt
# 2
```

## Paso 7: `flock`: una sola ejecución a la vez

**Por qué**: en la Semana 16 un script programado puede solaparse consigo
mismo. `flock` lo impide con un bloqueo que el kernel libera **aunque el
proceso muera**.

**Comando**:

```bash
cat > lk.sh <<'EOS'
exec {lock_fd}>/tmp/lk.lock
if ! flock -n "$lock_fd"; then
  echo "otra ejecucion en curso" >&2
  exit 3
fi
echo "trabajando"
sleep 2
EOS
bash lk.sh & sleep 0.3; bash lk.sh; echo "codigo: $?"; wait
# trabajando
# otra ejecucion en curso
# codigo: 3
flock -n /tmp/lk.lock echo libre; echo "codigo: $?"
# libre
# codigo: 0
```

Y el bloqueo **no queda huérfano** si el proceso muere de mala manera:

```bash
bash -c 'exec 9>/tmp/l2.lock; flock 9; read -r x' < <(sleep 30) & h=$!
sleep 0.4; flock -n /tmp/l2.lock true; echo "ocupado: $?"
# ocupado: 1
kill -9 $h; sleep 0.2; flock -n /tmp/l2.lock true; echo "tras kill -9: $?"
# tras kill -9: 0
```

**Verifica**:

```bash
flock -n /tmp/lk.lock true; echo "$?"
# 0
```

## Paso 8: `timeout`, reintentos e idempotencia

**Por qué**: un comando colgado no debe bloquear al script; un fallo pasajero
merece otro intento (con tope y espera); y todo lo que se repite debe ser
seguro de repetir.

**Comando**:

```bash
timeout 1 sleep 5; echo "codigo: $?"
# codigo: 124
timeout -s KILL 1 sleep 3; echo "codigo: $?"
# codigo: 137
timeout -k 1 1 bash -c 'trap "" TERM; sleep 5'; echo "codigo: $?"
# codigo: 137
retry() {
  local intentos=$1 espera=1 i
  shift
  for ((i = 1; i <= intentos; i++)); do
    "$@" && return 0
    echo "intento ${i} fallo, espero ${espera}s" >&2
    sleep "$espera"
    espera=$(( espera * 2 ))
  done
  return 1
}
retry 3 false; echo "codigo: $?"
# intento 1 fallo, espero 1s
# intento 2 fallo, espero 2s
# intento 3 fallo, espero 4s
# codigo: 1
mkdir -p dir; mkdir -p dir; echo "mkdir -p: $?"
# mkdir -p: 0
mkdir dir 2>/dev/null; echo "mkdir sin -p: $?"
# mkdir sin -p: 1
```

(`retry 3 false` tarda **7 s**: `1 + 2 + 4`.) El tercer `timeout` ilustra `-k`:
el comando ignora `TERM` y `timeout` lo mata con `KILL`.

**Verifica**:

```bash
retry 2 true; echo "codigo: $?"
# codigo: 0
```

## ✅ Resultado

- [ ] `l.sh` separa datos (`stdout`) y registro (`stderr`) y filtra `DEBUG`
- [ ] `exec >>archivo 2>&1` añade en cada ejecución y `tee -a` muestra y guarda
- [ ] Obtienes la traza con `archivo:línea:función` y `bash -n` detecta el `fi` que falta
- [ ] `e.sh` dice la línea del fallo
- [ ] `go.sh` gestiona `-vn3`, el valor ausente, la opción desconocida y `--`
- [ ] Explicas por qué `f -a; f -a` falla la segunda vez y `local OPTIND=1` lo arregla
- [ ] `lk.sh` sale con `3` la segunda vez, y el bloqueo se libera tras `kill -9`
- [ ] `timeout` da `124` y `137`, `retry` espera `1`, `2` y `4` s, y `mkdir -p` es idempotente

```bash
./scripts/verificar-semana.sh 15
```

(Esta práctica no tiene entregable propio: son las piezas de `guard`.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El registro aparece en `stdout` | Falta el `>&2` en `printf` | `... >&2` |
| `exec >>archivo` y la terminal "se calla" | Ejecutaste `exec` en tu shell, no en un script | Pruébalo dentro de `bash r.sh` |
| `+ set +x` aparece en la traza | El `set +x` también se traza | `{ set +x; } 2>/dev/null` |
| `getopts` no procesa nada en la segunda llamada | `OPTIND` sin reiniciar | `local OPTIND=1` |
| `--verbose` da "opción desconocida: --" | `getopts` no tiene opciones largas | `while` + `case` a mano (teoría 07) |
| `flock: command not found` | Imagen mínima sin `util-linux` | Viene en las cuatro distribuciones del laboratorio; compruébalo con `command -v flock` |
| `retry` no termina | Reintentas sin tope | Siempre un máximo de intentos |
| `timeout` no corta una función | Solo ejecuta programas externos | `timeout 5 bash -c '...'` |

---

[← Práctica 02: `trap` y archivos temporales](02-trap-y-archivos-temporales.md) · [Práctica 04: `guard` a mano →](04-guard-a-mano.md)
