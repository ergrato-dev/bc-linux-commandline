# sed: direcciones, múltiples comandos y edición in-place

> Hasta ahora, cada ejemplo aplicó `sed` a **todas** las líneas. Las
> direcciones acotan dónde actúa un comando — por número de línea, por
> rango, o por patrón — y `-i` da el paso final: editar el archivo de
> verdad, no solo imprimir el resultado.

## 🎯 Objetivos

- Acotar un comando de `sed` a una línea, un rango, o las líneas que coincidan con un patrón
- Negar una dirección con `!` y combinar varios comandos en una sola invocación
- Borrar líneas con `d`, no solo sustituir texto
- Editar un archivo in-place con `-i`, con y sin respaldo automático

## 1. Qué problema resuelve

"Comentar solo la línea 22", "borrar todo entre una marca de inicio y una
de fin", "cambiar algo solo en las líneas que ya tienen `ERROR`" — ninguno
de estos casos quiere tocar el archivo completo. Las direcciones le dicen
a `sed` **dónde** aplicar un comando, antes de que importe **qué** comando
sea.

## 2. Cómo funciona

### 2.1 Dirección por número de línea

```bash
sed '2s/.*/DOS/' archivo.txt
```

```bash
printf 'uno\ndos\ntres\n' | sed '2s/.*/DOS/'
# uno
# DOS
# tres
```

El número antes del comando limita dónde se aplica — acá, solo a la
línea 2.

### 2.2 Rango de líneas

```bash
printf 'uno\ndos\ntres\ncuatro\n' | sed '2,3s/^/>> /'
# uno
# >> dos
# >> tres
# cuatro
```

`2,3` aplica el comando a ese rango inclusive. `$` representa la última
línea del archivo, útil para rangos que llegan hasta el final sin saber
cuántas líneas tiene:

```bash
printf 'uno\ndos\ntres\n' | sed '2,$s/^/>> /'
# uno
# >> dos
# >> tres
```

### 2.3 Dirección por patrón

```bash
printf 'INFO ok\nERROR fallo\nINFO bien\n' | sed '/ERROR/s/fallo/FALLO/'
# INFO ok
# ERROR FALLO
# INFO bien
```

En vez de un número de línea, `/patrón/` aplica el comando solo a las
líneas que coinciden con esa regex — el mismo motor BRE/ERE de `grep` y
de `s///`, ahora usado para decidir **dónde**, no **qué** reemplazar.

### 2.4 Rango definido por dos patrones

```bash
printf 'inicio\na\nb\nfin\nc\n' | sed '/inicio/,/fin/s/^/>> /'
# >> inicio
# >> a
# >> b
# >> fin
# c
```

El rango empieza en la primera línea que coincide con el primer patrón, y
termina (inclusive) en la primera línea *después* de esa que coincide con
el segundo — útil para bloques delimitados por marcadores de texto, sin
saber de antemano en qué número de línea están.

### 2.5 Negar una dirección: `!`

```bash
printf 'uno\ndos\ntres\n' | sed '2!s/^/>> /'
# >> uno
# dos
# >> tres
```

`!` después de la dirección invierte la selección: el comando se aplica
a **todo lo que no sea** esa dirección. Acá, todas las líneas excepto la
segunda.

### 2.6 Múltiples comandos: `;` o varios `-e`

```bash
printf 'hola mundo\n' | sed 's/hola/chau/; s/mundo/tierra/'
# chau tierra
```

```bash
sed -e 's/hola/chau/' -e 's/mundo/tierra/' archivo.txt
```

Ambas formas encadenan comandos en una sola invocación de `sed`, cada uno
aplicado en orden sobre el resultado del anterior — equivalente a un pipe
de `sed | sed`, pero sin el proceso extra.

### 2.7 Borrar líneas: `d`

```bash
printf 'uno\n# comentario\ndos\n' | sed '/^#/d'
# uno
# dos
```

`d` no sustituye texto — elimina la línea completa de la salida. Con una
dirección por patrón (`/^#/d`), es la forma más directa de quitar
comentarios de un archivo de configuración antes de procesarlo.

### 2.8 Edición in-place: `-i`

```bash
sed -i 's/original/modificado/' archivo.txt
```

Sin `-i`, `sed` imprime el resultado a stdout y el archivo original queda
intacto — para editar el archivo de verdad, hace falta `-i`. Con un
sufijo (`-i.bak`), `sed` guarda una copia del original **antes** de
modificarlo:

```bash
printf 'original\n' > archivo.txt
sed -i.bak 's/original/modificado/' archivo.txt
cat archivo.txt       # modificado
cat archivo.txt.bak   # original
```

**`-i` sin sufijo no deja respaldo** — el contenido anterior se pierde en
cuanto `sed` termina. Dado que esta semana trabaja con operaciones que
modifican archivos, aplica el mismo hábito de la Semana 03: previsualizar
sin `-i` primero, confirmar la salida, recién después agregar `-i` (con
sufijo, si el archivo importa).

## 3. Cómo se usa

```bash
# Comentar una linea especifica de configuracion, con respaldo
sed -i.bak '22s/^/#/' config.conf

# Borrar todas las lineas vacias de un archivo
sed -i '/^$/d' archivo.txt

# Aplicar un cambio solo dentro de un bloque delimitado por marcadores
sed '/BEGIN/,/END/s/http/https/' config.txt

# Dos transformaciones en una sola pasada
sed -e 's/;/,/g' -e '/^#/d' datos.csv > datos-limpios.csv
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `-i` directo sobre un archivo sin probar el patrón antes | Si el patrón está mal, el archivo se modifica igual, y sin sufijo no hay forma de recuperarlo | Probar sin `-i` primero (revisar la salida en pantalla), recién después agregar `-i.bak` o `-i` |
| Encadenar comandos con `sed '...' | sed '...'`  en vez de `;` o `-e` | Un proceso de más por cada comando, sin ninguna ventaja sobre encadenarlos en una sola invocación | `sed 's/a/b/; s/c/d/'` o `sed -e '...' -e '...'` |
| Usar un rango de números de línea cuando el contenido puede cambiar de posición | Un rango fijo (`5,10`) asume que el contenido de interés siempre está ahí — si el archivo cambia, el rango deja de tener sentido | Usar un rango por patrón (`/inicio/,/fin/`) cuando lo que importa es el contenido, no la posición |
| Asumir que `-i` sin sufijo es "seguro porque es rápido" | Rápido y sin respaldo no es lo mismo que seguro — un patrón equivocado destruye el contenido original sin aviso | `-i.bak` (o un respaldo manual previo) en cualquier edición in-place que importe de verdad |

## 5. Trucos

- `sed -n '$p'` imprime solo la última línea de un archivo, sin cargar el
  archivo completo en memoria como haría `tail` de una forma menos
  directa para este caso puntual.
- `sed '1d'` borra solo la primera línea — útil para quitar una cabecera
  de un CSV antes de procesarlo con el resto del pipeline de esta semana.
- `sed -i.bak-$(date +%s) '...'` genera un sufijo de respaldo único por
  segundo, para no pisar un `.bak` anterior si corres el mismo comando
  varias veces.

## Resumen

Una dirección (número de línea, rango `N,M` o `$`, patrón `/regex/`, o un
rango de dos patrones) acota dónde actúa un comando de `sed`; `!` niega
esa selección. `;` o varios `-e` encadenan comandos en una sola
invocación. `d` borra líneas completas en vez de sustituir texto. `-i`
edita el archivo original — sin sufijo, sin respaldo; con sufijo
(`-i.bak`), guarda una copia antes de modificar.

## 📚 Recursos Adicionales

- [GNU sed Manual — Addresses](https://www.gnu.org/software/sed/manual/sed.html#sed-regular-expressions-addresses) — sintaxis completa de direcciones y rangos.
- [GNU sed Manual — Common Commands](https://www.gnu.org/software/sed/manual/sed.html#Common-Commands) — `d`, `p` y el resto de comandos de una letra.
- `man sed` — sección `-i[SUFFIX]`, con el comportamiento exacto según la distro (GNU sed vs BSD sed difieren levemente en esta bandera).

## ✅ Checklist de Verificación

- [ ] Aplicaste un comando a una sola línea por número, y a un rango `N,M`
- [ ] Usaste un rango definido por dos patrones (`/inicio/,/fin/`)
- [ ] Negaste una dirección con `!` y confirmaste que invierte la selección
- [ ] Encadenaste dos comandos en una sola invocación (`;` o dos `-e`)
- [ ] Editaste un archivo con `-i.bak` y confirmaste que el respaldo contiene el contenido original

---

[← 01 — sed: anatomía de la sustitución](01-sed-anatomia-de-la-sustitucion.md) · [03 — cut: extraer campos y caracteres →](03-cut-extraer-campos-y-caracteres.md)
