# Práctica 02 — `trap` y archivos temporales

> Duración estimada: 60 min · Teoría de apoyo: archivos [03](../1-teoria/03-trap-senales-y-limpieza.md) y [04](../1-teoria/04-archivos-temporales-y-escritura-atomica.md)

Trabajas **dentro de `ubuntu-lab`**:

```bash
docker exec -it ubuntu-lab bash
rm -rf ~/p15/t && mkdir -p ~/p15/t && cd ~/p15/t
```

## Paso 1: `trap` sobre `EXIT` y el código de salida

**Por qué**: `EXIT` es el sitio de la limpieza porque corre en **todas** las
salidas controladas. Y dentro del trap, `$?` es el código con el que se va a
salir: hay que leerlo primero.

**Comando**:

```bash
bash -c 'trap "echo adios" EXIT; echo hola'
# hola
# adios
bash -c 'trap "echo adios" EXIT; exit 3'; echo "codigo: $?"
# adios
# codigo: 3
bash -c 'trap "echo EXIT-codigo=\$?" EXIT; set -e; false; echo no-llega'
# EXIT-codigo=1
bash -c 'trap false EXIT; exit 2'; echo "codigo: $?"
# codigo: 2
bash -c 'trap "exit 9" EXIT; exit 2'; echo "codigo: $?"
# codigo: 9
```

El trap se ejecuta aunque `set -e` aborte, y **no cambia** el código de
salida salvo que él mismo llame a `exit`.

**Verifica**:

```bash
bash -c 'trap "echo limpio" EXIT; true'
# limpio
```

## Paso 2: `trap` sobre señales (y lo que no se puede atrapar)

**Por qué**: `Ctrl+C` y `kill` son las salidas "no planeadas". El patrón es
un manejador por señal que **solo** hace `exit 128+N`, y la limpieza una sola
vez en `EXIT`.

**Comando**:

```bash
bash -c 'trap "echo limpio" EXIT; trap "echo term; exit 143" TERM; kill -TERM $$; echo no-llega'; echo "codigo: $?"
# term
# limpio
# codigo: 143
bash -c 'trap "echo ctrlc" INT; kill -INT $$; echo sigue'
# ctrlc
# sigue
bash -c 'trap "echo CHAU" EXIT; kill -9 $$'; echo "codigo: $?"
# codigo: 137
bash -c 'trap "" TERM; kill -TERM $$; echo "ignoro TERM"'
# ignoro TERM
```

En la tercera, `kill -9` mata **sin avisar**: `CHAU` no aparece. Un trap
que atrapa `INT` **sin** salir (la segunda) hace que el script siga, que
suele ser lo que **no** quieres.

**Verifica**:

```bash
kill -l TERM; kill -l INT; kill -l KILL
# 15
# 2
# 9
```

## Paso 3: Ver, reemplazar y quitar traps

**Por qué**: un segundo `trap` sobre la misma señal **reemplaza** al primero.
Es la causa de "mi limpieza no se ejecuta": algo más la pisó.

**Comando**:

```bash
bash -c 'trap "echo uno" EXIT; trap "echo dos" EXIT; true'
# dos
bash -c 'trap "echo x" EXIT; trap -p EXIT'
# trap -- 'echo x' EXIT
bash -c 'trap "echo x" EXIT; trap - EXIT; echo sin-trap'
# sin-trap
bash -c 'cleanup() { echo "limpiando"; }; trap cleanup EXIT INT TERM; echo trabajo'
# trabajo
# limpiando
```

La última línea usa **una función** para varias señales: es la forma de
"sumar" acciones sin que un trap pise al otro.

**Verifica**:

```bash
bash -c 'for s in EXIT HUP INT TERM; do trap "echo $s" $s; done; trap -p | wc -l'
# 4
# EXIT
```

(Cuatro traps activos; el `EXIT` final es ese trap ejecutándose al terminar.)

## Paso 4: El `trap` que se retrasa (y cómo evitarlo)

**Por qué**: si bash espera a un comando **en primer plano**, el trap de una
señal no se ejecuta hasta que el comando acaba. Con `&` y `wait` se ejecuta
al instante. Es el motivo de `guard_run`.

**Comando**:

```bash
cat > defer.sh <<'EOS'
trap 'echo "trap a los ${SECONDS}s"' TERM
(sleep 1; kill -TERM $$) &
sleep 3
echo "fin a los ${SECONDS}s"
EOS
bash defer.sh
# trap a los 3s
# fin a los 3s
cat > defer2.sh <<'EOS'
trap 'echo "trap a los ${SECONDS}s"' TERM
(sleep 1; kill -TERM $$) &
sleep 3 &
wait $!
echo "fin a los ${SECONDS}s"
EOS
bash defer2.sh
# trap a los 1s
# fin a los 1s
```

La señal llegó a **1 s** en las dos; en la primera el trap esperó a que
terminara `sleep 3`.

**Verifica**:

```bash
bash defer2.sh | head -1
# trap a los 1s
```

## Paso 5: `ERR` y `set -E`

**Por qué**: `trap ... ERR` da el **dónde** y el **qué** de un fallo
(`$LINENO`, `$BASH_COMMAND`). Pero no se hereda en funciones sin `-E`.

**Comando**:

```bash
bash -c 'set -eE; f() { false; }; trap "echo ERR en linea \$LINENO: \$BASH_COMMAND" ERR; f; echo no-llega'; echo "codigo: $?"
# ERR en linea 1: false
# codigo: 1
bash -c 'set -e; f() { false; }; trap "echo ERR-sin-E" ERR; f; echo no-llega'; echo "codigo: $?"
# codigo: 1
```

La segunda **no imprime** el mensaje: sin `-E`, el trap no salta dentro
de `f`.

**Verifica**:

```bash
bash -c 'f() { trap "echo en-return" RETURN; echo dentro; }; f; echo fuera'
# dentro
# en-return
# fuera
```

(`RETURN` se ejecuta al volver de una función: instálalo **dentro** de ella.)

## Paso 6: `mktemp` y por qué no `/tmp/algo.$$`

**Por qué**: `mktemp` crea el archivo con nombre aleatorio y permisos `600`;
un nombre predecible deja abierta la puerta a un **enlace simbólico**
preparado de antemano.

**Comando**:

```bash
f=$(mktemp); ls -l "$f" | cut -c1-10
# -rw-------
d=$(mktemp -d); ls -ld "$d" | cut -c1-10
# drwx------
rm -f "$f"; rmdir "$d"
mktemp /tmp/aXX
# mktemp: too few X's in template '/tmp/aXX'
echo "datos importantes" > victima
ln -s "$PWD/victima" predecible.1234
echo "malicioso" > predecible.1234
cat victima
# malicioso
```

Las cuatro últimas líneas **reproducen el ataque** sobre un archivo tuyo: el
`>` escribió **a través del enlace**. Con `mktemp` la creación falla si el
nombre ya existe, así que nunca sigue un enlace puesto de antemano.

**Verifica**:

```bash
t=$(mktemp -p .); echo "${t##*/}" | grep -cE '^tmp\.[A-Za-z0-9]{10}$'
# 1
rm -f "$t"
```

## Paso 7: Limpieza con `trap EXIT` y `${dir:?}`

**Por qué**: el directorio de trabajo debe desaparecer **aunque el script
falle**. Y el `rm -rf` va protegido: con la variable vacía sería `rm -rf /`.

> ⚠️ **Antes de un `rm -rf`**: imprímelo con `echo` y comprueba la ruta. El
> respaldo es borrar **solo** lo que creaste tú con `mktemp -d`.

**Comando**:

```bash
dir=""; echo rm -rf "$dir/"
# rm -rf /
bash -c 'dir=""; echo rm -rf "${dir:?}/"'
# bash: line 1: dir: parameter null or not set
cat > cd.sh <<'EOS'
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf -- "${work:?}"' EXIT
echo "$work" > lastwork
touch "$work/a" "$work/b"
ls "$work" | wc -l
exit 3
EOS
bash cd.sh; echo "codigo: $?"
# 2
# codigo: 3
```

**Verifica**:

```bash
test -d "$(cat lastwork)" && echo "sigue" || echo "borrado"
# borrado
```

## Paso 8: Escritura atómica

**Por qué**: un lector no debe ver nunca un archivo a medias. Se escribe en
un temporal **del mismo directorio** y se hace `mv`: un `rename()` del kernel.

**Comando**:

```bash
cat > aw.sh <<'EOS'
set -euo pipefail
destino=$1
tmp=$(mktemp "${destino}.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
printf 'linea1\nlinea2\n' > "$tmp"
chmod 644 "$tmp"
mv -- "$tmp" "$destino"
EOS
bash aw.sh salida.txt; ls -l salida.txt | cut -c1-10
# -rw-r--r--
ls salida.txt*
# salida.txt
stat -c '%d %n' /tmp /dev/shm
# 105 /tmp
# 155 /dev/shm
```

(Tus números de dispositivo serán otros; lo que importa es que **difieren**:
un `mv` entre ellos ya no es atómico, por eso el temporal va junto al
destino.)

**Verifica**:

```bash
cat salida.txt
# linea1
# linea2
```

## Paso 9: `noclobber` y `umask`

**Por qué**: dos redes de seguridad baratas. `noclobber` impide pisar un
archivo por accidente; `umask 077` crea los archivos solo para ti.

**Comando**:

```bash
echo uno > nc; set -o noclobber
echo dos > nc
# bash: nc: cannot overwrite existing file
echo dos >| nc; cat nc
# dos
set +o noclobber
(umask 077; touch u1; ls -l u1 | cut -c1-10)
# -rw-------
(umask 022; touch u2; ls -l u2 | cut -c1-10)
# -rw-r--r--
```

**Verifica**:

```bash
echo uno > nc2; (set -o noclobber; { echo dos > nc2; } 2>/dev/null) || echo "bloqueado"; cat nc2
# bloqueado
# uno
```

## ✅ Resultado

- [ ] Un `trap EXIT` corre con `exit 3`, con `set -e` y no cambia el código salvo que llame a `exit`
- [ ] Reproduces `term` + `limpio` con `143`, y que `kill -9` no ejecuta ningún trap
- [ ] Demuestras que un segundo `trap` reemplaza al primero y usas una función para sumar acciones
- [ ] Reproduces el retraso de `3s` y el trap inmediato de `1s`
- [ ] El `ERR` salta en funciones con `set -E` y no sin él
- [ ] `mktemp` da `-rw-------` y reproduces el ataque del enlace con un nombre predecible
- [ ] `cd.sh` borra su directorio aunque salga con `exit 3`, y `${dir:?}` aborta con la variable vacía
- [ ] `aw.sh` publica `salida.txt` sin dejar temporales

```bash
./scripts/verificar-semana.sh 15
```

(Esta práctica no tiene entregable propio: son las piezas de `guard_cleanup`
y de su temporal.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| La limpieza no se ejecuta | Otro `trap` sobre la misma señal la reemplazó | `trap -p` y una función `cleanup` única |
| `CHAU` no aparece tras `kill -9` | `KILL` no se puede atrapar | Usa `TERM` para que haya limpieza |
| El trap tarda en ejecutarse | Comando en primer plano | `cmd & wait $!` |
| `$?` vale `0` dentro del trap | Leíste `$?` tras otro comando | `local rc=$?` en la primera línea |
| El `ERR` no salta en una función | Falta `set -E` | `set -eE` |
| `mktemp: too few X's` | La plantilla tiene menos de 3 `X` | `XXXXXX` |
| `parameter null or not set` | `${work:?}` con la variable vacía: es la protección | Comprueba que `mktemp -d` funcionó |
| `mv` deja un temporal con otro nombre | El temporal estaba en otro sistema de archivos | `mktemp "${destino}.XXXXXX"` |

---

[← Práctica 01: el modo estricto y sus agujeros](01-modo-estricto-y-sus-agujeros.md) · [Práctica 03: registro, `getopts` y concurrencia →](03-registro-getopts-y-concurrencia.md)
