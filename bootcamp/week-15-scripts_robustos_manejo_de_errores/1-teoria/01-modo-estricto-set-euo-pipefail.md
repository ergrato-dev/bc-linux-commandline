# Modo estricto: `set -euo pipefail`

> Desde la Semana 13 abres cada script con `set -euo pipefail` casi por
> reflejo. Esta semana abres la caja: qué hace cada letra, **dónde deja de
> funcionar** y por qué no es una red de seguridad sino un detector con
> agujeros conocidos.

## 🎯 Objetivos

- Explicar qué hace `-e`, `-u` y `pipefail` por separado
- Enumerar los contextos donde `set -e` **no** aborta (condiciones, `&&`/`||`, `!`, `local v=$(...)`)
- Leer los códigos de cada tramo de una tubería con `PIPESTATUS`
- Reconocer la trampa del `SIGPIPE` (`141`) y la del `((i++))`
- Decidir cuándo conviene **manejar** un fallo en vez de dejar que `set -e` lo mate

## 1. Qué problema resuelve

Sin modo estricto, bash sigue ejecutando tras un error:

```bash
# Simulacion SEGURA: en lugar de rm -rf, solo imprime donde actuaria.
bash -c 'cd /no/existe 2>/dev/null; echo "rm -rf ./* actuaria sobre: $PWD"'
# rm -rf ./* actuaria sobre: <el directorio donde estabas al lanzarlo>
```

El `cd` falla, el script sigue y un `rm -rf ./*` real actuaría sobre
**donde estés**. Ese es el desastre clásico. Los tres ajustes de la
Semana 13 existen para que un script **falle pronto y fuerte**
en lugar de seguir con un estado inconsistente. Pero cada uno tiene
excepciones, y las excepciones son donde se esconden los fallos silenciosos
que este bootcamp quiere evitar.

## 2. Cómo funciona

### 2.1 `-e` (`errexit`): aborta si un comando falla

```bash
bash -c 'set -e; false; echo no-llega'; echo "codigo: $?"
# codigo: 1
```

Un comando "falla" cuando sale con código distinto de `0`. Con `-e`, la
shell termina **con ese mismo código**. Pero hay contextos donde un fallo
**se considera ya comprobado** y no aborta:

| Contexto | Ejemplo | ¿Aborta? |
|---|---|:--:|
| Condición de `if`/`while`/`until` | `if false; then :; fi` | No |
| Antes de `&&` o `\|\|` | `false \|\| echo manejado` | No |
| Negado con `!` | `! true` | No |
| Último de una lista `&&` | `true && false` | **Sí** |
| Asignación con `$( )` | `x=$(false)` | **Sí** |
| `local`/`export` con `$( )` | `local v=$(false)` | No (el código lo da `local`) |
| Dentro de `echo $(false)` | `echo $(false)` | No (el código es el de `echo`) |
| Tubería sin `pipefail` | `false \| true` | No (cuenta el último) |

Todas se comprobaron así, una por una, en `ubuntu-lab`:

```bash
bash -c 'set -e; false && echo x; echo siguio'
# siguio
bash -c 'set -e; true && false; echo no'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; v() { local x=$(false); echo "sigue, codigo $?"; }; v'
# sigue, codigo 0
```

La diferencia importante es el orden dentro de la lista: `false && echo x`
**no** aborta (el `false` está "comprobado" por el `&&`), pero `true &&
false` **sí** (el que falla es el último de la lista).

### 2.2 `-e` y las funciones

`set -e` se **apaga dentro de cualquier función llamada desde un `if`, `||` o
`&&`** (ya lo viste en la Semana 14):

```bash
bash -c 'set -e; f() { false; echo seguia; }; if f; then :; fi'
# seguia
```

Y una función cuyo último comando es `[[ ... ]] && algo` sale con `1` cuando
la condición es falsa, lo que con `-e` mata el script **al llamarla**:

```bash
bash -c 'set -e; f() { [[ 1 -eq 2 ]] && echo x; }; f; echo no'; echo "codigo: $?"
# codigo: 1
```

### 2.3 Subshells y sustituciones

Un subshell `( ... )` hereda `-e`, y su fallo se propaga al padre:

```bash
bash -c 'set -e; (false; echo en-subshell); echo fuera'; echo "codigo: $?"
# codigo: 1
```

Pero **`$( )` dentro de una asignación no hereda `-e`** salvo que actives
`inherit_errexit` (bash 4.4+):

```bash
bash -c 'set -e; x=$(false; echo hi); echo "x=$x"'
# x=hi
bash -c 'set -e; shopt -s inherit_errexit; x=$(false; echo hi); echo "x=$x"'; echo "codigo: $?"
# codigo: 1
```

### 2.4 `-u` (`nounset`): variable sin definir es un error

```bash
bash -c 'set -u; echo "$nada"'
# bash: line 1: nada: unbound variable
bash -c 'set -u; echo "${nada:-por-defecto}"'
# por-defecto
bash -c 'set -u; a=(); echo "${#a[@]}"; echo "${a[@]}" fin'
# 0
# fin
```

Atrapa el typo `rm -rf "$dir/"` con `$dir` mal escrito. Para **admitir** una
variable vacía, `${v:-}`. En bash 5, un array vacío expandido con
`"${a[@]}"` no da error. Los parámetros posicionales sí: con `set -u`,
`$1` sin argumento aborta, y se evita con `"${1:-}"`.

### 2.5 `pipefail`: el código de una tubería

Sin `pipefail`, una tubería devuelve el código del **último** comando; con
él, el del **último que falló**:

```bash
false | true; echo "codigo: $?"
# codigo: 0
set -o pipefail; false | true; echo "codigo: $?"
# codigo: 1
```

`PIPESTATUS` guarda el código **de cada tramo**:

```bash
false | true | false; echo "${PIPESTATUS[*]}"
# 1 0 1
```

(Se lee justo después de la tubería: cualquier otro comando lo pisa, como
`$?`.) `pipefail` es de bash, ksh y zsh; **`dash` no lo tiene**, otra razón
del `#!/usr/bin/env bash` de la Semana 13.

### 2.6 La trampa del `SIGPIPE` (141)

Cuando el lector de una tubería cierra pronto (`head -1`, `grep -q`), el
escritor recibe `SIGPIPE` y sale con `128 + 13 = 141`. Con `pipefail`, eso
**cuenta como fallo**:

```bash
bash -c 'set -eo pipefail; yes | head -1 >/dev/null; echo no-llega'; echo "codigo: $?"
# codigo: 141
```

No es un bug del script: `yes` produce sin parar y `head` corta, así que es
lo esperado. Es la razón de que los `checks.json` usen `sed -n 1p` en lugar
de `head -1` con `pipefail`. Si el escritor puede ser largo, usa un lector
que lea **todo** (`sed -n 1p`, `awk 'NR==1'`) o tolera el `141`.

### 2.7 La trampa del `((i++))`

```bash
bash -c 'set -e; i=0; ((i++)); echo no-llega'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; i=0; i=$((i + 1)); echo "i=$i"'
# i=1
```

`((i++))` evalúa a `0` (el valor **anterior**), y una expresión aritmética
que vale `0` sale con código `1`: con `-e`, aborta. `i=$((i + 1))` es una
**asignación** y siempre sale con `0`.

## 3. Cómo se usa

La regla práctica: **`set -euo pipefail` al principio, y fallos esperados
manejados explícitamente**. Los tres idiomas para un fallo que no es un
error:

```bash
# 1. "grep sin coincidencias" no es un error: se tolera de forma explicita.
grep -q ERROR "$log" || true

# 2. Un if captura el codigo: es una decision, no una excepcion.
if ! grep -q ERROR "$log"; then
  echo "log limpio"
fi

# 3. Un fallo que SI importa se maneja con un mensaje, no con el aborto mudo de -e.
cd -- "$dir" || { echo "toolkit: no puedo entrar en ${dir}" >&2; exit 1; }
```

El tercero es el importante: `set -e` aborta **sin decir por qué**. Un
mensaje con el motivo y un código elegido por ti es lo que `cron` y tus
compañeros necesitan.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Confiar en `set -e` como única defensa | Se apaga en `if`, `\|\|`, `&&`, `!` y en funciones llamadas desde ellos | Comprobar los pasos críticos con `\|\| { ...; exit N; }` |
| `local v=$(cmd)` | Oculta el código de `cmd` | `local v` y luego `v=$(cmd)` |
| `((i++))` bajo `set -e` | La primera vez vale `0` y aborta | `i=$(( i + 1 ))` |
| `cmd \| head -1` con `pipefail` | `SIGPIPE` (141) hace fallar la tubería | `sed -n 1p` o `awk 'NR==1'` |
| `set +e` "para que funcione" en medio del script | Desactiva la protección sin que se note | `\|\| true` solo en el comando que puede fallar |
| `grep` sin coincidencias que mata el script | `grep` sale con `1` si no encuentra | `\|\| true` o `if grep -q ...` |
| `set -u` con `$1` opcional | `$1` sin argumento aborta | `"${1:-}"` |
| Meter `set -e` y no mirar el código de salida | El script "falla" y nadie sabe por qué | Mensaje a `stderr` + `exit` con código propio |

## 5. Trucos

- **`set -o`** (sin más) lista el estado de **todas** las opciones:
  `errexit`, `nounset`, `pipefail`... útil para depurar "¿por qué este script
  no se comporta?".
- **`set -e` y `set +e` envuelven un tramo**, pero es un olor: cuando lo
  necesitas, normalmente quieres un `|| true` en el comando concreto.
- **`bash -o pipefail -c '...'`** activa la opción en una línea suelta, sin
  tocar el script.
- **`shellcheck` no avisa de `((i++))`** (no es un error de sintaxis): esa
  trampa solo la evitas conociéndola. Lo que sí detecta es `local v=$(cmd)`
  (SC2155).

## 📚 Recursos Adicionales

- `man bash`, secciones *SHELL BUILTIN COMMANDS* (`set`) y *Pipelines*
- [BashFAQ 105 — por qué `set -e` no hace lo que esperas](https://mywiki.wooledge.org/BashFAQ/105)

## ✅ Checklist de Verificación

- [ ] `false && echo x; echo siguio` con `set -e` imprime `siguio`, y `true && false` aborta
- [ ] `local x=$(false)` sigue y `x=$(false)` aborta
- [ ] Reproduces `x=hi` sin `inherit_errexit` y el aborto con ella
- [ ] `false | true | false` deja `1 0 1` en `PIPESTATUS`
- [ ] `yes | head -1` con `pipefail` sale con `141`
- [ ] `((i++))` aborta y `i=$(( i + 1 ))` no

---

[← Índice de la semana](../README.md) · [Códigos de salida y manejo explícito de errores →](02-codigos-de-salida-y-errores-explicitos.md)
