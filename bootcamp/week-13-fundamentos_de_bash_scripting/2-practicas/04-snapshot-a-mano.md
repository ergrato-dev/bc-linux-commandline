# Práctica 04 — `snapshot` a mano

> Duración estimada: 45 min · Teoría de apoyo: [archivo 08](../1-teoria/08-construyendo-snapshot.md) (y todas las anteriores)

Construyes `snapshot` **por fragmentos**, probando cada uno antes de unirlos,
fuera del toolkit. En el [proyecto](../3-proyecto/README.md) pasarás el
resultado a `toolkit.sh`. Trabajas **dentro de `ubuntu-lab`**:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p13/snap && mkdir -p ~/p13/snap && cd ~/p13/snap
```

Cada fragmento es un archivo pequeño (`opciones.sh`, `identidad.sh`...) que
**se prueba con `source`** y al final se concatenan en un solo script. Es la
forma de probar una pieza sin ejecutar las demás.

## Paso 1: Opciones y validación del umbral

**Por qué**: lo primero que hace un script serio es rechazar lo que no
entiende. Si `--umbral abc` pasara y el resto del script lo usara en una
comparación numérica, fallaría lejos del origen (o ejecutaría código: Semana
12). La validación es el primer fragmento, no el último.

**Comando**:

```bash
cat > opciones.sh <<'EOS'
salida="" umbral=90
while [[ $# -gt 0 ]]; do
  case "$1" in
    --salida | --umbral)
      if [[ $# -lt 2 ]]; then
        echo "snap: $1 necesita un valor" >&2
        exit 1
      fi
      if [[ "$1" == --salida ]]; then salida="$2"; else umbral="$2"; fi
      shift 2
      ;;
    *)
      echo "snap: opcion desconocida: $1" >&2
      exit 1
      ;;
  esac
done

# La regex va primero: -le evalua su operando como aritmetica.
if ! [[ "$umbral" =~ ^[0-9]+$ && "$umbral" -le 100 ]]; then
  echo "snap: umbral invalido: '$umbral'" >&2
  exit 1
fi
EOS
bash -c 'source ./opciones.sh; declare -p umbral salida' _ --umbral 80 --salida "/tmp/a b.txt"
# declare -- umbral="80"
# declare -- salida="/tmp/a b.txt"
```

**Verifica**:

```bash
bash -c 'source ./opciones.sh' _ --umbral abc; echo "codigo: $?"
# snap: umbral invalido: 'abc'
# codigo: 1
bash -c 'source ./opciones.sh' _ --umbral; echo "codigo: $?"
# snap: --umbral necesita un valor
# codigo: 1
bash -c 'source ./opciones.sh; echo "umbral=$umbral"' _
# umbral=90
```

## Paso 2: La identidad de la máquina

**Por qué**: `host`, `usuario`, `sistema`, `fecha` y `kernel` salen de cinco
fuentes distintas, y dos tienen trampa: `$USER` no existe en `docker exec` y
`/etc/os-release` define varias variables que no quieres en tu script.
Aprenderás a **explorarlas antes** de meterlas en el script.

**Comando**:

```bash
uname -n
# ubuntu-lab
uname -r; date +%F
# 6.18.33.2-microsoft-standard-WSL2
# 2026-10-25
echo "[${USER:-}] [$(id -un)]"
# [] [root]
grep -E '^(NAME|PRETTY_NAME)=' /etc/os-release
# PRETTY_NAME="Ubuntu 24.04.5 LTS"
# NAME="Ubuntu"
( . /etc/os-release && echo "$PRETTY_NAME" )
# Ubuntu 24.04.5 LTS
echo "[${PRETTY_NAME:-no existe fuera del subshell}]"
# [no existe fuera del subshell]
```

(Tu `uname -r` y tu fecha serán distintos.) El subshell `( ... )` es lo que impide que
`os-release` ensucie tu shell. Ahora el fragmento:

```bash
cat > identidad.sh <<'EOS'
# $USER no existe en un contenedor lanzado con docker exec: id -un lo sustituye.
usuario="${USER:-$(id -un)}"
# El subshell ( ) evita que os-release contamine las variables del script.
# shellcheck source=/dev/null  # /etc/os-release lo lee bash en ejecucion, no shellcheck
sistema=$( . /etc/os-release && echo "$PRETTY_NAME" )
EOS
```

**Verifica**:

```bash
bash -c 'source ./identidad.sh; declare -p usuario sistema'
# declare -- usuario="root"
# declare -- sistema="Ubuntu 24.04.5 LTS"
env -u USER bash -c 'source ./identidad.sh; echo "$usuario"'
# root
bash -c 'source ./identidad.sh; echo "[${NAME:-no-contamina}]"'
# [no-contamina]
```

## Paso 3: Los números: uptime, memoria, procesos y disco

**Por qué**: cuatro datos numéricos que el kernel te da en archivos de texto,
sin instalar nada. Cada uno exige una técnica de la semana: `read` y recorte
(`${v%%.*}`), `awk`, `find` con `wc` y `df -P` con `gsub`. Los exploras uno
a uno **antes** de componer el fragmento.

**Comando**:

```bash
cat /proc/uptime
# 91234.56 363000.12
awk '/^MemTotal:/ { print $2 }' /proc/meminfo
# 10183488
find /proc -mindepth 1 -maxdepth 1 -name '[0-9]*' | wc -l
# 5
df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
# 25
```

(Tus cifras serán otras.) `/proc/uptime` tiene dos campos: segundos desde el
arranque y segundos de inactividad. `MemTotal` viene en kB; los
procesos son los directorios numéricos de `/proc` (los de **tu** espacio de
PIDs: en un contenedor, pocos); y `df -P` imprime una cabecera y una línea
por sistema de archivos, en formato POSIX.

```bash
cat > numeros.sh <<'EOS'
read -r segundos _resto < /proc/uptime
dias=$(( ${segundos%%.*} / 86400 ))
memoria_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
procesos=$(find /proc -mindepth 1 -maxdepth 1 -name '[0-9]*' | wc -l)
uso=$(df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }')
EOS
```

**Verifica**:

```bash
bash -c 'set -euo pipefail; source ./numeros.sh; declare -p dias memoria_kb procesos uso'
# declare -- dias="1"
# declare -- memoria_kb="10183488"
# declare -- procesos="5"
# declare -- uso="25"
bash -c 'source ./numeros.sh; echo "$(( memoria_kb / 1024 )) MiB"'
# 9945 MiB
```

## Paso 4: El estado y la alerta

**Por qué**: la decisión del informe: ¿el disco llegó al umbral? Es una
comparación **numérica** (`-ge`, no `>`), y la frase de alerta se construye
aquí y se imprime después **solo si existe**.

**Comando**:

```bash
cat > estado.sh <<'EOS'
estado="ok"
alerta=""
if [[ "$uso" -ge "$umbral" ]]; then
  estado="alerta"
  alerta="alerta: disco / al ${uso}% (umbral ${umbral}%)"
fi
EOS
bash -c 'uso=25; umbral=0; source ./estado.sh; declare -p estado alerta'
# declare -- estado="alerta"
# declare -- alerta="alerta: disco / al 25% (umbral 0%)"
```

**Verifica**:

```bash
bash -c 'uso=25; umbral=90; source ./estado.sh; echo "[$estado] [$alerta]"'
# [ok] []
bash -c 'uso=9; umbral=80; source ./estado.sh; echo "$estado"'
# ok
```

La última prueba es la trampa del archivo 05: con `>` (texto), `9 > 80` sería
verdadero y esto diría `alerta`.

## Paso 5: El informe con un here-doc

**Por qué**: un informe de once líneas se lee mejor escrito **tal cual
saldrá** que construido con once `echo`. El here-doc sin comillas expande
variables y comandos, y la línea de alerta usa `${alerta:+...}` para existir
solo cuando hay alerta. Se guarda en una variable porque irá **o** a la
pantalla **o** a un archivo.

**Comando**:

```bash
cat > informe.sh <<'EOS'
informe=$(cat <<EOF
== toolkit snapshot ==
fecha: $(date +%F)
host: $(uname -n)
usuario: $usuario
sistema: $sistema
kernel: $(uname -r)
uptime: $dias dias
memoria: $(( memoria_kb / 1024 )) MiB
procesos: $procesos
disco /: ${uso}%
${alerta:+$alerta
}estado: $estado
EOF
)
EOS
```

Ensambla las piezas con la cabecera y la salida (paso 6 completo) y prueba
de momento solo el informe:

```bash
{ printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'; cat opciones.sh identidad.sh numeros.sh estado.sh informe.sh; echo 'printf "%s\n" "$informe"'; } > snap.sh
chmod +x snap.sh
./snap.sh --umbral 100
# == toolkit snapshot ==
# fecha: 2026-10-25
# host: ubuntu-lab
# usuario: root
# sistema: Ubuntu 24.04.5 LTS
# kernel: 6.18.33.2-microsoft-standard-WSL2
# uptime: 1 dias
# memoria: 9945 MiB
# procesos: 5
# disco /: 25%
# estado: ok
```

**Verifica**:

```bash
./snap.sh --umbral 100 | grep -q '== toolkit snapshot ==' && echo CABECERA
# CABECERA
./snap.sh --umbral 100 | wc -l
# 11
./snap.sh --umbral 0 | wc -l
# 12
```

Con alerta salen **doce** líneas: la de `alerta:` solo existe cuando hay alerta.

## Paso 6: La salida a un archivo y el código de salida

**Por qué**: un informe que solo va a la pantalla no sirve a `cron`. Con
`--salida` se guarda (creando el directorio, y con rutas con espacios: ahí
se prueban tus comillas), y el código de salida cuenta el resultado al que
lo lance: `2` si hubo alerta.

**Comando**:

```bash
cat > salida.sh <<'EOS'
if [[ -n "$salida" ]]; then
  mkdir -p "$(dirname "$salida")"
  printf '%s\n' "$informe" > "$salida"
  echo "informe guardado en: $salida"
else
  printf '%s\n' "$informe"
fi

if [[ "$estado" == alerta ]]; then
  exit 2
fi
EOS
{ printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'; cat opciones.sh identidad.sh numeros.sh estado.sh informe.sh salida.sh; } > snap.sh
./snap.sh --umbral 100 --salida "/tmp/mis informes/rep final.txt"; echo "codigo: $?"
# informe guardado en: /tmp/mis informes/rep final.txt
# codigo: 0
./snap.sh --umbral 0 >/dev/null; echo "codigo: $?"
# codigo: 2
```

**Verifica**:

```bash
./snap.sh --umbral 100 >/dev/null; echo "codigo: $?"
# codigo: 0
./snap.sh --umbral 0 | tail -2
# alerta: disco / al 25% (umbral 0%)
# estado: alerta
./snap.sh --umbral abc 2>&1; echo "codigo: $?"
# snap: umbral invalido: 'abc'
# codigo: 1
shellcheck snap.sh && echo LIMPIO
# LIMPIO
```

## Paso 7: Llevarlo a `toolkit.sh`

**Por qué**: un script suelto no es una capa del toolkit. El starter de esta
semana trae todas las capas anteriores completas y `cmd_snapshot` con
`TODO`s numerados: cada uno corresponde a un fragmento que acabas de probar.
Esta práctica es **tu guion**; el [proyecto](../3-proyecto/README.md) lo
entrega.

**Comando** (desde **tu máquina**, no desde el contenedor; `exit` para salir):

```bash
exit
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-13-fundamentos_de_bash_scripting/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
docker exec ubuntu-lab /root/bin/toolkit.sh snapshot | head -3
# TODO TODO TODO TODO 0 TODO 0
# estado: ok (salida= umbral=90)
```

El starter, como el de semanas anteriores, **imprime marcadores `TODO`** hasta
que completes cada hueco. Equivalencia de fragmentos:

| `TODO` del starter | Fragmento de esta práctica |
|:--:|---|
| 1 y 2 | `opciones.sh` (opciones y validación) |
| 3 | `identidad.sh` y `numeros.sh` |
| 4 | `estado.sh` |
| 5 | `informe.sh` |
| 6 y 7 | `salida.sh` |

Cambios al pasar a función: las variables llevan `local`, y el mensaje de
error lleva el prefijo `toolkit snapshot:` (los tests lo comprueban por el
código de salida, no por el texto).

**Verifica**:

```bash
./scripts/verificar-semana.sh 13 | grep comprobaciones
# 5/18 comprobaciones superadas.
```

Con el starter intacto pasan 5 de 18; al completar los siete `TODO`, las 18.

## ✅ Resultado

- [ ] `./snap.sh --umbral abc` sale con `1` y avisa por `stderr`
- [ ] El informe tiene **once** líneas, y **doce** con alerta
- [ ] `./snap.sh --umbral 0` sale con `2` y `--umbral 100` con `0`
- [ ] `shellcheck snap.sh` sale limpio
- [ ] Sabes qué `TODO` del starter corresponde a cada fragmento
```bash
./scripts/verificar-semana.sh 13
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `declare: umbral: not found` | `declare -p` fuera del `bash -c`, donde `umbral` no existe | `source` y `declare` en la misma cadena |
| `uso` vacío | `df -P /` sin la columna esperada | Ejecuta `df -P /` y revisa que la columna 5 sea `Capacity` |
| El informe tiene líneas en blanco de más | `${alerta:+...}` con el salto fuera de las llaves | El salto de línea va **dentro**: `${alerta:+$alerta<salto>}` |
| `unbound variable` | Falta un fragmento anterior | Concatena en orden: opciones, identidad, números, estado, informe, salida |
| `rep final.txt` se crea como dos archivos | Comillas que faltan en `"$salida"` | `"$(dirname "$salida")"` y `> "$salida"` |

---

[← Práctica 03: condicionales, here-docs y printf](03-condicionales-heredocs-y-printf.md) · [Proyecto: Capa 13 de toolkit →](../3-proyecto/README.md)
