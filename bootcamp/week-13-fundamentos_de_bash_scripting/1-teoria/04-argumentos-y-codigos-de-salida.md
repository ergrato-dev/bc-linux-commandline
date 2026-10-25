# Argumentos y códigos de salida

> Un script que no recibe argumentos ni devuelve un código es un programa que
> solo puede hacer una cosa y no puede decirle a nadie cómo le fue. Esta es la
> interfaz de un script con el mundo: **entra** por `$1 $2 ...` y **sale** por `exit`.

## 🎯 Objetivos

- Leer argumentos con `$0`, `$1`, `$#`, `"$@"` y consumirlos con `shift`
- Escribir un procesador de opciones con `while` + `case` (el que usa `toolkit.sh`)
- Conocer `getopts` y saber cuándo conviene frente al `case`
- Usar `exit` con códigos con significado y leer `$?` sin perderlo
- Validar el uso: mensaje a `stderr` y `exit 1`

## 1. Qué problema resuelve

`toolkit.sh snapshot --umbral 80 --salida informe.txt` es una línea que el
script tiene que **entender**: ¿qué es una opción?, ¿falta un valor?, ¿hay una
opción que no conozco? Y al terminar, quien lo lanzó (otra persona, `cron`,
otro script) necesita saber **sin leer el texto** si salió bien. Los códigos
de salida son esa respuesta.

## 2. Cómo funciona

### 2.1 Los parámetros posicionales

```bash
cat > pos.sh <<'EOS'
#!/usr/bin/env bash
echo "script=$0 primero=$1 segundo=${2:-(vacio)} total=$#"
shift
echo "tras shift: total=$# todos=$*"
echo "desde el 2: ${@:2}"
EOS
chmod +x pos.sh
./pos.sh a "b c" d
# script=./pos.sh primero=a segundo=b c total=3
# tras shift: total=2 todos=b c d
# desde el 2: d
./pos.sh
# script=./pos.sh primero= segundo=(vacio) total=0
# tras shift: total=0 todos=
# desde el 2:
```

| Variable | Contiene |
|---|---|
| `$0` | cómo te llamaron (el script) |
| `$1` ... `$9`, `${10}` | el argumento N (a partir del 10, con llaves) |
| `$#` | cuántos argumentos hay |
| `"$@"` | todos, cada uno como palabra aparte (archivo 03) |
| `${@:2}` | todos desde el segundo |
| `shift` / `shift N` | descarta el primero (o N) y renumera |

`shift` es el verbo que hace funcionar un procesador de opciones: consumes
lo que ya entendiste y miras el siguiente. Con `set -e`, `shift` sin
argumentos que quitar sale con `1` y **aborta** el script:

```bash
bash -c 'set -e; shift; echo sigue'; echo "codigo: $?"
# codigo: 1
```

Por eso se comprueba `$#` **antes** (apartado 2.2).

### 2.2 `while` + `case`: el procesador de opciones

Es el patrón de **todas** las funciones del toolkit y el de `snapshot`:

```bash
cat > opt.sh <<'EOS'
#!/usr/bin/env bash
salida="" verbose=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) verbose=1; shift ;;
    -o|--salida)  salida="${2:?-o necesita un valor}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "opcion desconocida: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
echo "verbose=$verbose salida=[$salida] resto=($*)"
EOS
chmod +x opt.sh
./opt.sh -v -o out.txt f1 f2
# verbose=1 salida=[out.txt] resto=(f1 f2)
./opt.sh --salida
# ./opt.sh: line 6: 2: -o necesita un valor
./opt.sh -x; echo "codigo: $?"
# opcion desconocida: -x
# codigo: 2
./opt.sh -- -v x
# verbose=0 salida=[] resto=(-v x)
```

Cómo se lee:

- `while [[ $# -gt 0 ]]`: mientras queden argumentos.
- Cada rama de `case` **consume** lo que entendió (`shift` o `shift 2`) o
  sale del bucle (`break`).
- `--` es la convención universal para "aquí acaban las opciones": lo que
  sigue, aunque empiece por `-`, es un argumento normal.
- `-*)` captura **cualquier otra opción** y la rechaza. Sin esa rama,
  `./opt.sh -x` no daría error: `-x` sería un archivo.
- `*) break` deja de interpretar en cuanto llega algo que no es opción.

> ⚠️ Fíjate en el mensaje de `--salida` sin valor: `line 6: 2: -o necesita
> un valor`. El `2` es el **nombre de la variable** que falló (`$2` sin
> definir), no un error tuyo: `${2:?msg}` lo muestra así. Para un mensaje
> limpio, `toolkit.sh` comprueba `$#` y lo escribe él:

```bash
if [[ $# -lt 2 ]]; then
  echo "toolkit snapshot: $1 necesita un valor" >&2
  exit 1
fi
```

### 2.3 `getopts`: el procesador integrado

```bash
cat > go.sh <<'EOS'
#!/usr/bin/env bash
verbose=0 salida=""
while getopts ":vo:" opt; do
  case "$opt" in
    v) verbose=1 ;;
    o) salida="$OPTARG" ;;
    :) echo "falta valor para -$OPTARG" >&2; exit 2 ;;
    \?) echo "opcion invalida: -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
echo "verbose=$verbose salida=[$salida] resto=($*)"
EOS
chmod +x go.sh
./go.sh -vo out.txt a b
# verbose=1 salida=[out.txt] resto=(a b)
./go.sh -o; echo "codigo: $?"
# falta valor para -o
# codigo: 2
./go.sh --largo; echo "codigo: $?"
# opcion invalida: --
# codigo: 2
```

La cadena `":vo:"` dice: la `:` inicial = "los errores los gestiono yo", `v` =
opción sin valor, `o:` = opción **con** valor (llega en `$OPTARG`).
`OPTIND` es el índice del primer argumento que ya no es opción, de ahí
`shift $((OPTIND - 1))`.

| | `while` + `case` | `getopts` |
|---|---|---|
| Opciones largas (`--salida`) | **sí** | **no** (solo `-o`) |
| Opciones agrupadas (`-vo`) | no | sí |
| Rama de valor ausente | tú la escribes | la rama `:` |
| Usado en el toolkit | **sí** | no |

Para una herramienta con opciones largas (`--umbral`, `--salida`) usas
`case`. Para scripts con unas pocas opciones cortas, `getopts`.

### 2.4 Los códigos de salida

Todo proceso termina con un entero de 0 a 255. **`0` es éxito, todo lo demás
es un fallo** (al revés que en la mayoría de lenguajes; lo que importa es
"¿hubo error?", y hay muchas formas de tenerlo).

```bash
true;  echo $?     # 0
false; echo $?     # 1
(exit 3); echo $?  # 3
bash -c 'exit 300'; echo $?
# 44
bash -c 'exit -1'; echo $?
# 255
```

Un código se **trunca a 8 bits**: `300` es `300 mod 256 = 44`, y `-1` es
`255`. No uses números grandes.

Las convenciones que ya has visto y las que usa el toolkit:

| Código | Significado | Ejemplo |
|---|---|---|
| `0` | éxito | |
| `1` | error general | `grep` sin coincidencias; en el toolkit, **uso inválido** |
| `2` | mal uso o error grave de un comando / **hallazgo** en el toolkit | `ls /noexiste`, `grep x /noexiste`; `snapshot` con alerta |
| `126` | encontrado pero no ejecutable | script sin `chmod +x` |
| `127` | comando no encontrado | `./noexiste` |
| `128 + N` | muerto por la señal N | `kill -9` da `137`, `kill -TERM` da `143` |

> ⚠️ `2` tiene dos significados: el de `ls`/`grep` ("error de uso o de archivo") y el
> del toolkit ("encontré un problema"). No es contradicción: es la
> convención propia de este proyecto, documentada en la cabecera de
> `toolkit.sh`. En un script **tuyo** decides tú, pero **documéntalo**.

### 2.5 `$?` es frágil

`$?` guarda el código del **último** comando y cualquier comando lo
sobrescribe, hasta el `echo` que lo imprime:

```bash
false; echo "valor: $?"; echo "otra vez: $?"
# valor: 1
# otra vez: 0
false; r=$?; echo "guardado: $r"
# guardado: 1
```

Guárdalo en una variable si lo vas a usar después de otro comando. Y casi
nunca hace falta: `if comando; then` ya mira el código. En lugar de:

```bash
grep -q root /etc/passwd
if [[ $? -eq 0 ]]; then echo hay-root; fi     # ❌ ShellCheck SC2181
```

escribe:

```bash
if grep -q root /etc/passwd; then echo hay-root; fi
# hay-root
```

`!` invierte el código (`! grep -q x f` es "no contiene"): `! true; echo $?`
imprime `1`.

### 2.6 `exit` frente a `return`

`exit N` termina el **script entero**. `return N` sale de una **función**
(archivo de la Semana 14). Por eso `cmd_snapshot` usa `exit 2` y no
`return`: así `main` no puede olvidarse de propagar el código.

## 3. Cómo se usa

Tres reglas para los scripts de este bootcamp:

1. **Los errores de uso van a `stderr` y salen con `1`**: `echo "..." >&2; exit 1`.
2. **Los resultados van a `stdout`**: así `snapshot > informe.txt` no guarda
   los errores dentro del informe.
3. **El éxito es `0` y, si hay un hallazgo que automatizar, `2`**: el que lo
   lance (cron, otro script, tú) decide con `if toolkit.sh snapshot; then`.

```bash
toolkit.sh snapshot --umbral 0; echo "codigo: $?"
# (informe con la línea "alerta: disco / al 25% (umbral 0%)")
# codigo: 2
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Un script que siempre sale `0` | `cron` y las demás herramientas creen que fue bien | `exit` con código; `set -e` |
| Mensajes de error a `stdout` | Acaban dentro de `> informe.txt` | `>&2` |
| `$1` sin comprobar | Con `set -u` aborta con `unbound variable` sin explicación | `[[ $# -ge 1 ]] \|\| { echo "uso: ..." >&2; exit 1; }` |
| Dejar pasar una opción desconocida | `--umbrall 80` (tecleado mal) se ignora y usas el valor por defecto sin saberlo | Rama `-*)` que rechaza |
| `exit` con un código inventado distinto en cada script | Nadie sabe qué significa un `7` | Tabla de códigos en la cabecera del script |
| `if [[ $? -eq 0 ]]` | Frágil y verboso | `if comando; then` |

## 5. Trucos

- `exit` sin argumento sale con el código del **último comando**: útil en un
  `trap` (Semana 15), traicionero en un script largo.
- **`set --`** reasigna los posicionales: `set -- "$@" extra` añade uno al
  final, `set --` los vacía.
- **`${@: -1}`** (con espacio) es el **último** argumento.
- **`$_`** es el último argumento del comando anterior; `mkdir /tmp/nuevo &&
  cd "$_"` entra en el directorio recién creado.
- **`wait $!`** devuelve el código de un proceso en segundo plano: `sleep 1 &
  kill $!; wait $!; echo $?` imprime `143` (terminado por `TERM`).

## 📚 Recursos Adicionales

- `man bash`, secciones *Special Parameters* y *EXIT STATUS*
- `help getopts`, `help shift`, `help exit`: la ayuda integrada de bash

## ✅ Checklist de Verificación

- [ ] `./pos.sh a "b c" d` imprime `total=3` y `segundo=b c`
- [ ] `./opt.sh -x` sale con `2` y escribe el error en `stderr` (`./opt.sh -x 2>/dev/null` no imprime nada)
- [ ] `bash -c 'exit 300'; echo $?` imprime `44`
- [ ] Sabes por qué `false; echo $?; echo $?` imprime `1` y luego `0`
- [ ] `docker exec ubuntu-lab bash -c './noexiste; echo $?'` imprime `127`

---

[← Quoting: comillas y expansiones](03-quoting-comillas-y-expansiones.md) · [Condicionales: test y doble corchete →](05-condicionales-test-y-doble-corchete.md)
