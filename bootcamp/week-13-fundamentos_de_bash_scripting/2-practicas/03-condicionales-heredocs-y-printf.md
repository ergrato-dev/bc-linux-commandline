# Práctica 03 — Condicionales, here-docs y `printf`

> Duración estimada: 45 min · Teoría de apoyo: archivos [05](../1-teoria/05-condicionales-test-y-doble-corchete.md) y [06](../1-teoria/06-sustitucion-de-comandos-heredocs-y-printf.md)

Trabajas **dentro de `ubuntu-lab`**:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p13/c && mkdir -p ~/p13/c && cd ~/p13/c
```

## Paso 1: `if` ejecuta un comando y mira su código

**Por qué**: en bash `if` no evalúa una expresión: **ejecuta un comando** y
actúa según salga con `0` o no. Cuando lo ves así, `grep -q`, `command -v` y
`[[ ]]` son el mismo tipo de cosa.

**Comando**:

```bash
if grep -q root /etc/passwd; then echo hay-root; fi
# hay-root
if ! command -v nope >/dev/null; then echo no-nope; fi
# no-nope
if grep -q zzz /etc/passwd; then echo si; else echo no; fi
# no
grep -q root /etc/passwd; echo "codigo: $?"
# codigo: 0
```

**Verifica**:

```bash
command -v ls >/dev/null && echo ls-existe
# ls-existe
command -v cd
# cd
type -a cd | head -1
# cd is a shell builtin
```

## Paso 2: `[ ]` frente a `[[ ]]` con una variable vacía

**Por qué**: `[ ]` es un **comando**: bash expande `$x` antes y, si está
vacío, desaparece y `[` recibe argumentos de menos. `[[ ]]` es sintaxis de
bash y no tiene ese problema. Es la razón por la que usarás `[[ ]]`.

**Comando**:

```bash
x=""
[ $x = a ]; echo "codigo: $?"
# bash: [: =: unary operator expected
# codigo: 2
[[ $x = a ]]; echo "codigo: $?"
# codigo: 1
[ "$x" = a ]; echo "codigo: $?"
# codigo: 1
```

**Verifica**:

```bash
x="a b"
[ $x = a ] 2>&1; echo "codigo: $?"
# bash: [: too many arguments
# codigo: 2
[[ $x = "a b" ]]; echo "codigo: $?"
# codigo: 0
```

## Paso 3: Pruebas de archivo

**Por qué**: casi todo script empieza comprobando que un archivo existe, es
legible o no está vacío. Cada prueba responde una pregunta distinta, y usar
`-e` donde querías `-f` deja pasar directorios.

**Comando**:

```bash
touch f; mkdir -p d
[[ -f f ]] && echo f-archivo
# f-archivo
[[ -d d ]] && echo d-dir
# d-dir
[[ -f d ]] || echo "d no es un archivo"
# d no es un archivo
[[ -e nada ]] || echo no-existe
# no-existe
[[ -s f ]] || echo vacio
# vacio
[[ -x f ]] || echo no-exec
# no-exec
[[ -r f && -w f ]] && echo rw
# rw
```

**Verifica**:

```bash
echo hola > f
[[ -s f ]] && echo con-contenido
# con-contenido
```

## Paso 4: Texto frente a número

**Por qué**: es la trampa más cara del capítulo. `<` y `>` comparan **texto**
(orden alfabético): `10 < 9` es verdadero. Si comparas un uso de disco de
`9` con un umbral de `90` con `>`, tu alerta falla sin avisar.

**Comando**:

```bash
[[ 10 -lt 9 ]] && echo num-si || echo num-no
# num-no
[[ 10 < 9 ]]   && echo str-si || echo str-no
# str-si
[[ "2" == "02" ]] && echo igual-str || echo distinto-str
# distinto-str
[[ 2 -eq 02 ]] && echo igual-num
# igual-num
```

Y la validación de un dato externo, **con la regex primero**:

```bash
umbral=abc
if ! [[ "$umbral" =~ ^[0-9]+$ && "$umbral" -le 100 ]]; then echo "invalido: '$umbral'"; fi
# invalido: 'abc'
umbral=101
if ! [[ "$umbral" =~ ^[0-9]+$ && "$umbral" -le 100 ]]; then echo "invalido: '$umbral'"; fi
# invalido: '101'
umbral=90
if ! [[ "$umbral" =~ ^[0-9]+$ && "$umbral" -le 100 ]]; then echo "invalido: '$umbral'"; else echo "valido: '$umbral'"; fi
# valido: '90'
```

**Verifica**:

```bash
[[ 9 -ge 80 ]] && echo si || echo no
# no
[[ 9 > 80 ]] && echo si || echo no
# si
```

La segunda es **incorrecta** y es la que no debes escribir: como texto,
`"9"` va **después** de `"80"` (se compara el primer carácter: `9` > `8`),
así que un disco al `9 %` dispararía una alerta de umbral `80`. Números,
`-ge`.

## Paso 5: Patrones, regex y `case`

**Por qué**: `[[ ]]` también compara contra patrones (`==`) y expresiones
regulares (`=~`), y `case` es la forma legible de decidir entre varios
patrones. Los usarás en cada validación y en cada procesador de opciones.

**Comando**:

```bash
[[ abc == a* ]] && echo glob-ok
# glob-ok
if [[ "v1.22.3" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[0]}"
fi
# 1 22 v1.22.3
for x in a.txt b.log c; do
  case "$x" in
    *.txt)       echo "$x txt" ;;
    *.log|*.out) echo "$x log" ;;
    *)           echo "$x otro" ;;
  esac
done
# a.txt txt
# b.log log
# c otro
s=abc
[[ $s =~ "^a" ]] && echo lit-si || echo lit-no
# lit-no
re='^a'
[[ $s =~ $re ]] && echo re-si
# re-si
```

La regex entre comillas se tomó **literal** (`lit-no`); en una variable y sin
comillas, es regex (`re-si`).

**Verifica**:

```bash
for x in uno.out dos.txt; do case "$x" in *.txt) echo txt;; *.log|*.out) echo log;; esac; done
# log
# txt
```

## Paso 6: `A && B || C` no es un `if`

**Por qué**: `A && B || C` parece un `if/else` y no lo es: si `A` se cumple
pero `B` **falla**, también se ejecuta `C`. Es un clásico que pasa
inadvertido en revisiones.

**Comando**:

```bash
true && echo A || echo B
# A
false && echo A || echo B
# B
true && false || echo "C-trampa"
# C-trampa
```

La tercera línea hizo lo que **no** esperabas de un `if`: `A` fue verdadero,
`B` falló, y se ejecutó `C`.

**Verifica**:

```bash
if true; then false; else echo C; fi; echo "codigo: $?"
# codigo: 1
```

Con un `if` de verdad, `C` no se ejecuta cuando falla `B`.

## Paso 7: `$( )` y el código de salida enmascarado

**Por qué**: capturar la salida de un comando es la base de todo informe, y
tiene dos peculiaridades: se comen los saltos de línea finales y
`local v=$(cmd)` **oculta** el fallo de `cmd`. ShellCheck lo marca como
`SC2155`: ahora sabes qué ocurre debajo.

**Comando**:

```bash
fecha=$(date +%F); echo "hoy: $fecha"
# hoy: 2026-10-25
n=$(printf "a\nb\n\n\n"); echo "[$n]"
# [a
# b]
echo "$(echo "$(echo anidado)")"
# anidado
x=$(false); echo "$?"
# 1
f() { local v=$(false); echo "codigo: $?"; }; f
# codigo: 0
g() { local v; v=$(false); echo "codigo: $?"; }; g
# codigo: 1
false | true; echo "$?"
# 0
set -o pipefail; false | true; echo "$?"; set +o pipefail
# 1
```

(Tu fecha será la de hoy.)

**Verifica**:

```bash
printf 'uno\ndos\n' > l.txt
x=$(< l.txt); echo "[$x]"
# [uno
# dos]
```

## Paso 8: Here-docs y `printf`

**Por qué**: el informe de `snapshot` es un here-doc con variables dentro.
Aquí ves sus tres formas y `printf`, que es lo que imprime ese informe sin
sorpresas de `echo`.

**Comando**:

```bash
v=hola
cat <<EOF
sin comillas: $v $(echo cmd)
EOF
# sin comillas: hola cmd
cat <<"EOF"
con comillas: $v $(echo cmd)
EOF
# con comillas: $v $(echo cmd)
cat <<-EOT
	con tab quitado
	  espacios siguen
	EOT
# con tab quitado
#   espacios siguen
cat <<< "here-string $HOME"
# here-string /root
```

(En el tercero, las líneas y el `EOT` de cierre **empiezan por un tabulador**:
tecléalo con la tecla Tab; con espacios `<<-` no los quita.)

`printf`:

```bash
printf "%5s|%-5s|%05d|%.2f|%x\n" ab cd 42 3.14159 255
#    ab|cd   |00042|3.14|ff
printf "%s\n" a b c
# a
# b
# c
printf "%d%%\n" 50
# 50%
printf '%s\n' "$(printf '%(%F)T' -1)"
# 2026-10-25
```

Y la línea **opcional** de un informe:

```bash
alerta=""
cat <<EOF
disco: 25%
${alerta:+$alerta
}estado: ok
EOF
# disco: 25%
# estado: ok
alerta="alerta: disco al 95%"
cat <<EOF
disco: 95%
${alerta:+$alerta
}estado: alerta
EOF
# disco: 95%
# alerta: disco al 95%
# estado: alerta
```

**Verifica**:

```bash
informe=$(cat <<EOF
== prueba ==
fecha: $(date +%F)
suma: $(( 2 + 3 ))
EOF
)
printf '%s\n' "$informe" | grep -c .
# 3
printf '%s\n' "$informe" | grep -q '^suma: 5$' && echo OK
# OK
```

## ✅ Resultado

- [ ] Explicas por qué `[ $x = a ]` falla con `x` vacío y `[[ $x = a ]]` no
- [ ] Predices `[[ 10 < 9 ]]` (verdadero) y `[[ 10 -lt 9 ]]` (falso)
- [ ] Validas un número con regex **antes** de `-le`
- [ ] Reproduces la trampa de `A && B || C`
- [ ] Muestras la diferencia de código entre `local v=$(false)` y `local v; v=$(false)`
- [ ] Un here-doc con `<<EOF` expande y con `<<"EOF"` no; `${alerta:+...}` solo imprime con alerta

```bash
./scripts/verificar-semana.sh 13
```

(Las comprobaciones de `snapshot` se cumplen con la práctica 04.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `[: =: unary operator expected` | Variable vacía sin comillas dentro de `[ ]` | `[[ ]]` o `"$x"` |
| `syntax error: unexpected end of file` con un here-doc | El delimitador de cierre lleva espacios o texto detrás | `EOF` **solo** en su línea, sin sangrar (con `<<-` se sangra con tabuladores) |
| `<<-` no quita la sangría | Usaste espacios, no tabuladores | Tab de verdad (o no sangrar) |
| `[[ $s =~ "^a" ]]` no coincide | Comillas: regex tomada como texto | Regex en variable, sin comillas |
| `printf` imprime `%` raro | Falta `%%` para un `%` literal | `printf '%d%%\n' 50` |
| `$(< l.txt)` vacío | El archivo no existe o está vacío | `ls -l l.txt` |

---

[← Práctica 02: variables, quoting y argumentos](02-variables-quoting-y-argumentos.md) · [Práctica 04: `snapshot` a mano →](04-snapshot-a-mano.md)
