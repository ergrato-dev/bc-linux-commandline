# Despacho dinámico y estructura de un script

> Cuando un script crece, lo que importa ya no es cada línea sino **cómo
> está organizado**: dónde van las funciones, qué ejecuta `main` y cómo se
> llama a una función cuyo nombre se decide en tiempo de ejecución. Es la
> diferencia entre un script que se mantiene y uno que se reescribe.

## 🎯 Objetivos

- Llamar a una función **por nombre** (`"hc_check_${nombre}"`) y comprobar antes que existe
- Explicar por qué una función no lleva `eval` y cómo se evita
- Ordenar un script: cabecera, constantes, funciones, `main`, guarda de ejecución
- Usar `if [[ "${BASH_SOURCE[0]}" == "$0" ]]` para poder cargar un script sin ejecutarlo
- Probar una función suelta con `source` desde la terminal

## 1. Qué problema resuelve

`healthcheck` tiene tres comprobaciones y mañana tendrá cinco. Un
`case "$nombre" in disk) hc_check_disk ;; mem) hc_check_mem ;; ...` obliga a
editar **dos sitios** (la función y el `case`) por cada una. Con despacho
dinámico, el nombre `disk` **construye** el nombre de la función. Y para
probar una de esas funciones sin lanzar todo el script, hay que poder
**cargarlo sin que ejecute `main`**.

## 2. Cómo funciona

### 2.1 Llamar a una función por su nombre

```bash
chk_disk() { echo "disk-ok"; }
chk_mem()  { echo "mem-ok"; }
for n in disk mem nada; do
  if declare -F "chk_$n" >/dev/null; then
    "chk_$n"
  else
    echo "no existe chk_$n"
  fi
done
# disk-ok
# mem-ok
# no existe chk_nada
```

`"chk_$n"` se expande a `chk_disk` y bash lo trata como **un comando**:
ejecuta la función que se llame así. No hace falta `eval`. Las comillas
dobles son obligatorias (un nombre con espacios se partiría).

`declare -F nombre` sale con `0` si la función existe y con `1` si no, sin
imprimir (con `>/dev/null` para que no escriba el nombre). Es la comprobación
de existencia. Alternativa: `[[ "$(type -t "chk_$n")" == function ]]`.

> ⚠️ **Seguridad**: si `$n` viene del usuario, `"chk_$n"` solo puede
> llamar a funciones que **empiecen por `chk_`**, no a cualquier comando:
> el prefijo es una **lista cerrada**. Aun así, `healthcheck` **valida**
> el nombre contra `disk|mem|procs` con un `case` antes de despachar: una
> lista blanca explícita es lo seguro (y da un mensaje de error útil).
> Nunca `eval "$entrada"` ni llamar a `"$n"` sin prefijo.

### 2.2 Tabla de despacho frente a `case`

| Cuándo | Qué usar |
|---|---|
| Pocos nombres, cada uno con lógica distinta y **una sola vez** | `case` |
| Muchos nombres con **una función por nombre**, y se añaden con frecuencia | Despacho por prefijo (`"hc_check_${nombre}"`) |
| El **argumento** de la función es lo que cambia | Un array asociativo (`"${limite[$nombre]}"`) |

El `main` de `toolkit.sh` usa un `case` (15 subcomandos, cada uno distinto
y con su propio mensaje de ayuda), y `healthcheck` usa despacho por
prefijo. Las dos cosas son correctas; la regla es **elegir la más legible**.

### 2.3 La estructura de un script

El orden de `toolkit.sh`, y de cualquier script que quieras mantener:

```bash
#!/usr/bin/env bash
# 1. Cabecera: qué hace, uso, códigos de salida
set -euo pipefail                      # 2. Modo estricto

readonly UMBRAL_POR_DEFECTO=90         # 3. Constantes y configuración

is_uint() { ...; }                     # 4. Funciones: de las más pequeñas
sys_disk_usage() { ...; }              #    a las más grandes
cmd_snapshot() { ...; }

main() { ...; }                        # 5. main: reparte el trabajo

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then   # 6. Guarda de ejecución
  main "$@"
fi
```

Por qué este orden:

- **Todas las funciones antes de la llamada a `main`**: una función se
  define al ejecutarla (archivo 02), así que debe existir cuando se llama.
- **Los helpers primero** y `main` al final: el script se lee de abajo
  arriba, de lo concreto a lo general, y `main` es el **índice**.
- **Nada suelto** fuera de funciones, salvo constantes y `set`: el código
  suelto se ejecuta **siempre**, incluso al cargarlo con `source`.

### 2.4 La guarda `BASH_SOURCE[0] == $0`

```bash
cat > lib.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
saluda() { echo "hola $1"; }
main() { saluda "${1:-mundo}"; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
EOS
chmod +x lib.sh
./lib.sh ana
# hola ana
./lib.sh
# hola mundo
bash -c 'source ./lib.sh; saluda desde-source'
# hola desde-source
```

`$0` es el script que **lanzaron**; `${BASH_SOURCE[0]}` es el archivo
**donde está escrita esa línea**. Si los lanzas, coinciden y se ejecuta
`main`. Si lo cargas con `source`, `$0` es **tu shell** y no coinciden: las
funciones quedan disponibles **sin ejecutar nada**. Esa es la forma de
**probar una función suelta**:

```bash
source ~/bin/toolkit.sh      # carga las funciones, no ejecuta main
sys_mem_mib                  # prueba una función a mano
# 9945
```

(Con `set -euo pipefail` dentro del script, el `source` lo activa en tu
**shell actual**: un comando que falle a partir de ahí puede cerrar tu
terminal. Prueba en un `bash` hijo: `bash -c 'source ~/bin/toolkit.sh; sys_mem_mib'`.)

### 2.5 `main "$@"` y `readonly`

`main "$@"` pasa **todos** los argumentos del script a `main`, que reparte
(en el toolkit: `main` quita el subcomando con `shift` y pasa el resto).
`readonly NOMBRE=valor` define una **constante**: reasignarla da `readonly
variable` y es el mejor aviso contra un typo que la pisa. Las constantes
van en MAYÚSCULAS y arriba.

### 2.6 `export -f` y los hijos

```bash
f() { echo "en hijo"; }
export -f f
bash -c f
# en hijo
```

`export -f` pasa una función a los **procesos hijo bash**. Sirve para
`find ... -exec bash -c 'f "$1"' _ {} \;` o `xargs`. Un script no
exportado no ve las funciones de quien lo lanza.

## 3. Cómo se usa

Así se añade una comprobación nueva a `healthcheck`, **sin tocar el
bucle** (la ventaja del despacho por prefijo):

```bash
# 1. La función: hc_check_NOMBRE, imprime una línea y devuelve 0/1.
hc_check_load() { ... }

# 2. Dos retoques: un límite y un hueco en la lista blanca.
local -A limite=([disk]=90 [mem]=128 [procs]=500 [load]=4)
local -a orden=(disk mem procs load)
case "$nombre" in disk | mem | procs | load) ;; ...
```

El **bucle** que despacha no cambia. (El `case` de validación sigue siendo
la lista blanca; es un sitio, no tres.)

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `eval "$comando"` para despachar | Ejecuta lo que le des: inyección | `"prefijo_${nombre}"` con lista blanca |
| Despachar sin prefijo (`"$nombre"`) | El usuario puede llamar a **cualquier** comando (`rm`) | Prefijo fijo + validar |
| Código suelto entre funciones | Se ejecuta al cargar con `source` y complica las pruebas | Todo dentro de funciones |
| `main` antes de definir las funciones | `command not found` | `main` al final |
| Olvidar la guarda | No se puede probar nada con `source` | `if [[ "${BASH_SOURCE[0]}" == "$0" ]]` |
| `source` de un script con `set -e` en tu terminal | Un fallo posterior cierra tu sesión | Probar en un `bash -c` hijo |
| Constantes que se reasignan por descuido | Un typo cambia un valor "fijo" | `readonly` |
| Una función `main` de 100 líneas | Es el script de antes con otro nombre | `main` solo reparte |

## 5. Trucos

- **`declare -F | awk '{print $3}'`** lista los nombres de **todas** las
  funciones cargadas; `declare -F | grep ' hc_check_'` solo las del prefijo:
  así **descubres** las comprobaciones sin mantener una lista.
- **`compgen -A function hc_check_`** lista las funciones que empiezan por
  el prefijo: el bucle `for f in $(compgen -A function hc_check_)` recorre
  **todas las comprobaciones disponibles** sin `orden`.
- **`shellcheck -x toolkit.sh`** sigue los `source` de otros archivos
  (Semana 13).
- **`${FUNCNAME[1]}`** dentro de una función es quién la llamó:
  imprímelo en un mensaje de error para saber **desde dónde** falló.

## 📚 Recursos Adicionales

- `man bash`, secciones *FUNCTIONS* y `BASH_SOURCE`
- [Bash FAQ 050 — cómo poner un comando en una variable](https://mywiki.wooledge.org/BashFAQ/050)

## ✅ Checklist de Verificación

- [ ] El bucle llama a `chk_disk` y `chk_mem` por nombre y avisa de `chk_nada`
- [ ] `./lib.sh ana` imprime `hola ana` y `source ./lib.sh` no imprime nada
- [ ] Explicas por qué `"hc_check_${nombre}"` con una lista blanca es seguro y `eval` no
- [ ] `declare -F` lista las funciones cargadas y `compgen -A function hc_` las filtra
- [ ] Sabes por qué las funciones van antes que `main` y `main` antes de la guarda

---

[← Arrays asociativos](05-arrays-asociativos.md) · [Construyendo `healthcheck` →](07-construyendo-healthcheck.md)
