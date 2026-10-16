# Práctica 04: sumfield con awk real

Esta práctica construye **a mano**, paso por paso, la lógica exacta que
después vas a completar en el starter de `sumfield` — igual que la
Práctica 04 de las semanas anteriores hizo con `logreport`, `logscan` y
`topcount`. Si entiendes cada paso de aquí, completar los `TODO` del
starter es traducir esto a variables de bash.

## Paso 1: Preparar un log de ventas con un dato corrupto

**Por qué**: `sumfield` tiene que detectar valores no numéricos, no
solo sumar — un archivo sin ninguno no probaría esa parte.

**Comando**:

```bash
cd ~/practica-wk08
cat > ventas.log <<'EOF'
norte:150
sur:200
norte:120
sur:300
centro:90
norte:abc
EOF
cat ventas.log
```

**Verifica**:

```bash
wc -l ventas.log
# 6 ventas.log
```

## Paso 2: Contar los valores no numéricos del campo

**Por qué**: el primer número que reporta `sumfield` — cuántas líneas
tienen, en el campo de valor, algo que no es un número.

**Comando**:

```bash
no_numericos=$(awk -F: -v campo=2 'NF>=campo && $campo !~ /^-?[0-9]+([.][0-9]+)?$/' ventas.log | wc -l)
echo "no_numericos=$no_numericos"
```

**Verifica**:

```bash
echo "no_numericos=$no_numericos"
# no_numericos=1
```

Solo `norte:abc` tiene un valor no numérico en el campo 2.

## Paso 3: Armar la tabla de suma por grupo

**Por qué**: el array asociativo que acumula por clave, excluyendo las
líneas con valor no numérico — el mismo patrón del archivo 02 de
teoría, combinado con la validación del archivo 03.

**Comando**:

```bash
tabla=$(awk -F: -v campo=2 -v grupo=1 '
  NF>=campo && NF>=grupo && $campo ~ /^-?[0-9]+([.][0-9]+)?$/ {
    suma[$grupo]+=$campo
  }
  END { for (k in suma) print suma[k], k }
' ventas.log | sort -rn)
echo "$tabla"
```

**Verifica**:

```bash
echo "$tabla"
#       500 sur
#       270 norte
#       90 centro
```

`norte` suma `270` (`150 + 120`), sin el valor corrupto de `norte:abc`.

## Paso 4: Calcular la suma total

**Por qué**: un segundo `awk`, más simple, sobre la primera columna de
la tabla ya armada.

**Comando**:

```bash
total=$(echo "$tabla" | awk '{s+=$1} END {print s+0}')
echo "total=$total"
```

**Verifica**:

```bash
echo "total=$total"
# total=860
```

`860 = 500 + 270 + 90` — la suma de las tres sumas por grupo.

## Paso 5: La decisión final de código de salida

**Por qué**: convertir el conteo de no numéricos en una decisión
binaria — el mismo patrón de tres códigos que ya usaste en `audit`,
`logreport`, `logscan` y `topcount`.

**Comando**:

```bash
if [[ "$no_numericos" -gt 0 ]]; then
  echo "habria salida 2 (valores no numericos encontrados)"
else
  echo "habria salida 0 (datos limpios)"
fi
```

**Verifica**:

```bash
# con no_numericos=1 del Paso 2:
# habria salida 2 (valores no numericos encontrados)
```

## ✅ Resultado

- [ ] Contaste los valores no numéricos del campo con un solo `awk`
- [ ] Armaste la tabla de suma por grupo, excluyendo las líneas inválidas
- [ ] Calculaste la suma total a partir de la tabla ya armada
- [ ] Tradujiste el conteo de no numéricos a una decisión de código de salida (0 o 2)

```bash
./scripts/verificar-semana.sh 08
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 da `no_numericos=0` | El archivo no tiene la línea `norte:abc` tal como en el Paso 1 | Recrear `ventas.log` exactamente como en el Paso 1 |
| El Paso 3 incluye `norte:abc` en la suma de `norte` | Falta la condición `$campo ~ /^-?[0-9]+([.][0-9]+)?$/` en el bloque de acumulación | Confirmar que la validación está en el mismo bloque que `suma[$grupo]+=$campo`, no solo en el conteo del Paso 2 |
| El Paso 4 da un total distinto a `860` | `$tabla` quedó de una corrida anterior con otros datos | Repetir los Pasos 2 y 3 en la misma sesión de shell antes del Paso 4 |

---

[← Práctica 03 — Validación y control de flujo](03-validacion-y-control-de-flujo.md) · [Proyecto: Capa 8 de toolkit →](../3-proyecto/README.md)
