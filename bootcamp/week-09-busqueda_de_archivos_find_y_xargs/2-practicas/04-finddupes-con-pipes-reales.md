# Práctica 04: finddupes con pipes reales

Esta práctica construye **a mano**, paso por paso, la lógica exacta que
después vas a completar en el starter de `finddupes` — igual que la
Práctica 04 de las semanas anteriores. Si entiendes cada paso de aquí,
completar los `TODO` del starter es traducir esto a variables de bash.

## Paso 1: Preparar fotos con contenido duplicado

**Por qué**: dos archivos con nombres y ubicaciones distintas, pero
contenido idéntico — exactamente el caso que `finddupes` tiene que
detectar.

**Comando**:

```bash
mkdir -p ~/practica-wk09d && cd ~/practica-wk09d
mkdir -p fotos/vacaciones fotos/eventos
printf "contenido identico\n" > fotos/original.jpg
printf "contenido identico\n" > fotos/vacaciones/copia.jpg
printf "contenido distinto\n" > fotos/eventos/otro.jpg
find fotos -type f
```

**Verifica**:

```bash
find fotos -type f | wc -l
# 3
```

## Paso 2: Calcular un hash por archivo, de forma segura

**Por qué**: el primer bloque del pipeline — un hash de contenido por
cada archivo, protegido con `-print0`/`-r0` por si el árbol estuviera
vacío.

**Comando**:

```bash
salida=$(find fotos -type f -print0 | xargs -r0 sha256sum)
echo "$salida"
```

**Verifica**: tres líneas, cada una con un hash y una ruta. Los dos
primeros archivos (contenido idéntico) comparten el mismo hash; el
tercero tiene uno distinto.

## Paso 3: Contar archivos analizados

**Por qué**: el primer número que reporta `finddupes` — protegido con
`|| true` por si `grep -c` sale con código 1 sobre una entrada vacía.

**Comando**:

```bash
total=$(printf '%s\n' "$salida" | grep -c .) || true
echo "total=$total"
```

**Verifica**:

```bash
echo "total=$total"
# total=3
```

## Paso 4: Encontrar hashes que se repiten

**Por qué**: el mismo patrón `sort | uniq -d` de la Semana 07/08,
aplicado a hashes en vez de valores de columna.

**Comando**:

```bash
grupos=$(printf '%s\n' "$salida" | awk '{print $1}' | sort | uniq -d | grep -c .) || true
echo "grupos=$grupos"
```

**Verifica**:

```bash
echo "grupos=$grupos"
# grupos=1
```

Un solo hash se repite — el de `original.jpg` y `copia.jpg`.

## Paso 5: Mostrar qué archivos corresponden al hash duplicado

**Por qué**: convertir "hay un hash repetido" en "estos son los
archivos exactos", filtrando la salida completa por esa clave.

**Comando**:

```bash
while read -r hash; do
  echo "duplicado ($hash):"
  printf '%s\n' "$salida" | awk -v h="$hash" '$1==h { $1=""; sub(/^ /,""); print "  "$0 }'
done < <(printf '%s\n' "$salida" | awk '{print $1}' | sort | uniq -d)
```

**Verifica**:

```bash
# duplicado (29427f5d...):
#   fotos/original.jpg
#   fotos/vacaciones/copia.jpg
```

## ✅ Resultado

- [ ] Calculaste un hash por archivo con `find -print0 | xargs -r0 sha256sum`
- [ ] Contaste archivos analizados, protegido con `|| true`
- [ ] Encontraste hashes repetidos con `awk | sort | uniq -d`
- [ ] Mostraste las rutas exactas de un hash duplicado, filtrando con `awk -v`

```bash
./scripts/verificar-semana.sh 09
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 no muestra ningún hash repetido | Los dos archivos del Paso 1 no tienen contenido **exactamente** igual (un salto de línea de más o de menos) | Recrear ambos archivos con `printf`, copiando el texto exacto del Paso 1 |
| El Paso 3 falla con un error bajo `set -e` | Falta el `\|\| true` después de la asignación con `grep -c` | Agregar `\|\| true` inmediatamente después del `$(...)`, como en el Paso 3 |
| El Paso 5 no imprime ninguna ruta | El `awk -v h="$hash"` no coincide porque `$hash` quedó vacío o con espacios de más | Confirmar que el `while read -r hash` recibió una línea limpia del `uniq -d` anterior |

---

[← Práctica 03 — xargs seguro y en paralelo](03-xargs-seguro-y-en-paralelo.md) · [Proyecto: Capa 9 de toolkit →](../3-proyecto/README.md)
