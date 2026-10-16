# Práctica 03: uniq y tr

Esta práctica reproduce, dentro de `ubuntu-lab`, por qué `uniq` necesita
datos normalizados para contar bien, y el gotcha de `tr -c` con saltos
de línea.

## Paso 1: Preparar un log de sesiones con mayúsculas inconsistentes

**Por qué**: un dato real rara vez llega con el mismo formato siempre —
`CARLOS` y `carlos` son, en sentido lógico, el mismo usuario.

**Comando**:

```bash
cd ~/practica-wk07
cat > sesiones.log <<'EOF'
ana
ana
carlos
CARLOS
juan
juan
juan
EOF
cat sesiones.log
```

**Verifica**:

```bash
wc -l sesiones.log
# 7 sesiones.log
```

## Paso 2: Contar sin normalizar — el resultado está mal

**Por qué**: ver el problema antes de corregirlo. `uniq` compara texto
exacto; `carlos` y `CARLOS` no son la misma cadena.

**Comando**:

```bash
sort sesiones.log | uniq -c
```

**Verifica**: `carlos` aparece como dos entradas separadas (`1 carlos` y
`1 CARLOS`), en vez de una sola de `2`.

```bash
sort sesiones.log | uniq -c | grep -ci carlos
# 2
```

## Paso 3: Normalizar con `tr` antes de contar

**Por qué**: corregir el problema del Paso 2 con la herramienta que
corresponde — `tr` para normalizar caracteres, antes de `sort | uniq`.

**Comando**:

```bash
tr '[:upper:]' '[:lower:]' < sesiones.log | sort | uniq -c
```

**Verifica**:

```bash
tr '[:upper:]' '[:lower:]' < sesiones.log | sort | uniq -c | grep carlos
#       2 carlos
```

Ahora `carlos` cuenta como una sola entrada con frecuencia `2`.

## Paso 4: Reproducir el gotcha de `-c` con saltos de línea

**Por qué**: ver con tus propios ojos por qué `-c` sin pensar en `\n`
puede fusionar líneas — antes de que te pase sin darte cuenta en un
script real.

**Comando**:

```bash
printf 'hola123\nmundo456\n' | tr -sc '[:alpha:]' ' '
```

**Verifica**: las dos líneas originales (`hola123` y `mundo456`) se
fusionan en **una sola** línea de salida.

```bash
printf 'hola123\nmundo456\n' | tr -sc '[:alpha:]' ' ' | wc -l
# 0
```

`wc -l` cuenta `0` porque la salida no tiene ningún salto de línea real
— se perdió en el complemento.

## Paso 5: Corregir el gotcha agregando `\n` al set

**Por qué**: la corrección real — incluir explícitamente el salto de
línea en el set cuando se usa `-c`, para que no caiga en el complemento.

**Comando**:

```bash
printf 'hola123\nmundo456\n' | tr -sc '[:alpha:]\n' ' '
```

**Verifica**: ahora quedan dos líneas separadas, cada una con su
contenido alfabético intacto.

```bash
printf 'hola123\nmundo456\n' | tr -sc '[:alpha:]\n' ' ' | wc -l
# 2
```

## ✅ Resultado

- [ ] Reprodujiste por qué `uniq` sin normalizar cuenta `carlos`/`CARLOS` como valores distintos
- [ ] Corregiste el conteo normalizando con `tr` antes de `sort | uniq -c`
- [ ] Reprodujiste cómo `tr -sc` sin `\n` en el set fusiona líneas distintas en una sola
- [ ] Corregiste el gotcha agregando `\n` explícitamente al set de `-c`

```bash
./scripts/verificar-semana.sh 07
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 ya muestra `carlos` con conteo `2` | El archivo `sesiones.log` no tiene la mayúscula `CARLOS` tal como en el Paso 1 | Recrear el archivo exactamente como en el Paso 1, revisando mayúsculas con `cat -A` |
| El Paso 4 no fusiona las líneas | El patrón no incluye `-s`, o el shell interpretó mal las comillas de `tr` | Copiar el comando exacto, con `-sc` (ambas banderas juntas) y comillas simples alrededor de cada set |
| El Paso 5 sigue fusionando líneas | El `\n` dentro de las comillas simples no se interpretó como salto de línea | Confirmar que el set es `'[:alpha:]\n'` (con barra invertida n), no un salto de línea literal tecleado |

---

[← Práctica 02 — cut y sort con criterio](02-cut-y-sort-con-criterio.md) · [Práctica 04 →](04-topcount-con-pipes-reales.md)
