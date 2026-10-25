# Rúbrica de Evaluación — Semana 01

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
| 1 | ¿Por qué un servidor sin pantalla ni teclado puede "tener terminal" cuando te conectas por SSH? |
| 2 | ¿Qué diferencia concreta hay entre que un proceso termine por `SIGHUP` y que termine porque tú lo cerraste a propósito? |
| 3 | ¿Por qué `cd` tiene que ser un builtin y no puede ser un programa externo como `ls`? |
| 4 | Si un cron job falla con "command not found" para un comando que funciona perfecto en tu terminal, ¿cuál es la primera hipótesis que deberías probar, y por qué? |
| 5 | ¿Qué diferencia hay entre `$SHELL` y el resultado de `ps -p $$ -o comm=`, y por qué uno puede mentir y el otro no? |
| 6 | ¿Por qué `man passwd` y `man 5 passwd` pueden mostrar contenido completamente distinto? |
| 7 | Explica, con tus palabras, qué significa que el directorio actual no esté en `$PATH`, y por qué eso es una decisión de seguridad, no un descuido. |
| 8 | ¿Qué problema concreto resuelve `HISTCONTROL=ignorespace`, y en qué situación real lo usarías? |
| 9 | Si `which miprograma` encuentra el binario pero bash igual dice "command not found" al escribir `miprograma`, ¿qué deberías revisar antes que nada? |
| 10 | ¿Por qué el prompt por defecto no muestra el código de salida del último comando, y qué riesgo concreto genera no verlo? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque "tener terminal" no depende de hardware gráfico: depende de que el
   kernel cree un PTY y un shell quede conectado a su lado esclavo. El
   cliente SSH de tu máquina cumple el rol de emulador; el servidor solo
   necesita crear el PTY y lanzar `bash` — ambas cosas las hace sin pantalla.

2. `SIGHUP` es una señal específica que el kernel manda automáticamente al
   proceso de control de una sesión cuando esa sesión se corta (cerrar la
   ventana, cortarse el SSH). Cerrarlo "a propósito" con `exit` termina el
   shell de forma ordenada sin pasar por esa señal — la diferencia importa
   porque un proceso puede elegir ignorar `SIGHUP` (con `nohup`), pero no
   puede "ignorar" que tú escribiste `exit`.

3. Porque cambiar el directorio de trabajo tiene que modificar el estado del
   proceso del shell mismo. Si `cd` fuera externo, correría en un proceso
   hijo con su propia copia del directorio; al terminar ese hijo, el shell
   padre seguiría exactamente donde estaba, sin ningún cambio visible.

4. Que el cron job no es una sesión interactiva ni de login, así que no carga
   `.bashrc` ni ningún archivo con alias o `$PATH` extendido — hay que
   revisar si el comando depende de algo definido solo ahí.

5. `$SHELL` es una variable heredada que indica cuál es tu shell de login
   configurado, pero no se actualiza si lanzas otro shell manualmente
   después. `ps -p $$ -o comm=` le pregunta al kernel qué proceso eres
   *ahora*, así que siempre refleja el shell real en el que estás parado.

6. Porque `passwd` existe en dos secciones distintas del manual: la sección 1
   documenta el comando para cambiar contraseñas, la sección 5 documenta el
   formato del archivo `/etc/passwd`. Sin especificar sección, `man` muestra
   la primera que encuentra, casi siempre la 1.

7. Si el directorio actual estuviera en `$PATH`, cualquier carpeta compartida
   (o descargada) podría contener un archivo llamado igual que un comando
   común (`ls`, `cd`) y ese archivo se ejecutaría sin que lo pidieras
   explícitamente, con el riesgo de que sea malicioso. Excluirlo por defecto
   obliga a usar `./` cuando realmente quieres correr algo de ahí.

8. Evita que una línea que empieza con un espacio quede guardada en
   `~/.bash_history`. Es el lugar correcto para escribir, por ejemplo, una
   contraseña de prueba en texto plano sin dejarla grabada para siempre en un
   archivo de texto plano.

9. Que la tabla hash interna de bash tiene memorizada una ruta vieja o
   inexistente para ese nombre. `hash -r` fuerza a recalcular la búsqueda en
   `$PATH` desde cero.

10. Porque mostrarlo requeriría lógica adicional en `PS1` que no viene
    configurada por defecto en la mayoría de las distros. El riesgo concreto
    es no notar que un comando falló silenciosamente y seguir trabajando
    sobre una base de error sin saberlo — especialmente grave en scripts o
    cadenas de comandos donde un fallo intermedio pasa desapercibido.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Primer contacto | Prompt muestra código de salida; historial y alias configurados y persistentes | 10 |
| 02 — Ayuda y manual | Resolvió la ambigüedad de `passwd` y encontró un comando por descripción con `apropos` | 10 |
| 03 — Historial y atajos | Usó `Ctrl+R`, `!!`, `!$` en casos reales, no solo copiando el ejemplo | 10 |
| 04 — Builtins, externos y PATH | Script propio corre por nombre desde cualquier carpeta; explica el error de `./` | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` existe, ejecutable, shebang y modo estricto correctos | 10 |
| `doctor` reporta bash y distro correctamente | 15 |
| `doctor` falla con código distinto de 0 sin `$HOME` | 10 |
| `~/bin` en `$PATH`, historial configurado, alias `ll` definido | 15 |
| `doctor --tipos` distingue builtin de externo | 10 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|:--:|
| Mensajes de `doctor` legibles y bien formateados | 10 |
| Nombres de variables/funciones en inglés, `snake_case` | 10 |
| Comentarios explican el porqué, no repiten la línea | 10 |
| Sin código muerto ni TODOs sin completar en la entrega final | 10 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Ejecutar algo destructivo contra el host en vez del contenedor | Entrega inválida, repetir desde cero |
| `set -euo pipefail` eliminado o comentado "para que ande" | -30 pts |
| Secreto o contraseña real escrita en cualquier archivo del repositorio | Entrega inválida |

## 🔗 Navegación

[← Proyecto: Capa 1 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
