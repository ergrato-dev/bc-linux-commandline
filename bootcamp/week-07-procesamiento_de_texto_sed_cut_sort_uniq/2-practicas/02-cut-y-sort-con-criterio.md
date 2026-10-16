# Práctica 02: cut y sort con criterio

Esta práctica reproduce, dentro de `ubuntu-lab`, extracción de columnas y
ordenamiento con distintos criterios contra un CSV de prueba.

## Paso 1: Preparar un CSV de prueba

**Por qué**: un archivo con cabecera y varias columnas numéricas y de
texto deja probar `cut` y `sort` en combinaciones realistas.

**Comando**:

```bash
cd ~/practica-wk07
cat > usuarios.csv <<'EOF'
nombre,edad,ciudad
ana,25,cordoba
carlos,40,rosario
juan,30,caba
beatriz,22,cordoba
EOF
cat usuarios.csv
```

**Verifica**:

```bash
wc -l usuarios.csv
# 5 usuarios.csv
```

## Paso 2: Extraer columnas específicas

**Por qué**: confirmar `-f` con una lista de columnas, no solo una.

**Comando**:

```bash
cut -d, -f1,3 usuarios.csv
```

**Verifica**:

```bash
cut -d, -f1,3 usuarios.csv | head -1
# nombre,ciudad
```

## Paso 3: Quitar la cabecera antes de ordenar

**Por qué**: ordenar un CSV con `sort` directo también ordenaría la fila
de cabecera como si fuera un dato más — `tail -n +2` la descarta primero.

**Comando**:

```bash
tail -n +2 usuarios.csv | sort -t, -k2,2n
```

**Verifica**: el resultado queda ordenado por edad, de menor a mayor, sin
la fila `nombre,edad,ciudad`.

```bash
tail -n +2 usuarios.csv | sort -t, -k2,2n | head -1
# beatriz,22,cordoba
```

## Paso 4: Orden descendente por columna numérica

**Por qué**: combinar `-r` (reverso) con `-k`/`-n` (columna numérica) en
un solo criterio, y limitar el resultado con `head`.

**Comando**:

```bash
tail -n +2 usuarios.csv | sort -t, -k2,2rn | head -2
```

**Verifica**:

```bash
tail -n +2 usuarios.csv | sort -t, -k2,2rn | head -1
# carlos,40,rosario
```

## Paso 5: Ranking de frecuencia por columna

**Por qué**: el mismo patrón `cut | sort | uniq -c | sort -rn` del
proyecto de esta semana, aplicado a una columna de texto en vez de un
log.

**Comando**:

```bash
tail -n +2 usuarios.csv | cut -d, -f3 | sort | uniq -c | sort -rn
```

**Verifica**:

```bash
tail -n +2 usuarios.csv | cut -d, -f3 | sort | uniq -c | sort -rn | head -1
#       2 cordoba
```

`cordoba` aparece dos veces (ana y beatriz); las otras dos ciudades,
una vez cada una.

## ✅ Resultado

- [ ] Extrajiste dos columnas no consecutivas con `cut -d, -f1,3`
- [ ] Quitaste una cabecera con `tail -n +2` antes de ordenar
- [ ] Ordenaste por una columna numérica, ascendente y descendente
- [ ] Construiste un ranking de frecuencia por columna con `cut | sort | uniq -c | sort -rn`

```bash
./scripts/verificar-semana.sh 07
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 3 ordena mal (texto, no números) | Falta la `n` al final de `-k2,2` | `sort -t, -k2,2n`, con la `n` pegada al cierre de la clave |
| La cabecera aparece mezclada en el resultado ordenado | Se usó `sort` directo sobre `usuarios.csv`, sin `tail -n +2` antes | Siempre descartar la cabecera antes de ordenar un CSV con datos numéricos |
| El Paso 5 da un número distinto a 2 para `cordoba` | El CSV de prueba no coincide exactamente con el del Paso 1 (edición manual, líneas de más) | Recrear `usuarios.csv` exactamente como en el Paso 1 antes de repetir |

---

[← Práctica 01 — sed, sustitución y direcciones](01-sed-sustitucion-y-direcciones.md) · [Práctica 03 →](03-uniq-y-tr.md)
