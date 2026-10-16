# Práctica 04: logscan con pipes y regex reales

Esta práctica construye **a mano**, paso por paso, la lógica exacta que
después vas a completar en el starter de `logscan` — igual que la
Práctica 04 de la Semana 05 hizo con `logreport`. Si entiendes cada paso
de aquí, completar los `TODO` del starter es traducir esto a variables
de bash.

## Paso 1: Preparar un árbol de logs realista

**Por qué**: `logscan` tiene que distinguir archivos `.log` de otros
archivos, y recorrer subdirectorios — un solo archivo plano no alcanza
para probar eso.

**Comando**:

```bash
cd ~/practica-grep
rm -rf logs && mkdir -p logs/web logs/db logs/raro
printf "2026-10-15 09:00:00 INFO arranque web\n2026-10-15 09:00:05 ERROR 502 gateway\n2026-10-15 09:00:10 INFO ok\n" > logs/web/access.log
printf "2026-10-15 09:00:00 INFO conexion db\n2026-10-15 09:00:02 WARN pool casi lleno\n" > logs/db/db.log
printf "2026-10-15 09:00:00 INFO todo tranquilo\n" > logs/db/limpio.log
printf "esto no es un log, no deberia contarse\nERROR aunque diga error aca\n" > logs/raro/notas.txt
find logs -type f
```

**Verifica**:

```bash
find logs -type f | wc -l
# 4
```

Cuatro archivos: tres `.log` en dos subdirectorios distintos, y un `.txt`
que **contiene** la palabra `ERROR` pero no debería contar — exactamente
el caso que distingue a `logscan` de un `grep -r` sin filtrar.

## Paso 2: Contar archivos `.log`, sin mirar el contenido todavía

**Por qué**: el primer número que reporta `logscan` no necesita `grep` en
absoluto — solo necesita encontrar los archivos correctos.

**Comando**:

```bash
find logs -type f -name '*.log' | wc -l
```

**Verifica**:

```bash
find logs -type f -name '*.log' | wc -l
# 3
```

Tres, no cuatro — el `.txt` de `logs/raro/` queda afuera, aunque esté
dentro del árbol.

## Paso 3: Contar líneas coincidentes totales — y el gotcha de `pipefail`

**Por qué**: esta es la parte más delicada de todo `logscan`. `grep` sale
con código `1` cuando no encuentra nada (visto en el archivo 01 de
teoría) — y bajo `pipefail` (activo en todo `toolkit.sh` desde la Semana
05), ese `1` puede tirar abajo el pipeline completo aunque `wc -l` sí haya
funcionado.

**Comando**:

```bash
set -o pipefail
grep -rEh --include="*.log" "CRIT" logs | wc -l
echo "salida sin guardia: $?"
```

**Verifica**:

```bash
grep -rEh --include="*.log" "CRIT" logs | wc -l
# 0
echo "salida sin guardia: $?"
# salida sin guardia: 1
```

El número `0` es correcto — no hay ningún `CRIT` en estos logs — pero el
código de salida del pipeline completo es `1`, no `0`, porque `pipefail`
toma el código de salida de `grep` (que falló por no encontrar nada), no
el de `wc -l` (que sí tuvo éxito). Si esta línea estuviera dentro de
`toolkit.sh` (que corre con `set -euo pipefail`), el script entero
cortaría ahí, con un log perfectamente limpio.

**Comando** (la corrección):

```bash
total=$( { grep -rEh --include="*.log" "ERROR|WARN|CRIT" logs || true; } | wc -l )
echo "total=$total"
echo "salida con guardia: $?"
```

**Verifica**:

```bash
echo "total=$total"
# total=2
echo "salida con guardia: $?"
# salida con guardia: 0
```

El `|| true` **dentro** del grupo `{ ... ; }`, antes del pipe hacia
`wc -l`, absorbe el código `1` de `grep` ahí mismo — para cuando
`pipefail` evalúa el pipeline completo, `grep` ya "tuvo éxito" (gracias al
`|| true`), y el único código que importa es el de `wc -l`.

## Paso 4: Contar en cuántos archivos distintos hay coincidencias

**Por qué**: es un número distinto al del Paso 3 — no "cuántas líneas en
total", sino "en cuántos archivos al menos una vez". Usa `-l` (listar
archivos) en vez de `-h` (ocultar nombre de archivo).

**Comando**:

```bash
archivos=$( { grep -rEl --include="*.log" "ERROR|WARN|CRIT" logs || true; } | wc -l )
echo "archivos=$archivos"
```

**Verifica**:

```bash
echo "archivos=$archivos"
# archivos=2
```

Dos archivos (`access.log` y `db.log` tienen al menos una coincidencia;
`limpio.log` no tiene ninguna) — aunque el total de líneas coincidentes
del Paso 3 también dio un número cercano, miden cosas distintas, y con
más archivos "ruidosos" (varias coincidencias en el mismo archivo) los dos
números se separarían mucho más.

## Paso 5: Listar cada línea coincidente, con archivo y número de línea

**Por qué**: los dos números anteriores son el resumen; esto es el
detalle que permite ir directo a revisar el problema.

**Comando**:

```bash
grep -rEn --include="*.log" "ERROR|WARN|CRIT" logs || true
```

**Verifica**:

```bash
grep -rEn --include="*.log" "ERROR|WARN|CRIT" logs || true
# logs/db/db.log:2:2026-10-15 09:00:02 WARN pool casi lleno
# logs/web/access.log:2:2026-10-15 09:00:05 ERROR 502 gateway
```

El `|| true` acá cumple el mismo rol que en los pasos anteriores: sin él,
bajo `pipefail`, un árbol de logs completamente limpio haría fallar a todo
el script en esta línea, aunque "no encontrar nada" sea exactamente el
resultado esperado cuando todo está bien.

## Paso 6: La decisión final de código de salida

**Por qué**: `logscan` necesita convertir el número del Paso 3 en una
decisión binaria — el mismo patrón de tres códigos que ya usaste en
`audit` (Semana 04) y `logreport` (Semana 05), aplicado ahora a
coincidencias de regex en vez de permisos o líneas con `ERROR` de un solo
archivo.

**Comando**:

```bash
if [[ "$total" -gt 0 ]]; then
  echo "habria salida 2 (coincidencias encontradas)"
else
  echo "habria salida 0 (todo limpio)"
fi
```

**Verifica**:

```bash
# con total=2 del Paso 3:
# habria salida 2 (coincidencias encontradas)
```

## ✅ Resultado

- [ ] Contaste archivos `.log` recursivamente sin tocar su contenido
- [ ] Reprodujiste el fallo de `pipefail` con `grep -rEh | wc -l` sin coincidencias, y lo corregiste con `{ grep ... || true; } | wc -l`
- [ ] Contaste líneas coincidentes totales y archivos con coincidencias como dos números distintos
- [ ] Listaste cada coincidencia con archivo y número de línea, sin que un árbol limpio rompa el pipeline
- [ ] Tradujiste el conteo final a una decisión de código de salida (0 o 2)

```bash
./scripts/verificar-semana.sh 06
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 3 "sin guardia" no muestra el error de `pipefail` | `set -o pipefail` no quedó activo en la sesión actual, o se abrió una shell nueva entre pasos | Confirmar con `shopt -p pipefail` (o `set -o | grep pipefail`) que sigue activo antes de repetir el paso |
| `total` y `archivos` dan el mismo número siempre | Normal en este árbol de prueba, donde cada archivo con coincidencias tiene exactamente una — no es un error | Agregar una segunda línea con `ERROR` al mismo archivo y repetir ambos pasos para ver los números separarse |
| El Paso 5 no muestra ninguna línea aunque el Paso 3 dio `total > 0` | El patrón del Paso 5 no es exactamente el mismo que el del Paso 3 (mayúsculas, alternancia completa) | Copiar el patrón `"ERROR|WARN|CRIT"` igual en ambos pasos, carácter por carácter |

---

[← Práctica 03 — Límites de palabra, grep -P y búsqueda recursiva](03-limites-de-palabra-grep-perl-y-busqueda-recursiva.md) · [Proyecto: Capa 6 de toolkit →](../3-proyecto/README.md)
