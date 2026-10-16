# Práctica 02: arrays asociativos y agrupación

Esta práctica reproduce, dentro de `ubuntu-lab`, el conteo por clave con
arrays asociativos, y el gotcha de crear una clave por accidente.

## Paso 1: Preparar un CSV de eventos de usuario

**Por qué**: un archivo con una cabecera y varias repeticiones del mismo
usuario deja probar el patrón de conteo por clave.

**Comando**:

```bash
cd ~/practica-wk08
cat > eventos.csv <<'EOF'
usuario,accion
ana,login
carlos,login
ana,logout
ana,login
carlos,fail
EOF
cat eventos.csv
```

**Verifica**:

```bash
wc -l eventos.csv
# 6 eventos.csv
```

## Paso 2: Contar eventos por usuario

**Por qué**: el patrón central del archivo 02 de teoría — un array
asociativo reemplaza `sort | uniq -c`, sin necesitar ordenar primero.

**Comando**:

```bash
awk -F, 'NR>1 { conteo[$1]++ } END { for (k in conteo) print conteo[k], k }' eventos.csv | sort -rn
```

**Verifica**:

```bash
awk -F, 'NR>1 { conteo[$1]++ } END { for (k in conteo) print conteo[k], k }' eventos.csv | sort -rn
# 3 ana
# 2 carlos
```

## Paso 3: Reproducir el gotcha de crear una clave por accidente

**Por qué**: ver con tus propios ojos cómo comparar directamente
`array[clave]` crea esa clave, antes de aprender a evitarlo.

**Comando**:

```bash
awk 'BEGIN {
  a["x"] = 1
  if (a["nueva"] == "") print "comparacion directa crea la clave"
  n = 0
  for (k in a) n++
  print "claves:", n
}'
```

**Verifica**:

```bash
# comparacion directa crea la clave
# claves: 2
```

Dos claves, aunque solo se asignó una — `a["nueva"]` se creó al
compararla, con valor vacío.

## Paso 4: Corregir con `in`

**Por qué**: la forma correcta de comprobar existencia, sin crear nada.

**Comando**:

```bash
awk 'BEGIN {
  a["x"] = 1
  if ("nueva" in a) print "existe"; else print "no existe"
  n = 0
  for (k in a) n++
  print "claves:", n
}'
```

**Verifica**:

```bash
# no existe
# claves: 1
```

Una sola clave — `in` comprobó sin crear.

## Paso 5: Borrar una clave con `delete`

**Por qué**: distinguir borrar de verdad de asignar un valor vacío.

**Comando**:

```bash
awk 'BEGIN {
  a["x"] = 1
  a["y"] = 2
  delete a["x"]
  for (k in a) print k
}'
```

**Verifica**:

```bash
# y
```

Solo queda `y` — `x` se eliminó del array, no quedó con valor vacío.

## ✅ Resultado

- [ ] Contaste ocurrencias por clave con un array asociativo, sin ordenar antes
- [ ] Reprodujiste cómo comparar `array[clave]` directamente crea esa clave
- [ ] Corregiste el gotcha con `"clave" in array`
- [ ] Borraste una clave con `delete`, confirmando que ya no aparece al recorrer el array

```bash
./scripts/verificar-semana.sh 08
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 cuenta la cabecera como un usuario más | Falta `NR>1` en el programa | Agregar `NR>1` como patrón antes del bloque de conteo |
| El Paso 3 muestra solo 1 clave, no 2 | El `awk` instalado optimiza distinto, o el programa se copió con una diferencia | Confirmar que la comparación es `a["nueva"] == ""`, no `"nueva" in a` (eso es el Paso 4) |
| El Paso 5 sigue mostrando `x` | El programa tiene un error de sintaxis en `delete a["x"]` | Confirmar que la línea es exactamente `delete a["x"]`, con los corchetes y las comillas |

---

[← Práctica 01 — awk básico](01-awk-basico-campos-y-filtros.md) · [Práctica 03 →](03-validacion-y-control-de-flujo.md)
