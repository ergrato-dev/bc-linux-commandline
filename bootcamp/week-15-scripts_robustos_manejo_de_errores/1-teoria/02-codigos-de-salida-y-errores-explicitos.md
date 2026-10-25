# Códigos de salida y manejo explícito de errores

> `set -e` aborta; **tú decides qué decir y con qué código**. Este archivo
> trata de convertir un fallo mudo en un mensaje con motivo, un código con
> significado y, cuando toca, una recuperación.

## 🎯 Objetivos

- Leer `$?` sin perderlo y guardar el código antes de que otro comando lo pise
- Reconocer los códigos reservados: `126`, `127` y `128+N`
- Escribir un `die` que imprime a `stderr` y sale con el código que elijas
- Manejar un fallo con `if`, `||` y `PIPESTATUS`, según lo que necesites
- Validar entradas y proteger los argumentos con `--` y `${v:?}`

## 1. Qué problema resuelve

Un script que "falla" con `exit 1` y sin mensaje obliga a quien lo lanza a
**adivinar** qué pasó. Y quien lo lanza suele ser `cron` (Semana 16), que solo
ve el código de salida y, si lo hay, lo que escribiste a `stderr`. Un buen
manejo de errores responde a tres preguntas: **¿qué falló?** (mensaje),
**¿de qué tipo?** (código) y **¿se puede seguir?** (decisión).

## 2. Cómo funciona

### 2.1 `$?` es volátil

`$?` vale el código del **último** comando, y casi todo lo reemplaza,
incluido un `echo`:

```bash
false; echo "primero: $?"; echo "segundo: $?"
# primero: 1
# segundo: 0
```

Si lo necesitas más de una vez, **guárdalo** en una variable en la línea
siguiente al comando:

```bash
cmd=false
"$cmd" || rc=$?
echo "codigo guardado: ${rc}"
# codigo guardado: 1
```

El patrón `cmd || rc=$?` es el idiomático con `set -e`: el `||` "comprueba"
el fallo (no aborta) y `rc` conserva el código (con `rc=0` declarado antes
si el comando puede salir bien).

### 2.2 Códigos con significado

| Código | Significa | Ejemplo |
|:--:|---|---|
| `0` | Éxito | `true` |
| `1` | Fallo genérico | `false` |
| `2` | Uso incorrecto (convención de muchas herramientas) y, en el toolkit, "hallazgos" | `grep` con opciones inválidas |
| `126` | Se encontró el archivo pero **no es ejecutable** | `bash -c '/tmp/sin-permiso.sh'` |
| `127` | **Comando no encontrado** | `bash -c 'nocmd_zz'` |
| `128 + N` | Muerto por la señal `N` | `143` = `TERM`, `130` = `INT`, `137` = `KILL` |
| `255` | Reservado (por ejemplo, `ssh` con error de conexión) | |

```bash
touch /tmp/sin-permiso.sh; bash -c '/tmp/sin-permiso.sh'; echo "codigo: $?"
# bash: line 1: /tmp/sin-permiso.sh: Permission denied
# codigo: 126
bash -c 'nocmd_zz'; echo "codigo: $?"
# bash: line 1: nocmd_zz: command not found
# codigo: 127
bash -c 'kill -TERM $$'; echo "codigo: $?"
# codigo: 143
bash -c 'exit 300'; echo "codigo: $?"
# codigo: 44
```

Los códigos van de `0` a `255`: `exit 300` es `300 mod 256 = 44`. En el
toolkit usamos `0` bien, `1` uso inválido y `2` hallazgo (y esta semana
`guard` añade `3` bloqueo ocupado y `4` timeout). **Documenta los tuyos en la
cabecera del script**, como hace `toolkit.sh`.

### 2.3 `die`: el mensaje y el código en un solo sitio

```bash
die() {
  echo "toolkit: $1" >&2
  exit "${2:-1}"
}
die "algo ha ido mal" 7
# toolkit: algo ha ido mal
```

(Sale con `7`.) Tres detalles: el mensaje va a **`stderr`** (`>&2`) para no
mezclarse con los datos de `stdout`; el código por defecto es `1` con
`${2:-1}`; y `exit` dentro de una función termina **el script entero**, no
solo la función (a diferencia de `return`, Semana 14).

### 2.4 Tres formas de manejar un fallo

```bash
# A. El fallo es una DECISION: if
if ! grep -q '^root:' /etc/passwd; then
  echo "no hay root en passwd" >&2
fi

# B. El fallo es un ERROR con recuperacion o salida: ||  { ...; }
cd -- /no/existe 2>/dev/null || { echo "no puedo entrar" >&2; exit 5; }

# C. El fallo es TOLERABLE: || true
grep -q zzz /etc/hostname || true
```

| Forma | Cuándo |
|---|---|
| `if cmd; then ...` | El resultado es una **decisión** del script |
| `cmd \|\| { msg; exit N; }` | El fallo es **fatal** y quieres decirlo |
| `cmd \|\| true` | El fallo es **esperado** y no importa |
| `cmd \|\| rc=$?` | Necesitas el **código** para decidir después |

### 2.5 Fallos dentro de una tubería: `PIPESTATUS`

```bash
set -o pipefail
grep -c root /etc/passwd | sort > /dev/null; echo "${PIPESTATUS[*]}"
# 0 0
```

Con `pipefail`, el código de la tubería ya refleja el primer fallo; si
necesitas saber **cuál** de los tramos falló, `PIPESTATUS` lo dice. Se lee
**inmediatamente** después y se guarda: `st=("${PIPESTATUS[@]}")`.

### 2.6 Validar en la frontera

La validación va donde **entran los datos** (argumentos, variables de
entorno, archivos de usuario) y con un mensaje que diga qué se esperaba:

```bash
: "${REQ:?falta la variable REQ}"      # aborta con mensaje si no existe (exit 1 en un script)
[[ -r "$archivo" ]] || die "no puedo leer ${archivo}" 1
[[ "$n" =~ ^[0-9]+$ ]] || die "n debe ser un entero: '${n}'" 1
```

`${REQ:?mensaje}` imprime el mensaje a `stderr` y sale con `1` **en un
script** (bajo `bash -c` sale con `127`, una rareza que conviene conocer al
probar). El `[[ =~ ]]` entero se usa **antes** de cualquier `-gt` (Semana
12).

### 2.7 `--`: el fin de las opciones

```bash
touch -- /tmp/-n
ls -- /tmp/-n
# /tmp/-n
rm -- /tmp/-n
```

Un nombre de archivo que empieza por `-` se interpreta como **opción**.
`--` le dice al comando "lo que viene ya son argumentos". En un script que
recibe nombres de archivo de fuera, `rm -- "$f"` y `cp -- "$a" "$b"` evitan
que un archivo llamado `-rf` cambie el comportamiento.

## 3. Cómo se usa

El esqueleto que usa `guard` esta semana: valida, informa con el motivo y
elige el código:

```bash
if [[ $# -eq 0 ]]; then
  echo "toolkit guard: falta el comando (uso: guard [opciones] -- COMANDO [ARGS...])" >&2
  exit 1
fi
if ! command -v "$1" > /dev/null; then
  echo "toolkit guard: comando no encontrado: $1" >&2
  exit 1
fi
```

`command -v nombre` es la forma portable de preguntar "¿existe este comando,
función o alias?": sale con `0` si existe y con `1` si no, sin imprimir
errores.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `exit 1` sin mensaje | Quien lo lanza no sabe qué pasó | Mensaje a `stderr` con el motivo |
| Mensajes de error a `stdout` | Se mezclan con los datos y rompen las tuberías | `>&2` |
| Usar `$?` tras otro comando intermedio | Ya no es el código que querías | Guardar `rc=$?` enseguida, o usar `\|\| rc=$?` |
| Todos los fallos con `exit 1` | El llamador no distingue "uso mal" de "algo falló" | Códigos documentados (`1`, `2`, `3`...) |
| `which cmd` para comprobar que existe | No es POSIX y su salida varía entre distros | `command -v cmd` |
| Interpolar un nombre de usuario en `rm $f` | Un `-rf` en el nombre cambia el comando | `rm -- "$f"` |
| `\|\| true` en todo para que no falle | Convierte los errores reales en silencio | Solo en los fallos **esperados** |
| `exit` en una función que debía devolver un estado | Mata el script entero | `return N` y que decida el llamador |

## 5. Trucos

- **`trap 'echo "error en la linea $LINENO" >&2' ERR`** (con `set -E`) da la
  línea del fallo sin tocar el resto del script; lo ves entero en el archivo 03.
- **`exit "$rc"` tras limpiar**: el patrón es guardar el código, limpiar y
  salir con **ese** código, no con el de la limpieza.
- **`[[ -v nombre ]]`** distingue "no existe" de "existe y está vacía"; `-z`
  no.
- **`kill -l 143`** traduce un código de salida a su señal (`TERM`):
  `kill -l` acepta tanto el número de señal como `128+N`.

## 📚 Recursos Adicionales

- `man bash`, sección *EXIT STATUS*
- [Advanced Bash-Scripting Guide: códigos de salida reservados](https://tldp.org/LDP/abs/html/exitcodes.html)

## ✅ Checklist de Verificación

- [ ] `false; echo $?; echo $?` imprime `1` y luego `0`
- [ ] Reproduces los códigos `126`, `127`, `143` y `44` de la tabla
- [ ] `die "msg" 7` imprime a `stderr` y sale con `7`
- [ ] `cd -- /no/existe || { ...; exit 5; }` imprime tu mensaje y sale con `5`
- [ ] `false | true | false` deja `1 0 1` en `PIPESTATUS`
- [ ] `ls -- /tmp/-n` encuentra un archivo cuyo nombre empieza por `-`

---

[← Modo estricto: `set -euo pipefail`](01-modo-estricto-set-euo-pipefail.md) · [`trap`: señales y limpieza →](03-trap-senales-y-limpieza.md)
