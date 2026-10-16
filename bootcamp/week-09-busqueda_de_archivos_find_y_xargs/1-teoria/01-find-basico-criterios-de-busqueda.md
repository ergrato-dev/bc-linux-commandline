# find básico: criterios de búsqueda

> `ls` lista lo que hay en un directorio. `find` busca en un **árbol
> completo** de directorios, con criterios que `ls` no entiende: tipo de
> archivo, nombre con patrón, profundidad — el primer paso de todo este
> bootcamp hacia operar sobre muchos archivos a la vez, sin saber de
> antemano dónde están.

## 🎯 Objetivos

- Buscar archivos por nombre con `-name`/`-iname`, con patrones glob
- Filtrar por tipo de archivo con `-type`
- Controlar la profundidad de la búsqueda con `-maxdepth`/`-mindepth`
- Explicar por qué `find` imprime rutas relativas al punto de partida, no nombres sueltos

## 1. Qué problema resuelve

"¿Dónde están todos los archivos `.log` de este proyecto?" — en un árbol
de decenas de subdirectorios, revisar carpeta por carpeta con `ls` no
escala. `find` recorre el árbol completo desde un punto de partida,
aplicando los criterios que se le indiquen, sin que importe cuántos
niveles de subdirectorios haya.

## 2. Cómo funciona

### 2.1 Sintaxis básica: punto de partida, después criterios

```bash
find . -name "*.txt"
```

El primer argumento es **dónde** empezar a buscar (`.` es el directorio
actual); todo lo que sigue son criterios. Sin ningún criterio, `find .`
simplemente lista todo el árbol, archivos y directorios incluidos.

### 2.2 `-name`: patrón de nombre, sensible a mayúsculas

```bash
find . -name "*.TXT"
# (nada, si los archivos reales son .txt en minuscula)

find . -iname "*.TXT"
# ./sub/anidado.txt
# ./viejo.txt
# ./nuevo.txt
```

`-name` compara contra un patrón **glob** (el mismo tipo de patrón de
`*.txt` que usarías con `ls`, no una expresión regular), y distingue
mayúsculas de minúsculas — `"*.TXT"` no encuentra archivos `.txt`.
`-iname` es la versión que ignora el caso, igual que `grep -i`.

### 2.3 `-type`: filtrar por tipo de entrada

```bash
find . -type f    # solo archivos regulares
find . -type d    # solo directorios
find . -type l    # solo enlaces simbolicos
```

```bash
find . -type d
# .
# ./sub
```

Nota que el propio directorio de partida (`.`) cuenta como resultado si
cumple el criterio — `find . -type d` siempre incluye `.` mismo, a menos
que se excluya explícitamente.

### 2.4 `-maxdepth` y `-mindepth`: controlar cuántos niveles bajar

```bash
find . -maxdepth 1 -type f
# ./viejo.txt
# ./nuevo.txt
```

`-maxdepth 1` limita la búsqueda al directorio de partida mismo, sin
entrar a subdirectorios — el archivo `./sub/anidado.txt` no aparece.
`-mindepth` hace lo opuesto: excluye resultados demasiado cerca de la
raíz de la búsqueda (útil, por ejemplo, para excluir el propio directorio
de partida de los resultados con `-mindepth 1`).

Estas dos banderas ya aparecieron en `toolkit.sh inventory` (Semana 02)
y `toolkit.sh audit` (Semana 04) — son las mismas, ahora explicadas a
fondo.

### 2.5 Las rutas que imprime `find` dependen del punto de partida

```bash
find . -name "nuevo.txt"
# ./nuevo.txt

find /root/practica-find -name "nuevo.txt"
# /root/practica-find/nuevo.txt
```

`find` siempre imprime la ruta relativa (o absoluta) **al punto de
partida que se le indicó**, no solo el nombre del archivo — esto importa
cuando el resultado se pasa a otro comando que espera una ruta
utilizable, no un nombre suelto.

### 2.6 Por qué el patrón de `-name` siempre va entre comillas

```bash
find . -name *.txt
```

```
find: paths must precede expression: `a.txt'
find: possible unquoted pattern after predicate `-name'?
```

Sin comillas, **la shell** expande `*.txt` a la lista de archivos que
coinciden **antes** de que `find` vea el patrón — si hay más de un
archivo `.txt` en el directorio actual, `find` recibe varios nombres
sueltos donde esperaba un solo patrón, y falla con un error que a
primera vista no deja claro cuál fue la causa.

```bash
find . -name "*.txt"
```

Con comillas, la shell no toca el `*` — se lo pasa a `find` tal cual,
que es quien debe interpretarlo como patrón glob. Esta es la razón por
la que todo ejemplo de este archivo (y del resto de la semana) entre
comillas cada patrón de `-name`/`-iname`, sin excepción.

### 2.7 `-path`: patrón contra la ruta completa, no solo el nombre

```bash
find . -name "sub"
# ./sub

find . -path "*/sub/*"
# ./sub/anidado.txt
```

`-name` compara solo el nombre final de cada entrada (el `basename`);
`-path` compara contra la ruta **completa** que `find` construyó hasta
ese punto. Útil para excluir o incluir todo lo que está **dentro** de
un directorio con cierto nombre, no el directorio mismo — como excluir
cualquier cosa bajo `node_modules` sin importar en qué nivel aparezca.

## 3. Cómo se usa

```bash
# Todos los scripts .sh de un proyecto, sin bajar a node_modules
find . -maxdepth 3 -name "*.sh"

# Archivos de configuracion, sin distinguir mayusculas
find /etc -iname "*.conf"

# Solo directorios vacios de primer nivel bajo el directorio actual
find . -maxdepth 1 -type d -empty

# Enlaces simbolicos rotos (apuntan a algo que no existe)
find . -type l -xtype l 2>/dev/null
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `-name` esperando que sea una expresión regular | `-name` compara contra un patrón glob (`*`, `?`, `[...]`), no una regex completa — un patrón como `^archivo` no hace lo que parece | Usar `-regex` (fuera del alcance básico de este archivo) cuando de verdad hace falta una regex, o replantear el patrón como glob |
| Olvidar que `find .` incluye el propio `.` en los resultados | Un script que espera "solo los archivos de abajo" puede procesar accidentalmente el directorio raíz de la búsqueda también | Agregar `-mindepth 1` cuando el punto de partida mismo no debe contar como resultado |
| Buscar sin `-maxdepth` en un árbol enorme cuando solo interesa un nivel | `find` recorre todo el árbol por defecto, aunque la respuesta esté en el primer nivel — more lento de lo necesario | `-maxdepth N` cuando se conoce de antemano hasta qué profundidad hace falta buscar |
| Pasar el resultado de `find` a otro comando asumiendo que son solo nombres de archivo | Las rutas que imprime `find` incluyen el punto de partida — un script que concatena manualmente el directorio de nuevo duplica la ruta | Usar la ruta tal como la imprime `find`, sin reconstruirla |

## 5. Trucos

- `find . -maxdepth 1 -type d -empty` encuentra directorios vacíos de
  primer nivel — `-empty` también funciona con archivos (de 0 bytes).
- `find /etc -iname "*.conf" 2>/dev/null` descarta los mensajes de
  "Permission denied" que `find` genera al topar con directorios sin
  acceso, sin perder los resultados válidos.
- `find . -type f -name "*.txt" | wc -l` es la forma más directa de
  contar cuántos archivos cumplen un criterio, sin necesitar `ls | grep
  | wc -l`.

## Resumen

`find PUNTO_DE_PARTIDA CRITERIOS` recorre un árbol completo de
directorios. `-name`/`-iname` filtran por patrón glob (sensible o no a
mayúsculas); `-type` filtra por tipo de entrada (`f`, `d`, `l`);
`-maxdepth`/`-mindepth` controlan cuántos niveles bajar. El propio punto
de partida cuenta como resultado si cumple el criterio, y las rutas que
imprime `find` siempre incluyen ese punto de partida.

## 📚 Recursos Adicionales

- [GNU Findutils Manual — Finding Files](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Finding-Files) — referencia completa de criterios de búsqueda.
- `man find` — disponible sin conexión en cualquier distro.

## ✅ Checklist de Verificación

- [ ] Buscaste archivos por patrón de nombre con `-name` e `-iname`, confirmando la diferencia de mayúsculas
- [ ] Filtraste por tipo de entrada con `-type f`, `-type d` y `-type l`
- [ ] Limitaste la profundidad de una búsqueda con `-maxdepth`
- [ ] Confirmaste que `find .` incluye el propio `.` en los resultados
- [ ] Contaste cuántos archivos cumplen un criterio con `find | wc -l`

---

[← Semana 09](../README.md) · [02 — find por tiempo y tamaño →](02-find-por-tiempo-y-tamano.md)
