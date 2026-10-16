# uniq: duplicados adyacentes

> `uniq` no elimina duplicados del archivo — elimina duplicados
> **consecutivos** de lo que recibe. Esa distinción, mal entendida, es la
> causa de casi todos los "`uniq` no funcionó" de esta semana.

## 🎯 Objetivos

- Explicar por qué `uniq` necesita entrada ordenada para funcionar como se espera
- Contar ocurrencias con `-c`, y filtrar solo duplicados o solo únicos
- Ignorar mayúsculas/minúsculas y saltear columnas al comparar
- Reconocer cuándo `sort -u` ya resuelve el problema sin necesitar `uniq` aparte

## 1. Qué problema resuelve

Contar cuántas veces aparece cada valor distinto en una lista — direcciones
IP de un log, usuarios de un sistema, categorías de un reporte — sin
escribir un script para llevar la cuenta a mano. `uniq` colapsa líneas
**repetidas y consecutivas** en una sola, opcionalmente con el conteo.

## 2. Cómo funciona

### 2.1 El requisito que todo el mundo olvida: entrada ordenada

```bash
printf 'a\nb\na\n' | uniq
# a
# b
# a
```

`uniq` no mira el archivo completo buscando repetidos — compara cada
línea solo con la **anterior**. Si las dos apariciones de `a` no son
consecutivas, `uniq` no las considera duplicadas entre sí. Por eso casi
siempre aparece después de `sort`, que agrupa los valores iguales uno al
lado del otro:

```bash
printf 'b\na\nb\na\n' | sort | uniq
# a
# b
```

### 2.2 `-c`: contar ocurrencias

```bash
printf 'a\na\nb\nb\nb\nc\n' | uniq -c
#       2 a
#       3 b
#       1 c
```

Antepone el conteo de cada grupo de líneas idénticas consecutivas — la
base del patrón `sort | uniq -c | sort -rn` para un ranking de frecuencia,
que es exactamente lo que construye `toolkit.sh topcount` esta semana.

### 2.3 `-d`: mostrar solo los que se repiten

```bash
printf 'a\na\nb\nc\nc\n' | uniq -d
# a
# c
```

Filtra la salida a solo los valores que aparecieron más de una vez
consecutiva — útil para encontrar qué apareció repetido, descartando lo
que apareció una sola vez.

### 2.4 `-u`: mostrar solo los que NO se repiten

```bash
printf 'a\na\nb\nc\nc\n' | uniq -u
# b
```

Lo opuesto exacto de `-d`: solo los valores que aparecieron exactamente
una vez — útil para encontrar la excepción en un conjunto de datos donde
"lo normal" es repetirse.

### 2.5 `-i`: ignorar mayúsculas/minúsculas al comparar

```bash
printf 'a\nA\nb\n' | uniq -i
# a
# b
```

Sin `-i`, `"a"` y `"A"` se consideran valores distintos (no son
literalmente la misma línea) y no se colapsan — `-i` los trata como
equivalentes para decidir si son "la misma línea repetida".

### 2.6 `-f`: ignorar las primeras N columnas al comparar

```bash
printf '1 a\n2 a\n3 b\n' | uniq -f1
# 1 a
# 3 b
```

`-f1` le dice a `uniq` que **ignore el primer campo** al comparar líneas
consecutivas — acá, compara solo `"a"` vs `"a"` (iguales, se colapsan) y
después `"a"` vs `"b"` (distintas). Útil cuando una columna varía
siempre (como un timestamp o un ID) pero el resto de la línea es lo que
realmente define un "duplicado".

### 2.7 `-w`: comparar solo los primeros N caracteres

```bash
printf '2026-10-15 evento A\n2026-10-15 evento B\n2026-10-16 evento C\n' | uniq -w10
# 2026-10-15 evento A
# 2026-10-16 evento C
```

`-w N` compara únicamente los primeros `N` caracteres de cada línea para
decidir si es "igual" a la anterior — acá, agrupa por fecha (los
primeros 10 caracteres) sin importar qué dice el resto de la línea.
Complementario a `-f` (que ignora columnas completas): `-w` recorta por
cantidad de caracteres, sin importar dónde caigan los separadores de
columna.

### 2.8 Cuando `sort -u` ya alcanza

```bash
printf 'b\na\nb\na\n' | sort -u
# a
# b
```

Si lo único que importa es la lista de valores únicos (sin contar
ocurrencias), `sort -u` hace el trabajo de `sort | uniq` en un solo
comando — reserva `uniq` para cuando necesitas el conteo (`-c`) o
distinguir duplicados de únicos (`-d`/`-u`), que `sort -u` no puede dar.

## 3. Cómo se usa

```bash
# Ranking de IPs mas frecuentes en un log de acceso
cut -d' ' -f1 acceso.log | sort | uniq -c | sort -rn | head -10

# Usuarios que aparecen mas de una vez en un reporte (posible duplicado real)
cut -d, -f1 reporte.csv | sort | uniq -d

# Valores que aparecen UNA sola vez (anomalias, casos unicos)
cut -d, -f2 datos.csv | sort | uniq -u

# Lista de usuarios unicos, sin contar cuantas veces aparece cada uno
cut -d: -f1 /etc/passwd | sort -u
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Correr `uniq` sin `sort` antes, sobre datos no ordenados | Solo colapsa duplicados **consecutivos** — duplicados repartidos por el archivo pasan desapercibidos, sin ningún error | `sort archivo | uniq`, siempre, salvo que ya tengas certeza de que los datos vienen ordenados |
| Confundir `-d` con `-u` | Son opuestos exactos (repetidos vs únicos) — usar el equivocado da la lista contraria a la que se buscaba | Repites el valor buscado dos veces de memoria: `-d` = "Duplicado", `-u` = "Único" |
| Usar `sort | uniq -c` cuando alcanza `sort -u` (sin necesitar el conteo) | Un paso de más sin ganancia, si el conteo nunca se usa | `sort -u` cuando solo interesa la lista de valores distintos |
| Esperar que `uniq -c` cuente ocurrencias de un patrón en vez de líneas exactas | `uniq` compara la línea completa, no un patrón — dos líneas con pequeñas diferencias (un espacio, mayúsculas) no se consideran iguales sin `-i` | Normalizar el formato de la línea (con `tr`/`sed`) antes de `sort | uniq -c`, si lo que importa es el valor lógico, no el texto exacto |

## 5. Trucos

- `uniq -cd` combina ambas banderas: conteo, pero solo de los valores
  que efectivamente se repitieron — una forma compacta de "mostrame
  cuántas veces aparece cada cosa que aparece más de una vez", sin las
  líneas de conteo `1` de los valores únicos mezcladas en el resultado.
- `uniq -c | sort -rn` es, virtualmente, el patrón de "ranking de
  frecuencia" más usado en procesamiento de texto por línea de comandos
  — vale la pena memorizarlo como una unidad, no como dos comandos
  separados.
- `uniq -c` antepone el conteo con espacios de relleno — para usar ese
  número en otro comando, conviene extraerlo con `read` (como hace
  `topcount` esta semana) en vez de parsear el texto a mano con `cut`.
- `comm` (no visto en profundidad este bootcamp) compara dos archivos
  **ya ordenados** línea por línea y reporta qué es exclusivo de cada uno
  y qué es común — relacionado con `uniq`, pero para comparar dos
  conjuntos en vez de deduplicar uno.

## Resumen

`uniq` colapsa líneas **consecutivas** idénticas — sin ordenar antes, un
duplicado no adyacente no se detecta. `-c` cuenta ocurrencias; `-d` y
`-u` filtran a solo-repetidos o solo-únicos respectivamente; `-i` ignora
mayúsculas/minúsculas; `-f N` ignora las primeras N columnas al comparar.
`sort -u` reemplaza `sort | uniq` cuando no hace falta el conteo.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — uniq invocation](https://www.gnu.org/software/coreutils/manual/coreutils.html#uniq-invocation) — referencia completa de banderas.
- `man uniq` — disponible sin conexión en cualquier distro.
- `man comm` — para comparar dos archivos ordenados, mencionado en los trucos de este archivo.

## ✅ Checklist de Verificación

- [ ] Reprodujiste por qué `uniq` sin `sort` antes no detecta duplicados no consecutivos
- [ ] Contaste ocurrencias con `uniq -c` sobre datos ya ordenados
- [ ] Distinguiste `-d` (solo repetidos) de `-u` (solo únicos) con el mismo archivo
- [ ] Usaste `-i` para que mayúsculas y minúsculas cuenten como la misma línea
- [ ] Usaste `-w` o `-f` para comparar solo una parte de cada línea, no la línea completa
- [ ] Explicaste cuándo `sort -u` reemplaza a `sort | uniq`, y cuándo no alcanza

---

[← 04 — sort: ordenar con criterio](04-sort-ordenar-con-criterio.md) · [06 — tr: traducir, borrar y comprimir caracteres →](06-tr-traducir-borrar-y-comprimir-caracteres.md)
