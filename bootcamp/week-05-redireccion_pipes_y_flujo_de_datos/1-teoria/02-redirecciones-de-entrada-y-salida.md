# Redirecciones de entrada y salida

> `>`, `>>`, `<`, `2>`, `&>` parecen un puñado de símbolos para memorizar.
> Son, en realidad, un mecanismo único — reasignar un descriptor — con
> distinta sintaxis según qué descriptor y en qué dirección.

## 🎯 Objetivos

- Usar `>`, `>>`, `<`, `2>` y `&>` con precisión, sin confundir uno con otro
- Explicar por qué el **orden** de las redirecciones en una línea importa
- Evitar el error más común: truncar un archivo que también estás leyendo
- Reconocer que los descriptores de archivo no se limitan a stdin/stdout/stderr

## 1. Qué problema resuelve

Cada redirección reemplaza, para ese comando puntual, a qué apunta uno de
sus descriptores — sin este mecanismo, cada comando solo podría escribir a
la terminal y leer del teclado, y guardar un resultado en un archivo
requeriría copiar y pegar a mano. Entender el mecanismo completo (no solo
memorizar `>` como "guardar a archivo") es lo que evita errores como
truncar un archivo de origen por accidente.

## 2. Cómo funciona

### 2.1 Las redirecciones básicas

| Sintaxis | Qué hace |
|---|---|
| `comando > archivo` | stdout al archivo, **sobrescribiendo** su contenido |
| `comando >> archivo` | stdout al archivo, **agregando** al final |
| `comando < archivo` | stdin desde el archivo |
| `comando 2> archivo` | stderr al archivo, sobrescribiendo |
| `comando 2>> archivo` | stderr al archivo, agregando |
| `comando &> archivo` | stdout **y** stderr al mismo archivo (forma corta) |
| `comando > archivo 2>&1` | lo mismo que `&>`, forma explícita y portable |
| `comando <> archivo` | abre el archivo para lectura y escritura en el mismo descriptor (poco común, útil para dispositivos) |

### 2.2 `>` trunca, siempre — incluso si el comando falla

```bash
echo "version 1" > notas.txt
comando-que-no-existe > notas.txt
cat notas.txt
# (vacio)
```

`>` trunca el archivo de destino **antes** de que el comando se ejecute,
sin importar si ese comando termina fallando. El contenido anterior de
`notas.txt` ya se perdió en el momento en que bash abrió el archivo para
escribir, no cuando el comando efectivamente escribió algo.

### 2.3 El orden importa: `2>&1 >archivo` no es lo mismo que `>archivo 2>&1`

```bash
# MAL: stderr se va a la terminal, no al archivo
comando 2>&1 > archivo.log

# BIEN: stderr sigue a donde va stdout, que ya apunta al archivo
comando > archivo.log 2>&1
```

Bash procesa las redirecciones de **izquierda a derecha**, y `2>&1`
significa "el descriptor 2 pasa a apuntar adonde apunta el descriptor 1
**en este momento**", no "donde vaya a apuntar después". En el caso MAL,
`2>&1` copia el destino de `1` (la terminal) antes de que `>archivo.log`
cambie adónde apunta `1` — así que `2` queda apuntando a la terminal,
no al archivo. En el caso BIEN, `1` ya apunta al archivo cuando `2>&1` lo
copia.

### 2.4 Leer y escribir el mismo archivo: el error clásico

```bash
sort datos.txt > datos.txt
cat datos.txt
# (vacio o datos incompletos)
```

Esto falla de forma sutil: `>` trunca `datos.txt` **antes** de que `sort`
tenga oportunidad de leerlo — para cuando `sort` intenta leer, el archivo
ya está vacío. La redirección de salida se procesa al abrir el pipeline,
no al terminar de ejecutarlo.

```bash
# Correcto: un archivo intermedio, o sponge (de moreutils)
sort datos.txt > datos.ordenados.txt && mv datos.ordenados.txt datos.txt
```

### 2.5 `<<` y `<<<`: entrada en línea, sin archivo

```bash
# Here-document: multiples lineas, hasta la marca de cierre
cat << EOF
línea uno
línea dos
EOF
```

```bash
# Here-string: una sola linea/variable, sin archivo ni marca de cierre
grep "patron" <<< "$variable"
```

Un here-string equivale a `echo "$variable" | grep "patron"`, pero sin el
proceso intermedio de `echo` ni el pipe — más directo cuando el contenido
ya está en una variable.

Ambos alimentan `stdin` sin necesitar un archivo real — útil para pasarle
contenido a un comando directamente desde el script.

### 2.6 `/dev/null`: el destino que descarta todo

```bash
comando > /dev/null 2>&1
```

`/dev/null` es un archivo especial que acepta cualquier cantidad de datos
y los descarta — "silenciar" un comando completamente (ni salida normal ni
errores) es la razón más común para usarlo, aunque (visto en el archivo
anterior) conviene mirar qué se está descartando antes de hacerlo por
costumbre.

### 2.7 Redirigir descriptores arbitrarios, no solo 0/1/2

Bash no limita las redirecciones a los tres descriptores estándar — puedes
abrir y usar descriptores adicionales con `exec`:

```bash
exec 3> archivo-propio.log   # abre el descriptor 3 apuntando a un archivo
echo "una linea" >&3          # escribe especificamente por el descriptor 3
exec 3>&-                     # cierra el descriptor 3
```

No hace falta dominar esto todavía — reaparece en la Semana 15, cuando
escribir funciones de logging propias dentro de un script se vuelve
necesario. Alcanza con saber que `0`, `1` y `2` son solo los tres que
existen por convención al arrancar, no un límite del mecanismo.

## 3. Cómo se usa

```bash
# Guardar salida y error en archivos separados
comando > salida.log 2> errores.log

# Guardar todo junto, en orden correcto
comando > todo.log 2>&1

# Agregar al final de un log existente, sin truncar
echo "nueva entrada" >> historial.log

# Alimentar un comando con contenido en linea, sin archivo
grep "ERROR" <<< "$(cat registro.log)"
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir `2>&1 > archivo` esperando que redirija ambos flujos al archivo | El orden importa: así, stderr se queda en la terminal | Escribir `> archivo 2>&1`, redirección de stdout primero |
| Hacer `comando archivo > archivo` para "procesar y guardar en el mismo lugar" | `>` trunca el archivo antes de que el comando lo lea, perdiendo los datos | Usar un archivo intermedio y `mv`, o una herramienta como `sponge` |
| Usar `>` cuando la intención era agregar, no reemplazar | Se pierde todo el contenido anterior sin aviso | Usar `>>` cuando la intención es agregar al final |
| Usar `<<` cuando el contenido cabe en una sola línea | Un here-document de una sola línea es más verboso que necesario | Usar `<<<` (here-string) para una sola línea o variable |
| Descartar stderr con `2>/dev/null` como primer reflejo ante cualquier mensaje molesto | Puede estar ocultando el único indicio de un problema real | Leer el mensaje al menos una vez, decidir recién después si conviene silenciarlo |

## 5. Trucos

- `comando > >(otro-comando)` (sustitución de proceso) redirige la salida
  hacia otro comando como si fuera un archivo — una herramienta avanzada,
  vale la pena saber que existe aunque no se use a diario.
- `cat << 'EOF'` (con comillas en la marca) evita que bash expanda
  variables dentro del bloque — útil para pegar texto literal sin que
  `$variable` se interprete.
- `command > archivo.log; echo $?` después del `;` sigue refiriéndose al
  código de salida de `comando`, no de la redirección — la redirección en
  sí casi nunca falla de forma que cambie `$?`.
- `: > archivo` (dos puntos, el builtin que no hace nada, seguido de `>`)
  es el modismo más corto para vaciar un archivo sin borrarlo y recrearlo.

## Resumen

Toda redirección es el mismo mecanismo — reasignar a qué apunta un
descriptor — con distinta sintaxis según dirección y descriptor. `>`
trunca al abrir, no al escribir, lo que explica tanto el riesgo de
`comando archivo > archivo` como por qué el orden de `2>&1` importa. Los
descriptores no terminan en `0`/`1`/`2`: son solo los tres que bash abre
por convención al arrancar cualquier proceso.

## 📚 Recursos Adicionales

- [Bash Reference Manual — Redirections](https://www.gnu.org/software/bash/manual/bash.html#Redirections) — la referencia oficial completa, incluidos here-documents y here-strings.
- `man bash`, sección `REDIRECTION` — la misma referencia, offline.
- [moreutils — sponge](https://joeyh.name/code/moreutils/) — la herramienta que resuelve de forma directa el problema de leer y escribir el mismo archivo.

## ✅ Checklist de Verificación

- [ ] Reprodujiste por qué el orden de `2>&1` y `>archivo` importa
- [ ] Reprodujiste el error de `sort archivo > archivo` perdiendo datos
- [ ] Usaste `<<` (here-document) y `<<<` (here-string) al menos una vez cada uno
- [ ] Guardaste stdout y stderr en archivos separados, y luego juntos en el orden correcto
- [ ] Abriste y cerraste un descriptor propio (`exec 3> archivo`) y escribiste por él con `>&3`

---

[← 01 — stdin, stdout y stderr](01-stdin-stdout-stderr.md) · [03 — Pipes: encadenar comandos →](03-pipes-encadenar-comandos.md)
