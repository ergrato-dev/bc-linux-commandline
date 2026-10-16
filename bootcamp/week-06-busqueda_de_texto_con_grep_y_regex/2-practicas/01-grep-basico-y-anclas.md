# Práctica 01: grep básico y anclas

Esta práctica reproduce, dentro de `ubuntu-lab`, las banderas esenciales de
`grep` y las anclas de línea contra un log sintético.

## Paso 1: Preparar un log de prueba

**Por qué**: todos los pasos siguientes necesitan un archivo con una
mezcla realista de líneas limpias y con error, mayúsculas y minúsculas
mezcladas a propósito.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
mkdir -p ~/practica-grep && cd ~/practica-grep
printf "2026-10-15 08:00:01 INFO arranque\n2026-10-15 08:00:02 ERROR disco lleno\n2026-10-15 08:00:03 error minuscula tambien\n2026-10-15 08:00:04 INFO reintentando\n2026-10-15 08:00:05 ERROR disco lleno otra vez\n2026-10-15 08:00:06 INFO ok de nuevo\n" > servidor.log
wc -l servidor.log
```

**Verifica**:

```bash
wc -l servidor.log
# 6 servidor.log
```

## Paso 2: `-c` cuenta líneas, no ocurrencias — confirmarlo con `-o`

**Por qué**: es el error más común al empezar con `grep -c`: asumir que
cuenta apariciones del patrón, cuando cuenta líneas que lo contienen al
menos una vez.

**Comando**:

```bash
grep -c "ERROR" servidor.log
grep -io "error" servidor.log | wc -l
```

**Verifica**:

```bash
grep -c "ERROR" servidor.log
# 2
grep -io "error" servidor.log | wc -l
# 3
```

`-c` da `2` (dos líneas con `ERROR` en mayúsculas exactas). `-io | wc -l`
da `3`: con `-i` también cuenta la línea con `error` en minúsculas, y con
`-o | wc -l` cuenta ocurrencias extraídas una por línea, no líneas
originales — en este archivo coinciden en valor porque cada línea tiene
una sola ocurrencia, pero el mecanismo que usa cada número es distinto.

## Paso 3: `-i` y `-v`, combinadas

**Por qué**: confirmar que `-i` ignora mayúsculas/minúsculas y que `-v`
invierte la selección, no solo leerlo en la teoría.

**Comando**:

```bash
grep -i "error" servidor.log
grep -v "INFO" servidor.log
```

**Verifica**: el primer comando muestra las tres líneas con `ERROR` o
`error` (sin distinguir caso); el segundo muestra las mismas tres líneas,
por el camino contrario — todo lo que **no** es `INFO`.

```bash
grep -i "error" servidor.log | wc -l
# 3
grep -v "INFO" servidor.log | wc -l
# 3
```

## Paso 4: `-l` y `-L` sobre varios archivos

**Por qué**: distinguir "qué archivos tienen el patrón" de "qué archivos
no lo tienen", sin leer el contenido de cada uno a mano.

**Comando**:

```bash
printf "INFO todo bien\nINFO sigue bien\n" > limpio.log
grep -l "ERROR" *.log
grep -L "ERROR" *.log
```

**Verifica**:

```bash
grep -l "ERROR" *.log
# servidor.log
grep -L "ERROR" *.log
# limpio.log
```

## Paso 5: Anclas `^` y `$` para validar formato, no solo buscar contenido

**Por qué**: un patrón sin anclas encuentra el texto en cualquier parte de
la línea — para confirmar que la línea **completa** cumple un formato,
hacen falta las dos anclas juntas.

**Comando**:

```bash
printf "192.168.1.1\n192.168.1.1 extra texto\nno es una ip\n" > ips.txt
grep "192.168.1.1" ips.txt
grep -E "^([0-9]{1,3}\.){3}[0-9]{1,3}$" ips.txt
```

**Verifica**: el primer `grep` muestra dos líneas (encuentra el texto
donde sea que aparezca); el segundo muestra **una sola**, la que es
puramente esa IP sin nada extra alrededor.

```bash
grep "192.168.1.1" ips.txt | wc -l
# 2
grep -E "^([0-9]{1,3}\.){3}[0-9]{1,3}$" ips.txt | wc -l
# 1
```

## Paso 6: El antipatrón de `ps aux | grep` y su corrección

**Por qué**: reproducir en carne propia por qué `ps aux | grep proceso`
casi siempre incluye una línea de más — el propio proceso `grep` buscando
ese texto. (Evitamos `sleep` como nombre de proceso en este paso a
propósito: el `PID 1` que mantiene vivo el contenedor del laboratorio ya
se llama `sleep infinity`, y contaminaría el conteo.)

**Comando**:

```bash
tail -f /dev/null &
ps aux | grep tail
ps aux | grep "[t]ail"
```

**Verifica**: el primer comando muestra dos líneas (el proceso `tail`
real y el proceso `grep tail` buscándose a sí mismo); el segundo muestra
solo una, el proceso `tail` real.

```bash
ps aux | grep tail | wc -l
# 2
ps aux | grep "[t]ail" | wc -l
# 1
```

El truco funciona porque la línea del propio `grep`, en `ps aux`, contiene
literalmente los caracteres `[t]ail` — con los corchetes de por medio, esa
línea ya no tiene la subcadena exacta `tail` seguida sin interrupción, así
que el patrón no se matchea a sí mismo.

Terminá el proceso de fondo antes de seguir:

```bash
kill %1
```

## ✅ Resultado

- [ ] Confirmaste que `-c` cuenta líneas, no ocurrencias, y usaste `-o | wc -l` para el total real
- [ ] Combinaste `-i` y `-v` contra el mismo archivo
- [ ] Distinguiste `-l` de `-L` sobre varios archivos a la vez
- [ ] Validaste un formato completo de línea con `^...$`, no solo buscaste contenido
- [ ] Reprodujiste y corregiste el antipatrón `ps aux | grep` matcheándose a sí mismo

```bash
./scripts/verificar-semana.sh 06
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `grep -c` y `grep -io \| wc -l` dan el mismo número siempre | Normal si cada línea tiene como máximo una ocurrencia del patrón — no es un error, es que este archivo no distingue ambos casos | Repetir el Paso 2 con una línea que tenga el patrón dos veces, como en la teoría |
| `ps aux \| grep "[t]ail"` sigue mostrando la línea de `grep` | El patrón entre corchetes no coincide exactamente con el nombre del proceso | Confirmar el nombre exacto del proceso con `ps aux \| grep tail` primero, y usar esa misma palabra entre corchetes |
| El proceso `tail` en segundo plano sigue vivo al final | El `kill %1` no se ejecutó, o el job no era `%1` | `jobs` para ver el número de job correcto, y `kill %N` con ese número |

---

[← 07 — Contexto, color y extracción con grep -o](../1-teoria/07-contexto-color-y-extraccion-con-grep-o.md) · [Práctica 02 →](02-regex-extendida-cuantificadores-y-alternancia.md)
