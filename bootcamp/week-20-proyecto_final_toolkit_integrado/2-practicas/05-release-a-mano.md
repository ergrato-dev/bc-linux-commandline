# Práctica 05: `release` a mano (1/2): entrada, validación y construcción

> Rellenas los `TODO` 1 a 4 del `release` del `starter/toolkit.sh`: leer opciones, validar, montar el árbol del paquete y construirlo con su `SHA256SUMS`.
> Tras cada paso compruebas lo añadido; al final, `toolkit release build` produce un `.deb` verificable.

**Teoría de apoyo**: [06 · Construir release y selftest](../1-teoria/06-construir-release-y-selftest.md) y [02 · Control, versión y numeración](../1-teoria/02-control-version-y-numeracion.md).
**Duración estimada**: 1 h · **Entorno**: `ubuntu-lab` (más `rhel-lab` para un caso)

Los `TODO` traen en su comentario **todos** los mensajes y reglas; aquí van las piezas difíciles. Edita el `starter/` en tu **host** y llévalo al laboratorio con esta función (desde la raíz del repositorio):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh release build --out /tmp --dry-run; echo "codigo: $?"
# codigo: 0
```

Es el punto de partida: las funciones son marcadores y por eso `release build` termina sin hacer nada y sin protestar. Desde el host usa `/root/bin`, **no** `~/bin`. Los pasos 2 a 4 se prueban con `source`, que carga las funciones sin ejecutar `main`.

Las pruebas usan un directorio que se rehace desde cero (solo borra bajo `/tmp/wk20`):

```bash
docker exec ubuntu-lab bash -c 'rm -rf /tmp/wk20 && mkdir -p /tmp/wk20/out'
```

---

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae `cmd_release` (el reparto: parsear, validar y llamar a `build` o a `verify`), `release_line` (la **única** función que imprime un chequeo de `verify` y los cuenta) y `release_manpage`. Y cada `TODO` trae sus mensajes exactos. No los inventes.

**Comando**: abre `starter/toolkit.sh` en el bloque de `release` y lee, sin tocar, `cmd_release`, `release_line` y `TK_SELF`. Fíjate en que `TK_SELF` es `readlink -f "${BASH_SOURCE[0]}"`: la ruta real del propio script, que es lo que `release_stage` empaquetará.

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh
# 8
```

---

## Paso 2: TODO 1: `release_parse`

**Por qué**: cada acción admite **solo** sus opciones: `--dry-run` en `verify` haría creer que ensaya algo que no ensaya. Los errores de uso salen **aquí**, antes de que otra función toque el disco. La pieza delicada es el `case` sobre `"${RL_ACTION}:$1"`, que distingue la misma opción según la acción.

**Comando**: un `while [[ $# -gt 0 ]]` con este `case`. Rellena tú los valores por defecto antes del bucle.

```bash
    case "${RL_ACTION}:$1" in
      build:--out | build:--version)
        if [[ $# -lt 2 ]]; then
          echo "${pre} $1 necesita un valor" >&2
          exit 1
        fi
        # ... guarda $2 en RL_OUT o en RL_VERSION segun $1, y "shift 2"
        ;;
      build:--dry-run) ... ;;
      verify:--quiet) ... ;;
      *:--*)            # cualquier otra opcion, valida en otra accion o no
        echo "${pre} opcion desconocida: $1" >&2
        exit 1
        ;;
      *)                # un posicional: solo el primero de verify
        ...
        ;;
    esac
```

El orden importa: `*:--*` va **después** de las opciones válidas, o las taparía; y el posicional va el último. `pre` es `toolkit release ${RL_ACTION}:`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
release_parse build --out /tmp/o --version 2.0.0 --dry-run
echo "[$RL_ACTION] out=$RL_OUT ver=$RL_VERSION dry=$RL_DRY quiet=$RL_QUIET pos=[$RL_POS]"
release_parse verify pkg.deb --quiet
echo "[$RL_ACTION] pos=$RL_POS quiet=$RL_QUIET"'
# [build] out=/tmp/o ver=2.0.0 dry=1 quiet=0 pos=[]
# [verify] pos=pkg.deb quiet=1
```

Y los cuatro errores de uso, cada uno con código 1:

```bash
for a in "build --zz" "build --out" "build extra" "verify --out x" "verify a b"; do
  docker exec ubuntu-lab bash -c "source /root/bin/toolkit.sh; release_parse $a"; echo "  ($a) rc=$?"
done
# toolkit release build: opcion desconocida: --zz
#   (build --zz) rc=1
# toolkit release build: --out necesita un valor
#   (build --out) rc=1
# toolkit release build: demasiados argumentos: extra
#   (build extra) rc=1
# toolkit release verify: opcion desconocida: --out
#   (verify --out x) rc=1
# toolkit release verify: demasiados argumentos: b
#   (verify a b) rc=1
```

---

## Paso 3: TODO 2: `release_prepare`

**Por qué**: valida **todo** antes de crear nada: si algo está mal, no debe quedar un directorio a medias. El **orden** de las comprobaciones es parte del contrato: `falta --out` antes que `version invalida`, y `falta dpkg-deb` la última, para que un error tuyo no se confunda con uno del entorno.

**Comando**: una expresión regular anclada en una variable **sin comillas**.

```bash
local re='^[0-9]+\.[0-9]+\.[0-9]+$'
if [[ ! "$RL_VERSION" =~ $re ]]; then
  echo "${pre} version invalida: ${RL_VERSION} (usa MAYOR.MENOR.PARCHE)" >&2
  exit 1
fi
```

Entre comillas, bash compararía la cadena literal y ninguna versión pasaría. Rellena el resto: `falta --out`, `no existe el directorio`, y las dos de `verify`.

**Verifica**:

```bash
entregar
p() { docker exec ubuntu-lab /root/bin/toolkit.sh "$@"; echo "  rc=$?"; }
p release build
p release build --out /tmp/wk20/out --version 1.0
p release build --out /tmp/wk20/nada
p release verify
p release verify /tmp/wk20/nada.deb
p release build --out /tmp/wk20/out --version 1.0.0
# toolkit release build: falta --out
#   rc=1
# toolkit release build: version invalida: 1.0 (usa MAYOR.MENOR.PARCHE)
#   rc=1
# toolkit release build: no existe el directorio: /tmp/wk20/nada
#   rc=1
# toolkit release verify: falta ARCHIVO
#   rc=1
# toolkit release verify: no existe el archivo: /tmp/wk20/nada.deb
#   rc=1
#   rc=0
```

La última sale con `0` y sin mensaje: la validación pasa y `release_build` aún no hace nada. Para el último caso, `falta dpkg-deb`, usa `rhel-lab`, que no lo trae:

```bash
docker cp bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh rhel-lab:/tmp/tk.sh
docker exec rhel-lab bash -c 'chmod +x /tmp/tk.sh; mkdir -p /tmp/o; /tmp/tk.sh release build --out /tmp/o; echo "rc=$?"'
# toolkit release build: falta dpkg-deb
# rc=1
```

---

## Paso 4: TODO 3: `release_stage`

**Por qué**: es la función que reproduce lo que hiciste a mano en la práctica 03: deja en un directorio el árbol exacto del paquete. Tres cosas fallan siempre: los permisos `0700` de `mktemp -d`, olvidarse de estampar la versión y un `md5sums` con rutas absolutas.

**Comando**: las piezas delicadas.

```bash
chmod 0755 "$dir"                                     # mktemp -d da 0700 y dpkg-deb lo rechaza
install -d -m 0755 "$dir/DEBIAN" "$dir/usr/bin" "$dir/usr/share/man/man1"
install -m 0755 "$TK_SELF" "$dir/usr/bin/toolkit"
# Estampa solo la linea TOOLKIT_VERSION de la COPIA, no de tu script:
sed -i "s/^TOOLKIT_VERSION=\".*\"\$/TOOLKIT_VERSION=\"${RL_VERSION}\"/" "$dir/usr/bin/toolkit"
release_manpage | gzip -9n > "$dir/usr/share/man/man1/toolkit.1.gz"
# Rutas relativas a $dir, orden fijo, seguro con espacios:
(cd "$dir" && find usr -type f -print0 | LC_ALL=C sort -z | xargs -0 md5sum) > "$dir/DEBIAN/md5sums"
```

Rellena tú el `chmod 0644` de la página de manual y el `control`, con el `Installed-Size` sacado de `du -sk`. La descripción extendida va con **un espacio** delante de cada línea.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
RL_VERSION=1.2.3
d=$(mktemp -d); release_stage "$d"
(cd "$d" && find . | LC_ALL=C sort)
cat "$d/DEBIAN/control"
"$d/usr/bin/toolkit" version
ls -l "$d/usr/share/man/man1/toolkit.1.gz" | cut -c1-10
dpkg-deb --build --root-owner-group "$d" /tmp/wk20/t.deb; echo "rc=$?"
rm -rf "$d"'
# .
# ./DEBIAN
# ./DEBIAN/control
# ./DEBIAN/md5sums
# ./usr
# ./usr/bin
# ./usr/bin/toolkit
# ./usr/share
# ./usr/share/man
# ./usr/share/man/man1
# ./usr/share/man/man1/toolkit.1.gz
# Package: toolkit
# Version: 1.2.3
# Architecture: all
# Maintainer: Toolkit <toolkit@example.invalid>
# Depends: bash (>= 5.0)
# Section: utils
# Priority: optional
# Installed-Size: 104
# Description: caja de herramientas personal de sysadmin
#  Subcomandos para inspeccionar, auditar y automatizar una maquina Linux
#  desde la linea de comandos.
# toolkit 1.2.3
# -rw-r--r--
# dpkg-deb: building package 'toolkit' in '/tmp/wk20/t.deb'.
# rc=0
```

`Installed-Size` será similar, no idéntico, al tuyo (depende del tamaño de tu script). Lo esencial: `toolkit 1.2.3` demuestra que la versión se **estampó** en la copia y que tu `~/bin/toolkit.sh` sigue diciendo `1.0.0`.

---

## Paso 5: TODO 4: `release_build`

**Por qué**: es donde el temporal, el `mv` y el `SHA256SUMS` idempotente se juntan. Cada decisión evita un fallo concreto: el `.deb` se escribe **dentro de `RL_OUT`** (para que `mv` sea atómico), el `trap` borra los temporales si algo falla y `trap - EXIT` los deja en paz si todo salió bien.

**Comando**: las piezas delicadas.

```bash
stage=$(mktemp -d)
tmp=$(mktemp "${RL_OUT}/.toolkit.XXXXXX")     # junto al destino: mv atomico
trap 'rm -rf "${stage}" "${tmp}"' EXIT
release_stage "$stage"
dpkg-deb --build --root-owner-group "$stage" "$tmp" >/dev/null
chmod 0644 "$tmp"
mv "$tmp" "$deb"
# SHA256SUMS: conserva las lineas de otros paquetes y sustituye la del actual.
awk -v f="$nombre" '$2 != f' "${RL_OUT}/SHA256SUMS" > "$sums"
echo "${hash}  ${nombre}" >> "$sums"          # dos espacios
trap - EXIT
```

El `awk` solo se ejecuta si `SHA256SUMS` ya existe (protégelo con un `if [[ -f … ]]`). El `--dry-run` es lo **primero** que haces en la función: imprime `[dry-run] paquete: RUTA` y vuelve sin crear nada, ni siquiera el directorio temporal.

**Verifica**:

```bash
entregar
r() { docker exec ubuntu-lab bash -c "cd /tmp/wk20 && /root/bin/toolkit.sh release build --out out $*"; }
r --version 1.2.3; echo "rc=$?"
docker exec ubuntu-lab bash -c 'ls -A /tmp/wk20/out; cd /tmp/wk20/out && sha256sum -c SHA256SUMS'
# paquete: out/toolkit_1.2.3_all.deb
# sha256: <tu hash, 64 caracteres hexadecimales>
# rc=0
# SHA256SUMS
# toolkit_1.2.3_all.deb
# toolkit_1.2.3_all.deb: OK
```

La ruta del paquete sale **tal como la escribiste** (`out/…`), sin normalizar. Ahora la idempotencia, otra versión y el ensayo:

```bash
r --version 1.2.3 >/dev/null; docker exec ubuntu-lab bash -c 'wc -l < /tmp/wk20/out/SHA256SUMS'
# 1
r --version 1.3.0 >/dev/null; docker exec ubuntu-lab bash -c 'wc -l < /tmp/wk20/out/SHA256SUMS; ls /tmp/wk20/out'
# 2
# SHA256SUMS
# toolkit_1.2.3_all.deb
# toolkit_1.3.0_all.deb
r --version 1.4.0 --dry-run; docker exec ubuntu-lab bash -c 'ls /tmp/wk20/out | wc -l'
# [dry-run] paquete: out/toolkit_1.4.0_all.deb
# 3
```

Reconstruir `1.2.3` no duplicó su línea (sigue habiendo **una**), añadir `1.3.0` la dejó en **dos**, y el ensayo no creó nada: siguen siendo tres entradas (`SHA256SUMS` y los dos `.deb`).

---

## Paso 6: Qué dice el autograding ahora

**Por qué**: con `build` hecho, ya pasan casi todos los chequeos de `release build` y los de regresión. Los de `verify` y `selftest` aún no: son la práctica 06. Ver cuáles pasan te confirma que tu trabajo encaja con el contrato.

**Comando**:

```bash
entregar
bash scripts/verificar-semana.sh 20
```

**Verifica**:

```bash
# 14/18 comprobaciones superadas.
# Pasan: sigue-ejecutable, shellcheck, las cuatro regresiones, version-imprime,
# los seis de release build y release-uso-invalido.
# Fallan: release-verify-ok, release-verify-detecta-manipulacion,
# selftest-pasa y selftest-detecta-fallo (las del paso siguiente).
```

Si un chequeo de `release build` falla, su pista te dice el paso de esta práctica que debes revisar.

---

## Paso 7: Limpiar

**Por qué**: deja el laboratorio como estaba.

> **Aviso**: `rm -rf` es destructivo. La ruta es solo `/tmp/wk20`.

**Comando**:

```bash
docker exec ubuntu-lab rm -rf /tmp/wk20
docker exec rhel-lab rm -rf /tmp/o /tmp/tk.sh
```

**Verifica**:

```bash
docker exec ubuntu-lab test ! -e /tmp/wk20 && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] `release_parse` acepta solo las opciones de cada acción y rechaza el resto con código 1
- [ ] `release_prepare` valida en el orden del contrato (y `falta dpkg-deb` se ve en `rhel-lab`)
- [ ] `release_stage` deja el árbol con permisos 755, la versión estampada y un `md5sums` relativo
- [ ] `release_build` crea `toolkit_V_all.deb` y su `SHA256SUMS` de forma idempotente
- [ ] `--dry-run` no escribe nada
- [ ] `shellcheck` sigue limpio sobre `starter/toolkit.sh`

```bash
shellcheck bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh && echo limpio
# limpio
bash scripts/verificar-semana.sh 20
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `dpkg-deb: error: control directory has bad permissions 700` | Falta `chmod 0755 "$dir"` en `release_stage` | Añádelo antes de los `install -d` |
| `version invalida` con una versión correcta | La regex va entre comillas | Quita las comillas de `$re` |
| El paquete dice `toolkit 1.0.0` pese a `--version 1.2.3` | No estampaste la versión con `sed` | Revisa el patrón `^TOOLKIT_VERSION=` |
| `SHA256SUMS` crece con cada construcción | No filtras la línea anterior | Usa `awk -v f=… '$2 != f'` antes de añadir |
| `sha256sum -c` dice `No such file` | Calculaste la suma con la ruta completa | Calcúlala desde `RL_OUT` con el nombre sin ruta |
| Quedan `.toolkit.XXXXXX` en `out/` | El `trap` no se instaló antes del trabajo | Pon el `trap` justo después de crear los temporales |
| El `.deb` desaparece tras un éxito | No quitaste el `trap` con `trap - EXIT` | Añade `trap - EXIT` al final |
| `shellcheck` SC2034 sobre una variable | Una variable global que aún no usas | Mantén el `: "${VAR}"` del marcador hasta usarla |

---

[← Práctica 04: Probar con un arnés de pruebas](04-probar-con-selftest.md) · [Práctica 06: `verify` y `selftest` a mano →](06-verify-y-selftest-a-mano.md)
