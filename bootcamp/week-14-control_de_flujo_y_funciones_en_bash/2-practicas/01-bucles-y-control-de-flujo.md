# Práctica 01 — Bucles y control de flujo

> Duración estimada: 45 min · Teoría de apoyo: [archivo 01](../1-teoria/01-bucles-for-while-until.md)

Trabajas **dentro de `ubuntu-lab`**. Abre una shell y crea el directorio de la semana:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p14 && mkdir -p ~/p14/b && cd ~/p14/b
```

## Paso 1: `for` sobre una lista con elementos con espacios

**Por qué**: un `for` recorre **palabras**. Entender que `"b c"` entrecomillado
es **un** elemento (y sin comillas son dos) es la base de todo lo demás: es
la misma regla de quoting de la Semana 13.

**Comando**:

```bash
for x in a "b c" d; do echo "<$x>"; done
# <a>
# <b c>
# <d>
for x in a b c d; do echo -n "$x "; done; echo
# a b c d
for z in 1 2 3; do :; done; echo "z=$z"
# z=3
set -- x y; for a; do echo "<$a>"; done
# <x>
# <y>
```

La variable del bucle **sobrevive** (`z=3`), y `for a` sin `in` recorre los
argumentos (`"$@"`).

**Verifica**:

```bash
n=0; for x in a "b c" d; do n=$(( n + 1 )); done; echo "$n"
# 3
```

## Paso 2: Rangos con llaves, `for (( ))` y `seq`

**Por qué**: contar es lo más habitual, y la trampa es siempre la misma:
las llaves se expanden **antes** que las variables, así que `{1..$n}` no
funciona. Hay que saber qué forma usar según de dónde venga el límite.

**Comando**:

```bash
for i in {1..3}; do echo -n "$i "; done; echo
# 1 2 3
for i in {01..03}; do echo -n "$i "; done; echo
# 01 02 03
for i in {10..1..3}; do echo -n "$i "; done; echo
# 10 7 4 1
n=3
for i in {1..$n}; do echo -n "[$i]"; done; echo
# [{1..3}]
for ((i=1; i<=n; i++)); do echo -n "$i "; done; echo
# 1 2 3
for i in $(seq 1 "$n"); do echo -n "$i "; done; echo
# 1 2 3
```

La cuarta línea es la trampa: imprimió `{1..3}` **literal**. Las dos
siguientes son las salidas correctas con un límite en variable.

**Verifica**:

```bash
n=4; t=0; for ((i=1; i<=n; i++)); do t=$(( t + i )); done; echo "$t"
# 10
```

## Paso 3: El comodín que no coincide con nada

**Por qué**: `for f in *.zip` sin ningún zip no deja el bucle vacío: ejecuta
el cuerpo **una vez con el texto `*.zip`**. Un script que luego haga
`rm "$f"` o `gzip "$f"` falla (o peor). Hay dos defensas y las ves aquí.

**Comando**:

```bash
touch "a b.txt" c.txt
for f in *.zip; do echo "<$f>"; done
# <*.zip>
for f in *.zip; do [[ -e $f ]] || continue; echo "<$f>"; done; echo fin-1
# fin-1
shopt -s nullglob
for f in *.zip; do echo "<$f>"; done; echo fin-2
# fin-2
shopt -u nullglob
for f in *.txt; do echo "<$f>"; done
# <a b.txt>
# <c.txt>
```

El último bucle muestra que un archivo con **espacio** no se parte: el
resultado de un glob no se vuelve a dividir.

**Verifica**:

```bash
shopt -s nullglob; zips=(*.zip); shopt -u nullglob; echo "${#zips[@]}"
# 0
```

## Paso 4: `while`, `until`, `break` y `continue`

**Por qué**: `while` y `until` repiten según un **comando**, no una lista, y
`break`/`continue` controlan la salida. Con ellos se escriben reintentos
y esperas, que es lo que necesitará la Semana 16.

**Comando**:

```bash
i=0; while [[ $i -lt 3 ]]; do echo -n "w$i "; i=$(( i + 1 )); done; echo
# w0 w1 w2
i=0; until [[ $i -ge 3 ]]; do echo -n "u$i "; i=$(( i + 1 )); done; echo
# u0 u1 u2
for i in 1 2 3 4 5; do
  [[ $i -eq 2 ]] && continue
  [[ $i -eq 4 ]] && break
  echo -n "$i "
done; echo
# 1 3
for i in 1 2; do for j in a b c; do [[ $j == b ]] && break 2; echo "$i$j"; done; done
# 1a
```

`continue` salta un elemento; `break` sale; `break 2` sale de **los dos**
bucles anidados.

Y un reintento con tope (el patrón real: esperar a algo **sin colgarse**):

```bash
intentos=0
until [[ -f listo.txt ]]; do
  intentos=$(( intentos + 1 ))
  if [[ $intentos -ge 3 ]]; then echo "se rindio tras $intentos intentos"; break; fi
  echo "esperando ($intentos)"
  [[ $intentos -eq 2 ]] && touch listo.txt
done
# esperando (1)
# esperando (2)
```

(En el intento 2 el archivo aparece y el `until` termina.) En un script
real, entre intentos va un `sleep 1`.

**Verifica**:

```bash
test -f listo.txt && echo ENCONTRADO
# ENCONTRADO
rm listo.txt
```

## Paso 5: Leer un archivo línea a línea y recorrer nombres con espacios

**Por qué**: `for l in $(cat archivo)` parte por palabras; el bucle correcto
es `while IFS= read -r`. Y para listas de archivos con nombres cualesquiera,
`find -print0` con `read -d ''`. Son los dos patrones que más se copian mal.

**Comando**:

```bash
printf 'a b\n  c\n' > l.txt
for l in $(cat l.txt); do echo "<$l>"; done
# <a>
# <b>
# <c>
while IFS= read -r linea; do echo "<$linea>"; done < l.txt
# <a b>
# <  c>
find . -name '*.txt' -print0 | while IFS= read -r -d '' f; do echo "<$f>"; done | sort
# <./a b.txt>
# <./c.txt>
# <./l.txt>
```

Las dos líneas del archivo se convirtieron en tres **palabras** con el `for`;
con `while read`, siguen siendo dos líneas **intactas** (incluidos los dos espacios).

**Verifica**:

```bash
n=0; while IFS= read -r linea; do n=$(( n + 1 )); done < l.txt; echo "$n lineas"
# 2 lineas
```

## Paso 6: La tubería y el contador que no cuenta

**Por qué**: cada comando de una tubería corre en un **subshell**: si el
`while` está detrás de un `|`, el contador que cambia **desaparece** al
terminar. Es el error de "mi contador siempre da 0". Se arregla con
`< <(comando)`.

**Comando**:

```bash
unset n
printf 'a\nb\nc\n' | while read -r l; do n=$(( ${n:-0} + 1 )); done; echo "n=${n:-0}"
# n=0
while read -r l; do n=$(( ${n:-0} + 1 )); done < <(printf 'a\nb\nc\n'); echo "n=$n"
# n=3
```

**Verifica**:

```bash
unset n; while read -r l; do n=$(( ${n:-0} + 1 )); done < <(ls /etc | head -5); echo "$n"
# 5
```

## Paso 7: `for f in $(ls)`: el antipatrón que rompe con un espacio

**Por qué**: es lo que verás en tutoriales antiguos. Lo provocas una vez, aquí,
para reconocerlo y no copiarlo nunca.

**Comando**:

```bash
for f in $(ls); do echo "<$f>"; done
# <a>
# <b.txt>
# <c.txt>
# <l.txt>
for f in *; do echo "<$f>"; done
# <a b.txt>
# <c.txt>
# <l.txt>
```

El `$(ls)` partió `a b.txt` en `a` y `b.txt`, dos archivos que **no existen**;
`for f in *` conservó el nombre.

**Verifica**:

```bash
shellcheck -f gcc <(printf '#!/usr/bin/env bash\nfor f in $(ls); do echo "$f"; done\n') | grep -o 'SC[0-9]*'
# SC2045
```

(`shellcheck` lo avisa antes de ejecutar nada; si no lo tienes instalado:
`apt-get update && apt-get install -y shellcheck`.)

## ✅ Resultado

- [ ] Demuestras que `"b c"` es un elemento y que `{1..$n}` no funciona
- [ ] Sabes qué forma de rango usar con un límite en variable
- [ ] Provocaste el comodín sin coincidencias y lo arreglaste de dos formas
- [ ] `break 2` sale de dos bucles; `until` con tope de intentos no se cuelga
- [ ] `while IFS= read -r` conserva los espacios y `for l in $(cat ...)` no
- [ ] Reproduces `n=0` frente a `n=3` con `|` y con `< <( )`
- [ ] Explicas por qué `for f in $(ls)` parte `a b.txt`

```bash
./scripts/verificar-semana.sh 14
```

(Esta práctica no tiene entregable propio: construye las piezas del bucle del
`healthcheck`.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `{1..3}` se imprime tal cual | Usaste variable en el límite (`{1..$n}`) o comillas | `for ((i=1; i<=n; i++))` |
| El bucle de `*.zip` imprime `<*.zip>` | No hay coincidencias y bash deja el patrón | `nullglob` o `[[ -e $f ]] \|\| continue` |
| `n=0` aunque el bucle itera | El `while` va detrás de una tubería | `done < <(comando)` |
| `until` no termina | La condición nunca se cumple y no hay tope | `intentos` y `break` |
| `read` pierde espacios | Falta `IFS=` o `-r` | `while IFS= read -r l` |
| `bash: syntax error near unexpected token done` | Falta `;` o salto antes de `done`/`fi` | `; done` |
| `<(...)`: `syntax error near unexpected token '('` | Estás en `sh`, no en bash | `bash` (o `#!/usr/bin/env bash`) |

---

[← Construyendo `healthcheck`](../1-teoria/07-construyendo-healthcheck.md) · [Práctica 02: funciones y ámbito →](02-funciones-y-ambito.md)
