# Práctica 01 — El modo estricto y sus agujeros

> Duración estimada: 45 min · Teoría de apoyo: archivos [01](../1-teoria/01-modo-estricto-set-euo-pipefail.md) y [02](../1-teoria/02-codigos-de-salida-y-errores-explicitos.md)

Trabajas **dentro de `ubuntu-lab`**. Cada experimento usa `bash -c '...'` para
que un aborto no cierre tu terminal:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p15 && mkdir -p ~/p15/e && cd ~/p15/e
```

## Paso 1: `set -e` aborta... y sus excepciones

**Por qué**: antes de confiar en `set -e` hay que saber **cuándo no funciona**.
La primera mitad de la tabla de la teoría 01 se ve aquí en cuatro líneas.

**Comando**:

```bash
bash -c 'set -e; false; echo no-llega'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; if false; then :; fi; echo siguio'
# siguio
bash -c 'set -e; false || echo manejado; echo siguio'
# manejado
# siguio
bash -c 'set -e; false && echo x; echo siguio'
# siguio
bash -c 'set -e; true && false; echo no-llega'; echo "codigo: $?"
# codigo: 1
```

Un fallo **comprobado** (en un `if`, antes de `||` o de `&&`) no aborta; el
último de una lista `&&` sí.

**Verifica**:

```bash
bash -c 'set -e; ! true; echo siguio'
# siguio
```

## Paso 2: Las sustituciones de comandos que esconden el código

**Por qué**: es donde más fallos silenciosos nacen. `x=$(false)` aborta, pero
`local v=$(false)` y `echo $(false)` **no**, y sin `inherit_errexit` el
fallo de dentro de un `$( )` no se propaga.

**Comando**:

```bash
bash -c 'set -e; x=$(false); echo no-llega'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; v() { local x=$(false); echo "sigue, codigo $?"; }; v'
# sigue, codigo 0
bash -c 'set -e; echo $(false); echo "echo+subst sigue"'
# 
# echo+subst sigue
bash -c 'set -e; x=$(false; echo hi); echo "x=$x"'
# x=hi
bash -c 'set -e; shopt -s inherit_errexit; x=$(false; echo hi); echo "x=$x"'; echo "codigo: $?"
# codigo: 1
```

**Verifica**:

```bash
bash -c 'set -e; (false; echo en-subshell); echo fuera'; echo "codigo: $?"
# codigo: 1
```

(El subshell hereda `-e` y su fallo llega al padre.)

## Paso 3: `-u`, variables sin definir

**Por qué**: es la defensa contra el typo que convierte `rm -rf "$dir/"` en
`rm -rf /`. Aquí se prueba **sin** `rm`: solo con `echo`.

**Comando**:

```bash
bash -c 'set -u; echo "$nada"'
# bash: line 1: nada: unbound variable
bash -c 'set -u; echo "${nada:-por-defecto}"'
# por-defecto
bash -c 'set -u; set --; echo "[${1:-}]"'
# []
bash -c 'set -u; a=(); echo "${#a[@]}"; echo "${a[@]}" fin'
# 0
# fin
bash -c 'dir=""; echo rm -rf "$dir/"'
# rm -rf /
bash -c 'dir=""; echo rm -rf "${dir:?}/"'; echo "codigo: $?"
# bash: line 1: dir: parameter null or not set
# codigo: 127
```

El último es el patrón que vas a usar con `rm -rf`: `${dir:?}` **aborta antes**
de ejecutar nada. (El `127` es una rareza de `bash -c`; en un script es `1`.)

**Verifica**:

```bash
bash -c 'set -u; echo "${nada:-x}"'
# x
```

## Paso 4: `pipefail`, `PIPESTATUS` y el `141`

**Por qué**: una tubería devuelve el código del **último** comando salvo que
actives `pipefail`. Y el lector que cierra pronto (`head -1`) provoca un
`141` que con `pipefail` cuenta como fallo.

**Comando**:

```bash
false | true; echo "codigo: $?"
# codigo: 0
bash -c 'set -o pipefail; false | true; echo "codigo: $?"'
# codigo: 1
bash -c 'false | true | false; echo "${PIPESTATUS[*]}"'
# 1 0 1
bash -c 'set -eo pipefail; yes | head -1 >/dev/null; echo no-llega'; echo "codigo: $?"
# codigo: 141
```

Cuando el escritor es **infinito** (`yes`), `head -1` lo corta con
`SIGPIPE` y `pipefail` lo cuenta como fallo. Con un escritor **finito**, un
lector que lea todo (`sed -n 1p`) no provoca ningún `141`:

```bash
bash -c 'set -eo pipefail; seq 1 5 | sed -n 1p; echo llega'
# 1
# llega
```

**Verifica**:

```bash
bash -c 'set -eo pipefail; seq 1 100000 | head -1 > /dev/null; echo no-llega'; echo "codigo: $?"
# codigo: 141
```

(`seq` escribe mucho más de lo que `head` lee, así que recibe `SIGPIPE`; con
una entrada corta de pocas líneas, `seq` termina antes y no hay `141`.)

## Paso 5: `((i++))` y `grep` sin coincidencias

**Por qué**: dos fallos de `set -e` que sorprenden al principio: una cuenta
que vale `0` "falla", y `grep` sale con `1` cuando **no encuentra**, que no es
un error.

**Comando**:

```bash
bash -c 'set -e; i=0; ((i++)); echo no-llega'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; i=0; i=$(( i + 1 )); echo "i=$i"'
# i=1
bash -c 'set -e; grep -q zzz /etc/hostname; echo no-llega'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; grep -q zzz /etc/hostname || true; echo siguio'
# siguio
```

**Verifica**:

```bash
bash -c 'set -e; if grep -q zzz /etc/hostname; then echo hay; else echo "no hay"; fi'
# no hay
```

## Paso 6: `set -e` y las funciones

**Por qué**: es la trampa que explica por qué `hc_check_*` (Semana 14) y
`guard_run` devuelven el código **explícitamente** y se llaman con `if !` o
`|| rc=$?`.

**Comando**:

```bash
bash -c 'set -e; f() { false; echo seguia; }; f; echo fin'; echo "codigo: $?"
# codigo: 1
bash -c 'set -e; f() { false; echo seguia; }; if f; then echo si; fi'
# seguia
# si
bash -c 'set -e; f() { [[ 1 -eq 2 ]] && echo x; }; f; echo no-llega'; echo "codigo: $?"
# codigo: 1
```

La misma `f` aborta suelta y **no** aborta dentro de `if f`. Y una función
cuyo último comando es un `[[ ]] && ...` falso sale con `1` y mata el script
al llamarla.

**Verifica**:

```bash
bash -c 'set -e; f() { [[ 1 -eq 2 ]] && echo x; return 0; }; f; echo ok'
# ok
```

## Paso 7: Códigos de salida con significado

**Por qué**: `cron` solo ve el código. Conocer `126`, `127` y `128+N` permite
interpretar un fallo sin abrir el script.

**Comando**:

```bash
touch /tmp/sin-permiso.sh
bash -c '/tmp/sin-permiso.sh'; echo "codigo: $?"
# bash: line 1: /tmp/sin-permiso.sh: Permission denied
# codigo: 126
bash -c 'nocmd_zz'; echo "codigo: $?"
# bash: line 1: nocmd_zz: command not found
# codigo: 127
bash -c 'kill -TERM $$'; echo "codigo: $?"
# codigo: 143
bash -c 'exit 300'; echo "codigo: $?"
# codigo: 44
kill -l 143
# TERM
```

**Verifica**:

```bash
false; echo "primero: $?"; echo "segundo: $?"
# primero: 1
# segundo: 0
```

## Paso 8: Manejar el fallo con mensaje y código propios

**Por qué**: `set -e` aborta sin explicar nada. `die` convierte el fallo en un
mensaje con motivo y un código que **tú** eliges.

**Comando**:

```bash
bash -c 'die() { echo "toolkit: $1" >&2; exit "${2:-1}"; }; die "algo ha ido mal" 7'; echo "codigo: $?"
# toolkit: algo ha ido mal
# codigo: 7
bash -c 'cd -- /no/existe 2>/dev/null || { echo "no puedo entrar" >&2; exit 5; }'; echo "codigo: $?"
# no puedo entrar
# codigo: 5
bash -c 'cmd=false; rc=0; "$cmd" || rc=$?; echo "codigo guardado: ${rc}"'
# codigo guardado: 1
touch -- /tmp/-n; ls -- /tmp/-n; rm -- /tmp/-n
# /tmp/-n
```

**Verifica**:

```bash
bash -c 'set -e; f() { false; }; f || echo "manejado, codigo $?"; echo sigue'
# manejado, codigo 1
# sigue
```

## ✅ Resultado

- [ ] Reproduces las excepciones de `set -e` (`if`, `||`, `&&`, `!`) y que `true && false` sí aborta
- [ ] Demuestras que `local x=$(false)` sigue y `x=$(false)` aborta, y el efecto de `inherit_errexit`
- [ ] `${dir:?}` aborta antes de un `rm -rf "$dir/"` imaginario
- [ ] Obtienes `1 0 1` en `PIPESTATUS` y el `141` de `yes | head -1`
- [ ] `((i++))` aborta y `i=$(( i + 1 ))` no
- [ ] Explicas por qué `f` aborta suelta y no dentro de `if f`
- [ ] Reproduces `126`, `127`, `143` y `44`, y escribes un `die` con código propio

```bash
./scripts/verificar-semana.sh 15
```

(Esta práctica no tiene entregable propio: son las reglas con las que se
escribe `guard`.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| La terminal se cierra o el script "desaparece" | Ejecutaste `set -e` directamente en tu shell | Usa siempre `bash -c '...'` |
| `yes \| sed -n 1p` no termina | `yes` no acaba nunca y `sed` lee todo | `Ctrl+C`; usa un escritor finito (`seq 1 5`) |
| El `141` no aparece con `seq` | La salida es corta y `seq` termina antes del `SIGPIPE` | `seq 1 100000` |
| `${dir:?}` da `127` en vez de `1` | Estás bajo `bash -c` | En un archivo `.sh` sale con `1` |
| `set -e` no aborta dentro de una función | La llamaste desde `if`, `\|\|` o `&&` | Devuelve el código con `return` explícito |
| `bash: ... unbound variable` en `$1` | Usas `-u` y el argumento no se pasó | `"${1:-}"` |
| `inherit_errexit` no tiene efecto | Bash anterior a 4.4 | Las cuatro distribuciones del laboratorio lo traen (5.1 a 5.3) |

---

[← Construyendo `guard`](../1-teoria/08-construyendo-guard.md) · [Práctica 02: `trap` y archivos temporales →](02-trap-y-archivos-temporales.md)
