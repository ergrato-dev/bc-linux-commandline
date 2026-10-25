# Práctica 02 — Funciones, ámbito y valores de retorno

> Duración estimada: 45 min · Teoría de apoyo: archivos [02](../1-teoria/02-funciones-definicion-y-uso.md) y [03](../1-teoria/03-ambito-y-valores-de-retorno.md)

Trabajas **dentro de `ubuntu-lab`**:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p14/f && mkdir -p ~/p14/f && cd ~/p14/f
```

## Paso 1: Definir una función y llamarla con argumentos

**Por qué**: una función se llama **como un comando** (sin paréntesis) y lee
sus argumentos con `$1`, `$#`... Es la base de todo el resto: si entiendes
esto, `sys_mem_mib` y `hc_check_disk` son una función más.

**Comando**:

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

**Verifica**:

```bash
type -t saludar
# function
declare -f saludar
# saludar ()
# {
#     echo "hola $1 ($#)"
# }
```

## Paso 2: Los argumentos de la función no son los del script

**Por qué**: dentro de una función, `$1` es **su** primer argumento. Quien
espera que siga siendo el del script se lleva una sorpresa. Se pasa el dato
explícitamente.

**Comando**:

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

Y los argumentos con nombre y valor por defecto:

```bash
f() { local a=$1; shift; echo "$a|$*"; }
f 1 2 3
# 1|2 3
g() { local n="${1:-mundo}"; echo "hola $n"; }
g
# hola mundo
g x
# hola x
```

**Verifica**:

```bash
bash fa.sh uno dos | grep -c '^func'
# 2
g ana
# hola ana
```

## Paso 3: Una función existe cuando se **ejecuta** su definición

**Por qué**: por eso `toolkit.sh` pone **todas** las funciones antes de
`main`. Provocas el error a propósito para verlo.

**Comando**:

```bash
bash -c 'main() { helper; }; helper() { echo ayuda; }; main'
# ayuda
bash -c 'main2() { helper2; }; main2; helper2() { echo tarde; }'
# environment: line 1: helper2: command not found
```

En la primera, `main` se **llama** después de definir las dos. En la
segunda, `main2` se llama antes de que `helper2` exista.

**Verifica**:

```bash
bash -c 'a() { b; }; b() { echo b-ok; }; a'
# b-ok
```

## Paso 4: `return` y el código de una función

**Por qué**: una función no devuelve un valor, **sale con un código**: lo que
usan `if`, `&&` y `||`. Y el código es el del **último comando** si no hay
`return`: más trampas de las que parece.

**Comando**:

```bash
f() { return 3; }; f; echo "$?"
# 3
g() { return 300; }; g; echo "$?"
# 44
k() { return; }; false; k; echo "$?"
# 1
is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }
is_uint 12 && echo si
# si
is_uint a1 || echo no
# no
is_uint "" || echo no-vacio
# no-vacio
bash -c 'return 1'
# bash: line 1: return: can only `return' from a function or sourced script
```

`is_uint` no tiene `return`: devuelve el código del `[[ ]]`, que es justo lo que
queremos. `is_uint` es la función que usa el toolkit para validar números.

**Verifica**:

```bash
if is_uint 90; then echo valido; fi
# valido
if ! is_uint 9x; then echo rechazado; fi
# rechazado
```

## Paso 5: Variables globales y `local`

**Por qué**: sin `local`, una variable asignada en una función **es global**
y pisa a las demás. Con `local`, muere con la función. Es lo que hay que
hacer **siempre**.

**Comando**:

```bash
cnt=0; inc() { cnt=$(( cnt + 1 )); }; inc; inc; echo "$cnt"
# 2
f() { y=creada; }; f; echo "y=$y"
# y=creada
v=global; f() { local v=local; echo "dentro $v"; }; f; echo "fuera $v"
# dentro local
# fuera global
f() { local z=1; }; f; echo "z=${z:-vacia}"
# z=vacia
```

**Verifica**:

```bash
unset y z; f() { y=1; local z=2; }; f; echo "y=${y:-vacia} z=${z:-vacia}"
# y=1 z=vacia
```

## Paso 6: El ámbito dinámico

**Por qué**: en bash, una función ve las variables `local` de **quien la
llamó**. Es contraintuitivo y explica "funciona en mi script pero no en el
tuyo". Se resuelve pasando los datos como argumentos.

**Comando**:

```bash
v=global
show() { echo "show ve $v"; }
f() { local v=local; show; }
f
# show ve local
show
# show ve global
```

La misma función `show` da dos resultados según **quién la llama**. Ahora,
sin depender del ámbito:

```bash
show() { echo "show recibe $1"; }
f() { local v=local; show "$v"; }
f
# show recibe local
show global
# show recibe global
```

**Verifica**:

```bash
f
# show recibe local
```

## Paso 7: Devolver un dato por `stdout` (y el subshell que se come los cambios)

**Por qué**: para sacar un **valor** de una función se escribe en `stdout` y
se captura con `$( )`. Es lo que hacen todas las `sys_*` del toolkit. El
precio: `$( )` es un subshell, y nada de lo que la función cambie sale.

**Comando**:

```bash
suma() { echo $(( $1 + $2 )); }
t=$(suma 2 3); echo "$t"
# 5
cnt=0; inc() { cnt=$(( cnt + 1 )); }
r=$(inc); echo "cnt=$cnt r=[$r]"
# cnt=0 r=[]
inc | cat; echo "cnt=$cnt"
# cnt=0
inc; echo "cnt=$cnt"
# cnt=1
```

Las dos primeras llamadas a `inc` corrieron en subshell y **no** cambiaron
`cnt`; la tercera, directa, sí.

Y los mensajes de depuración: a `stderr`, no a `stdout`, o se mezclan con el valor:

```bash
mal()  { echo "calculando..."; echo 42; }
bien() { echo "calculando..." >&2; echo 42; }
x=$(mal);  echo "x=[$x]"
# x=[calculando...
# 42]
x=$(bien); echo "x=[$x]"
# calculando...
# x=[42]
```

**Verifica**:

```bash
x=$(bien 2>/dev/null); echo "$x"
# 42
```

## Paso 8: `set -e` dentro de una función

**Por qué**: `set -e` **se apaga** dentro de una función llamada desde un
`if`, `||` o `&&`. Quien cuenta con él para parar a mitad de la función se
encuentra con que sigue ejecutando. Por eso las `hc_check_*` devuelven `1`
**explícitamente**.

**Comando**:

```bash
bash -c 'set -e; f() { false; echo seguia; }; f; echo fin'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; f() { false; echo seguia; }; if f; then echo si; fi'
# seguia
# si
bash -c 'set -e; f() { false; }; f || echo manejado; echo fin'
# manejado
# fin
bash -c 'set -e; f() { [[ 1 -eq 2 ]] && echo x; }; f; echo seguia'; echo "codigo: $?"
# codigo: 1
```

Las líneas 1 y 2 muestran la misma función con **dos** comportamientos. La
cuarta: el `&&` falso es el último comando, la función sale con `1` y
`set -e` aborta **al llamarla**.

**Verifica** (con un `return 0` explícito, la misma función ya no aborta):

```bash
bash -c 'set -e; f() { [[ 1 -eq 2 ]] && echo x; return 0; }; f; echo ok'
# ok
```

## Paso 9: Inspeccionar, borrar y no tapar comandos

**Por qué**: una función puede tapar un comando (`ls`, `test`) sin que te
des cuenta. Saber qué es cada nombre (`type`) y cómo saltarse la función
(`command`) evita depurar a ciegas.

**Comando**:

```bash
type -t saludar; type -t ls; type -t cd; type -t nada || echo "(vacio, codigo $?)"
# function
# file
# builtin
# (vacio, codigo 1)
bash -c 'ls() { echo falso-ls; }; ls; command ls / | head -1'
# falso-ls
# bin
unset -f saludar
saludar
# bash: saludar: command not found
```

**Verifica**:

```bash
f() { echo "${FUNCNAME[0]} desde ${FUNCNAME[1]:-main}"; }; g() { f; }
g
# f desde g
f
# f desde main
```

## ✅ Resultado

- [ ] Llamas a una función con argumentos y explicas por qué `$1` de la función no es el del script
- [ ] Reproduces el `helper2: command not found` y explicas por qué
- [ ] Sabes qué devuelve una función sin `return`
- [ ] Demuestras que sin `local` la variable sale de la función
- [ ] Reproduces `show ve local` y lo arreglas pasando el dato como argumento
- [ ] Capturas un dato con `$( )` y demuestras que `r=$(inc)` no cambia `cnt`
- [ ] Explicas por qué `set -e` no para dentro de `if f; then`

```bash
./scripts/verificar-semana.sh 14
```

(Esta práctica no tiene entregable propio: son las piezas de las funciones
del toolkit.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `syntax error near unexpected token '}'` | Falta `;` o salto antes de `}` | `f() { cmd; }` |
| `f: command not found` | Llamas a la función antes de definirla (o en otra shell) | Defínela antes; `declare -f f` para comprobar |
| La variable "no se queda" tras `r=$(f)` | `$( )` es un subshell | Devolver por `stdout`, o llamar a `f` sin `$( )` |
| El valor capturado trae texto de más | La función imprime mensajes a `stdout` | `echo ... >&2` |
| `local: can only be used in a function` | `local` fuera de una función | Quita `local` o ponlo dentro |
| `return: can only 'return' from a function` | `return` en el cuerpo del script | `exit` |
| `f` ve una variable que "no debería" | Ámbito dinámico: la define quien la llamó | Pasar el dato como argumento |

---

[← Práctica 01: bucles y control de flujo](01-bucles-y-control-de-flujo.md) · [Práctica 03: arrays y refactor de `snapshot` →](03-arrays-y-refactor-de-snapshot.md)
