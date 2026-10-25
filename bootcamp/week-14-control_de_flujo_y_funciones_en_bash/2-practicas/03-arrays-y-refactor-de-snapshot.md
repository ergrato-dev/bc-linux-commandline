# Práctica 03 — Arrays y refactor de `snapshot`

> Duración estimada: 45 min · Teoría de apoyo: archivos [04](../1-teoria/04-arrays-indexados.md), [05](../1-teoria/05-arrays-asociativos.md) y [07](../1-teoria/07-construyendo-healthcheck.md)

Trabajas **dentro de `ubuntu-lab`**. Los pasos 1 a 5 son arrays; los pasos 6 y 7
**refactorizan `snapshot`** en funciones sin cambiar lo que imprime.

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p14/a && mkdir -p ~/p14/a && cd ~/p14/a
```

## Paso 1: Crear, leer y contar un array

**Por qué**: un array guarda **varios valores en una variable**, incluso con
espacios. Es lo que `healthcheck` usa para su lista de comprobaciones.

**Comando**:

```bash
a=(uno "dos tres" cuatro)
echo "${a[1]} ${#a[@]} ${#a[1]}"
# dos tres 3 8
echo "${a[-1]}"
# cuatro
echo "${a[@]:1:2}"
# dos tres cuatro
echo "${!a[@]}"
# 0 1 2
```

`${#a[@]}` son **3** elementos; `${#a[1]}` es la longitud del elemento 1 (8
caracteres); `${a[@]:1:2}` son dos elementos desde el índice 1.

**Verifica**:

```bash
[[ ${#a[@]} -eq 3 ]] && echo TRES
# TRES
```

## Paso 2: `"${a[@]}"`, `${a[@]}` y `"${a[*]}"`

**Por qué**: es la misma diferencia que `"$@"` y `"$*"` de la Semana 13, y
la causa del 90 % de los errores con arrays: sin comillas, `"dos tres"` se
parte en dos.

**Comando**:

```bash
for x in "${a[@]}"; do echo "<$x>"; done
# <uno>
# <dos tres>
# <cuatro>
for x in ${a[@]}; do echo -n "<$x>"; done; echo
# <uno><dos><tres><cuatro>
for x in "${a[*]}"; do echo "<$x>"; done
# <uno dos tres cuatro>
```

**Verifica**:

```bash
n=0; for x in "${a[@]}"; do n=$(( n + 1 )); done; echo "$n"
# 3
```

## Paso 3: Añadir, borrar y los huecos

**Por qué**: asignar a un índice lejano crea un array **disperso** y `unset`
no renumera. Por eso `${#a[@]}` (cuántos hay) y la posición del último no
son lo mismo, y un `for ((i=0; i<${#a[@]}; i++))` puede saltarse elementos.

**Comando**:

```bash
a+=(cinco)
a[7]=siete
echo "${#a[@]} ${!a[@]}"
# 5 0 1 2 3 7
unset "a[1]"
echo "${#a[@]} ${!a[@]}"
# 4 0 2 3 7
echo "${a[1]-vacio}"
# vacio
declare -p a
# declare -a a=([0]="uno" [2]="cuatro" [3]="cinco" [7]="siete")
```

**Verifica**:

```bash
for x in "${a[@]}"; do echo -n "$x "; done; echo
# uno cuatro cinco siete
```

## Paso 4: Llenar un array desde fuera (y por qué `arr=($(cmd))` es un error)

**Por qué**: casi nunca escribes el array a mano; lo llenas de un archivo, de
un comando o de una cadena. Cada fuente tiene su forma correcta, y la
incorrecta (`arr=($(cmd))`) parece funcionar hasta que aparece un espacio.

**Comando**:

```bash
IFS=, read -ra p <<< "x,y z,w"
echo "${#p[@]}"
# 3
printf 'l1\nl2\n\nl4\n' > m.txt
mapfile -t lineas < m.txt
echo "${#lineas[@]} [${lineas[2]}]"
# 4 []
touch "a b.txt" c.txt
fs=(*.txt)
printf '<%s>\n' "${fs[@]}"
# <a b.txt>
# <c.txt>
# <m.txt>
bad=($(echo "a b" "c"))
echo "${#bad[@]}"
# 3
```

`mapfile -t` conserva la línea **vacía** como elemento. `*.txt` guardó
`a b.txt` como **un** elemento. Y `bad=($(...))` partió dos "líneas" en tres
palabras.

**Verifica**:

```bash
mapfile -t ls_etc < <(ls /etc | head -3); echo "${#ls_etc[@]}"
# 3
f() { local x; for x in "$@"; do echo "-$x"; done; }
f "${a[@]}" | head -2
# -uno
# -cuatro
```

## Paso 5: Arrays asociativos

**Por qué**: `healthcheck` guarda un **límite por comprobación**. Con un
asociativo, `"${limite[$nombre]}"` elige el límite según el nombre. Pero
**sin `declare -A` no es asociativo**, y el error es silencioso.

**Comando**:

```bash
declare -A d=([disk]=90 [mem]=128)
d[procs]=500
echo "${d[disk]} ${#d[@]}"
# 90 3
echo "${d[nada]-sin}"
# sin
bash -c 'z[foo]=1; z[bar]=2; echo ${#z[@]} ${z[0]}'
# 1 2
[[ -v d[mem] ]] && echo tiene-mem
# tiene-mem
[[ -v d[x] ]] || echo no-x
# no-x
```

El `bash -c` sin `declare -A` imprimió `1 2`: `foo` y `bar` se evaluaron
como aritmética (`0`) y **las dos asignaciones cayeron en `z[0]`**.

El **orden** de `${!d[@]}` no es el de inserción. Si importa, recorre un
array indexado de claves:

```bash
for k in "${!d[@]}"; do echo "$k=${d[$k]}"; done | sort
# disk=90
# mem=128
# procs=500
orden=(disk mem procs)
for n in "${orden[@]}"; do echo "$n=${d[$n]}"; done
# disk=90
# mem=128
# procs=500
```

**Verifica**:

```bash
declare -A veces
for w in a b a c a; do veces[$w]=$(( ${veces[$w]:-0} + 1 )); done
for w in "${!veces[@]}"; do echo "$w ${veces[$w]}"; done | sort
# a 3
# b 1
# c 1
```

## Paso 6: Refactor de `snapshot` en funciones, sin cambiar su salida

**Por qué**: el `cmd_snapshot` de la Semana 13 es un bloque de sesenta
líneas. Lo partes en funciones pequeñas (`sys_*` para los datos, `snapshot_report`
para el texto) y compruebas que **la salida no ha cambiado**. Un refactor sin
esa comprobación es solo un cambio.

Primero, la **línea base**: lo que imprime hoy tu `snapshot`:

```bash
rm -rf ~/p14/s && mkdir -p ~/p14/s && cd ~/p14/s
~/bin/toolkit.sh snapshot --umbral 100 > base100.txt; echo "codigo: $?"
# codigo: 0
~/bin/toolkit.sh snapshot --umbral 0 > base0.txt; echo "codigo: $?"
# codigo: 2
wc -l base100.txt base0.txt
#  11 base100.txt
#  12 base0.txt
#  23 total
```

Ahora el **script refactorizado** (`snap2.sh`), pieza a pieza: cada `sys_*`
imprime **un** dato; `snapshot_report` recibe lo calculado por **argumentos**
(no lee variables de `main`); `main` decide.

```bash
cat > snap2.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

sys_os_name() {
  # shellcheck source=/dev/null  # /etc/os-release lo lee bash en ejecucion, no shellcheck
  ( . /etc/os-release && echo "$PRETTY_NAME" )
}

sys_uptime_days() {
  local segundos _resto
  read -r segundos _resto < /proc/uptime
  echo $(( ${segundos%%.*} / 86400 ))
}

sys_mem_mib() {
  local memoria_kb
  memoria_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
  echo $(( memoria_kb / 1024 ))
}

sys_proc_count() {
  find /proc -mindepth 1 -maxdepth 1 -name '[0-9]*' | wc -l
}

sys_disk_usage() {
  df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
}

snapshot_report() {
  local uso=$1 estado=$2 alerta=$3
  local usuario="${USER:-$(id -un)}"
  cat <<EOT
== toolkit snapshot ==
fecha: $(date +%F)
host: $(uname -n)
usuario: $usuario
sistema: $(sys_os_name)
kernel: $(uname -r)
uptime: $(sys_uptime_days) dias
memoria: $(sys_mem_mib) MiB
procesos: $(sys_proc_count)
disco /: ${uso}%
${alerta:+$alerta
}estado: $estado
EOT
}

main() {
  local umbral="${1:-90}"
  if ! is_uint "$umbral" || [[ "$umbral" -gt 100 ]]; then
    echo "snap2: umbral invalido: '$umbral'" >&2
    exit 1
  fi
  local uso estado="ok" alerta=""
  uso=$(sys_disk_usage)
  if [[ "$uso" -ge "$umbral" ]]; then
    estado="alerta"
    alerta="alerta: disco / al ${uso}% (umbral ${umbral}%)"
  fi
  snapshot_report "$uso" "$estado" "$alerta"
  if [[ "$estado" == alerta ]]; then
    exit 2
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
EOS
chmod +x snap2.sh
```

(Recibe el umbral como primer argumento: `./snap2.sh 100`. La opción
`--salida` y el resto del `while`/`case` los trae el starter completo.)

**Verifica**:

```bash
./snap2.sh 100 > new100.txt; echo "codigo: $?"
# codigo: 0
./snap2.sh 0 > new0.txt; echo "codigo: $?"
# codigo: 2
diff <(grep -v '^procesos:' base100.txt) <(grep -v '^procesos:' new100.txt) && echo IGUAL-100
# IGUAL-100
diff <(grep -v '^procesos:' base0.txt) <(grep -v '^procesos:' new0.txt) && echo IGUAL-0
# IGUAL-0
./snap2.sh abc; echo "codigo: $?"
# snap2: umbral invalido: 'abc'
# codigo: 1
```

(Se excluye la línea `procesos:` de la comparación: cambia entre
ejecuciones porque cada `docker exec` crea procesos propios.)

## Paso 7: Probar una función suelta y dejar el script limpio

**Por qué**: la guarda `if [[ "${BASH_SOURCE[0]}" == "$0" ]]` permite
**cargar** el script sin ejecutar `main`: así pruebas cada `sys_*` desde
la terminal. Y `shellcheck` confirma que el refactor no dejó nada sucio.

**Comando**:

```bash
bash -c 'source ./snap2.sh; sys_mem_mib; sys_disk_usage; is_uint 12 && echo uint'
# 9945
# 25
# uint
shellcheck snap2.sh && echo LIMPIO
# LIMPIO
```

(Cargas el script en un `bash -c` hijo, no en tu shell: tiene `set -euo
pipefail`, y un fallo posterior cerraría tu terminal.)

**Verifica**:

```bash
./snap2.sh 100 | wc -l
# 11
shellcheck snap2.sh; echo "codigo: $?"
# codigo: 0
```

El `toolkit.sh` del starter de esta semana ya trae `snapshot` refactorizado
(más las opciones `--umbral` y `--salida` y `snapshot_emit`). Léelo de
`snapshot_report` a `cmd_snapshot` y compáralo con tu `snap2.sh`.

## ✅ Resultado

- [ ] `${#a[@]}`, `${#a[1]}` y `${!a[@]}` te dan cuántos, cuánto mide uno y qué índices
- [ ] Sabes por qué `"${a[@]}"` y no `${a[@]}`
- [ ] `unset "a[1]"` deja índices `0 2 3 7` y lo explicas
- [ ] Llenas un array con `mapfile`, `read -a` y un glob, y sabes por qué `arr=($(cmd))` no
- [ ] Reproduces el `1 2` de un asociativo **sin** `declare -A`
- [ ] Recorres un asociativo en el orden que decides, con un array de claves
- [ ] `snap2.sh` imprime lo mismo que `snapshot` (con `diff`) y sale con los mismos códigos
- [ ] `shellcheck snap2.sh` sale limpio

```bash
./scripts/verificar-semana.sh 14
```

(Las comprobaciones de `snapshot` se cumplen con el starter y se mantienen
tras tu refactor; las de `healthcheck`, con la práctica 04.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `bad substitution` | `${!a[@]}` o `${a[@]:1:2}` en `sh` | Ejecuta con `bash` |
| El array tiene más elementos de los esperados | `${a[@]}` o `($(cmd))` sin comillas | `"${a[@]}"`; `mapfile -t` |
| `declare: -A: invalid option` | Estás en una shell sin arrays asociativos | Usa `bash` (comprueba `bash --version`) |
| `${d[x]}` da error con `set -u` | La clave no existe | `${d[x]:-}` o `[[ -v d[x] ]]` |
| `diff` muestra diferencias en `fecha` | Ejecutaste una medianoche después | Repite las dos ejecuciones seguidas |
| `snap2.sh: line N: sys_mem_mib: command not found` | Llamas a la función antes de definirla | Funciones primero, `main` al final |
| `shellcheck` avisa de SC1091 | Falta la directiva sobre `os-release` | La línea `# shellcheck source=/dev/null  # ...` encima de `( . /etc/os-release ...)` |

---

[← Práctica 02: funciones y ámbito](02-funciones-y-ambito.md) · [Práctica 04: `healthcheck` a mano →](04-healthcheck-a-mano.md)
