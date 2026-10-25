# Práctica 04 — `guard` a mano

> Duración estimada: 90 min · Teoría de apoyo: archivos [07](../1-teoria/07-getopts-y-validacion-de-entradas.md) y [08](../1-teoria/08-construyendo-guard.md)

Aquí rellenas, **un `TODO` cada vez** (en el orden que más te conviene
comprobar), el `guard` del [`starter/toolkit.sh`](../3-proyecto/starter/toolkit.sh).
Tras cada paso lo entregas al laboratorio y compruebas lo que acabas de añadir.
Es el mismo trabajo que el proyecto, partido en pasos verificables.

Edita el `toolkit.sh` del `starter/` en tu **host** y usa esta función para
llevarlo al laboratorio (pégala en la terminal del host, desde la raíz del
repositorio):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-15-scripts_robustos_manejo_de_errores/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh guard -- echo hola; echo "codigo: $?"
# TODO:   0 1  0
# codigo: 0
```

Es el punto de partida: el esqueleto ya ejecuta, pero el cuerpo de
`cmd_guard` son marcadores. (Dentro del laboratorio usas `/root/bin/...`;
desde el host, **no** `~/bin`, que se expandiría en tu máquina.)

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae `guard_log` y `guard_interrupt` completas y
las variables globales. Reconocerlas evita reescribir lo que ya está.

**Comando**:

```bash
grep -n '^GUARD_\|^guard_\|^cmd_guard' bootcamp/week-15-scripts_robustos_manejo_de_errores/3-proyecto/starter/toolkit.sh | cut -c1-60
# 898:GUARD_LOG=""
# 899:GUARD_TMP=""
# 900:GUARD_PID=""
# 904:guard_log() {
# 918:guard_cleanup() {
# 925:guard_interrupt() {
# 940:guard_run() {
# 946:cmd_guard() {
```

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-15-scripts_robustos_manejo_de_errores/3-proyecto/starter/toolkit.sh
# 8
```

## Paso 2: TODO 3 y 4 — opciones y validación

**Por qué**: antes de crear nada, `guard` rechaza el uso inválido con código
`1` y un mensaje en `stderr`. `getopts` en modo silencioso procesa las
opciones, y la validación comprueba, en este orden, el comando, los tres
números, que el comando exista y que el registro se pueda abrir.

**Comando**: sustituye los comentarios `TODO 3` y `TODO 4` **y** la línea
`local nombre=""` que los sigue por:

```bash
  while getopts ':l:k:t:r:w:' opt; do
    case "$opt" in
      l) GUARD_LOG=$OPTARG ;;
      k) lock=$OPTARG ;;
      t) segundos=$OPTARG ;;
      r) reintentos=$OPTARG ;;
      w) espera=$OPTARG ;;
      :)
        echo "toolkit guard: -${OPTARG} necesita un valor" >&2
        exit 1
        ;;
      *)
        echo "toolkit guard: opcion desconocida: -${OPTARG}" >&2
        exit 1
        ;;
    esac
  done
  shift $(( OPTIND - 1 ))

  if [[ $# -eq 0 ]]; then
    echo "toolkit guard: falta el comando (uso: guard [opciones] -- COMANDO [ARGS...])" >&2
    exit 1
  fi
  local nombre="" valor=""
  for nombre in segundos reintentos espera; do
    valor=${!nombre}
    if ! is_uint "$valor"; then
      echo "toolkit guard: valor invalido para ${nombre}: '${valor}'" >&2
      exit 1
    fi
  done
  if ! command -v "$1" > /dev/null; then
    echo "toolkit guard: comando no encontrado: $1" >&2
    exit 1
  fi
  if [[ -n "$GUARD_LOG" ]] && ! { : >> "$GUARD_LOG"; } 2> /dev/null; then
    echo "toolkit guard: no puedo escribir el registro: ${GUARD_LOG}" >&2
    exit 1
  fi
```

(`local OPTIND=1` ya está arriba, en el esqueleto: la lección de la teoría
07. `${!nombre}` es la expansión **indirecta**: el valor de la variable cuyo
nombre está en `nombre`.)

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh guard; echo "codigo: $?"
# toolkit guard: falta el comando (uso: guard [opciones] -- COMANDO [ARGS...])
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh guard -z -- true; echo "codigo: $?"
# toolkit guard: opcion desconocida: -z
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh guard -t abc -- true; echo "codigo: $?"
# toolkit guard: valor invalido para segundos: 'abc'
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh guard -r; echo "codigo: $?"
# toolkit guard: -r necesita un valor
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh guard -- nocmd; echo "codigo: $?"
# toolkit guard: comando no encontrado: nocmd
# codigo: 1
```

## Paso 3: TODO 1 y 5 (primera parte) — el temporal y el `trap EXIT`

**Por qué**: el `trap EXIT` es el sitio de la limpieza y lo que registra el
**código final**. Va **después** de validar: un error de uso no debe dejar
temporal ni línea de `fin`. El manejador lee `$?` lo primero.

**Comando**: sustituye el cuerpo de `guard_cleanup` (la línea `:`) por:

```bash
  local rc=$?
  guard_log INFO "fin: codigo de salida ${rc}"
  if [[ -n "$GUARD_TMP" ]]; then
    rm -f -- "$GUARD_TMP"
  fi
```

y el comentario `TODO 5` por:

```bash
  GUARD_TMP=$(mktemp "${TMPDIR:-/tmp}/toolkit-guard.XXXXXX")
  trap guard_cleanup EXIT
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.log; /root/bin/toolkit.sh guard -l /tmp/g.log -- true 2>/dev/null; cat /tmp/g.log'
# 2026-10-25T10:15:02 INFO fin: codigo de salida 0
docker exec ubuntu-lab bash -c 'ls /tmp/toolkit-guard.* 2>&1 | head -1'
# ls: cannot access '/tmp/toolkit-guard.*': No such file or directory
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.log; /root/bin/toolkit.sh guard -t abc -l /tmp/g.log -- true 2>/dev/null; wc -c < /tmp/g.log'
# 0
```

La última comprobación: un error de **uso** (`exit 1` antes de los traps) no
escribe nada en el registro.

## Paso 4: TODO 2, 7 (una vez) y 8 — ejecutar y cerrar

**Por qué**: `guard_run` lanza el comando en **segundo plano** con su salida al
temporal, y lo espera con `wait` (así un `TERM` actúa al instante, paso 7). El
cierre muestra la salida y traduce `rc` a `0`, `2` o `4`.

**Comando**: sustituye el cuerpo de `guard_run` (la línea `: "${segundos}" ...`) por:

```bash
  if [[ "$segundos" -gt 0 ]]; then
    timeout "$segundos" "$@" > "$GUARD_TMP" 2>&1 &
  else
    "$@" > "$GUARD_TMP" 2>&1 &
  fi
  GUARD_PID=$!
  wait "$GUARD_PID"
```

el comentario `TODO 7` y la línea `local rc=0` por:

```bash
  guard_log INFO "intento 1/1: $*"
  local rc=0
  guard_run "$segundos" "$@" || rc=$?
```

y el comentario `TODO 8` junto con la línea `echo "TODO: ..."` por:

```bash
  cat "$GUARD_TMP"
  if [[ "$rc" -eq 0 ]]; then
    guard_log INFO "ok"
    return 0
  fi
  tail -n 5 "$GUARD_TMP" | while IFS= read -r linea; do
    guard_log INFO "salida: ${linea}"
  done
  if [[ "$rc" -eq 124 ]]; then
    exit 4
  fi
  exit 2
```

(El `|| rc=$?` es la forma de que `set -e` **no aborte** con el fallo y de
conservar el código.)

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh guard -- echo hola 2>/dev/null; echo "codigo: $?"
# hola
# codigo: 0
docker exec ubuntu-lab /root/bin/toolkit.sh guard -- false 2>/dev/null; echo "codigo: $?"
# codigo: 2
docker exec ubuntu-lab /root/bin/toolkit.sh guard -t 1 -- sleep 5 2>/dev/null; echo "codigo: $?"
# codigo: 4
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.log; /root/bin/toolkit.sh guard -l /tmp/g.log -- false; grep -c "fin: codigo de salida 2" /tmp/g.log'
# 1
docker exec ubuntu-lab bash -c 'ls /tmp/toolkit-guard.* 2>&1 | head -1'
# ls: cannot access '/tmp/toolkit-guard.*': No such file or directory
```

## Paso 5: TODO 6 — el bloqueo con `flock`

**Por qué**: así dos `guard` con el mismo `-k` no se solapan. `flock -n` no
espera: si está ocupado, `guard` sale con `3`. El bloqueo dura lo que el
descriptor abierto, es decir, lo que `guard`.

**Comando**: sustituye el comentario `TODO 6` por:

```bash
  if [[ -n "$lock" ]]; then
    local lock_fd
    exec {lock_fd}> "$lock"
    if ! flock -n "$lock_fd"; then
      guard_log ERROR "bloqueado: otra ejecucion tiene ${lock}"
      exit 3
    fi
  fi
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.lock; T=/root/bin/toolkit.sh; $T guard -k /tmp/g.lock -- sleep 2 2>/dev/null & sleep 0.5; $T guard -k /tmp/g.lock -- true 2>/dev/null; echo "codigo: $?"; wait'
# codigo: 3
docker exec ubuntu-lab /root/bin/toolkit.sh guard -k /tmp/g.lock -- echo libre 2>/dev/null
# libre
```

## Paso 6: TODO 7 — los reintentos

**Por qué**: un fallo pasajero merece otro intento, con **tope** y espera
**entre** intentos. Cada intento deja una línea en el registro: es lo que
permite entender después qué pasó.

**Comando**: sustituye las tres líneas del intento único (`guard_log INFO "intento 1/1: $*"`,
`local rc=0` y `guard_run ... || rc=$?`) por:

```bash
  local intento=0 maximo=$(( reintentos + 1 )) rc=0
  while [[ "$intento" -lt "$maximo" ]]; do
    intento=$(( intento + 1 ))
    guard_log INFO "intento ${intento}/${maximo}: $*"
    rc=0
    guard_run "$segundos" "$@" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      break
    fi
    if [[ "$rc" -eq 124 ]]; then
      guard_log WARN "timeout tras ${segundos}s"
    else
      guard_log WARN "fallo con codigo ${rc}"
    fi
    if [[ "$intento" -lt "$maximo" ]]; then
      sleep "$espera"
    fi
  done
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.log; /root/bin/toolkit.sh guard -l /tmp/g.log -r 2 -w 0 -- false; echo "codigo: $?"; grep -c "intento" /tmp/g.log; grep "intento 3/3" /tmp/g.log | cut -c21-'
# codigo: 2
# 3
# INFO intento 3/3: false
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.log; /root/bin/toolkit.sh guard -l /tmp/g.log -- true; grep -c "INFO intento 1/1: true" /tmp/g.log'
# 1
```

## Paso 7: TODO 5 (segunda parte) — `INT` y `TERM`

**Por qué**: una señal mientras el comando corre debe **matar al hijo**,
dejar constancia y salir con `128 + N`, y el `trap EXIT` hace la limpieza.
`guard_interrupt` ya viene escrita en el esqueleto: léela antes (mata al hijo,
lo recoge con `wait` y llama a `exit`).

**Comando**: sustituye la línea `trap guard_cleanup EXIT` por:

```bash
  trap guard_cleanup EXIT
  trap 'guard_interrupt INT 130' INT
  trap 'guard_interrupt TERM 143' TERM
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'rm -f /tmp/g.log; /root/bin/toolkit.sh guard -l /tmp/g.log -- sleep 30 & p=$!; sleep 0.5; kill -TERM $p; wait $p; echo "codigo: $?"; cat /tmp/g.log | cut -c21-; ls /tmp/toolkit-guard.* 2>&1 | head -1'
# codigo: 143
# INFO intento 1/1: sleep 30
# WARN interrumpido (TERM)
# INFO fin: codigo de salida 143
# ls: cannot access '/tmp/toolkit-guard.*': No such file or directory
```

`guard` salió con `143`, dejó el registro y **no** dejó el temporal.

## Paso 8: `shellcheck` y la verificación completa

**Por qué**: el script completo debe quedar limpio de `shellcheck` y sin
regresiones en las capas anteriores.

**Comando**:

```bash
docker exec ubuntu-lab apt-get install -y shellcheck > /dev/null   # si aun no lo instalaste
docker exec ubuntu-lab shellcheck /root/bin/toolkit.sh; echo "codigo: $?"
# codigo: 0
./scripts/verificar-semana.sh 15
# ... 18/18 comprobaciones superadas.
```

**Verifica**:

```bash
docker exec ubuntu-lab bash -c 'ls /tmp/toolkit-guard.* 2>&1 | head -1'
# ls: cannot access '/tmp/toolkit-guard.*': No such file or directory
```

## ✅ Resultado

- [ ] Opciones y valores inválidos salen con `1` y un mensaje en `stderr`, sin crear nada
- [ ] El `trap EXIT` registra `fin: codigo de salida N` y borra el temporal en todos los casos
- [ ] `guard -- echo hola` muestra la salida y sale con `0`; `false` da `2`; el timeout, `4`
- [ ] El segundo `guard -k` sale con `3` mientras el primero corre
- [ ] `-r 2` deja `intento 3/3` en el registro
- [ ] `TERM` a un `guard` en marcha da `143`, deja `interrumpido (TERM)` y limpia
- [ ] `shellcheck` sale limpio y `verificar-semana.sh 15` da 18/18

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `nombre: unbound variable` | Falta inicializar `nombre` o `opt` (`set -u`) | `local nombre="" valor=""` |
| `guard_run: command not found` | La función no está definida antes de `cmd_guard` | Las funciones van **antes** de quien las llama |
| Sale con `0` aunque el comando falle | Falta el `exit 2` del cierre | Revisa el paso 4 |
| `guard` aborta con el primer fallo y no reintenta | Llamas a `guard_run` sin `\|\| rc=$?` | `guard_run ... \|\| rc=$?` |
| Queda `/tmp/toolkit-guard.*` | El `trap EXIT` no está instalado o va antes del `mktemp` | Pasos 3 y 7: `mktemp`, luego `trap` |
| El `TERM` tarda en notarse | El comando corre en primer plano | `&` y `wait "$GUARD_PID"` en `guard_run` |
| Queda un `sleep` huérfano tras el `kill` | `guard_interrupt` no mata al hijo | Léela: `kill "$GUARD_PID"` y `wait` |
| `exec: {lock_fd}: bad file descriptor` | Falta el espacio o la sintaxis `{var}` | `exec {lock_fd}> "$lock"` |

---

[← Práctica 03: registro, `getopts` y concurrencia](03-registro-getopts-y-concurrencia.md) · [Proyecto: `toolkit` semana 15 →](../3-proyecto/README.md)
