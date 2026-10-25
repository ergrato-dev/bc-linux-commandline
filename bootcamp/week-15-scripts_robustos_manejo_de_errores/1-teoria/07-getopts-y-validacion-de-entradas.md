# `getopts` y validación de entradas

> Todo dato que entra a tu script desde fuera (argumentos, variables de
> entorno, archivos) es **sospechoso hasta que lo compruebas**. `getopts`
> procesa opciones sin reinventar la rueda y la validación decide si lo que
> llegó es aceptable.

## 🎯 Objetivos

- Procesar opciones cortas con `getopts`, con y sin valor, y con el modo silencioso (`:`)
- Explicar `OPTARG`, `OPTIND` y por qué una función necesita `local OPTIND=1`
- Detener las opciones con `--` y dejar los argumentos restantes en `"$@"`
- Validar enteros con regex, valores con una lista blanca y rutas con `-r`/`-d`/`realpath`
- Escribir un procesador de opciones **largas** a mano cuando haga falta

## 1. Qué problema resuelve

El `while` + `case` + `shift` de la Semana 13 funciona, pero cada script lo
reescribe con sus propios fallos: `-vn3` (opciones juntas), `--` (fin de
opciones), `-n` sin valor... `getopts` es el procesador **estándar de
bash y de POSIX** para eso. Y cuando el dato ya está dentro, hay que decidir
si **lo aceptas**: un `5; echo pwned` en una variable que esperabas
numérica no debe llegar a ningún `-gt`.

## 2. Cómo funciona

### 2.1 `getopts`

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
```

La **cadena de opciones** (`':vn:'`) dice qué letras existen: una letra sola
es un **interruptor** (`v`); con `:` detrás espera **valor** (`n:`). Cada vuelta
del `while` deja en `opt` la opción leída y, si lleva valor, en `OPTARG`.

| Elemento | Significa |
|---|---|
| `:` al **principio** de la cadena | **Modo silencioso**: getopts no imprime sus propios errores; los manejas tú |
| `opt` = `:` | A una opción le **falta el valor**; `OPTARG` es la opción |
| `opt` = `?` | **Opción desconocida**; `OPTARG` es la letra |
| `OPTIND` | Índice del **siguiente** argumento a procesar |
| `shift $((OPTIND - 1))` | Deja en `"$@"` solo lo que no son opciones |

```bash
bash go.sh -n
# falta valor para -n
# uso: go.sh [-v] [-n NUM] ARCHIVO
bash go.sh -x
# opcion desconocida: -x
# uso: go.sh [-v] [-n NUM] ARCHIVO
```

Sin el `:` inicial (modo "verboso"), `getopts` imprime **su** mensaje en
inglés (`go.sh: illegal option -- x`) y `OPTARG` queda vacío: menos control.
**Usa el modo silencioso** y escribe tus propios mensajes en español.

### 2.2 `--` y el primer argumento que no es opción

```bash
bash go.sh -- -v
# v=0 n=1 resto=[-v]
bash go.sh a -v
# v=0 n=1 resto=[a -v]
```

`getopts` se detiene en `--` (que **descarta**) y también en el **primer
argumento que no es una opción**: en `go.sh a -v`, el `-v` ya no se procesa.
Por eso `guard` se escribe `guard -t 5 -- comando -v`: las opciones del
comando que sigue **no** son de `guard`. Un valor que parece opción (`-n -5`)
se acepta tal cual: `OPTARG` es `-5`.

### 2.3 `OPTIND` y las funciones

`OPTIND` es una variable **global** que recuerda por dónde va `getopts`. Una
función que usa `getopts` y se llama **dos veces** se encuentra con el
`OPTIND` de la primera llamada:

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
```

`f -a` funciona la primera vez y la **segunda no procesa nada**: `OPTIND`
quedó en 2. `local OPTIND=1` lo reinicia por llamada. Es la línea que lleva
`cmd_guard`. (Dentro de `main`, el subcomando ya se quitó con `shift`, así
que `cmd_guard` recibe solo sus argumentos.)

### 2.4 Opciones largas: `getopts` no las conoce

`getopts` solo maneja letras sueltas (`--verbose` se interpreta como la opción desconocida `-`).
Para `--log archivo`, un `while` con `case`:

```bash
cat > gl.sh <<'EOS'
while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) log=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "desconocida $1"; exit 1 ;;
    *) break ;;
  esac
done
echo "log=${log:-} resto=[$*]"
EOS
bash gl.sh --log x.log -- cmd arg
# log=x.log resto=[cmd arg]
```

Es el estilo de `snapshot`, `healthcheck` y los demás subcomandos del
toolkit. Regla: **cortas con `getopts`, largas a mano**; mezclarlas
(`--log` y `-l`) exige las dos.

### 2.5 Validar el dato

Cuatro validaciones que cubren casi todo:

```bash
# Un entero SIN signo: regex con anclas, ANTES de cualquier -gt/-lt
[[ "$n" =~ ^[0-9]+$ ]] || die "n debe ser un entero: '${n}'"

# Un valor de una lista cerrada: case
case "$nombre" in
  disk | mem | procs) ;;
  *) die "comprobacion desconocida: '${nombre}'" ;;
esac

# Un archivo o directorio: los tests -r, -d, -w
[[ -r "$archivo" ]] || die "no puedo leer ${archivo}"
[[ -d "$dir" && -w "$dir" ]] || die "no puedo escribir en ${dir}"

# Una ruta "normalizada": realpath -m resuelve .. sin exigir que exista
realpath -m /tmp/../etc/./x
# /etc/x
```

```bash
x="5; echo pwned"; [[ $x =~ ^[0-9]+$ ]] || echo "rechazado"
# rechazado
v="12 "; [[ $v =~ ^[0-9]+$ ]] || echo "con espacio no"
# con espacio no
v=""; [[ $v =~ ^[0-9]+$ ]] || echo "vacio no"
# vacio no
```

El regex con **anclas** (`^...$`) rechaza espacios, signos, vacíos y
cualquier intento de colar código. Para una **lista cerrada**, `case` es
mejor que comprobar "que no sea `rm`": define **qué se permite**, no qué se
prohíbe.

`printf %q` escapa una cadena para que sea segura **si algún día tienes que
reinsertarla** en un comando (casi siempre hay una forma mejor, un array):

```bash
printf '%q\n' "a b;c" '$HOME'
# a\ b\;c
# \$HOME
```

### 2.6 Los argumentos del script, con cuidado

```bash
f() { echo "n=$#"; }
f $(echo "a b")
# n=2
f "$(echo "a b")"
# n=1
```

Sin comillas, la expansión se **parte** (Semana 13); con ellas, es un
argumento. Y `--` antes de datos de fuera: `rm -- "$f"`, `ls -- "$f"`.

## 3. Cómo se usa

El bloque de entrada de `cmd_guard` es el modelo completo:

```bash
local OPTIND=1 opt
while getopts ':l:k:t:r:w:' opt; do
  case "$opt" in
    l) GUARD_LOG=$OPTARG ;;
    ...
    :) echo "toolkit guard: -${OPTARG} necesita un valor" >&2; exit 1 ;;
    *) echo "toolkit guard: opcion desconocida: -${OPTARG}" >&2; exit 1 ;;
  esac
done
shift $(( OPTIND - 1 ))
[[ $# -eq 0 ]] && ...           # ¿hay comando?
is_uint "$valor" || ...         # ¿son enteros los numeros?
command -v "$1" > /dev/null     # ¿existe el comando?
```

Todo **antes** de crear temporales o bloqueos: validar primero, actuar
después.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `getopts` sin `:` inicial | Mensajes en inglés y sin control del código de salida | `getopts ':vn:' opt` |
| Olvidar `shift $((OPTIND - 1))` | Los argumentos siguen incluyendo las opciones | Siempre tras el bucle |
| `getopts` en una función sin `local OPTIND=1` | La segunda llamada no procesa nada | Reiniciar `OPTIND` |
| Esperar `--long` en `getopts` | No existe | `while` + `case` a mano |
| `[[ $n -gt 5 ]]` sin validar `$n` antes | `-gt` evalúa aritmética: `a[$(cmd)]` ejecuta `cmd` (Semana 12) | `[[ $n =~ ^[0-9]+$ ]]` primero |
| Validar con "lista negra" (`!= rm`) | Siempre te dejas algo | Lista blanca con `case` |
| Validar tras usar el dato | Ya hizo daño | Validar en la frontera, antes de actuar |
| Aceptar rutas con `..` de un usuario sin normalizar | Salen del directorio permitido | `realpath -m` y comprobar el prefijo |

## 5. Trucos

- **`getopts ':vn:' opt "$@"`** acepta una lista explícita de argumentos en
  vez de `"$@"` implícito: sirve para probar el procesador sin llamar al script.
- **`OPTERR=0`** silencia los mensajes del modo verboso; con `:` inicial ya no
  hace falta.
- **`set -- -x foo`** reemplaza los argumentos posicionales del shell actual:
  lo mejor para **probar** un procesador de opciones en la terminal.
- **`${1:?uso: script ARCHIVO}`** exige el primer argumento con un mensaje de
  uso en una sola línea.

## 📚 Recursos Adicionales

- `help getopts` y `man bash`, sección *getopts*
- [BashFAQ 035 — cómo procesar argumentos](https://mywiki.wooledge.org/BashFAQ/035)

## ✅ Checklist de Verificación

- [ ] `bash go.sh -vn3 a b` da `v=1 n=3 resto=[a b]`
- [ ] `bash go.sh -n` y `bash go.sh -x` salen con tu mensaje y con `1`
- [ ] `bash go.sh -- -v` deja `-v` en `resto`
- [ ] Reproduces el `f -a; f -a` que falla y el `g -a; g -a` que funciona
- [ ] `[[ "5; echo pwned" =~ ^[0-9]+$ ]]` es falso
- [ ] `realpath -m /tmp/../etc/./x` imprime `/etc/x`

---

[← Concurrencia, bloqueos y reintentos](06-concurrencia-bloqueos-y-reintentos.md) · [Construyendo `guard` →](08-construyendo-guard.md)
