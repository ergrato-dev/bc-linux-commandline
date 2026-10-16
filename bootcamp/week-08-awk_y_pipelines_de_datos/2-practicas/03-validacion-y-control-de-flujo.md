# Práctica 03: validación y control de flujo

Esta práctica reproduce, dentro de `ubuntu-lab`, la coerción silenciosa
de `awk` ante datos no numéricos, y cómo clasificar líneas con `if`/`else if`.

## Paso 1: Preparar un archivo con datos mixtos

**Por qué**: necesitamos valores limpios, negativos, decimales y
corruptos en el mismo archivo para que cada paso tenga algo que
detectar.

**Comando**:

```bash
cd ~/practica-wk08
cat > montos.txt <<'EOF'
150
abc
42xyz
-30
3.5
EOF
cat montos.txt
```

**Verifica**:

```bash
wc -l montos.txt
# 5 montos.txt
```

## Paso 2: Validar qué líneas son puramente numéricas

**Por qué**: confirmar la expresión regular anclada antes de usarla
para decidir qué sumar.

**Comando**:

```bash
awk '$0 ~ /^-?[0-9]+([.][0-9]+)?$/ { print "valido:", $0 }' montos.txt
```

**Verifica**:

```bash
awk '$0 ~ /^-?[0-9]+([.][0-9]+)?$/ { print "valido:", $0 }' montos.txt | wc -l
# 3
```

Tres líneas válidas (`150`, `-30`, `3.5`); `abc` y `42xyz` quedan afuera.

## Paso 3: Reproducir la coerción silenciosa

**Por qué**: ver el resultado "incorrecto pero sin errores" antes de
corregirlo.

**Comando**:

```bash
awk '{ suma += $1 } END { print suma+0 }' montos.txt
```

**Verifica**:

```bash
awk '{ suma += $1 } END { print suma+0 }' montos.txt
# 165.5
```

`165.5` no es la suma real de los datos limpios — incluye `0` por
`abc` y `42` (no `42xyz` completo) por el parsing parcial. Sin ningún
error, el resultado está mal.

## Paso 4: Corregir, separando suma de datos descartados

**Por qué**: la corrección real — nunca reportar solo un total sin
decir cuántos datos se excluyeron.

**Comando**:

```bash
awk '{
  if ($0 ~ /^-?[0-9]+([.][0-9]+)?$/) { suma += $0; validos++ }
  else { invalidos++ }
}
END {
  print "suma:", suma+0
  print "validos:", validos+0
  print "invalidos:", invalidos+0
}' montos.txt
```

**Verifica**:

```bash
# suma: 123.5
# validos: 3
# invalidos: 2
```

`123.5` (`150 + -30 + 3.5`) es la suma real — y ahora se sabe que 2
líneas se descartaron.

## Paso 5: Clasificar con `if`/`else if`/`else`

**Por qué**: tres categorías mutuamente excluyentes, el patrón de
control de flujo del archivo 04 de teoría.

**Comando**:

```bash
awk '{
  if ($0 !~ /^-?[0-9]+([.][0-9]+)?$/) print $0, "invalido"
  else if ($0 < 0) print $0, "negativo"
  else print $0, "positivo"
}' montos.txt
```

**Verifica**:

```bash
# 150 positivo
# abc invalido
# 42xyz invalido
# -30 negativo
# 3.5 positivo
```

## ✅ Resultado

- [ ] Validaste líneas numéricas con una expresión regular anclada
- [ ] Reprodujiste la coerción silenciosa de un valor no numérico en una suma
- [ ] Corregiste la suma separando válidos de inválidos como conteos distintos
- [ ] Clasificaste líneas en tres categorías mutuamente excluyentes con `if`/`else if`/`else`

```bash
./scripts/verificar-semana.sh 08
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 3 da un número distinto a `165.5` | El archivo no tiene exactamente las 5 líneas del Paso 1, en ese orden | Recrear `montos.txt` desde cero con el heredoc del Paso 1 |
| El Paso 5 clasifica `-30` como `invalido` | La regex no incluye el signo negativo opcional (`-?`) | Confirmar que el patrón empieza con `^-?`, no solo `^` |
| El Paso 4 no imprime `invalidos: 2` | Falta el bloque `else` dentro de la regla, o el contador tiene un nombre distinto al usado en `END` | Confirmar que el nombre de la variable es idéntico en ambos bloques |

---

[← Práctica 02 — Arrays asociativos y agrupación](02-arrays-asociativos-y-agrupacion.md) · [Práctica 04 →](04-sumfield-con-awk-real.md)
