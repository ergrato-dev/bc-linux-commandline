# Rúbrica de Evaluación — Semana 03

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
| 1 | ¿Por qué `touch` sobre un archivo que ya existe no borra su contenido, y qué es lo único que cambia? |
| 2 | ¿Qué diferencia práctica hay entre `mkdir` y `mkdir -p` en un script que puede ejecutarse más de una vez? |
| 3 | ¿Qué preserva `cp -a` que una copia simple no preserva, y por qué eso importa al clonar un árbol de carpetas? |
| 4 | ¿Por qué mover un archivo de 10 GB dentro del mismo disco es instantáneo, y por qué deja de serlo entre dos discos distintos? |
| 5 | ¿Por qué no existe una papelera de reciclaje por defecto en la terminal, y qué consecuencia práctica tiene eso para cómo usas `rm`? |
| 6 | Explica la diferencia entre `rm -i`, `rm -I` y `rm -f`, y en qué situación usarías cada uno. |
| 7 | ¿Por qué `ctime` no significa "fecha de creación", y qué significa en realidad? |
| 8 | Un `rm` sobre un archivo de log no libera espacio en disco de inmediato. ¿Por qué, y qué tendría que pasar para que sí se libere? |
| 9 | ¿Qué patrón seguiste para que `toolkit.sh organize` nunca mueva nada por accidente, y por qué ese patrón es más seguro que mover directo? |
| 10 | ¿Por qué un espacio de más en `rm -rf /ruta /temporal` puede ser catastrófico, aunque la intención fuera borrar una sola cosa? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque `touch` solo garantiza que el archivo exista y actualiza su fecha
   de modificación a "ahora" — nunca toca ni trunca el contenido. Lo único
   que cambia es la fecha (`mtime`), visible en `ls -l` o `stat`.

2. `mkdir` sin `-p` falla si el directorio ya existe (o si falta algún
   directorio padre); `mkdir -p` no falla en ninguno de los dos casos. Un
   script con `set -e` que usa `mkdir` a secas se corta en la segunda
   corrida; con `mkdir -p` puede ejecutarse las veces que haga falta sin
   romperse.

3. `cp -a` preserva permisos, dueño/grupo, fechas, y no sigue enlaces
   simbólicos (los copia como enlaces, no como su contenido). Una copia
   simple pierde todo eso: nace con la fecha actual, tus permisos por
   defecto, y convierte cualquier enlace en el archivo real al que apunta.

4. Dentro del mismo disco, mover es solo reasignar a qué inodo apunta un
   nombre — no se toca el contenido, así que el tamaño no importa. Entre
   discos distintos no existe la posibilidad de "solo reapuntar": el
   contenido tiene que copiarse físicamente al otro disco antes de borrar
   el original, así que el tiempo ahora sí depende del tamaño.

5. Porque una papelera requiere una capa adicional (mover a un lugar
   especial, vaciarla eventualmente) que la mayoría de herramientas de
   línea de comandos, pensadas para scripts, no agregan por diseño. La
   consecuencia es que hay que tratar todo `rm` como definitivo desde el
   momento de escribirlo, no después de ejecutarlo.

6. `-i` pregunta antes de cada archivo (tedioso para más de dos o tres);
   `-I` pregunta una sola vez para operaciones grandes (el punto medio
   razonable para uso interactivo); `-f` no pregunta nunca y no falla si
   algo no existe (para scripts ya probados, nunca para uso exploratorio).

7. `ctime` significa "change time" (tiempo de cambio), no "creation time".
   Se actualiza con cualquier cambio de metadatos (permisos, dueño,
   nombre) además del contenido — no solo al crear el archivo. La mayoría
   de los sistemas de archivos tradicionales de Linux no exponen una
   fecha de creación real a través de las herramientas estándar.

8. Porque el espacio se libera recién cuando el contador de enlaces del
   inodo llega a cero **y** ningún proceso tiene el archivo abierto. Si un
   proceso sigue escribiendo al mismo inodo (aunque ya no tenga nombre),
   el espacio sigue ocupado hasta que ese proceso cierre el archivo o
   termine.

9. El patrón dry-run por defecto: mostrar el plan completo (qué se movería
   y adónde) sin ejecutar nada, y requerir un flag explícito (`--apply`)
   para el cambio real. Es más seguro que mover directo porque separa "ver
   qué haría" de "hacerlo", dando una oportunidad de revisar antes de que
   el cambio sea irreversible.

10. Porque `rm -rf /ruta /temporal` son **dos argumentos separados**, no
    una ruta con un espacio en el medio — equivale a borrar `/ruta` Y
    borrar `/temporal` (la raíz del segundo argumento, tal cual esté
    escrito). Si `/temporal` no era la intención real sino parte de una
    ruta mal escrita, el resultado es borrar algo completamente distinto
    de lo que se quiso.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Crear archivos y directorios | Reprodujo la diferencia `mkdir`/`mkdir -p` y que `touch` no borra contenido | 10 |
| 02 — Copiar archivos y directorios | Confirmó qué preserva `-p`/`-a` y la diferencia de copiar enlaces con/sin `-d` | 10 |
| 03 — Mover y eliminar con criterio | Midió velocidad de `mv`, vio la protección de `rm -rf /`, usó `-I` en lote | 10 |
| 04 — Operaciones seguras por lotes | Aplicó dry-run manual y probó `organize` en ambos modos | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `doctor`/`inventory` siguen funcionando (regresión) | 15 |
| `organize` sin `--apply` no modifica nada y lo reporta | 15 |
| `organize --apply` agrupa por extensión, incluidos archivos sin extensión | 20 |
| `organize` es idempotente y falla en ruta inexistente | 10 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|:--:|
| El plan de dry-run coincide exactamente con lo que `--apply` ejecuta | 10 |
| Usa `nullglob` al listar contenido del directorio | 10 |
| Solo mueve archivos regulares del nivel superior, no entra en subcarpetas ya organizadas | 10 |
| Mensajes de error van a stderr | 10 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor` o `inventory` de semanas anteriores al agregar `organize` | -30 pts (regresión) |
| `organize --apply` sobrescribe un archivo existente sin `-n` en el `mv` interno | -20 pts |
| Ejecutar movimientos reales en el modo dry-run (sin `--apply`) | Entrega inválida, repetir desde cero |
| `set -euo pipefail` eliminado o comentado "para que ande" | -30 pts |

## 🔗 Navegación

[← Proyecto: Capa 3 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
