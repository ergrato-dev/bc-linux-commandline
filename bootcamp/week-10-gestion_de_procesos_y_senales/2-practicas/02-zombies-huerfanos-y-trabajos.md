# Práctica 02: zombies, huérfanos y trabajos

Esta práctica reproduce, dentro de `ubuntu-lab`, un proceso zombie real,
por qué `kill` no tiene ningún efecto sobre él, y el uso de `jobs`/`disown`.

## Paso 1: Crear un zombie real

**Por qué**: ver el estado `Z` con tus propios ojos, no solo leerlo.

**Comando**:

```bash
cd ~/practica-wk10
perl -e 'my $p=fork(); if ($p==0){exit 0} else {sleep 3}' &
ppid=$!
sleep 0.3
zpid=$(ps --ppid "$ppid" -o pid= | tr -d ' ')
echo "zombie pid: $zpid"
ps -p "$zpid" -o pid,stat
```

**Verifica**:

```bash
ps -p "$zpid" -o stat=
# Z
```

## Paso 2: Confirmar que kill no tiene ningún efecto

**Por qué**: la lección central del archivo 02 de teoría, en carne
propia.

**Comando**:

```bash
kill -9 "$zpid"
echo "kill dijo exito: $?"
ps -p "$zpid" -o pid,stat
```

**Verifica**: `kill` reporta éxito (`0`), pero el STAT sigue siendo
`Z` — nada cambió de verdad.

```bash
ps -p "$zpid" -o stat=
# Z
```

## Paso 3: Jobs y disown

**Por qué**: distinguir "sacar de la lista de trabajos" de "matar el
proceso".

**Comando**:

```bash
sleep 60 &
jobs
disown %+
jobs
```

**Verifica**: antes de `disown`, `jobs` muestra el trabajo de `sleep`;
después, ya no aparece — pero el proceso sigue vivo.

```bash
pgrep -l sleep | grep -c "sleep$"
```

## Paso 4: SIGSTOP vs SIGTSTP en segundo plano

**Por qué**: reproducir la sutileza real del archivo 03 de teoría.

**Comando**:

```bash
sleep 60 & p1=$!
kill -TSTP "$p1"
ps -p "$p1" -o stat=

sleep 60 & p2=$!
kill -STOP "$p2"
ps -p "$p2" -o stat=
```

**Verifica**: `SIGTSTP` (primer caso) probablemente no cambia el
STAT (sigue `S`); `SIGSTOP` (segundo caso) sí lo cambia a `T`, sin
excepción.

```bash
kill -9 "$p1" "$p2" 2>/dev/null
```

## ✅ Resultado

- [ ] Creaste un proceso zombie real con el truco de `fork` + `exit` sin `wait`
- [ ] Confirmaste que `kill -9` sobre un zombie no cambia su estado
- [ ] Usaste `disown` para quitar un trabajo de `jobs` sin matar el proceso
- [ ] Reprodujiste la diferencia entre `SIGSTOP` y `SIGTSTP` en segundo plano

```bash
./scripts/verificar-semana.sh 10
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 1 no encuentra ningún zombie | El `perl` necesita el módulo de `fork` disponible, o el patrón `ps --ppid` no coincidió | Confirmar con `ps --ppid "$ppid"` solo (sin filtrar) que aparece algún hijo |
| El Paso 3 sigue mostrando el trabajo en `jobs` después de `disown` | El número de trabajo no era `%+` (el más reciente) | Confirmar con `jobs` cuál es el número correcto antes de `disown %N` |
| El Paso 4 muestra `T` para ambos casos | El contenedor tiene control de trabajos activo por alguna configuración previa | Revisar si `set -m` quedó activo de una sesión anterior con `shopt -o monitor` |

---

[← Práctica 01 — ps y estados de proceso](01-ps-y-estados-de-proceso.md) · [Práctica 03 →](03-senales-y-trap.md)
