# Práctica 02: find avanzado, lógica y acciones

Esta práctica reproduce, dentro de `ubuntu-lab`, la combinación de
criterios con `-o`/`-not`, y las acciones `-exec`/`-delete`.

## Paso 1: Preparar archivos de respaldo y temporales

**Por qué**: dos extensiones distintas, una de ellas repetida dentro de
un subdirectorio, dejan probar alternancia y exclusión por ruta.

**Comando**:

```bash
cd ~/practica-wk09c
mkdir -p proyecto/respaldo
touch proyecto/a.bak proyecto/b.tmp proyecto/respaldo/c.bak
find proyecto -type f
```

**Verifica**:

```bash
find proyecto -type f | wc -l
# 8
```

## Paso 2: Combinar dos extensiones con `-o`, agrupadas

**Por qué**: confirmar que la agrupación con `\( \)` es necesaria para
que `-o` funcione como se espera junto a otro criterio.

**Comando**:

```bash
find proyecto -type f \( -name "*.bak" -o -name "*.tmp" \)
```

**Verifica**:

```bash
find proyecto -type f \( -name "*.bak" -o -name "*.tmp" \) | wc -l
# 3
```

## Paso 3: Excluir una carpeta con `-not -path`

**Por qué**: distinguir `.bak`/`.tmp` en general de "los que están
afuera de `respaldo/`" en particular.

**Comando**:

```bash
find proyecto -type f \( -name "*.bak" -o -name "*.tmp" \) -not -path "*/respaldo/*"
```

**Verifica**:

```bash
find proyecto -type f \( -name "*.bak" -o -name "*.tmp" \) -not -path "*/respaldo/*" | wc -l
# 2
```

El `.bak` dentro de `respaldo/` queda afuera del resultado.

## Paso 4: `-exec` uno por uno, y después en lote

**Por qué**: ver la diferencia de cantidad de invocaciones entre `\;` y
`+`.

**Comando**:

```bash
find proyecto -name "*.bak" -exec echo "uno por uno:" {} \;
find proyecto -name "*.bak" -exec echo "en lote:" {} +
```

**Verifica**: el primer comando imprime dos líneas (una por archivo
`.bak`); el segundo imprime **una sola** línea con ambos archivos.

```bash
find proyecto -name "*.bak" -exec echo "uno por uno:" {} \; | wc -l
# 2
find proyecto -name "*.bak" -exec echo "en lote:" {} + | wc -l
# 1
```

## Paso 5: Previsualizar antes de `-delete`

**Por qué**: la misma disciplina de la Semana 03 — nunca `-delete`
directo sin haber visto antes qué va a borrar.

**Comando**:

```bash
find proyecto -maxdepth 1 -name "*.tmp"
find proyecto -maxdepth 1 -name "*.tmp" -delete
find proyecto -maxdepth 1 -name "*.tmp"
```

**Verifica**: la primera búsqueda muestra `proyecto/b.tmp`; después de
`-delete`, la misma búsqueda no muestra nada.

```bash
find proyecto -maxdepth 1 -name "*.tmp" | wc -l
# 0
```

## ✅ Resultado

- [ ] Combinaste dos criterios con `-o`, agrupados con `\( \)`
- [ ] Excluiste una ruta con `-not -path`
- [ ] Confirmaste que `-exec ... \;` genera una invocación por archivo, y `-exec ... +` una sola en lote
- [ ] Previsualizaste con `find` simple antes de aplicar `-delete`

```bash
./scripts/verificar-semana.sh 09
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 cuenta más o menos de 3 | El árbol no tiene exactamente los tres archivos del Paso 1 | Recrear `proyecto/a.bak`, `proyecto/b.tmp` y `proyecto/respaldo/c.bak` desde cero |
| El Paso 3 no excluye el archivo de `respaldo/` | El patrón de `-path` no coincide exactamente (falta un `/` al principio o al final) | Confirmar que el patrón es `"*/respaldo/*"`, con barras en ambos extremos |
| El Paso 5 no borra nada | El comando se corrió sin `-delete`, solo la previsualización | Agregar `-delete` al final del mismo comando exacto que ya se previsualizó |

---

[← Práctica 01 — find básico y criterios](01-find-basico-y-criterios.md) · [Práctica 03 →](03-xargs-seguro-y-en-paralelo.md)
