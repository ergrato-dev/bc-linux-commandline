# Práctica 03: xargs seguro y en paralelo

Esta práctica reproduce, dentro de `ubuntu-lab`, cómo un nombre con
espacio rompe un pipeline sin protección, y mide la diferencia real del
paralelismo.

## Paso 1: Preparar archivos con nombres realistas

**Por qué**: nombres con espacios son normales en archivos reales
(fotos, documentos) — el primer paso es tenerlos para poder romper algo
a propósito.

**Comando**:

```bash
cd ~/practica-wk09c
mkdir -p fotos
touch "fotos/vacaciones playa.jpg" "fotos/cumpleanos.jpg"
ls fotos/
```

**Verifica**:

```bash
find fotos -type f | wc -l
# 2
```

## Paso 2: Reproducir la ruptura sin protección

**Por qué**: ver el error real antes de la corrección.

**Comando**:

```bash
find fotos -type f | xargs ls -la
```

**Verifica**: aparecen errores de "No such file or directory" para
fragmentos del nombre con espacio, no para el archivo completo.

```bash
find fotos -type f | xargs ls -la 2>&1 | grep -c "No such file"
# 2
```

## Paso 3: Corregir con `-print0`/`-0`

**Por qué**: la combinación segura, sin importar qué caracteres tenga
el nombre.

**Comando**:

```bash
find fotos -type f -print0 | xargs -0 ls -la
```

**Verifica**: ambos archivos aparecen completos, sin ningún error.

```bash
find fotos -type f -print0 | xargs -0 ls -la | wc -l
# 2
```

## Paso 4: Usar `-I` para ubicar el argumento en el medio

**Por qué**: copiar un archivo agregándole un sufijo necesita el nombre
dos veces — algo que `xargs` sin `-I` no puede hacer.

**Comando**:

```bash
find fotos -name "cumpleanos.jpg" -print0 | xargs -0 -I{} cp {} {}.copia
ls fotos/
```

**Verifica**:

```bash
ls fotos/ | grep -c "cumpleanos.jpg"
# 2
```

El original y la copia con sufijo `.copia`.

## Paso 5: Reproducir y corregir el gotcha de entrada vacía

**Por qué**: confirmar, una vez más, por qué `-r` es obligatorio en
cualquier pipeline `find | xargs` donde la entrada puede quedar vacía.

**Comando**:

```bash
mkdir -p fotos-vacio
find fotos-vacio -name "*.jpg" -print0 | xargs -0 echo "hash:"
find fotos-vacio -name "*.jpg" -print0 | xargs -r0 echo "hash:"
```

**Verifica**: el primer comando imprime `hash:` (el comando corrió con
cero argumentos); el segundo no imprime nada (no corrió en absoluto).

## Paso 6: Medir el paralelismo

**Por qué**: confirmar con `time`, no solo creer, que `-P` acelera
tareas independientes.

**Comando**:

```bash
time (seq 1 4 | xargs -I{} sleep 0.3)
time (seq 1 4 | xargs -P4 -I{} sleep 0.3)
```

**Verifica**: el primer tiempo real es cercano a `1.2s` (4 × 0.3);
el segundo, cercano a `0.3s` — las cuatro tareas corrieron a la vez.

## ✅ Resultado

- [ ] Reprodujiste cómo un nombre con espacio rompe `find | xargs` sin protección
- [ ] Corregiste con `-print0`/`-0`
- [ ] Usaste `-I` para ubicar el argumento en el medio de un comando
- [ ] Reprodujiste y corregiste el gotcha de entrada vacía con `-r`
- [ ] Mediste con `time` la diferencia entre secuencial y `-P4`

```bash
./scripts/verificar-semana.sh 09
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 no muestra ningún error | Los archivos del Paso 1 no tienen espacios en el nombre tal como se pidió | Recrear `fotos/` con los nombres exactos, incluidas las comillas en el `touch` |
| El Paso 4 no crea el archivo `.copia` | Falta `-I{}` o el marcador no coincide entre la bandera y el comando | Confirmar que `{}` aparece igual en `-I{}` y en ambos lugares del `cp {} {}.copia` |
| El Paso 6 no muestra una diferencia clara de tiempo | El sistema tiene muy pocos núcleos disponibles, o algo más está consumiendo CPU en simultáneo | Confirmar `nproc` (debería ser al menos 4 para ver la diferencia completa) y repetir la medición |

---

[← Práctica 02 — find avanzado, lógica y acciones](02-find-avanzado-logica-y-acciones.md) · [Práctica 04 →](04-finddupes-con-pipes-reales.md)
