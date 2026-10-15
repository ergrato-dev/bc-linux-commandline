# Práctica 01: Crear archivos y directorios

Esta práctica te hace construir, dentro de `ubuntu-lab`, toda la estructura
de prueba que vas a usar en el resto de las prácticas de esta semana.

## Paso 1: Crear un árbol de proyecto completo en un solo comando

**Por qué**: entrenar el reflejo de `mkdir -p` con expansión de llaves,
antes de necesitarlo bajo presión.

**Comando**:

```bash
mkdir -p /tmp/wk03/{entrantes,procesados,respaldos}
ls /tmp/wk03
```

**Verifica**:

```bash
ls /tmp/wk03
# entrantes  procesados  respaldos
```

## Paso 2: Poblar `entrantes/` con archivos variados

**Por qué**: necesitas contenido real variado para que las prácticas
siguientes (copiar, mover, organizar) tengan sentido.

**Comando**:

```bash
cd /tmp/wk03/entrantes
touch factura-001.txt factura-002.txt reporte.csv notas.md script.sh
echo "contenido real" > factura-001.txt
ls -la
```

**Verifica**: cinco archivos listados, `factura-001.txt` con tamaño mayor a
0, el resto en 0 bytes.

## Paso 3: Confirmar que `touch` no borra contenido existente

**Por qué**: es el malentendido más común sobre `touch` — confirmarlo en
carne propia evita el error después.

**Comando**:

```bash
cat factura-001.txt
touch factura-001.txt
cat factura-001.txt
```

**Verifica**: el contenido es idéntico antes y después del segundo `touch`;
solo cambió la fecha de modificación.

## Paso 4: Reproducir por qué `mkdir` sin `-p` falla en la segunda corrida

**Por qué**: ver el error de primera mano fija mejor la lección que solo
leerla.

**Comando**:

```bash
mkdir /tmp/wk03/nueva
mkdir /tmp/wk03/nueva
# que error aparece?

mkdir -p /tmp/wk03/nueva
mkdir -p /tmp/wk03/nueva
# compara con el resultado anterior
```

**Verifica**: el segundo `mkdir` (sin `-p`) falla con "File exists"; ambas
corridas de `mkdir -p` terminan sin error.

## Paso 5: Crear un directorio con permisos exactos

**Por qué**: practicar `install -d` como alternativa a `mkdir` + `chmod`
por separado.

**Comando**:

```bash
install -d -m 750 /tmp/wk03/restringido
ls -ld /tmp/wk03/restringido
```

**Verifica**:

```bash
ls -ld /tmp/wk03/restringido
# drwxr-x--- ...
```

## ✅ Resultado

- [ ] Creaste un árbol de carpetas completo con `mkdir -p` y llaves en un solo comando
- [ ] Poblaste una carpeta con archivos variados, algunos vacíos y uno con contenido
- [ ] Confirmaste que `touch` sobre un archivo existente no toca su contenido
- [ ] Reprodujiste la diferencia entre `mkdir` y `mkdir -p` en una segunda corrida
- [ ] Creaste un directorio con permisos exactos usando `install -d`

```bash
./scripts/verificar-semana.sh 03
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `mkdir -p` también falla en la segunda corrida | Puede que el "directorio" ya exista como un archivo regular con ese nombre | `ls -la` para confirmar qué tipo de entrada ya ocupa ese nombre |
| `install -d` dice "command not found" | Paquete `coreutils` incompleto en una imagen muy mínima (poco común en `ubuntu-lab`) | Confirmar con `which install`; si falta, `mkdir` + `chmod` por separado logra lo mismo |
| Los archivos de prueba no aparecen donde esperabas | Quedaste parado en otro directorio después de un `cd` anterior | Confirmar con `pwd` antes de cada paso |

---

[← 06 — Patrones seguros para operaciones destructivas](../1-teoria/06-patrones-seguros-para-operaciones-destructivas.md) · [Práctica 02 →](02-copiar-archivos-y-directorios.md)
