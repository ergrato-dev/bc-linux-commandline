# Práctica 04: procwatch con pipes reales

Esta práctica construye **a mano**, paso por paso, la lógica exacta que
después vas a completar en el starter de `procwatch` — igual que la
Práctica 04 de las semanas anteriores. Si entiendes cada paso de aquí,
completar los `TODO` del starter es traducir esto a variables de bash.

## Paso 1: Lanzar un proceso y buscarlo

**Por qué**: el primer bloque del pipeline — encontrar coincidencias
por nombre, sin `-f`, igual que hace el starter.

**Comando**:

```bash
cd ~/practica-wk10
tail -f /dev/null &
sleep 0.3
procesos=$(pgrep -a tail)
echo "$procesos"
```

**Verifica**: al menos una línea con un PID y `tail -f /dev/null`.

## Paso 2: Contar coincidencias, protegido

**Por qué**: el mismo patrón `grep -c . || true` de las semanas
anteriores, para que una variable vacía no cuente como `1` línea ni
corte el script bajo `set -e`.

**Comando**:

```bash
total=$(printf '%s\n' "$procesos" | grep -c .) || true
echo "total=$total"
```

**Verifica**: un número mayor o igual a `1`.

## Paso 3: Clasificar cada PID por STAT

**Por qué**: el corazón de `procwatch` — antes de considerar cualquier
señal, saber si el PID sigue vivo.

**Comando**:

```bash
while read -r pid _; do
  stat=$(ps -p "$pid" -o stat= 2>/dev/null) || stat=""
  echo "PID $pid STAT $stat"
done < <(printf '%s\n' "$procesos")
```

**Verifica**: cada línea muestra un PID y su STAT — `Z` para zombies
que puedan existir de pruebas anteriores, `S`/`R` para el proceso que
acabas de lanzar.

## Paso 4: Decidir la acción según el STAT

**Por qué**: la lógica completa — zombie no recibe nada, proceso vivo
recibe el dry-run (o la señal real con `--apply`).

**Comando**:

```bash
senal="TERM"
aplicar=false
zombies=0
while read -r pid _; do
  stat=$(ps -p "$pid" -o stat= 2>/dev/null) || stat=""
  if [[ "$stat" == Z* ]]; then
    zombies=$(( zombies + 1 ))
    echo "zombie detectado: PID $pid"
  elif [[ -n "$senal" ]]; then
    if [[ "$aplicar" == true ]]; then
      kill -s "$senal" "$pid" 2>/dev/null || true
      echo "senal $senal enviada a PID $pid"
    else
      echo "dry-run: kill -s $senal $pid"
    fi
  fi
done < <(printf '%s\n' "$procesos")
echo "zombies encontrados: $zombies"
```

**Verifica**: cada zombie genera una línea de "zombie detectado"; el
proceso vivo genera una línea de "dry-run" (porque `aplicar=false`).

## Paso 5: La decisión final de código de salida

**Por qué**: convertir el conteo de zombies en una decisión binaria —
el mismo patrón de tres códigos de toda la semana.

**Comando**:

```bash
if [[ "$zombies" -gt 0 ]]; then
  echo "habria salida 2 (zombie encontrado)"
else
  echo "habria salida 0 (sin zombies)"
fi
```

## ✅ Resultado

- [ ] Buscaste procesos por nombre con `pgrep -a`, sin `-f`
- [ ] Contaste coincidencias protegido con `grep -c . || true`
- [ ] Clasificaste cada PID por STAT antes de considerar cualquier señal
- [ ] Decidiste dry-run vs señal real según `aplicar`, y zombie vs vivo según STAT
- [ ] Tradujiste el conteo de zombies a una decisión de código de salida

```bash
./scripts/verificar-semana.sh 10
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 1 no encuentra nada | El `tail -f /dev/null &` no se lanzó, o terminó antes de este paso | Relanzarlo en la misma sesión de shell, justo antes del Paso 1 |
| El Paso 4 no imprime ninguna línea de "zombie detectado" | No hay zombies `tail` en este momento del laboratorio (depende del historial de pruebas) | Normal si es la primera vez — el Paso 4 sigue siendo correcto, solo que no hay zombies que mostrar |
| El Paso 4 envía la señal de verdad en vez de dry-run | `aplicar` quedó en `true` de una prueba anterior en la misma sesión | Confirmar que `aplicar=false` se definió justo antes del bucle, en este mismo paso |

---

[← Práctica 03 — señales y trap](03-senales-y-trap.md) · [Proyecto: Capa 10 de toolkit →](../3-proyecto/README.md)
