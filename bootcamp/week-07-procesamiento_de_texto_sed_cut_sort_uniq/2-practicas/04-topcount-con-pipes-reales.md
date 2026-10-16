# Práctica 04: topcount con pipes reales

Esta práctica construye **a mano**, paso por paso, la lógica exacta que
después vas a completar en el starter de `topcount` — igual que la
Práctica 04 de las semanas 05 y 06 hizo con `logreport` y `logscan`. Si
entiendes cada paso de aquí, completar los `TODO` del starter es
traducir esto a variables de bash.

## Paso 1: Preparar un log con ruido real

**Por qué**: `topcount` tiene que ignorar comentarios y líneas vacías —
un archivo sin ninguno de los dos no probaría esa parte de la lógica.

**Comando**:

```bash
cd ~/practica-wk07
cat > eventos.log <<'EOF'
# log de eventos del sistema
root:login:ok

ROOT:logout:ok
admin:login:ok
root:login:ok
admin:login:fail
# fin de seccion
root:login:ok
EOF
cat eventos.log
```

**Verifica**:

```bash
wc -l eventos.log
# 8 eventos.log
```

Ocho líneas en total, pero solo seis son entradas válidas: dos son
comentarios, una está vacía.

## Paso 2: Contar las entradas válidas

**Por qué**: el primer número que reporta `topcount` — cuántas filas
reales hay para procesar, después de limpiar el ruido.

**Comando**:

```bash
total=$(sed '/^#/d; /^$/d' eventos.log | tr -s ':' | cut -d':' -f1 | tr '[:upper:]' '[:lower:]' | wc -l)
echo "total=$total"
```

**Verifica**:

```bash
echo "total=$total"
# total=6
```

Seis, no ocho — los comentarios y la línea vacía ya quedaron afuera.

## Paso 3: Armar la tabla de frecuencia completa

**Por qué**: el mismo pipeline del Paso 2, pero en vez de contar líneas
con `wc -l`, encadenarlo con `sort | uniq -c | sort -rn` para obtener el
ranking completo.

**Comando**:

```bash
tabla=$(sed '/^#/d; /^$/d' eventos.log | tr -s ':' | cut -d':' -f1 | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn)
echo "$tabla"
```

**Verifica**:

```bash
echo "$tabla"
#       4 root
#       2 admin
```

`root` y `ROOT` se normalizaron a la misma entrada (`4` en total);
`admin` aparece dos veces.

## Paso 4: Extraer el valor más frecuente con `read`

**Por qué**: la primera línea de la tabla trae el conteo y el valor
juntos, separados por espacios — `read` los separa en dos variables sin
necesitar `cut` ni parseo manual.

**Comando**:

```bash
read -r top1_count top1_valor <<< "$(echo "$tabla" | head -1)"
echo "count=$top1_count valor=$top1_valor"
```

**Verifica**:

```bash
echo "count=$top1_count valor=$top1_valor"
# count=4 valor=root
```

## Paso 5: La decisión final de dominancia

**Por qué**: convertir el conteo en una decisión binaria — el mismo
patrón de tres códigos de salida que ya usaste en `audit`, `logreport` y
`logscan`, aplicado ahora a un ranking de frecuencia.

**Comando**:

```bash
if (( top1_count * 2 > total )); then
  echo "DOMINA (exit 2)"
else
  echo "no domina (exit 0)"
fi
```

**Verifica**:

```bash
# con count=4 y total=6 del Paso 4:
# DOMINA (exit 2)
```

`4 * 2 = 8`, que es mayor que `6` — `root` aparece en más de la mitad de
las entradas válidas.

## ✅ Resultado

- [ ] Contaste las entradas válidas de un archivo con ruido (comentarios, líneas vacías)
- [ ] Armaste la tabla de frecuencia completa con el pipeline de siete pasos
- [ ] Separaste el conteo y el valor de la primera fila con `read`
- [ ] Tradujiste el conteo a una decisión de dominancia (`top1_count * 2 > total`)

```bash
./scripts/verificar-semana.sh 07
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 da `total=8` en vez de `6` | El `sed '/^#/d; /^$/d'` no se copió completo, o falta alguno de los dos patrones | Confirmar que el comando tiene ambos: `/^#/d` y `/^$/d`, separados por `;` |
| El Paso 4 separa mal `count` y `valor` | La línea de `$tabla` tiene espacios de más al principio (el formato de `uniq -c`) | `read` con espacios de separación maneja esto automáticamente — confirmar que no se usó `cut` en su lugar |
| El Paso 5 da el resultado contrario al esperado | Los valores de `top1_count` o `total` quedaron de una corrida anterior, no de los pasos de esta práctica | Repetir los Pasos 2 a 4 en orden, en la misma sesión de shell, antes del Paso 5 |

---

[← Práctica 03 — uniq y tr](03-uniq-y-tr.md) · [Proyecto: Capa 7 de toolkit →](../3-proyecto/README.md)
