# Práctica 06: `verify` y `selftest` a mano (2/2): comprobar y probar

> Rellenas los `TODO` 5 a 8 del `starter/toolkit.sh`: los seis chequeos de `release verify`, el caso de prueba, la maqueta y el `selftest` completo.
> Al terminar, el autograding de la semana pasa entero y tu `toolkit` puede probarse y comprobarse a sí mismo.

**Teoría de apoyo**: [05 · Probar una herramienta](../1-teoria/05-probar-una-herramienta.md) y [06 · Construir release y selftest](../1-teoria/06-construir-release-y-selftest.md).
**Duración estimada**: 1 h · **Entorno**: `ubuntu-lab`

Continúas donde acabó la [práctica 05](05-release-a-mano.md): `release build` ya funciona. Edita el `starter/` en tu **host** y llévalo al laboratorio con la misma función `entregar` (desde la raíz del repositorio):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh selftest; echo "codigo: $?"
# pruebas: 0, fallos: 0
# codigo: 0
```

El punto de partida de `selftest`: sin casos, «cero pruebas, cero fallos» y código `0`. Observa lo engañoso que es: **una autoprueba vacía siempre pasa**. Por eso los casos tienen que poder fallar.

Las pruebas usan un directorio que se rehace desde cero (solo borra bajo `/tmp/wk20`). Genera un paquete bueno con tu `release build`:

```bash
docker exec ubuntu-lab bash -c 'rm -rf /tmp/wk20 && mkdir -p /tmp/wk20/out && cd /tmp/wk20 \
  && /root/bin/toolkit.sh release build --out out --version 1.2.3'
# paquete: out/toolkit_1.2.3_all.deb
# sha256: <tu hash>
```

---

## Paso 1: TODO 5: `release_verify`

**Por qué**: es la herramienta que usará quien reciba tu paquete. Debe decir **todo** lo que está mal de una vez, no solo lo primero: por eso los chequeos no se cortan entre sí, salvo `paquete` cuando ni siquiera es un `.deb`. Cada chequeo detecta un defecto distinto (teoría 06, sección 2.4).

**Comando**: las piezas delicadas.

```bash
# suma: SHA256SUMS esta junto al paquete; la linea se busca por nombre exacto.
linea=$(awk -v f="$base" '$2 == f' "${dir}/SHA256SUMS")
(cd "$dir" && echo "$linea" | sha256sum -c --status -)

# version: la del nombre toolkit_VERSION_all.deb contra la del control.
if [[ "$base" =~ ^toolkit_(.+)_all\.deb$ ]]; then version_nombre=${BASH_REMATCH[1]}; fi

# permisos: caracteres 6 y 9 de la columna de permisos de "dpkg-deb -c".
awk 'substr($1, 6, 1) == "w" || substr($1, 9, 1) == "w" { print $NF }' <<<"$listado"
```

Escribe tú el resto, con `release_line ok NOMBRE` o `release_line falla NOMBRE DETALLE` y los **mensajes exactos** del `TODO`. `release_line` cuenta los fallos: tú no tocas ningún contador.

**Verifica**:

```bash
entregar
v() { docker exec ubuntu-lab bash -c "cd /tmp/wk20 && /root/bin/toolkit.sh release verify $*"; echo "  rc=$?"; }
v out/toolkit_1.2.3_all.deb
# ok suma
# ok paquete
# ok version
# ok ejecutable
# ok manual
# ok permisos
# fallos: 0
#   rc=0
v out/toolkit_1.2.3_all.deb --quiet
# fallos: 0
#   rc=0
```

Con `--quiet` los `ok` desaparecen y solo quedan los fallos y el resumen.

---

## Paso 2: Romper el paquete de cuatro maneras

**Por qué**: un verificador que solo ha visto paquetes buenos no demuestra nada. Estropea el paquete de varias formas y comprueba que cada chequeo salta **solo** cuando debe. Son pruebas de caso negativo, las mismas que protegen a `audit` y `harden`.

**Comando**: trabaja sobre copias en `/tmp/wk20`.

```bash
docker exec ubuntu-lab bash -c 'cd /tmp/wk20 && cp out/toolkit_1.2.3_all.deb t.deb
# 1. Manipulacion: cambia el archivo despues de construirlo.
mkdir a && cp out/SHA256SUMS a/ && cp t.deb a/toolkit_1.2.3_all.deb && echo x >> a/toolkit_1.2.3_all.deb
# 2. Renombrado: el nombre dice 9.9.9 y el control 1.2.3 (con su suma, para aislar el defecto).
mkdir b && cp t.deb b/toolkit_9.9.9_all.deb && (cd b && sha256sum toolkit_9.9.9_all.deb > SHA256SUMS)
# 3. Sin SHA256SUMS.
mkdir c && cp t.deb c/toolkit_1.2.3_all.deb
# 4. No es un .deb.
mkdir d && echo basura > d/toolkit_1.0.0_all.deb && (cd d && sha256sum toolkit_1.0.0_all.deb > SHA256SUMS)'
```

**Verifica**:

```bash
v a/toolkit_1.2.3_all.deb
# falla suma: la suma de toolkit_1.2.3_all.deb no coincide
# ok paquete
# ok version
# ok ejecutable
# ok manual
# ok permisos
# fallos: 1
#   rc=2
v b/toolkit_9.9.9_all.deb
# ok suma
# ok paquete
# falla version: el control dice '1.2.3' y el nombre '9.9.9'
# ok ejecutable
# ok manual
# ok permisos
# fallos: 1
#   rc=2
v c/toolkit_1.2.3_all.deb
# falla suma: no hay SHA256SUMS junto al paquete
# ...
# fallos: 1
#   rc=2
v d/toolkit_1.0.0_all.deb
# ok suma
# falla paquete: no es un .deb legible
# fallos: 1
#   rc=2
```

Cada rotura enciende **exactamente un** chequeo, y el del caso 4 corta tras `paquete`: no hay nada más que mirar. En la manipulación (caso 1) el resto siguen en `ok`: la suma detecta que el archivo cambió, y es la única que lo ve.

---

## Paso 3: TODO 6: `selftest_case`

**Por qué**: es el corazón del arnés que escribiste a mano en la práctica 04. Cada línea tiene un motivo: el subproceso aísla un `exit`, el `|| rc=$?` evita que `set -e` mate la autoprueba y el `>/dev/null 2>&1` oculta la salida de lo probado.

**Comando**: la pieza central.

```bash
( "$@" ) >/dev/null 2>&1 || rc=$?
```

Rellena tú el contador `ST_TOTAL`, el `ok` (que **no** se imprime con `ST_QUIET=1`) y el fallo (que se imprime **siempre** y suma a `ST_FAILS`).

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
ST_QUIET=0; ST_TOTAL=0; ST_FAILS=0
selftest_case a 0 true
selftest_case b 3 bash -c "exit 3"
selftest_case c 0 false
ST_QUIET=1
selftest_case d 0 true
selftest_case e 1 true
echo "total=$ST_TOTAL fails=$ST_FAILS"'
# ok a
# ok b
# falla c: esperaba 0, salio 1
# falla e: esperaba 1, salio 0
# total=5 fails=2
```

Fíjate en lo que **falta**: no sale `ok d`, porque `ST_QUIET=1` lo silencia, pero `falla e` sí sale. Un fallo nunca se oculta.

---

## Paso 4: TODO 7: `selftest_fixture`

**Por qué**: los casos necesitan datos concretos que **tú** controlas: no pueden depender de lo que haya en la máquina. La maqueta se crea en un directorio temporal único que `cmd_selftest` borrará al salir.

**Comando**: con `ST_DIR=$(mktemp -d)` crea las carpetas `audit`, `logs` y `src`, el archivo `audit/f` con modo `0777`, `logs/a.log`, `src/a.txt` y `bad.service`. Para el servicio sin endurecer:

```bash
printf '[Service]\nExecStart=/bin/true\n' > "$ST_DIR/bad.service"
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
selftest_fixture
(cd "$ST_DIR" && find . | LC_ALL=C sort)
stat -c "%a" "$ST_DIR/audit/f"
cat "$ST_DIR/logs/a.log" "$ST_DIR/src/a.txt" "$ST_DIR/bad.service"
rm -rf "$ST_DIR"'
# .
# ./audit
# ./audit/f
# ./bad.service
# ./logs
# ./logs/a.log
# ./src
# ./src/a.txt
# 777
# ERROR boom
# hola
# [Service]
# ExecStart=/bin/true
```

---

## Paso 5: TODO 8: `cmd_selftest`

**Por qué**: junta todo. Los cinco casos se lanzan siempre con `"$TK_SELF"` **como proceso aparte**: así pruebas el programa tal como lo ejecuta un usuario, no tus funciones. Y el `trap` borra la maqueta aunque algo falle.

**Comando**: las piezas delicadas.

```bash
selftest_fixture
trap 'rm -rf "${ST_DIR}"' EXIT
selftest_case audit-detecta-riesgo 2 "$TK_SELF" audit "$ST_DIR/audit"
...                                       # los otros cuatro, del TODO
echo "pruebas: ${ST_TOTAL}, fallos: ${ST_FAILS}"
```

`--quiet` se acepta; cualquier otra cosa sale con `toolkit selftest: opcion desconocida: X` y código `1`. Con algún fallo, la función termina con `exit 2`.

**Verifica**:

```bash
entregar
s() { docker exec ubuntu-lab /root/bin/toolkit.sh selftest "$@"; echo "  rc=$?"; }
s
s --quiet
s --zz
# ok audit-detecta-riesgo
# ok logscan-detecta-error
# ok backup-ida-y-vuelta
# ok harden-detecta-riesgos
# ok schedule-rechaza-expresion
# pruebas: 5, fallos: 0
#   rc=0
# pruebas: 5, fallos: 0
#   rc=0
# toolkit selftest: opcion desconocida: --zz
#   rc=1
docker exec ubuntu-lab bash -c 'ls -d /tmp/tmp.* 2>/dev/null | wc -l'
# 0
```

El último `0` confirma que el `trap` limpió la maqueta.

---

## Paso 6: Probar la propia prueba

**Por qué**: una autoprueba que nunca ha fallado no demuestra nada. Cambia el código esperado de un caso y comprueba que `selftest` lo delata y sale con `2`. Hazlo sobre una **copia** para no estropear tu `starter`.

**Comando**:

```bash
docker exec ubuntu-lab bash -c 'sed "s/schedule-rechaza-expresion 2/schedule-rechaza-expresion 0/" /root/bin/toolkit.sh > /tmp/wk20/roto.sh
chmod +x /tmp/wk20/roto.sh; /tmp/wk20/roto.sh selftest; echo "  rc=$?"'
```

**Verifica**:

```bash
# ok audit-detecta-riesgo
# ok logscan-detecta-error
# ok backup-ida-y-vuelta
# ok harden-detecta-riesgos
# falla schedule-rechaza-expresion: esperaba 0, salio 2
# pruebas: 5, fallos: 1
#   rc=2
```

---

## Paso 7: `shellcheck` y el autograding completo

**Por qué**: el último control antes de entregar. El `starter` debe seguir limpio de `shellcheck` y, con los cuatro `TODO` finales hechos, las dieciocho comprobaciones deben pasar.

**Comando**:

```bash
shellcheck bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh && echo limpio
entregar
bash scripts/verificar-semana.sh 20
```

**Verifica**:

```bash
# limpio
# 18/18 comprobaciones superadas.
```

---

## Paso 8: Limpiar

**Por qué**: deja el laboratorio como estaba.

> **Aviso**: `rm -rf` es destructivo. La ruta es solo `/tmp/wk20`.

**Comando**:

```bash
docker exec ubuntu-lab rm -rf /tmp/wk20
```

**Verifica**:

```bash
docker exec ubuntu-lab test ! -e /tmp/wk20 && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] `release verify` hace los seis chequeos, informa de todos los fallos y sale con `2` si hay alguno
- [ ] Comprobaste que cada defecto (manipulación, renombrado, sin sumas, no-`.deb`) enciende su chequeo
- [ ] `selftest_case` compara códigos, aísla el `exit` y no oculta un fallo ni con `--quiet`
- [ ] `selftest` ejecuta cinco casos, limpia su maqueta y sale con `0`, `1` o `2`
- [ ] Rompiste un caso a propósito y `selftest` lo delató
- [ ] `shellcheck` limpio y `verificar-semana.sh 20` en 18/18

```bash
bash scripts/verificar-semana.sh 20
# 18/18 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `verify` solo imprime el primer fallo | Haces `return` o `exit` tras cada `falla` | Solo `paquete` corta; los demás siguen |
| `ok suma` aunque manipulaste el `.deb` | Calculas la suma sobre otro archivo o con la ruta completa | `(cd "$dir" && … sha256sum -c --status -)` con el nombre sin ruta |
| `fallos: 0` pero hubo `falla` | No usas `release_line` para imprimir | Es la única función que cuenta |
| `falla ejecutable` en un paquete bueno | El `grep` busca `-rwxr-xr-x` sin anclar | Ancla con `^` y termina en `\./usr/bin/toolkit$` |
| `selftest` termina en el primer caso negativo | Falta `|| rc=$?` con `set -e` | Captura el código |
| `selftest` ejecuta pero no limpia `/tmp` | El `trap` está antes de `selftest_fixture` o falta | Instálalo justo después de crear la maqueta |
| `backup-ida-y-vuelta` falla | `selftest_backup` usa `ST_DIR` aún sin crear | Llama a `selftest_fixture` antes de los casos |
| `shellcheck` SC2034 en `ST_FAILS` | Declarada y aún no usada | Se usa en `selftest_case`: complétalo |

---

[← Práctica 05: `release` a mano](05-release-a-mano.md) · [Proyecto: toolkit integrado →](../3-proyecto/README.md)
