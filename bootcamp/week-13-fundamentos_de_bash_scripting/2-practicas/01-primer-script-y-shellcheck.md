# Práctica 01 — Tu primer script y `shellcheck`

> Duración estimada: 45 min · Teoría de apoyo: [archivos 01](../1-teoria/01-shebang-y-ejecucion.md) y [07](../1-teoria/07-shellcheck.md)

Todo el trabajo se hace **dentro de `ubuntu-lab`**. Abre una shell en él y
trabaja en un directorio de prácticas:

```bash
docker exec -it ubuntu-lab bash
```

A partir de aquí, cada comando se escribe en esa shell (el prompt será
`root@ubuntu-lab:~#`). Para salir, `exit`.

## Paso 1: Preparar el entorno e instalar `shellcheck`

**Por qué**: la imagen mínima de `ubuntu-lab` no trae `shellcheck` (ni casi
nada). Sin él no puedes comprobar nada de esta semana, y la entrega lo exige:
mejor instalarlo ahora y ver qué versión te ha tocado.

**Comando**:

```bash
# apt-get update refresca el indice de paquetes; sin el, install puede no encontrar nada.
apt-get update >/dev/null 2>&1
apt-get install -y shellcheck >/dev/null 2>&1
# Directorio de trabajo de la semana, separado del toolkit para no mezclar.
mkdir -p ~/p13 && cd ~/p13
pwd
# /root/p13
```

**Verifica**:

```bash
shellcheck --version | sed -n 2p
# version: 0.9.0
```

> En otra familia: `dnf install -y epel-release && dnf install -y ShellCheck`
> (`rhel-lab`), `pacman -S --noconfirm shellcheck` (`arch-lab`). Mira la
> [teoría 07](../1-teoria/07-shellcheck.md#21-instalarlo).

## Paso 2: Escribir y ejecutar tu primer script

**Por qué**: es la misma línea de comandos de siempre, guardada en un
archivo. Lo importante es ver las **dos partes** que la terminal te daba
gratis: el shebang (quién lo ejecuta) y el bit de ejecución (si te dejan).

**Comando**:

```bash
# printf escribe el archivo exacto: la primera linea DEBE ser el shebang, columna 1.
# Comillas simples: $0 y $# llegan al archivo sin expandir; los resuelve el script al ejecutarse.
printf '#!/usr/bin/env bash\necho "hola desde $0 con $# argumentos"\n' > hola.sh
cat hola.sh
# #!/usr/bin/env bash
# echo "hola desde $0 con $# argumentos"
```

**Verifica**:

```bash
head -c 2 hola.sh; echo
# #!
```

(Con comillas simples, `$0` y `$#` llegan al archivo sin expandir. Si
hubieras usado comillas dobles, `printf` los habría resuelto **antes** de
escribirlos.)

## Paso 3: Las tres formas de ejecutarlo y el bit `x`

**Por qué**: `Permission denied` y `command not found` son los dos errores que
más verás esta semana, y se resuelven entendiendo la diferencia entre
**ejecutar** (`./hola.sh`) e **interpretar** (`bash hola.sh`). Este paso
los provoca a propósito.

**Comando**:

```bash
ls -l hola.sh | cut -c1-10
# -rw-r--r--
./hola.sh; echo "codigo: $?"
# bash: ./hola.sh: Permission denied
# codigo: 126
bash hola.sh a b; echo "codigo: $?"
# hola desde hola.sh con 2 argumentos
# codigo: 0
chmod +x hola.sh
./hola.sh a b; echo "codigo: $?"
# hola desde ./hola.sh con 2 argumentos
# codigo: 0
hola.sh; echo "codigo: $?"
# bash: hola.sh: command not found
# codigo: 127
PATH="$PATH:$HOME/p13" hola.sh x
# hola desde /root/p13/hola.sh con 1 argumentos
```

Fíjate en el valor de `$0`: `hola.sh` si lo lanza `bash hola.sh`; `./hola.sh`
si lo ejecutas con ruta; una ruta absoluta si está en el `PATH`.

**Verifica**:

```bash
./hola.sh uno | grep -q "con 1 argumentos" && echo OK
# OK
test -x hola.sh && echo ejecutable
# ejecutable
```

## Paso 4: Un script no cambia tu shell (y cuándo sí)

**Por qué**: es la confusión más cara. Un script corre en un **proceso hijo**:
su `cd` y sus variables mueren con él. `source` lo carga en tu shell. Saber
cuál usar evita horas de "¿por qué no se queda mi variable?".

**Comando**:

```bash
printf 'mivar=desde-script\ncd /tmp\n' > efecto.sh
cd ~/p13
bash efecto.sh
echo "[${mivar:-vacia}] $PWD"
# [vacia] /root/p13
. ./efecto.sh
echo "[${mivar:-vacia}] $PWD"
# [desde-script] /tmp
cd ~/p13
```

**Verifica**:

```bash
unset mivar
bash efecto.sh; echo "[${mivar:-vacia}]"
# [vacia]
source efecto.sh; echo "[${mivar:-vacia}]"
# [desde-script]
cd ~/p13
```

## Paso 5: Dejar un script limpio de `shellcheck`

**Por qué**: la entrega de cada semana exige `shellcheck` sin avisos sobre el
toolkit. Practica con un script **a propósito mal escrito** para aprender a
leer cada aviso y arreglarlo entendiendo por qué lo es, y después comprueba el
`toolkit.sh` real.

**Comando**:

```bash
cat > sc.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

dir=$1
cd $dir
for f in $(ls); do
  echo $f
done
local_v=`date`
f() { local r=$(false); echo "$r"; }
grep -q x /etc/passwd
if [ $? -eq 0 ]; then echo si; fi
unused=1
EOS
# -f gcc: una linea por aviso (linea: nivel: mensaje [codigo]); cut quita el nombre del archivo y la columna.
shellcheck -f gcc sc.sh | cut -d: -f2,4-
# 5: note: Double quote to prevent globbing and word splitting. [SC2086]
# 6: error: Iterating over ls output is fragile. Use globs. [SC2045]
# 7: note: Double quote to prevent globbing and word splitting. [SC2086]
# 9: warning: local_v appears unused. Verify use (or export if used externally). [SC2034]
# 9: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
# 10: warning: Declare and assign separately to avoid masking return values. [SC2155]
# 12: note: Check exit code directly with e.g. 'if mycmd;', not indirectly with $?. [SC2181]
# 13: warning: unused appears unused. Verify use (or export if used externally). [SC2034]
```

Ahora arréglalos. Reescribe el script **entendiendo** cada cambio (tabla de la
[teoría 07](../1-teoria/07-shellcheck.md#23-los-avisos-que-veras-el-90--del-tiempo)):

```bash
cat > sc.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

dir=${1:?uso: sc.sh DIRECTORIO}
cd "$dir"
for f in *; do
  echo "$f"
done
fecha=$(date)
echo "$fecha"
f() {
  local r
  r=$(false)
  echo "$r"
}
if grep -q x /etc/passwd; then echo si; fi
EOS
shellcheck sc.sh; echo "codigo: $?"
# codigo: 0
```

(`unused=1` se eliminó: una variable que nadie lee sobra. `f` se queda sin
llamar: `shellcheck` no avisa de funciones sin usar.)

**Verifica**:

```bash
shellcheck sc.sh && echo LIMPIO
# LIMPIO
```

Y el comprobante final: si ya copiaste `toolkit.sh` al laboratorio (la
[teoría 08](../1-teoria/08-construyendo-snapshot.md) y la práctica 04 lo
hacen), debe salir limpio. Desde **tu máquina**, no desde el contenedor:

```bash
docker exec ubuntu-lab bash -c 'test -f /root/bin/toolkit.sh && shellcheck /root/bin/toolkit.sh && echo TOOLKIT-LIMPIO || echo "(aun sin toolkit o con avisos)"'
# (aun sin toolkit o con avisos)
```

## Paso 6: Depurar con `bash -n` y `bash -x`

**Por qué**: cuando un script falla, hay dos preguntas distintas: "¿está bien
escrito?" (`-n`) y "¿qué hace realmente?" (`-x`). Ninguna ejecuta tu lógica a
ciegas, y las dos te ahorrarán `echo` de depuración.

**Comando**:

```bash
printf 'if true; then\necho x\n' > roto.sh
bash -n roto.sh; echo "codigo: $?"
# roto.sh: line 3: syntax error: unexpected end of file
# codigo: 2
printf 'x=5\necho $((x+1))\n' > dbg.sh
bash -x dbg.sh
# 6
# + x=5
# + echo 6
```

`-x` imprime cada comando **ya expandido** (con `+` delante, en `stderr`).
Fíjate en que `echo $((x+1))` aparece como `echo 6`: ya sustituyó la
variable y calculó.

**Verifica**:

```bash
bash -n dbg.sh && echo SINTAXIS-OK
# SINTAXIS-OK
bash -x dbg.sh 2>&1 | grep -c '^+'
# 2
```

## Paso 7: Los dos fallos que el shebang esconde

**Por qué**: los finales de línea de Windows y un `#!/bin/sh` con funciones
de bash son los dos errores de entrada más desconcertantes, porque el mensaje
**no menciona el problema real**. Verlos una vez, en un laboratorio, te los
hace reconocibles para siempre.

**Comando**:

```bash
# CRLF: el shebang acaba en \r y el kernel busca un intérprete llamado "bash\r".
printf '#!/usr/bin/env bash\r\necho hola\r\n' > crlf.sh && chmod +x crlf.sh
./crlf.sh; echo "codigo: $?"
# /usr/bin/env: 'bash\r': No such file or directory
# /usr/bin/env: use -[v]S to pass options in shebang lines
# codigo: 127
sed -i 's/\r$//' crlf.sh
./crlf.sh
# hola
# #!/bin/sh en Ubuntu es dash: no conoce [[ ]].
printf '#!/bin/sh\nif [[ 1 -eq 1 ]]; then echo ok; fi\n' > sh.sh && chmod +x sh.sh
./sh.sh; echo "codigo: $?"
# ./sh.sh: 2: [[: not found
# codigo: 0
shellcheck -f gcc sh.sh | grep -o 'SC[0-9]*'
# SC3010
```

Dos hallazgos: el `[[: not found` **no hizo fallar el script** (salió con
`0`: el `if` simplemente no entró), y `shellcheck` lo habría avisado antes
(`SC3010`).

**Verifica**:

```bash
./crlf.sh
# hola
sed -i '1s|.*|#!/usr/bin/env bash|' sh.sh && ./sh.sh
# ok
```

### Segunda parte: lo mismo en otra familia (opcional, desde tu máquina)

```bash
# Mismo script, otra familia: en Rocky /bin/sh ES bash, así que "funciona".
docker exec rhel-lab bash -c "printf '#!/bin/sh\nif [[ 1 -eq 1 ]]; then echo ok; fi\n' > /tmp/sh.sh; chmod +x /tmp/sh.sh; /tmp/sh.sh"
# ok
docker exec debian-lab bash -c "printf '#!/bin/sh\nif [[ 1 -eq 1 ]]; then echo ok; fi\n' > /tmp/sh.sh; chmod +x /tmp/sh.sh; /tmp/sh.sh"
# /tmp/sh.sh: 2: [[: not found
```

Es la **divergencia real** de la teoría 01: "en mi Fedora funciona".

## ✅ Resultado

- [ ] `shellcheck --version` imprime una versión en `ubuntu-lab`
- [ ] Ejecutaste `hola.sh` de tres formas y explicas por qué la primera dio `126`
- [ ] Demostraste que `bash script` **no** cambia tu `PWD` y `source script` sí
- [ ] `sc.sh` tiene `shellcheck` sin avisos y sabes qué arregló cada cambio
- [ ] Provocaste el error de `CRLF` y el de `[[: not found` y los reconoces
- [ ] Sabes que la comprobación `toolkit-shellcheck-limpio` de `verificar-semana.sh` hace lo del paso 5, pero sobre `~/bin/toolkit.sh`

```bash
./scripts/verificar-semana.sh 13
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `shellcheck: command not found` | La imagen mínima no lo trae | Paso 1: `apt-get install -y shellcheck` (haz `apt-get update` antes) |
| `E: Unable to locate package shellcheck` | No ejecutaste `apt-get update` | `apt-get update` y repite |
| `./hola.sh: Permission denied` | Falta el bit `x` | `chmod +x hola.sh` |
| `hola.sh: command not found` | El directorio actual no está en el `PATH` | `./hola.sh` o `PATH="$PATH:$PWD" hola.sh` |
| `hola desde ./hola.sh con  argumentos` (sin número) | Escribiste `$#` entre comillas dobles en `printf` y se expandió al crear el archivo | Usa comillas **simples** alrededor del texto de `printf` |
| `/usr/bin/env: 'bash\r': No such file or directory` | Finales de línea de Windows | `sed -i 's/\r$//' archivo` |
| `[[: not found` | El shebang dice `sh` y `sh` es `dash` | Cámbialo a `#!/usr/bin/env bash` |
| `shellcheck` sigue avisando tras el arreglo | Quedó una variable sin usar o una expansión sin comillas | Lee la línea del aviso: `^--^` marca el trozo exacto |

---

[← Construyendo `snapshot`](../1-teoria/08-construyendo-snapshot.md) · [Práctica 02: variables, quoting y argumentos →](02-variables-quoting-y-argumentos.md)
