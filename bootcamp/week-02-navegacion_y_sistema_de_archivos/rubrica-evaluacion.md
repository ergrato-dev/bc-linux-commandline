# Rúbrica de Evaluación — Semana 02

## 📊 Distribución de Evidencias

| Evidencia | Peso |
|---|:--:|
| 🧠 Conocimiento | 30% |
| 💪 Desempeño | 40% |
| 📦 Producto | 30% |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | ¿Por qué la misma ruta relativa puede apuntar a dos archivos completamente distintos según desde dónde la escribas? |
| 2 | ¿Qué diferencia conceptual separa `/usr` de `/var` en el FHS, y por qué un sistema con `/usr` de solo lectura puede seguir funcionando mientras que uno con `/var` de solo lectura no? |
| 3 | ¿Por qué `/proc` no ocupa espacio real en disco, y qué significa eso para comandos que "leen" información de ahí? |
| 4 | Explicá la diferencia entre lo que ves en el "total" de `ls -l` y el tamaño real de un directorio. ¿Qué comando usarías en su lugar? |
| 5 | ¿Qué diferencia práctica hay entre un enlace simbólico roto y un enlace duro cuyo "original" fue borrado? |
| 6 | ¿Por qué `file` puede contradecir la extensión de un archivo, y por qué eso no es un error de `file`? |
| 7 | Explicá con tus palabras qué significa que bash "expanda" un glob antes de que el comando lo reciba, y qué efecto práctico tiene eso sobre `echo *.txt` en una carpeta vacía. |
| 8 | ¿Qué hace `nullglob`, y por qué su ausencia puede romper un script que filtra archivos por extensión? |
| 9 | ¿En qué se diferencia la expansión de llaves (`{a,b,c}`) de un glob real como `*.txt`? |
| 10 | ¿Cuándo preferirías `pushd`/`popd` sobre `cd -`, y cuándo sería al revés? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque una ruta relativa se resuelve siempre contra `$PWD`, tu directorio
   actual. El mismo texto, interpretado desde dos ubicaciones distintas,
   produce dos rutas absolutas distintas por detrás — no hay nada especial
   en el texto en sí, todo depende del punto de partida.

2. `/usr` contiene software instalado, que no cambia mientras el sistema
   corre normalmente; `/var` contiene los datos que ese software genera en
   el momento (logs, colas, cachés, bases de datos). Un sistema puede operar
   con `/usr` congelado porque no necesita escribir ahí para funcionar, pero
   casi cualquier proceso necesita escribir en `/var` constantemente — por
   eso ahí sí se traba.

3. Porque `/proc` es un sistema de archivos virtual: el kernel genera su
   contenido al vuelo, en el momento en que lo lees, reflejando su estado
   actual. No hay bytes guardados en disco esperando a ser leídos — "leer"
   ahí es más parecido a hacer una consulta que a abrir un archivo real.

4. El "total" es la cantidad de bloques de disco que ocupan los *metadatos*
   de las entradas listadas, no la suma de los tamaños de los archivos. Para
   el tamaño real de un directorio (incluyendo su contenido) se usa
   `du -sh directorio`.

5. Ninguna, en la práctica: ambos casos terminan con algo que no se puede
   leer. La diferencia está en el modelo: un enlace simbólico roto sigue
   "existiendo" como archivo (apunta a una ruta que ya no está); un enlace
   duro no tiene "original" — todos los nombres son iguales, y mientras
   quede al menos uno, el contenido sigue accesible por ese nombre.

6. Porque la extensión es solo una convención en el nombre, elegida por
   quien creó el archivo — no está garantizada ni verificada por el sistema.
   `file` inspecciona los primeros bytes del contenido real (los "magic
   numbers") para decidir qué es, así que puede legítimamente contradecir un
   nombre engañoso o incorrecto.

7. Bash reemplaza el patrón por la lista de coincidencias *antes* de
   ejecutar el comando — el comando nunca ve el patrón original, solo la
   lista ya resuelta (o el patrón literal, si no hubo coincidencias). En una
   carpeta vacía, `echo *.txt` imprime literalmente el texto `*.txt`, porque
   sin coincidencias bash no lo expande por defecto.

8. `nullglob` cambia el comportamiento de un glob sin coincidencias: en vez
   de dejarlo como texto literal, lo convierte en "nada" (un array vacío).
   Sin `nullglob`, un script que espera una lista de archivos puede terminar
   procesando el patrón literal como si fuera un nombre de archivo real,
   rompiendo la lógica siguiente.

9. La expansión de llaves genera las palabras siempre, sin mirar el sistema
   de archivos — es pura generación de texto. Un glob como `*.txt` sí
   consulta el sistema de archivos y solo produce las coincidencias reales
   que existen en ese momento.

10. `cd -` alcanza y es más simple cuando solo alternas entre dos lugares.
    `pushd`/`popd` vale la pena cuando trabajas activamente entre tres o más
    directorios y necesitas "apilar" lugares para volver en orden, no solo
    alternar entre dos.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Rutas absolutas y relativas | Reprodujo la ambigüedad de rutas relativas y la diferencia `pwd`/`pwd -P` | 10 |
| 02 — Explorando el FHS | Confirmó el usr-merge y comparó divergencia entre distros | 10 |
| 03 — Tipos de archivo y enlaces | Creó y rompió un symlink; creó un hard link y confirmó el inodo compartido | 10 |
| 04 — Globbing | Reprodujo el error de glob sin coincidencias y lo corrigió con `nullglob` | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `doctor` sigue funcionando (regresión) | 10 |
| `inventory` corre sin argumentos y resuelve ruta absoluta | 15 |
| `inventory` cuenta correctamente regulares/directorios/enlaces | 20 |
| `inventory --ext` filtra por extensión con globbing | 10 |
| `inventory` falla con código distinto de 0 en ruta inexistente | 5 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|:--:|
| Usa `nullglob` al filtrar por extensión, no concatenación frágil | 10 |
| Resuelve ruta absoluta con `cd ... && pwd`, no manipulación de strings | 10 |
| Mensajes de error van a stderr | 10 |
| Conteo con `-maxdepth 1`, sin recursión prematura | 10 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper el subcomando `doctor` de la Semana 01 al agregar `inventory` | -30 pts (regresión) |
| `set -euo pipefail` eliminado o comentado "para que ande" | -30 pts |
| Usar `find` con recursión completa en vez de `-maxdepth 1` | -10 pts |

## 🔗 Navegación

[← Proyecto: Capa 2 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
