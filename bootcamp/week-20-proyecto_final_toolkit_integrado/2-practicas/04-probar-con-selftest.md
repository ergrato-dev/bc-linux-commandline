# Práctica 04: Probar con un arnés de pruebas

> Escribes un arnés mínimo que ejecuta casos contra tu `toolkit`, lo rompes a propósito y descubres por qué cada línea de `selftest_case` está donde está.
> Cuando implementes `selftest` de verdad (práctica 06) ya habrás visto cada trampa por separado.

**Teoría de apoyo**: [05 · Probar una herramienta](../1-teoria/05-probar-una-herramienta.md).
**Duración estimada**: 1 h · **Entorno**: `ubuntu-lab`

## Preparación

Esta práctica **no depende** de los `TODO` del starter: pruebas subcomandos de semanas anteriores con un script aparte. Solo necesitas el `toolkit.sh` en `~/bin` con bit de ejecución.

```bash
docker exec -it ubuntu-lab bash
rm -rf /tmp/wk20 && mkdir -p /tmp/wk20 && cd /tmp/wk20
test -x ~/bin/toolkit.sh && echo listo
# listo
```

---

## Paso 1: Un caso a mano

**Por qué**: antes de automatizar, haz lo que hará la prueba. Crea una situación que `audit` **debe** detectar y comprueba que protesta con el código `2`. Si solo probaras una carpeta limpia, una herramienta que siempre devolviera `0` pasaría sin que lo notaras.

**Comando**:

```bash
# Un archivo con permisos 0777 (escribible por todos): el riesgo que audit busca.
mkdir -p fx/audit
touch fx/audit/f && chmod 0777 fx/audit/f
~/bin/toolkit.sh audit fx/audit >/dev/null; echo "rc=$?"
```

**Verifica**:

```bash
~/bin/toolkit.sh audit fx/audit >/dev/null; echo "rc=$?"
# rc=2
```

El código `2` significa «encontré algo que reportar». Ese es el comportamiento que quieres **fijar**.

---

## Paso 2: El arnés mínimo

**Por qué**: un caso es siempre lo mismo: un nombre, el código esperado y el comando. Con 15 líneas tienes un arnés que cuenta, informa y sale con el código correcto. Es una versión reducida de `selftest_case` de la práctica 06.

**Comando**:

```bash
cat > mini.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TK=~/bin/toolkit.sh
TOTAL=0
FAILS=0

# t NOMBRE ESPERADO CMD...: ejecuta CMD y compara su codigo de salida.
t() {
  local name=$1 want=$2 rc=0
  shift 2
  ( "$@" ) >/dev/null 2>&1 || rc=$?
  TOTAL=$((TOTAL + 1))
  if [[ "$rc" -eq "$want" ]]; then
    echo "ok ${name}"
  else
    FAILS=$((FAILS + 1))
    echo "falla ${name}: esperaba ${want}, salio ${rc}"
  fi
}

dir=$(mktemp -d)
trap 'rm -rf "${dir}"' EXIT
mkdir -p "$dir/audit" "$dir/logs"
touch "$dir/audit/f"
chmod 0777 "$dir/audit/f"
echo "ERROR boom" > "$dir/logs/a.log"

t audit-riesgo 2 "$TK" audit "$dir/audit"
t logscan-error 2 "$TK" logscan "$dir/logs"
t schedule-malo 2 "$TK" schedule check '61 * * * *'
t version-ok 0 "$TK" version
t uso-malo 1 "$TK"

echo "pruebas: ${TOTAL}, fallos: ${FAILS}"
[[ "$FAILS" -eq 0 ]] || exit 2
EOF
chmod +x mini.sh
```

**Verifica**:

```bash
test -x mini.sh && bash -n mini.sh && echo sintaxis-ok
# sintaxis-ok
```

---

## Paso 3: Ejecutarlo

**Por qué**: la primera ejecución debe pasar. Si falla algo, el fallo está en tu arnés o en tus capas anteriores, y es mejor saberlo ahora.

**Comando**:

```bash
./mini.sh; echo "rc=$?"
```

**Verifica**:

```bash
# ok audit-riesgo
# ok logscan-error
# ok schedule-malo
# ok version-ok
# ok uso-malo
# pruebas: 5, fallos: 0
# rc=0
```

Observa los cuatro tipos de comportamiento que se ejercitan: **detectar un riesgo** (2), **rechazar una entrada inválida** (2), **funcionar bien** (0) y **uso incorrecto** (1).

---

## Paso 4: Comprobar que el temporal se limpia

**Por qué**: un arnés que deja basura en `/tmp` es un arnés que nadie ejecuta dos veces. El `trap … EXIT` debe borrar el directorio aunque algo falle. Compruébalo en lugar de suponerlo.

**Comando**:

```bash
# Cuenta los directorios mktemp que existen antes y despues.
antes=$(ls -d /tmp/tmp.* 2>/dev/null | wc -l)
./mini.sh >/dev/null
despues=$(ls -d /tmp/tmp.* 2>/dev/null | wc -l)
echo "antes=$antes despues=$despues"
```

**Verifica**:

```bash
# antes=0 despues=0
```

Los dos números deben ser iguales. Si el contenedor tiene otros temporales, ambos serán mayores que cero pero **iguales**.

---

## Paso 5: Romper un caso a propósito

**Por qué**: una prueba que nunca ha fallado es una prueba de la que no sabes si funciona. Cambia un código esperado por uno que no se cumple y comprueba que el arnés lo **dice** y **sale con 2**.

**Comando**:

```bash
# Copia mini.sh con version-ok esperando 3 en vez de 0.
sed 's/t version-ok 0/t version-ok 3/' mini.sh > roto.sh
chmod +x roto.sh
./roto.sh; echo "rc=$?"
```

**Verifica**:

```bash
# ok audit-riesgo
# ok logscan-error
# ok schedule-malo
# falla version-ok: esperaba 3, salio 0
# ok uso-malo
# pruebas: 5, fallos: 1
# rc=2
```

Es el formato que verás en `selftest`: un `falla NOMBRE: esperaba E, salio R` por caso y un resumen. Con eso solo ya sabes **qué** falló, **qué** esperabas y **qué** ocurrió.

---

## Paso 6: Por qué `|| rc=$?` (y qué pasa sin él)

**Por qué**: con `set -e`, cualquier comando que devuelve distinto de 0 termina el script. Las pruebas esperan códigos distintos de 0 (`2`, `1`), así que **sin captura el arnés moriría en el primer caso negativo**.

**Comando**:

```bash
cat > sin.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
rc=0
( bash -c 'exit 2' )
rc=$?
echo "no llega: rc=$rc"
EOF
bash sin.sh; echo "rc=$?"
```

**Verifica**:

```bash
# rc=2
```

El `echo` nunca se ejecuta: `set -e` abortó en la línea del subproceso. El patrón correcto es `( cmd ) || rc=$?`, que convierte el fallo en **un valor** en lugar de en una excepción.

---

## Paso 7: Por qué el subproceso `( … )`

**Por qué**: un comando que ejecuta `exit` dentro de una función mata al script entero. Entre paréntesis, solo muere el subproceso. Es lo que permite probar un comando que **debe** salir con error sin que se lleve por delante a quien lo prueba.

**Comando**:

```bash
cat > nosub.sh <<'EOF'
#!/usr/bin/env bash
set -u
f() { exit 7; }
f
echo "esto no se imprime"
EOF
cat > sub.sh <<'EOF'
#!/usr/bin/env bash
set -u
f() { exit 7; }
( f )
echo "esto si se imprime: rc=$?"
EOF
bash nosub.sh; echo "rc=$?"
bash sub.sh; echo "rc=$?"
```

**Verifica**:

```bash
# rc=7
# esto si se imprime: rc=7
# rc=0
```

Sin paréntesis el script termina con el `7` de la función. Con paréntesis, el `exit` queda aislado, el script continúa y `$?` conserva el `7` para que lo compares.

---

## Paso 8: La prueba que no ejecuta nada: `shellcheck`

**Por qué**: `shellcheck` analiza el script sin ejecutarlo y encuentra errores que ningún caso de prueba tocará, como un `for` sobre la salida de `ls`. Aprende sus niveles y cómo pedirle solo lo grave.

**Comando**:

```bash
cat > malo.sh <<'EOF'
#!/usr/bin/env bash
cd /tmp
for f in $(ls); do echo $f; done
echo $nada
EOF
shellcheck -f gcc malo.sh
```

**Verifica**:

```bash
# malo.sh:2:1: warning: Use 'cd ... || exit' or 'cd ... || return' in case cd fails. [SC2164]
# malo.sh:3:10: error: Iterating over ls output is fragile. Use globs. [SC2045]
# malo.sh:3:25: note: Double quote to prevent globbing and word splitting. [SC2086]
# malo.sh:4:6: warning: nada is referenced but not assigned. [SC2154]
# malo.sh:4:6: note: Double quote to prevent globbing and word splitting. [SC2086]
```

Cinco hallazgos de tres niveles: `error`, `warning` y `note` (que en el formato normal se llama `info`). Ahora filtra y mira los códigos de salida:

```bash
shellcheck -S error malo.sh >/dev/null; echo "error: rc=$?"
# error: rc=1
shellcheck mini.sh; echo "mini.sh: rc=$?"
# mini.sh: rc=0
```

Tu `mini.sh` está limpio; `malo.sh` no. `shellcheck` sale con `1` cuando hay hallazgos **del nivel pedido** o superior.

---

## Paso 9: Depurar con una traza que dice la línea

**Por qué**: cuando un caso falla sin explicación, la traza de `bash -x` es lo más rápido. Por defecto solo marca `+`; si defines `PS4` **dentro del script**, indica archivo y línea de cada comando.

**Comando**:

```bash
cat > traza.sh <<'EOF'
#!/usr/bin/env bash
PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
set -x
echo hola
x=1
EOF
bash traza.sh
```

**Verifica**:

```bash
# + traza.sh:4: echo hola
# hola
# + traza.sh:5: x=1
```

(Las líneas con `+` salen por `stderr`; por eso pueden aparecer mezcladas con la salida normal.) Poner `PS4=… bash -x script` **desde fuera** no funciona: bash no hereda `PS4` del entorno en un script.

---

## Paso 10: Limpiar

**Por qué**: no dejes tus scripts de prueba en el laboratorio.

> **Aviso**: `rm -rf` es destructivo. Comprueba con `pwd` que estás en `/tmp/wk20`.

**Comando**:

```bash
pwd
# /tmp/wk20
cd / && rm -rf /tmp/wk20
```

**Verifica**:

```bash
test ! -e /tmp/wk20 && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] Fijaste a mano un caso negativo (`audit` con un archivo `0777` devuelve `2`)
- [ ] Escribiste un arnés `t NOMBRE ESPERADO CMD...` que cuenta y resume
- [ ] Comprobaste que el `trap` deja `/tmp` como estaba
- [ ] Rompiste un caso a propósito y viste `falla …: esperaba 3, salio 0` con código `2`
- [ ] Demostraste que sin `|| rc=$?` el arnés muere con `set -e`
- [ ] Demostraste que el subproceso `( … )` aísla un `exit`
- [ ] Usaste `shellcheck` con `-f gcc` y `-S error`, y trazaste con `PS4`

```bash
bash scripts/verificar-semana.sh 20
# (sin comprobación propia: lo que has aprendido aquí se aplica en la práctica 06)
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `mini.sh: Permission denied` | Falta el bit de ejecución | `chmod +x mini.sh` |
| Todos los casos fallan con `salio 126` o `127` | `~/bin/toolkit.sh` no es ejecutable o no existe | `docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh` |
| `ok audit-riesgo` no sale y da `salio 0` | El archivo no tiene modo `0777` | Comprueba `ls -l` en el fixture; `touch` primero, `chmod` después |
| `schedule-malo` falla | Tu `schedule check` de la Semana 16 acepta `61` | Revisa la validación del rango 0-59 |
| `antes` y `despues` distintos | El `trap` no se ejecutó | Revisa que `trap` esté **antes** de crear nada |
| `shellcheck: command not found` | Imagen sin `shellcheck` | Está en `ubuntu-lab`: `command -v shellcheck` |
| La traza no muestra la línea | `PS4` definida fuera del script | Defínela dentro, antes de `set -x` |

---

[← Práctica 03: Instalar, verificar y quitar](03-instalar-verificar-y-quitar.md) · [Práctica 05: Release a mano →](05-release-a-mano.md)
