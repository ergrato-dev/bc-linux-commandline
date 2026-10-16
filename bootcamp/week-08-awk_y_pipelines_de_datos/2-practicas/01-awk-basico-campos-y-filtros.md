# Práctica 01: awk básico, campos y filtros

Esta práctica reproduce, dentro de `ubuntu-lab`, el acceso a campos,
`NF`, `NR` y el filtrado por condición numérica de `awk`.

## Paso 1: Preparar un archivo de procesos simulado

**Por qué**: un archivo con columnas de texto y de número deja probar
filtros de ambos tipos.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
mkdir -p ~/practica-wk08 && cd ~/practica-wk08
cat > procesos.txt <<'EOF'
root 1 0.0 init
usuario 1234 2.5 firefox
usuario 1235 15.0 chrome
root 42 0.1 sshd
EOF
cat procesos.txt
```

**Verifica**:

```bash
wc -l procesos.txt
# 4 procesos.txt
```

## Paso 2: Extraer campos específicos

**Por qué**: confirmar `$1`, `$N` básico antes de combinarlo con
condiciones.

**Comando**:

```bash
awk '{ print $1, $4 }' procesos.txt
```

**Verifica**:

```bash
awk '{ print $1, $4 }' procesos.txt | head -1
# root init
```

## Paso 3: Confirmar `NF` en cada línea

**Por qué**: ver que `NF` se calcula línea por línea, no una sola vez
para todo el archivo.

**Comando**:

```bash
awk '{ print NF }' procesos.txt
```

**Verifica**: las cuatro líneas imprimen `4` (todas tienen el mismo
número de columnas en este archivo).

```bash
awk '{ print NF }' procesos.txt | sort -u
# 4
```

## Paso 4: Filtrar por una condición numérica

**Por qué**: esto es lo que ningún comando de la semana pasada podía
hacer solo — comparar un valor numérico de una columna, no solo
extraerla.

**Comando**:

```bash
awk '$3 > 1.0 { print $4, $3 }' procesos.txt
```

**Verifica**:

```bash
awk '$3 > 1.0 { print $4, $3 }' procesos.txt | wc -l
# 2
```

Solo `firefox` y `chrome` superan `1.0` en la tercera columna.

## Paso 5: Numerar líneas con `NR`

**Por qué**: confirmar que `awk` puede reemplazar `cat -n` sin ningún
comando adicional.

**Comando**:

```bash
awk '{ print NR": "$0 }' procesos.txt
```

**Verifica**:

```bash
awk '{ print NR": "$0 }' procesos.txt | head -1
# 1: root 1 0.0 init
```

## ✅ Resultado

- [ ] Extrajiste campos específicos con `$1`, `$N`
- [ ] Confirmaste que `NF` se calcula por línea, no por archivo
- [ ] Filtraste líneas por una condición numérica sobre una columna
- [ ] Numeraste líneas con `NR`, sin usar `cat -n`

```bash
./scripts/verificar-semana.sh 08
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 4 no filtra nada | La comparación usa comillas alrededor del número (`"$3 > '1.0'"`), forzando comparación de texto | Escribir el número sin comillas: `$3 > 1.0` |
| El Paso 2 imprime columnas de más o de menos | El archivo tiene espacios irregulares entre columnas | Confirmar con `cat -A procesos.txt` que no hay tabs mezclados con espacios |
| `NF` da un número distinto en alguna línea | El archivo de prueba no se copió exactamente como en el Paso 1 | Recrear `procesos.txt` desde cero con el heredoc del Paso 1 |

---

[← 07 — awk como pipeline completo](../1-teoria/07-awk-como-pipeline-completo.md) · [Práctica 02 →](02-arrays-asociativos-y-agrupacion.md)
