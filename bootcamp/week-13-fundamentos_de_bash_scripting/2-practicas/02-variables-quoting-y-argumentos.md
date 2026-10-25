# Práctica 02 — Variables, quoting y argumentos

> Duración estimada: 45 min · Teoría de apoyo: archivos [02](../1-teoria/02-variables-y-expansion-de-parametros.md), [03](../1-teoria/03-quoting-comillas-y-expansiones.md) y [04](../1-teoria/04-argumentos-y-codigos-de-salida.md)

Trabajas **dentro de `ubuntu-lab`**. Si cerraste la shell de la práctica 01:

```bash
docker exec -it ubuntu-lab bash
mkdir -p ~/p13 && cd ~/p13
```

## Paso 1: Asignar, leer y los tres errores clásicos

**Por qué**: el 80 % de los "mi variable no funciona" son uno de tres
errores: espacios alrededor del `=`, olvidar el `$` al leer, o pegar texto a
un nombre sin llaves. Provocarlos aquí te los hace reconocibles.

**Comando**:

```bash
fruta=pera
echo "$fruta"
# pera
x = 5
# bash: x: command not found
z=a b
# bash: b: command not found
echo "$frutas|${fruta}s"
# |peras
```

`$frutas` es otra variable (vacía): bash toma todos los caracteres de nombre
que ve. Con llaves, `${fruta}s` es lo que querías.

**Verifica**:

```bash
echo "${fruta}s"
# peras
x=5; echo "$x"
# 5
```

## Paso 2: Shell, entorno y "solo para este comando"

**Por qué**: el entorno solo se hereda **hacia abajo**. Entender esto evita
dos errores opuestos: esperar que un script cambie tus variables (no puede) y
no exportar lo que un script hijo sí necesita.

**Comando**:

```bash
v=local
bash -c 'echo "[${v:-vacio}]"'
# [vacio]
export v
bash -c 'echo "[${v:-vacio}]"'
# [local]
w=1 bash -c 'echo "[$w]"'
# [1]
echo "[${w:-vacio}]"
# [vacio]
```

**Verifica**:

```bash
echo "$HOME $UID ${BASH_VERSION%%(*}"
# /root 0 5.2.21
echo "[${USER-<sin definir>}]"
# [<sin definir>]
id -un
# root
```

(`$USER` **no existe** en una shell de `docker exec`: por eso el toolkit
usa `${USER:-$(id -un)}`. Tu versión de bash puede ser otra.)

## Paso 3: Valores por defecto y `${v:?}`

**Por qué**: es la protección más barata contra `rm -rf "$dir/"*` con `$dir`
vacío. Las cuatro formas con `:` cubren "dame un valor por defecto", "exige
este dato" y "imprime esto solo si existe".

**Comando**:

```bash
unset a
echo "[${a:-def}] [${a-def}]"
# [def] [def]
a=""
echo "[${a:-def}] [${a-def}] [${a:+alt}]"
# [def] [] []
unset a; echo "[${a:=asig}] [$a]"
# [asig] [asig]
a=x; echo "[${a:+alt}]"
# [alt]
printf '#!/usr/bin/env bash\necho ${x:?falta x}\necho no\n' > req.sh && chmod +x req.sh
unset x
./req.sh; echo "codigo: $?"
# ./req.sh: line 2: x: falta x
# codigo: 1
```

El segundo `echo` del script (`no`) **no llegó a ejecutarse**.

**Verifica**:

```bash
x=algo ./req.sh
# algo
# no
./req.sh 2>/dev/null; echo "codigo: $?"
# codigo: 1
```

## Paso 4: Recortar y sustituir sin lanzar un programa

**Por qué**: `basename`, `dirname`, `sed` y `cut` lanzan un proceso para algo
que bash resuelve en memoria. Dominar `${v#}`, `${v%}` y `${v//}` te da
scripts más rápidos y con menos dependencias.

**Comando**:

```bash
f=/home/ana/informe.final.tar.gz
echo "${f##*/} | ${f%/*} | ${f%.gz} | ${f%%.*} | ${f#*.} | ${f##*.} | ${#f} | ${f:6:3} | ${f/ana/luis} | ${f//./_} | ${f^^}"
# informe.final.tar.gz | /home/ana | /home/ana/informe.final.tar | /home/ana/informe | final.tar.gz | gz | 30 | ana | /home/luis/informe.final.tar.gz | /home/ana/informe_final_tar_gz | /HOME/ANA/INFORME.FINAL.TAR.GZ
```

Ahora al revés: **predice** cada resultado antes de ejecutar. Una pista: `#`
y `%` cortan por izquierda y derecha; doble es la coincidencia más larga.

**Verifica**:

```bash
[[ "${f##*/}" == "$(basename "$f")" ]] && [[ "${f%/*}" == "$(dirname "$f")" ]] && echo IGUAL-QUE-BASENAME
# IGUAL-QUE-BASENAME
```

## Paso 5: Aritmética entera y la trampa del octal

**Por qué**: `$(( ))` evita llamar a `bc` o `expr`, pero tiene dos rarezas que
se encuentran justo cuando se convierten horas o meses con ceros
(`date +%H` da `08`).

**Comando**:

```bash
echo $((10/3)) $((7%3)) $((2**10)) $((1<<4))
# 3 1 1024 16
n=5; ((n++)); echo $n
# 6
echo $((010)) $((0x1F))
# 8 31
echo $(( "08" ))
# bash: 08: value too great for base (error token is "08")
echo $(( 10#08 ))
# 8
```

(El mensaje real lleva delante `bash: line N:` si lo lanzas desde un
script.) `10#08` fuerza la base decimal: es el arreglo.

**Verifica**:

```bash
h=08; echo $(( 10#$h + 1 ))
# 9
```

## Paso 6: Un nombre con espacio rompe `ls` (y casi todo)

**Por qué**: es el fallo número uno de los scripts de bash. Lo provocas
aquí, en un directorio de pruebas, para verlo con tus ojos y no solo
creértelo.

**Comando**:

```bash
rm -rf ~/p13/q && mkdir -p ~/p13/q && cd ~/p13/q
touch "informe final.txt" otro.txt
f="informe final.txt"
ls -l $f
# ls: cannot access 'informe': No such file or directory
# ls: cannot access 'final.txt': No such file or directory
ls -l "$f" | cut -c1-12,30-
# -rw-r--r-- 125 03:10 informe final.txt
set -- $f;   echo "$# args"
# 2 args
set -- "$f"; echo "$# args"
# 1 args
printf '<%s>\n' $f
# <informe>
# <final.txt>
printf '<%s>\n' "$f"
# <informe final.txt>
```

(La fecha y hora de `ls -l` serán las tuyas; la forma es la misma.)
`printf '<%s>\n'` es el microscopio: imprime un argumento por línea.

**Verifica**:

```bash
set -- "$f"; echo "$#"
# 1
for x in *; do echo "<$x>"; done
# <informe final.txt>
# <otro.txt>
```

## Paso 7: `"$@"`, `$@` y `"$*"` con argumentos "difíciles"

**Por qué**: pasar los argumentos a otro comando sin romperlos es una
necesidad diaria (un *wrapper*). Solo `"$@"` lo hace bien, y verlo con un
espacio y un `*` lo deja grabado.

**Comando**:

```bash
cat > args.sh <<'EOS'
for a in $@;   do echo "1<$a>"; done
for a in "$@"; do echo "2<$a>"; done
for a in "$*"; do echo "3<$a>"; done
echo "$# argumentos"
EOS
bash args.sh "uno dos" tres "*"
# 1<uno>
# 1<dos>
# 1<tres>
# 1<args.sh>
# 1<informe final.txt>
# 1<otro.txt>
# 2<uno dos>
# 2<tres>
# 2<*>
# 3<uno dos tres *>
# 3 argumentos
```

El `*` de `$@` sin comillas se **expandió** a los archivos de la carpeta
(`args.sh`, `informe final.txt`, `otro.txt`); solo `"$@"` lo conservó.

**Verifica**:

```bash
bash args.sh "uno dos" tres "*" | grep -c '^2<'
# 3
```

## Paso 8: Un procesador de opciones y sus códigos de salida

**Por qué**: es el patrón exacto que usarás en `snapshot` y en cada
subcomando nuevo: `while` + `case` + `shift`. Aquí lo construyes sobre un
script de juguete donde equivocarte no cuesta nada.

**Comando**:

```bash
cat > opt.sh <<'EOS'
#!/usr/bin/env bash
salida="" verbose=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) verbose=1; shift ;;
    -o|--salida)
      if [[ $# -lt 2 ]]; then echo "opt.sh: $1 necesita un valor" >&2; exit 1; fi
      salida="$2"; shift 2 ;;
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
./opt.sh --salida; echo "codigo: $?"
# opt.sh: --salida necesita un valor
# codigo: 1
./opt.sh -x; echo "codigo: $?"
# opcion desconocida: -x
# codigo: 2
./opt.sh -- -v x
# verbose=0 salida=[] resto=(-v x)
```

**Verifica**:

```bash
./opt.sh -x 2>/dev/null; echo "codigo: $?"
# codigo: 2
./opt.sh -x 2>&1 >/dev/null | grep -c desconocida
# 1
```

> `getopts` hace lo mismo para opciones **cortas** (`-v`, `-o valor`) y no admite
> `--largo`; por eso el toolkit usa `while` + `case`. Mira el ejemplo completo
> en la [teoría 04](../1-teoria/04-argumentos-y-codigos-de-salida.md#23-getopts-el-procesador-integrado).

## Paso 9: Códigos de salida y `$?` frágil

**Por qué**: un código se trunca a 8 bits y `$?` se sobrescribe con
cualquier comando, incluso con el `echo` que lo imprime. Saberlo evita
condiciones que "a veces" funcionan.

**Comando**:

```bash
true; echo $?
# 0
(exit 3); echo $?
# 3
bash -c 'exit 300'; echo $?
# 44
bash -c 'exit -1'; echo $?
# 255
ls /noexiste 2>/dev/null; echo $?
# 2
./noexiste 2>/dev/null; echo $?
# 127
: > sin-permiso; ./sin-permiso 2>/dev/null; echo $?
# 126
false; echo "valor: $?"; echo "otra vez: $?"
# valor: 1
# otra vez: 0
false; r=$?; echo "guardado: $r"
# guardado: 1
```

**Verifica**:

```bash
bash -c 'kill -9 $$'; echo $?
# bash: line 1:  1768 Killed                  bash -c "kill -9 \$\$"
# 137
```

(`128 + 9`: terminado por la señal 9. El aviso `Killed` y el PID los imprime
tu shell y serán distintos.)

## ✅ Resultado

- [ ] Reproduces el `x = 5` y el `z=a b` y explicas qué intenta ejecutar bash
- [ ] Demuestras que `export` solo viaja hacia los procesos hijo
- [ ] `./req.sh` sale con `1` y no imprime `no`
- [ ] Sacas extensión y directorio con `${f##*.}` y `${f%/*}`
- [ ] `printf '<%s>\n' $f` imprime **dos** líneas y con `"$f"` una
- [ ] `args.sh` muestra la diferencia entre `$@`, `"$@"` y `"$*"`
- [ ] `opt.sh` sale con `2` ante una opción desconocida y con `1` si falta un valor
- [ ] Sabes por qué `false; echo $?; echo $?` imprime `1` y luego `0`

```bash
./scripts/verificar-semana.sh 13
```

(Esta práctica no tiene entregable propio: construye las piezas de la
práctica 04.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `x: command not found` al asignar | Espacios alrededor del `=` | `x=5` sin espacios |
| `./req.sh: line 2: x: falta x` | Es el comportamiento esperado de `${x:?}` | Define `x`: `x=algo ./req.sh` |
| `value too great for base` | Número con cero delante (`08`, `09`) leído como octal | `$(( 10#$h ))` |
| `ls -l $f` "no encuentra" un archivo que sí existe | El nombre tiene espacio y `$f` no va entre comillas | `"$f"` |
| `args.sh` imprime menos líneas `1<...>` | Tu carpeta tiene otros archivos o ninguno | Es normal: cuentan los de **tu** carpeta |
| `./opt.sh: Permission denied` | Falta `chmod +x` | `chmod +x opt.sh` |
| `bash -c 'exit -1'` no imprime `255` | Algún `set -e` o alias de tu shell | Ejecútalo en una shell limpia (`bash --norc`) |

---

[← Práctica 01: primer script y shellcheck](01-primer-script-y-shellcheck.md) · [Práctica 03: condicionales, here-docs y printf →](03-condicionales-heredocs-y-printf.md)
