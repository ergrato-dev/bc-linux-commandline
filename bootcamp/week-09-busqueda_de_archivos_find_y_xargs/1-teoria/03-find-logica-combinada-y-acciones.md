# find con lógica combinada y acciones directas

> Hasta ahora, `find` solo **encontró** cosas. `-exec` y `-delete` le
> permiten **actuar** sobre lo que encuentra, sin necesitar otro
> comando — y `-a`/`-o`/`-not` dan el control lógico fino que un simple
> "varios criterios seguidos" no alcanza a expresar.

## 🎯 Objetivos

- Combinar criterios con `-a` (y, implícito), `-o` (o) y `-not`
- Agrupar condiciones con `\( \)` para controlar la precedencia
- Ejecutar un comando por cada resultado con `-exec ... \;`
- Ejecutar un comando en lote con `-exec ... +`, y explicar por qué es más eficiente
- Borrar resultados directamente con `-delete`, con la misma disciplina de seguridad de la Semana 03

## 1. Qué problema resuelve

"Archivos `.tmp` **o** `.bak`, pero no dentro de `node_modules`" — una
combinación de criterios con **y**, **o** y **negación** que una lista
simple de banderas no puede expresar sin ambigüedad. Y una vez
encontrados, actuar sobre ellos (borrarlos, cambiarles el nombre,
comprimirlos) sin tener que copiar la lista a mano a otro comando.

## 2. Cómo funciona

### 2.1 `-a` (y, implícito) y `-o` (o)

```bash
find . -type f -name "*.txt" -a -newer viejo.txt
```

Varios criterios seguidos ya se combinan con **Y** (`-a`) por defecto —
escribirlo explícito es opcional, pero deja la intención clara. `-o`
(**o**) necesita escribirse siempre:

```bash
find . -type f \( -name "viejo.txt" -o -name "grande.txt" \)
# ./grande.txt
# ./viejo.txt
```

### 2.2 Por qué hacen falta los paréntesis `\( \)`

Sin agrupar, `-o` tiene **menor precedencia** que estar simplemente uno
al lado del otro — mezclar `-o` con otros criterios sin paréntesis casi
siempre da un resultado distinto al esperado. Los paréntesis necesitan
escaparse (`\(` `\)`) porque, sin escape, la shell los interpretaría
como sintaxis propia antes de que `find` los vea.

```bash
# SIN agrupar: "-type f" solo ata al primer -name, no al segundo
find . -maxdepth 1 -type f -name "*.conf" -o -name "*.bak"
# ./directorio.bak   <- un DIRECTORIO, aunque pedimos -type f
# ./config.conf

# CON agrupar: "-type f" aplica al resultado completo de la alternancia
find . -maxdepth 1 -type f \( -name "*.conf" -o -name "*.bak" \)
# ./config.conf      <- ahora si, solo archivos
```

`directorio.bak` es un directorio, no un archivo — pero igual aparece
en la versión sin agrupar, porque `-type f` solo se aplicó al primer
`-name`. La versión agrupada filtra correctamente ambas alternativas
por tipo.

### 2.3 `-not`: negar un criterio

```bash
find . -type f -not -name "*.txt"
```

Encuentra archivos que **no** cumplen el patrón — el equivalente de
`grep -v`, pero para criterios de `find` en vez de líneas de texto.
Combinable con agrupación: `-not \( -name "*.txt" -o -name "*.log" \)`
excluye ambas extensiones a la vez.

### 2.4 `-exec ... \;`: ejecutar un comando por cada resultado

```bash
find . -type f -name "*.txt" -exec echo "procesando: {}" \;
```

```
procesando: ./sub/anidado.txt
procesando: ./grande.txt
procesando: ./viejo.txt
procesando: ./nuevo.txt
```

`{}` se reemplaza por la ruta de cada resultado; `\;` (punto y coma
escapado) marca el final del comando. Esto ejecuta el comando **una vez
por cada archivo encontrado** — cuatro archivos, cuatro procesos
`echo` separados.

### 2.5 `-exec ... +`: ejecutar en lote, no uno por uno

```bash
find . -type f -name "*.txt" -exec echo "procesando:" {} +
```

```
procesando: ./sub/anidado.txt ./grande.txt ./viejo.txt ./nuevo.txt
```

Con `+` en vez de `\;`, `find` agrupa tantos resultados como puede en
**una sola** invocación del comando (como lo permita el límite del
sistema) — un solo proceso `echo`, no cuatro. Para comandos que aceptan
múltiples archivos como argumentos (como la mayoría), esto es
significativamente más eficiente en árboles grandes — el mismo
principio que `-exec ... +` de `find` comparte con `xargs` (archivo 04
de esta semana).

### 2.6 `-delete`: borrar directamente, sin otro comando

```bash
find . -name "*.tmp" -delete
```

Borra cada resultado directamente — más simple que `-exec rm {} \;`
para el caso específico de borrar. **Es irreversible**, con el mismo
peso que cualquier `rm` de la Semana 03: previsualizar primero sin
`-delete` (solo el `find` con los mismos criterios) es la misma
disciplina de "listar antes de actuar" ya vista.

```bash
# PRIMERO: solo ver que va a borrar
find . -name "*.tmp"

# RECIEN DESPUES: agregar -delete al mismo comando exacto
find . -name "*.tmp" -delete
```

## 3. Cómo se usa

```bash
# Borrar archivos temporales de mas de 7 dias, previsualizando primero
find /tmp -name "*.tmp" -mtime +7
find /tmp -name "*.tmp" -mtime +7 -delete

# Cambiar permisos en lote a todos los .sh de un proyecto
find . -name "*.sh" -exec chmod +x {} +

# Archivos .log O .bak, pero no dentro de un directorio de respaldos
find . -type f \( -name "*.log" -o -name "*.bak" \) -not -path "*/respaldo/*"

# Contar cuantos archivos NO son de un tipo esperado
find . -type f -not -name "*.conf" | wc -l
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Mezclar `-o` con otros criterios sin agrupar con `\( \)` | La precedencia por defecto casi nunca da el resultado que parece a simple lectura | Agrupar siempre una alternancia (`-o`) con paréntesis escapados cuando se combina con otros criterios |
| Usar `-exec ... \;` cuando el comando acepta múltiples archivos | Un proceso nuevo por cada resultado, mucho más lento en árboles grandes | `-exec ... +` cuando el comando soporta recibir varios archivos a la vez |
| Usar `-delete` sin haber visto antes qué va a borrar | Sin un paso de previsualización, un criterio mal pensado borra algo que no debía | Correr el mismo `find` sin `-delete` primero, confirmar la lista, recién después agregarlo |
| Olvidar que `{}` dentro de `-exec` necesita estar separado por espacios | `-exec mv {}.bak {} \;` (sin espacio entre `{}` y `.bak`) puede no expandirse como se espera en todas las implementaciones | Dejar `{}` como un argumento separado, usando variables intermedias si el comando necesita transformar el nombre |

## 5. Trucos

- `find . -name "*.tmp" -print` (antes de `-delete`) es exactamente la
  misma búsqueda sin la acción — el `-print` es incluso el
  comportamiento por defecto si no se indica ninguna acción, así que un
  `find` "normal" ya es la previsualización.
- `-exec comando {} + ` es casi siempre preferible a `-exec comando {}
  \;` salvo que el comando necesite procesar los archivos de uno en
  uno (por ejemplo, si el orden de cada llamada individual importa).
- `find . -type f \( -name "*.log" -o -name "*.txt" \) -delete` combina
  todo lo de este archivo en una sola línea: agrupación, alternancia, y
  acción — léela de afuera hacia adentro para entenderla rápido.

## Resumen

`-a` (y, implícito) y `-o` (o) combinan criterios; `-o` necesita
agruparse con `\( \)` para evitar sorpresas de precedencia. `-not`
niega un criterio. `-exec comando {} \;` ejecuta una vez por resultado;
`-exec comando {} +` agrupa en lote, más eficiente. `-delete` borra
directamente — con la misma disciplina de previsualizar antes de
aplicar que cualquier operación destructiva de este bootcamp.

La misma lógica de agrupación con paréntesis se aplica a tres o más
alternativas, no solo dos: `\( -name "*.a" -o -name "*.b" -o -name
"*.c" \)` encadena cuantas haga falta, siempre dentro del mismo par de
paréntesis escapados.

## 📚 Recursos Adicionales

- [GNU Findutils Manual — Operators](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Operators) — precedencia completa de `-a`, `-o`, `-not`.
- [GNU Findutils Manual — Executing](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Executing-a-Command) — diferencia exacta entre `\;` y `+`.

## ✅ Checklist de Verificación

- [ ] Combinaste dos criterios con `-o`, agrupados con `\( \)`
- [ ] Negaste un criterio con `-not`
- [ ] Ejecutaste un comando por resultado con `-exec ... \;`
- [ ] Ejecutaste el mismo comando en lote con `-exec ... +`, confirmando que es una sola invocación
- [ ] Previsualizaste con `find` simple antes de agregar `-delete` al mismo comando
- [ ] Reprodujiste por qué `-type f` sin agrupar no filtra correctamente una alternancia con `-o`

---

[← 02 — find por tiempo y tamaño](02-find-por-tiempo-y-tamano.md) · [04 — xargs básico y el gotcha de entrada vacía →](04-xargs-basico-y-el-gotcha-de-entrada-vacia.md)
