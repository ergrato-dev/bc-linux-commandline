# Rúbrica de Evaluación — Semana 13

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. ¿Qué hace el kernel con la primera línea `#!/usr/bin/env bash` y por qué debe estar en la línea 1, columna 1?

<details>
<summary>Ver respuesta</summary>

Cuando se ejecuta un archivo que empieza por los bytes `#!`, **el kernel**
(no la shell) lee el resto de la línea, arranca ese programa como intérprete
y le pasa la ruta del script. Si hay algo antes (un espacio, una línea en
blanco), los dos primeros bytes ya no son `#!` y el kernel no lo reconoce
como script: para bash será un comentario más. `env bash` busca `bash` en el
`PATH`, así que no depende de la ruta exacta.

</details>

2. Un script con `#!/bin/sh` y un `[[ ]]` funciona en Rocky y falla en Ubuntu. ¿Por qué?

<details>
<summary>Ver respuesta</summary>

`/bin/sh` no es la misma shell en todas las distribuciones: en Ubuntu y
Debian es `dash` (una shell mínima POSIX sin `[[ ]]`, que da `[[: not found`)
y en Rocky/RHEL y Arch es `bash`. Un script que usa características de bash
debe declararlo con `#!/usr/bin/env bash`. `shellcheck` lo avisa antes
(`SC3010`).

</details>

3. ¿Por qué un script no puede cambiar el directorio ni las variables de quien lo ejecuta, y qué hace `source` distinto?

<details>
<summary>Ver respuesta</summary>

Ejecutar un script crea un **proceso hijo** con una copia del entorno: su
`cd` y sus variables mueren cuando termina, y el entorno solo se hereda hacia
abajo. `source script` (o `. script`) no crea un proceso: sus comandos corren
**dentro de tu shell**, así que sus variables y su `cd` persisten. Es lo que
se usa para cargar configuración (`~/.bashrc`).

</details>

4. ¿Qué diferencia hay entre `${v:-x}`, `${v:=x}`, `${v:?msg}` y `${v:+x}`?

<details>
<summary>Ver respuesta</summary>

Si `v` está vacía o sin definir: `${v:-x}` **devuelve** `x` sin tocar `v`;
`${v:=x}` **asigna** `x` a `v` y lo devuelve; `${v:?msg}` **aborta el script**
con `msg` en `stderr`; `${v:+x}` devuelve vacío. Si `v` tiene valor: las tres
primeras devuelven `$v`, y `${v:+x}` devuelve `x`. `${v:?}` es la protección
contra `rm -rf "$dir/"*` con `dir` vacío; `${v:+...}` imprime algo solo
cuando existe un valor.

</details>

5. ¿Por qué `ls -l $archivo` falla con un archivo llamado `informe final.txt` y qué lo arregla?

<details>
<summary>Ver respuesta</summary>

Sin comillas, la expansión de `$archivo` pasa por la **división en palabras**
(por espacios) antes de ejecutar el comando: `ls` recibe **dos** argumentos,
`informe` y `final.txt`, que no existen. Con comillas dobles, `"$archivo"`
sigue siendo **un** argumento. Lo mismo ocurre con el globbing: un valor con
`*` se expande a archivos. Las comillas dobles impiden la división y el
globbing pero siguen expandiendo `$`; las simples impiden todo.

</details>

6. Con los argumentos `"uno dos" tres "*"`, ¿qué diferencia hay entre `$@`, `"$@"` y `"$*"`?

<details>
<summary>Ver respuesta</summary>

`$@` sin comillas parte `"uno dos"` en dos palabras y expande el `*` a los
archivos de la carpeta. `"$@"` produce **un argumento por argumento original**,
intactos (`uno dos`, `tres`, `*`): es la forma correcta de pasar argumentos a
otro comando. `"$*"` los junta en **un solo** argumento (`uno dos tres *`),
separados por el primer carácter de `IFS`.

</details>

7. ¿Por qué `[[ 10 < 9 ]]` es verdadero y cómo se compara numéricamente?

<details>
<summary>Ver respuesta</summary>

`<`, `>`, `==` y `!=` comparan **texto** (orden alfabético): como cadena,
`"10"` va antes que `"9"` porque `"1"` va antes que `"9"`. Para números se
usan `-lt -le -gt -ge -eq -ne` (o `(( ))`). En el toolkit, un uso de disco
de `9` frente a un umbral de `80` con `>` lanzaría una alerta falsa. Y como
`-ge`/`-le` evalúan su operando como aritmética, un dato externo se valida
primero con una regex (`^[0-9]+$`).

</details>

8. ¿Por qué `local v=$(comando)` es un problema y cómo se evita?

<details>
<summary>Ver respuesta</summary>

`local` es un comando y su propio código de salida (`0`) **sustituye** al del
`$( )`: si `comando` falla, el fallo desaparece y `set -e` no aborta.
`ShellCheck` lo avisa como `SC2155`. Se evita **declarando y asignando por
separado**: `local v` y, en la línea siguiente, `v=$(comando)`, que sí
conserva el código del comando.

</details>

9. ¿Qué diferencia hay entre un here-doc con `<<EOF` y con `<<'EOF'`, y por qué `snapshot` usa el primero?

<details>
<summary>Ver respuesta</summary>

Con `<<EOF` (sin comillas) bash **expande** `$variable`, `$(comando)` y
`$(( ))` dentro del texto; con `<<'EOF'` o `<<"EOF"` el texto es **literal**
(para escribir scripts o configuración que contienen `$`). `snapshot`
necesita variables y comandos dentro del informe (`$usuario`, `$(uname -n)`,
`$(( memoria_kb / 1024 ))`), así que usa el primero.

</details>

10. ¿Qué te dice `shellcheck`, qué no, y por qué un `# shellcheck disable=` necesita siempre un motivo?

<details>
<summary>Ver respuesta</summary>

`shellcheck` es un analizador estático: **detecta construcciones legales
pero peligrosas** (comillas que faltan, `cd` sin comprobar, `local v=$(...)`,
variables sin usar) sin ejecutar el script. **No** detecta errores de lógica
(un umbral mal comparado, un formato equivocado): hay que ejecutar y
comprobar la salida y el código. Un `disable` sin motivo esconde un problema
real y hace que "limpio" no signifique nada; con el motivo escrito al lado,
quien lea el script sabe que la excepción es deliberada.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — primer script y `shellcheck` | Ejecuta un script de tres formas, distingue `source` de ejecutar, provoca y corrige `CRLF` y `[[: not found`, y deja `sc.sh` limpio de `shellcheck` | 10 |
| 02 — variables, quoting y argumentos | Reproduce `x = 5`, los cuatro valores por defecto, el recorte de rutas, el quoting con un nombre con espacio y `"$@"`, y un `while`/`case` con códigos `1` y `2` | 10 |
| 03 — condicionales, here-docs y `printf` | Reproduce `[ ]` frente a `[[ ]]`, texto frente a número, `A && B \|\| C`, `local v=$(cmd)` y los tres tipos de here-doc | 10 |
| 04 — `snapshot` a mano | Construye por fragmentos opciones, identidad, números, estado, informe y salida; informe de 11 líneas (12 con alerta) y códigos `0`/`1`/`2` | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (5 checks) | 5 |
| `snapshot`: cabecera, host, usuario sin `$USER`, sistema, fecha, memoria, procesos y disco (8 checks) | 8 |
| `snapshot`: umbral inválido y opción desconocida con código `1` (2 checks) | 3 |
| `snapshot`: alerta con código `2` y mensaje con el porcentaje y el umbral (2 checks) | 4 |
| `snapshot`: informe guardado en una ruta con espacios (1 check) | 2 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| Cero `# shellcheck disable` sin justificar (la directiva de `os-release` lleva su motivo) | 3 |
| Todas las expansiones entre comillas dobles; `local` y asignación separados cuando hay `$( )` | 2 |
| El umbral se valida con regex **antes** de comparar con `-le`/`-ge`, y la comparación del disco es numérica | 2 |
| El informe es un here-doc con la línea de alerta opcional (`${alerta:+...}`) y `os-release` se lee en un subshell | 1 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave o token con formato real comiteado | Grave |
| `rm -rf` con una variable sin proteger (`$dir/*` sin `${dir:?}`) o sin aviso ni respaldo | Grave |
| `eval` o `bash -c "$dato"` con datos de fuera del script | Grave |
| `chmod 777` "para que funcione" | Moderada |
| Script sin shebang, o con `#!/bin/sh` y funciones de bash | Moderada |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 13 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
