# Anatomía del prompt

> El prompt no es un adorno: es información en vivo sobre quién eres, dónde
> estás y si el comando anterior falló. Casi nadie lo lee así.

## 🎯 Objetivos

- Leer un prompt estándar de bash e identificar usuario, host y directorio
- Explicar la variable `PS1` y cómo se construye con secuencias de escape
- Personalizar el prompt para que muestre el código de salida del último comando

## 1. Qué problema resuelve

El prompt por defecto de Ubuntu (`usuario@host:~/carpeta$`) ya contiene
información útil, pero la mayoría lo lee como ruido visual y no como datos.
El resultado: gente que corre `rm -rf algo` sin notar que el prompt decía
`root@servidor-produccion`, porque nunca aprendió a leerlo como una alerta.

Este archivo enseña a leer el prompt que ya tienes, y a extenderlo con una
señal que vas a necesitar todo el bootcamp: **si el comando anterior
falló**. Bash no te lo muestra por defecto, y es la pregunta más frecuente
que vas a hacerte en los próximos veinte semanas.

## 2. Cómo funciona

### 2.1 El prompt es el valor de una variable

Lo que ves antes del cursor es, literalmente, el contenido de la variable
`PS1` ("Prompt String 1"), evaluado cada vez que el shell te devuelve el
control:

```bash
echo "$PS1"
# \[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$
```

Esa maraña de caracteres son **secuencias de escape de bash**, no texto
literal. Bash las expande antes de mostrarlas.

### 2.2 Secuencias de escape más comunes

| Secuencia | Qué muestra |
|---|---|
| `\u` | Usuario actual |
| `\h` | Nombre de host, hasta el primer punto |
| `\H` | Nombre de host completo |
| `\w` | Directorio actual, con `~` si es tu home |
| `\W` | Solo el último componente del directorio actual |
| `\$` | `$` para usuario normal, `#` si eres root |
| `\t` | Hora actual, formato 24h |
| `\n` | Salto de línea |
| `\[` ... `\]` | Marca el inicio/fin de secuencias que no ocupan espacio visual (colores) — **sin esto, bash cuenta mal el ancho de línea y el cursor se desalinea al usar las flechas** |

El `\$` es la señal más importante de todas: distingue a simple vista si eres
root o un usuario normal. Un prompt que termina en `#` en vez de `$` debería
hacerte dudar dos veces antes de tocar Enter.

### 2.3 Por qué `\w` es `~` a veces

`\w` reemplaza tu directorio home por `~` para que el prompt no se vuelva
gigante. Esto es solo cosmético: `pwd` siempre te da la ruta real y completa,
nunca con `~`.

```bash
cd
echo "$PWD"
# /home/student
# pero el prompt muestra solo ~
```

### 2.4 El código de salida que el prompt no te muestra

Cada comando termina con un **código de salida** (`$?`): `0` si todo anduvo
bien, cualquier otro número si falló. Bash no lo muestra en el prompt por
defecto — hay que pedirlo explícitamente, y por eso casi nadie lo ve hasta que
un script lo necesita.

```bash
grep inexistente /etc/hostname
echo "codigo: $?"
# codigo: 1

ls /etc/hostname
echo "codigo: $?"
# codigo: 0
```

`$?` se **sobrescribe con cada comando**, incluido un `echo` de más: si
corres `echo algo` entre el comando que te interesa y la lectura de `$?`,
perdiste el valor que buscabas.

### 2.5 PS1 no está solo: PS2, PS3, PS4

| Variable | Cuándo aparece | Ejemplo |
|---|---|---|
| `PS1` | Prompt normal, esperando un comando nuevo | `student@ubuntu-lab:~$` |
| `PS2` | El comando anterior quedó incompleto (una comilla sin cerrar, un `\` al final) | `>` |
| `PS3` | Dentro de un menú `select` en un script (se ve recién en la Semana 14) | `#?` |
| `PS4` | Al depurar un script con `bash -x` (se ve en la Semana 15) | `+` |

`PS2` es el que más vas a cruzar sin querer esta semana: si abres una comilla
y aprietas Enter antes de cerrarla, bash no ejecuta nada — asume que vas a
seguir escribiendo en la línea siguiente, y te lo señala cambiando el prompt
a `>`.

```bash
echo "esto quedo sin cerrar
> todavia estoy esperando la comilla que falta"
```

Si esto te pasa sin querer, `Ctrl+C` cancela la entrada y te devuelve a `PS1`
limpio, sin ejecutar nada.

## 3. Cómo se usa

### 3.1 Agregar el código de salida al prompt

```bash
# En ~/.bashrc, agregar o modificar la linea de PS1:
PS1='[\$(ec=$?; [ $ec -ne 0 ] && echo "✗$ec ")]\u@\h:\w\$ '
```

Con esto, un comando que falla deja un `[✗1]` visible al lado del prompt del
intento siguiente — ya no hace falta acordarse de escribir `echo $?` cada
vez. (Esta forma usa una sub-expresión porque `PS1` se re-evalúa en cada
prompt nuevo; no hace falta entenderla línea por línea todavía — se retoma la
sintaxis de sustitución de comandos en la Semana 13.)

### 3.2 Recargar la configuración sin cerrar sesión

```bash
source ~/.bashrc
# o, mas corto:
. ~/.bashrc
```

`source` ejecuta el archivo *en el shell actual*, en vez de lanzarlo como
proceso aparte — por eso los cambios en `PS1` o en alias quedan disponibles de
inmediato, sin abrir una terminal nueva.

### 3.3 Ver PS1 sin secuencias de color que ensucien la lectura

```bash
# Version simplificada, sin colores, para leer la estructura
PS1='\u@\h:\w\$ '
```

Útil al diagnosticar: si tu prompt se ve raro (desalineado, con caracteres
sueltos), simplificarlo a esto aísla si el problema es de las secuencias de
color o de otra cosa.

### 3.4 Un prompt de dos líneas, legible cuando las rutas son largas

```bash
PS1='\n\u@\h:\w\n\$ '
```

El `\n` extra separa la información de contexto (usuario, host, ruta) del
punto donde realmente escribes — útil cuando trabajas dentro de carpetas con
rutas largas y el prompt de una sola línea deja poco espacio para el comando.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar colores en `PS1` sin envolverlos en `\[` `\]` | Bash cuenta mal el ancho visible de la línea; al usar las flechas del teclado el cursor termina en la posición incorrecta | Envolver siempre las secuencias de color (no las de texto como `\u`) entre `\[` y `\]` |
| Leer `#` al final del prompt como "normal" | Ese símbolo específicamente significa que eres root — ejecutar sin pensar ahí es el origen de buena parte de los desastres de sysadmin | Tratar un prompt terminado en `#` como una alerta visual, siempre |
| Asumir que `$?` sigue "disponible" varios comandos después | Se sobrescribe en cada comando, incluidos los que corres "solo para mirar" | Guardarlo en una variable propia (`codigo=$?`) apenas lo necesites, antes de correr nada más |
| Copiar un `PS1` ajeno de internet sin entender sus secuencias | Si rompe el conteo de ancho de línea, vas a tener una terminal "rota" sin saber por qué | Construirlo pieza por pieza, probando con `echo "$PS1"` en el medio |

## 5. Trucos

- `PROMPT_COMMAND` es una variable que bash ejecuta *antes* de mostrar cada
  prompt — permite lógica más compleja que no cabe cómodamente en `PS1`.
- Para un prompt temporal de una sola sesión (probar algo sin tocar
  `.bashrc`), alcanza con reasignar `PS1=` directo en la terminal: vive solo
  mientras esa sesión esté abierta.
- `\A` da la hora en formato `HH:MM` de 24 horas sin segundos — más legible
  que `\t` cuando solo te interesa la hora aproximada.
- `\j` muestra cuántos jobs en segundo plano tiene esta sesión — una forma de
  notar, sin escribir `jobs`, que dejaste algo corriendo de fondo antes de
  cerrar la terminal.

## 📚 Recursos Adicionales

- [Bash Reference Manual — Controlling the Prompt](https://www.gnu.org/software/bash/manual/bash.html#Controlling-the-Prompt) — la lista completa de secuencias de escape.
- `man bash`, buscar `PROMPTING` — la misma referencia offline.

## Resumen

El prompt es el valor de `PS1`, construido con secuencias de escape que bash
expande en vivo. Leerlo bien — usuario, host, directorio, y si el comando
anterior falló — es una herramienta de seguridad tanto como de información:
un `#` al final o un código de error visible son las dos señales más baratas
que tienes para evitar un error caro.

## ✅ Checklist de Verificación

- [ ] Corriste `echo "$PS1"` y ubicaste al menos tres secuencias de escape de la tabla
- [ ] Agregaste el código de salida visible al prompt en `~/.bashrc` y lo recargaste con `source`
- [ ] Provocaste un comando que falla y confirmaste que el prompt lo muestra en el intento siguiente

---

[← 02 — El shell: bash como intérprete](02-el-shell-bash-como-interprete.md) · [04 — Builtins, externos y $PATH →](04-builtins-externos-y-path.md)
