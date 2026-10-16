# Práctica 01: ps y estados de proceso

Esta práctica reproduce, dentro de `ubuntu-lab`, la lectura de columnas
de `ps`, el cambio de STAT con `SIGSTOP`/`SIGCONT`, y la jerarquía de
procesos.

## Paso 1: Lanzar un proceso y leer sus columnas básicas

**Por qué**: confirmar PID, PPID, STAT y CMD de un proceso real antes
de hacer nada con él.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
mkdir -p ~/practica-wk10 && cd ~/practica-wk10
sleep 60 &
p=$!
ps -p "$p" -o pid,ppid,stat,cmd
```

**Verifica**:

```bash
ps -p "$p" -o stat=
# S
```

## Paso 2: Pausar y reanudar con SIGSTOP/SIGCONT

**Por qué**: confirmar que el STAT cambia de verdad, no solo en teoría.

**Comando**:

```bash
kill -STOP "$p"
ps -p "$p" -o pid,stat
```

**Verifica**:

```bash
ps -p "$p" -o stat=
# T
```

```bash
kill -CONT "$p"
ps -p "$p" -o stat=
# S
```

## Paso 3: Visualizar la jerarquía de procesos

**Por qué**: ver la relación padre-hijo con indentación, no solo
números de PID sueltos.

**Comando**:

```bash
ps -ejH | head -5
```

**Verifica**: tu propio `bash` aparece, y `sleep` (si sigue vivo)
aparece indentado debajo, como su hijo.

```bash
ps -ejH | grep -A1 "bash$" | head -2
```

## Paso 4: Buscar por nombre con pgrep, y el límite de 15 caracteres

**Por qué**: confirmar el límite real del kernel, no solo leerlo.

**Comando**:

```bash
pgrep sleep
pgrep nombre-de-proceso-mas-largo-que-quince
```

**Verifica**: el primer comando encuentra el PID; el segundo muestra
la advertencia de `pgrep` sobre el límite de 15 caracteres.

```bash
pgrep nombre-de-proceso-mas-largo-que-quince 2>&1 | grep -c "15 characters"
# 1
```

## ✅ Resultado

- [ ] Leíste PID, PPID, STAT y CMD de un proceso real con `ps`
- [ ] Cambiaste el STAT entre `S` y `T` con `SIGSTOP`/`SIGCONT`
- [ ] Visualizaste la jerarquía de procesos con `ps -ejH`
- [ ] Reprodujiste el límite de 15 caracteres de `pgrep` sin `-f`

```bash
./scripts/verificar-semana.sh 10
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 no muestra `T` | El PID capturado en `$p` ya no corresponde al `sleep` lanzado (se perdió la variable entre pasos) | Relanzar `sleep 60 &` y volver a capturar `p=$!` en la misma sesión de shell |
| El Paso 3 no muestra ningún proceso indentado | El `sleep` del Paso 1 ya terminó o fue matado antes de este paso | Lanzar un nuevo `sleep 60 &` antes de este paso si hace falta |
| El Paso 4 no muestra la advertencia | El patrón tiene 15 caracteres o menos | Contar los caracteres del patrón exacto del paso, o usar uno más largo |

---

[← 07 — Construyendo procwatch](../1-teoria/07-construyendo-procwatch-deteccion-y-senales.md) · [Práctica 02 →](02-zombies-huerfanos-y-trabajos.md)
