# Funciones: definición y uso

> Una función es un bloque con nombre que se comporta como un comando
> nuevo: recibe argumentos, escribe en `stdout` y sale con un código. Con
> ellas un script deja de ser una lista de órdenes y pasa a tener **piezas
> que se prueban por separado**.

## 🎯 Objetivos

- Definir una función, llamarla con argumentos y leerlos con `$1`, `$#` y `"$@"`
- Distinguir los argumentos de la función de los del script
- Explicar por qué una función se define **antes de ejecutarse**, no antes de aparecer en el texto
- Listar, inspeccionar y borrar funciones (`declare -f`, `type`, `unset -f`)
- Evitar que una función choque con un comando existente

## 1. Qué problema resuelve

El `cmd_snapshot` de la Semana 13 tenía unas sesenta líneas en un solo
bloque: opciones, datos, informe y salida mezclados. Para cambiar cómo se
calcula la memoria había que leerlo entero. Con funciones, `sys_mem_mib`
hace **una cosa**, se prueba sola (`sys_mem_mib` en la terminal) y la
reutilizan `snapshot` y `healthcheck`. Es lo mismo que la Semana 13 pedía
de los scripts: que se puedan leer de un vistazo.

## 2. Cómo funciona

### 2.1 Definir y llamar

```bash
saludar() { echo "hola $1 ($#)"; }
saludar ana
# hola ana (1)
saludar "a b" c
# hola a b (2)
function otra { echo otra; }
otra
# otra
```

Dos sintaxis: `nombre() { ...; }` (la POSIX, **la que usamos**) y `function
nombre { ...; }` (solo bash). Se llama **como un comando**: sin paréntesis
y con los argumentos separados por espacios. No existe `saludar("ana")`.
Los espacios importan: `{` lleva espacio detrás y el último comando necesita
`;` o salto de línea antes de `}`.

### 2.2 Argumentos: `$1`, `$#`, `"$@"`

Dentro de la función, `$1`, `$2`, `$#`, `"$@"` y `shift` **hablan de los
argumentos de la función**, no de los del script:

```bash
cat > fa.sh <<'EOS'
#!/usr/bin/env bash
f() { echo "func: $1 $#"; }
echo "script: $1 $#"
f x
f "$@"
EOS
bash fa.sh uno dos
# script: uno 2
# func: x 1
# func: uno 2
```

Si la función necesita un argumento del script, **se lo pasas**: `f "$@"`
o `f "$1"`. Dentro de la función, `$0` sigue siendo el nombre del script;
para el de la función, `${FUNCNAME[0]}`:

```bash
f() { echo "${FUNCNAME[0]} desde ${FUNCNAME[1]:-main}"; }
g() { f; }
g
# f desde g
f
# f desde main
```

Una buena práctica: **dar nombre a los argumentos** en la primera línea:

```bash
f() { local a=$1; shift; echo "$a|$*"; }
f 1 2 3
# 1|2 3
f() { local n="${1:-mundo}"; echo "hola $n"; }
f
# hola mundo
f x
# hola x
```

### 2.3 Se define al ejecutar, no al leer

Bash crea la función cuando **ejecuta** su definición. Por eso una función
puede llamar a otra definida **más abajo**, siempre que ambas existan **cuando
se llama**:

```bash
bash -c 'main() { helper; }; helper() { echo ayuda; }; main'
# ayuda
bash -c 'main2() { helper2; }; main2; helper2() { echo tarde; }'
# environment: line 1: helper2: command not found
```

En el primero, `main` se llama después de definir las dos; en el segundo,
antes de definir `helper2`. Esta es la razón de la estructura de
`toolkit.sh`: **todas las funciones primero, `main` al final**.

### 2.4 Inspeccionar funciones

```bash
saludar() { echo "hola $1"; }
declare -f saludar
# saludar ()
# {
#     echo "hola $1"
# }
type saludar | head -1
# saludar is a function
declare -F | grep -c saludar
# 1
unset -f saludar
saludar
# bash: saludar: command not found
```

| Orden | Qué hace |
|---|---|
| `declare -f nombre` | Imprime el **código** de la función |
| `declare -F` | Lista **solo los nombres** (`-F` mayúscula) |
| `type nombre` / `type -t nombre` | Dice qué es: `function`, `builtin`, `file`... |
| `unset -f nombre` | La borra |
| `export -f nombre` | La pasa a los procesos hijo (`bash -c nombre` la ve) |

```bash
type -t saludar; type -t ls; type -t cd; type -t nada || echo "(vacio, codigo $?)"
# function
# file
# builtin
# (vacio, codigo 1)
```

`type -t` es la forma de **preguntar** si algo es una función: imprime
una palabra y sale con `1` si no existe. `declare -F nombre` hace lo mismo
(sale con `0`/`1`) y se usa en el archivo 06 para llamar a funciones **por
nombre**.

### 2.5 La función "gana" al comando

Un nombre de función tiene prioridad sobre un programa externo:

```bash
bash -c 'ls() { echo falso-ls; }; ls; command ls / | head -1'
# falso-ls
# bin
```

`command nombre` se salta las funciones y alias. Es una trampa cuando
llamas a una función como un comando ya existente (`test`, `ls`, `read`),
y una herramienta cuando **quieres** envolver un comando: `ls() { command
ls --color "$@"; }`. Para evitar choques, **prefija tus funciones**: el
toolkit usa `cmd_`, `sys_`, `hc_`, `snapshot_`.

### 2.6 Una función en una tubería o con redirecciones

```bash
cuenta() { wc -l; }
printf 'a\nb\n' | cuenta
# 2
salida() { echo uno; echo dos >&2; }
salida 2>/dev/null
# uno
```

La función lee de `stdin` y escribe en `stdout`/`stderr` como cualquier
comando, así que se encadena con `|` y se redirige con `>` y `2>`. Detrás
de una tubería corre en un **subshell** (Semana 13).

## 3. Cómo se usa

Tres convenciones que sigue todo el toolkit:

1. **Nombre con prefijo** y en `snake_case`: `sys_disk_usage`, `hc_check_mem`.
2. **Una función, un trabajo**: o calcula un dato (`sys_*`, imprime en
   `stdout`), o comprueba algo (`hc_check_*`, imprime una línea y devuelve
   `0`/`1`), o decide (`cmd_*`). Si el nombre necesita una "y", son dos funciones.
3. **Comentario de una línea encima** con qué hace y qué devuelve, cuando
   no es evidente:

```bash
# Imprime el uso de / en porcentaje, sin el signo %.
sys_disk_usage() {
  df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
}
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `saludar("ana")` | No es una llamada: bash intenta un subshell | `saludar ana` |
| Usar `$1` del script dentro de la función esperando que siga ahí | Dentro de la función `$1` es **el de la función** | Pasar el dato como argumento |
| Llamar a una función antes de definirla | `command not found` | Todas las funciones primero, `main` al final |
| Llamar a una función `test`, `ls` o `read` | Tapas el comando original sin querer | Prefijo propio (`hc_`, `sys_`) |
| Una función de 80 líneas | Es el script mismo, solo con otro nombre | Partir por responsabilidad |
| Dejar `{` pegado al nombre o `}` sin `;` | Error de sintaxis difícil de leer | `nombre() { cmd; }` con los espacios |
| Funciones con el mismo nombre en dos scripts que se cargan con `source` | La segunda pisa a la primera en silencio | Prefijos por módulo |

## 5. Trucos

- **`command -v nombre`** funciona también con funciones, y es la forma
  portable de comprobar "¿existe este comando o función?".
- **`${FUNCNAME[@]}`** es la **pila de llamadas**: un `echo
  "${FUNCNAME[*]}"` dentro de una función depura "¿quién me llamó?".
- **`return` sin número** devuelve el código del **último comando**:
  `false; k() { return; }; k` sale con `1`.

## 📚 Recursos Adicionales

- `man bash`, sección *FUNCTIONS*
- `help function` y `help return`

## ✅ Checklist de Verificación

- [ ] `saludar "a b" c` imprime `hola a b (2)`
- [ ] `bash fa.sh uno dos` muestra que `$1` de la función y del script son distintos
- [ ] Reproduces el `helper2: command not found` y explicas por qué
- [ ] `declare -f saludar` imprime el código y `unset -f saludar` la borra
- [ ] `type -t ls`, `type -t cd` y `type -t saludar` dan `file`, `builtin` y `function`

---

[← Bucles: for, while y until](01-bucles-for-while-until.md) · [Ámbito y valores de retorno →](03-ambito-y-valores-de-retorno.md)
