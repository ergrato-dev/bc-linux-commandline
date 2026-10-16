# Práctica 03: señales y trap

Esta práctica reproduce, dentro de `ubuntu-lab`, la diferencia entre
`SIGTERM` (ignorable) y `SIGKILL` (nunca), el código de salida `128+N`,
y la garantía de `trap ... EXIT`.

## Paso 1: SIGTERM se puede ignorar, SIGKILL no

**Por qué**: confirmar en carne propia la diferencia central del
archivo 04 de teoría.

**Comando**:

```bash
cd ~/practica-wk10
bash -c 'trap "" TERM; sleep 60' &
p=$!
sleep 0.2
kill -TERM "$p"
sleep 0.2
kill -0 "$p" 2>/dev/null; echo "vivo tras TERM: $?"
```

**Verifica**:

```bash
# vivo tras TERM: 0
```

El proceso ignoró `SIGTERM` (por el `trap "" TERM`) y sigue vivo.

```bash
kill -KILL "$p"
sleep 0.2
kill -0 "$p" 2>/dev/null; echo "vivo tras KILL: $?"
```

**Verifica**:

```bash
# vivo tras KILL: 1
```

`SIGKILL` no se puede ignorar — el proceso ya no existe.

## Paso 2: El código de salida 128+N

**Por qué**: confirmar el cálculo exacto, no solo creerlo.

**Comando**:

```bash
sleep 60 & p2=$!
kill -TERM "$p2"
wait "$p2" 2>/dev/null
echo "codigo: $?"
```

**Verifica**:

```bash
# codigo: 143
```

`143 = 128 + 15` (`SIGTERM`).

## Paso 3: trap EXIT corre incluso bajo set -e

**Por qué**: la garantía central del archivo 05 de teoría, aplicada a
un script que falla a mitad de camino.

**Comando**:

```bash
bash -c 'set -e; trap "echo LIMPIEZA" EXIT; echo antes; false; echo nunca'
```

**Verifica**: se imprime `antes` y `LIMPIEZA`, pero nunca `nunca` — el
trap corrió a pesar de que `false` cortó el script.

```bash
bash -c 'set -e; trap "echo LIMPIEZA" EXIT; echo antes; false; echo nunca' 2>&1 | grep -c LIMPIEZA
# 1
```

## Paso 4: Capturar una señal específica sin terminar el script

**Por qué**: confirmar que un trap reemplaza la acción por defecto, no
solo la retrasa.

**Comando**:

```bash
trap 'echo atrape una senal' TERM
( sleep 0.3; kill -TERM $$ ) &
sleep 1
echo "el script sigue vivo despues del trap"
```

**Verifica**:

```bash
# atrape una senal
# el script sigue vivo despues del trap
```

## ✅ Resultado

- [ ] Confirmaste que `SIGTERM` se puede ignorar con un `trap "" TERM`
- [ ] Confirmaste que `SIGKILL` nunca se puede ignorar
- [ ] Calculaste el código de salida `128+N` a partir de una señal real
- [ ] Confirmaste que `trap ... EXIT` corre incluso cuando `set -e` corta el script
- [ ] Capturaste una señal específica y confirmaste que el script sigue vivo después

```bash
./scripts/verificar-semana.sh 10
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 1 muestra el proceso muerto tras `SIGTERM` | El `trap "" TERM` no se copió exactamente (comillas vacías, no un comando) | Confirmar que el `trap` usa dos comillas vacías `""`, no un comando dentro |
| El Paso 2 da un código distinto a 143 | El PID capturado en `$p2` no corresponde al `sleep` recién lanzado | Relanzar `sleep 60 &` y capturar `p2=$!` en la misma sesión |
| El Paso 4 no imprime "atrape una senal" | El `kill -TERM $$` se envió antes de que el `trap` quedara registrado | Confirmar que el `trap` se ejecuta como comando separado, antes del subshell que envía la señal |

---

[← Práctica 02 — zombies, huérfanos y trabajos](02-zombies-huerfanos-y-trabajos.md) · [Práctica 04 →](04-procwatch-con-pipes-reales.md)
