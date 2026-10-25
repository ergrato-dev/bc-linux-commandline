# Rúbrica de Evaluación — Semana 05

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
| 1 | ¿Por qué stdout y stderr pueden parecer "un solo canal" aunque sean dos descriptores independientes? |
| 2 | ¿Por qué `sort archivo.txt > archivo.txt` pierde los datos del archivo, en vez de ordenarlos? |
| 3 | ¿Qué diferencia hay entre `comando 2>&1 > archivo` y `comando > archivo 2>&1`? |
| 4 | Explica con tus palabras qué hace un pipe a nivel de mecanismo — no "conecta dos comandos", sino qué conecta exactamente. |
| 5 | ¿Por qué `$?` después de un pipe sin `pipefail` puede ocultar que el primer comando de la cadena falló? |
| 6 | ¿Por qué `sudo comando > archivo-protegido` falla, mientras que `comando | sudo tee archivo-protegido` funciona? |
| 7 | ¿Qué significan los códigos de salida 126 y 127, y quién los genera — el programa que intentaste correr, o bash? |
| 8 | ¿Cómo se calcula qué señal terminó un proceso a partir de un código de salida como 137? |
| 9 | ¿Por qué `comando && echo "ok" | false || echo "igual se imprime"` puede imprimir el mensaje aunque `comando` haya sido exitoso? |
| 10 | ¿Por qué `toolkit.sh logreport` usa tres códigos de salida distintos en vez de solo "funcionó o no funcionó"? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque, por defecto, ambos apuntan al mismo destino visual (la
   terminal) — son dos descriptores de archivo distintos (1 y 2) que
   comparten destino solo hasta que algo los redirige por separado.

2. Porque `>` trunca el archivo de destino **antes** de que el comando se
   ejecute. Para cuando `sort` intenta leer `archivo.txt`, bash ya lo
   vació al abrirlo para escritura — `sort` termina ordenando un archivo
   vacío.

3. El orden importa: en `2>&1 > archivo`, `2>&1` copia el destino actual
   de stdout (la terminal) antes de que `> archivo` cambie stdout — así
   que stderr queda en la terminal. En `> archivo 2>&1`, stdout ya apunta
   al archivo cuando `2>&1` lo copia, así que stderr también va al
   archivo.

4. Un pipe conecta el descriptor de stdout de un proceso directamente al
   descriptor de stdin del siguiente, como una estructura del kernel —
   sin pasar por ningún archivo en disco. Ambos procesos corren al mismo
   tiempo, no uno después del otro.

5. Porque, sin `pipefail`, `$?` de un pipeline refleja el código de salida
   del **último** comando de la cadena, sin importar si alguno anterior
   falló. Un pipeline puede "parecer exitoso" mientras el primer comando
   fracasó en silencio.

6. Porque `>` la procesa **bash**, antes de ejecutar nada, con los
   privilegios del usuario actual — `sudo` nunca llega a aplicar porque el
   intento de abrir el archivo ya falló antes. `tee`, en cambio, es el
   programa que efectivamente escribe el archivo, y si se le antepone
   `sudo` a *él*, corre con privilegios elevados.

7. `126` significa que el archivo existe pero no se pudo ejecutar
   (típicamente, sin bit `x`); `127` significa que el comando no se
   encontró. Los genera **bash**, no el programa — por eso son
   consistentes sin importar qué intentaste correr.

8. Restando 128 al código: `N = código - 128`. Un código `137` corresponde
   a la señal `9` (`SIGKILL`); un `130` corresponde a la señal `2`
   (`SIGINT`, típicamente `Ctrl+C`).

9. Porque la precedencia de operadores hace que el pipe se evalúe primero:
   la expresión es `comando && (echo "ok" | false) || echo "..."`. El
   pipeline completo `echo "ok" | false` sale con el código de `false`
   (sin `pipefail`), que es distinto de cero — así que el `&&` completo
   resulta en fallo, y el `||` se dispara, aunque `comando` por sí solo
   haya sido exitoso.

10. Porque un código único ("funcionó o no") obliga a quien llama al
    script a leer texto para saber *qué tipo* de resultado hubo. Tres
    códigos distintos (limpio, archivo inválido, errores encontrados)
    permiten que otro script o una persona reaccione distinto a cada caso
    con solo mirar `$?`, sin parsear ningún mensaje.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Redirecciones | Reprodujo y corrigió el error de truncar un archivo que también leía | 10 |
| 02 — Pipes y tee | Confirmó `pipefail`/`PIPESTATUS`; usó `sudo tee` correctamente | 10 |
| 03 — Encadenar comandos | Calculó códigos 126/127/137; reprodujo el caso límite de `&&`/`||` sin agrupar | 10 |
| 04 — logreport con pipes reales | Construyó a mano la lógica que después completó en el starter | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, regresión de capas 1-4 sin romperse | 15 |
| `logreport` cuenta líneas totales y detecta `ERROR` correctamente | 20 |
| `logreport` guarda el informe en archivo aparte | 10 |
| `logreport` usa los tres códigos de salida (0/1/2) correctamente | 15 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|:--:|
| Usa `wc -l <` (redirección), no parseo de `wc -l archivo` | 10 |
| Maneja el caso de `grep -c` sin coincidencias bajo `set -e` | 10 |
| El informe se escribe con redirección real, no reconstruido a mano | 10 |
| Nombre de informe predecible y configurable con `--salida` | 10 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor`/`inventory`/`organize`/`audit` de semanas anteriores | -30 pts (regresión) |
| Usar el mismo código de salida para "archivo inválido" y "errores encontrados" | -20 pts |
| `set -euo pipefail` eliminado o comentado "para que ande" | -30 pts |

## 🔗 Navegación

[← Proyecto: Capa 5 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
