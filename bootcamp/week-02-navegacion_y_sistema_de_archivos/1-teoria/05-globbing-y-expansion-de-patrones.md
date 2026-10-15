# Globbing y expansión de patrones

> `*.txt` no es una expresión regular, y confundirlo con una es la fuente de
> media docena de bugs de "por qué este comando agarró archivos que no
> esperaba".

## 🎯 Objetivos

- Usar los patrones de globbing (`*`, `?`, `[...]`) con precisión
- Explicar que el glob lo expande **bash**, no el comando que lo recibe
- Evitar los errores más comunes de globbing: archivos ocultos, resultados vacíos, espacios

## 1. Qué problema resuelve

Escribir `rm *.log` y que borre algo que no esperabas, o escribir `ls *.txt`
en una carpeta vacía y que liste un archivo literal llamado `*.txt`, son dos
caras del mismo malentendido: no saber que es **bash**, no el comando, quien
expande el patrón antes de que `rm` o `ls` lo vean siquiera. Entender el
globbing es entender qué texto exacto le llega a un comando antes de que se
ejecute.

## 2. Cómo funciona

### 2.1 Quién expande el patrón

Cuando escribes `ls *.txt`, bash **reemplaza** `*.txt` por la lista de
archivos que coinciden, en el directorio actual, *antes* de ejecutar `ls`.
`ls` nunca ve el patrón: ve una lista de nombres ya resuelta.

```bash
touch a.txt b.txt c.txt
echo *.txt
# a.txt b.txt c.txt
```

`echo` no sabe nada de archivos — simplemente imprime lo que le llegó. Que
imprima tres nombres confirma que bash ya hizo el trabajo antes de que
`echo` corriera.

### 2.2 Los comodines básicos

| Patrón | Significa |
|---|---|
| `*` | Cero o más caracteres cualquiera |
| `?` | Exactamente un carácter cualquiera |
| `[abc]` | Un carácter, que sea `a`, `b` o `c` |
| `[a-z]` | Un carácter, cualquiera en ese rango |
| `[!abc]` o `[^abc]` | Un carácter que **no** sea ninguno de esos |
| `{a,b,c}` | Expansión de llaves: genera una palabra por cada opción (no es glob real, se explica aparte) |

```bash
ls archivo?.txt      # archivo1.txt, archivoA.txt — no archivo10.txt (dos caracteres)
ls archivo[123].txt  # archivo1.txt, archivo2.txt, archivo3.txt
ls [!a]*.txt         # cualquier .txt que no empiece con "a"
```

### 2.3 `*` no matchea archivos ocultos por defecto

Igual que `ls` sin `-a`, el glob `*` **no** incluye nombres que empiecen con
`.`:

```bash
ls -a
# .  ..  .bashrc  a.txt  b.txt

echo *
# a.txt b.txt          (no .bashrc)

echo .*
# . .. .bashrc          (solo los ocultos, incluidos . y ..)
```

Un `rm *` nunca va a borrar tus archivos de configuración ocultos por
accidente — pero tampoco los va a tocar cuando sí querías incluirlos, así
que hay que ser explícito con `.*` (con cuidado: `.*` incluye `.` y `..`,
ver antipatrones).

### 2.4 Qué pasa si el patrón no matchea nada

Por defecto, si un glob no encuentra ninguna coincidencia, bash **no lo
expande**: lo deja tal cual, como texto literal.

```bash
ls *.pdf
# ls: no se puede acceder a '*.pdf': No existe el archivo o directorio
```

Ese mensaje es engañoso a primera vista: parece que buscaste un archivo
llamado literalmente `*.pdf`. Lo que realmente pasó es que el glob no
matcheó nada, bash lo dejó sin expandir, y `ls` recibió el patrón literal —
que, como archivo, no existe.

```bash
# shopt nullglob cambia ese comportamiento: sin coincidencias, se borra
shopt -s nullglob
echo no-hay-nada*.pdf
# (nada, sin el patron literal)
shopt -u nullglob
```

Este es exactamente el comportamiento que usamos en `toolkit.sh inventory`
(la capa de esta semana): activar `nullglob` temporalmente para que un glob
sin coincidencias se convierta en un array vacío, no en un string literal
que rompería la cuenta.

### 2.5 Expansión de llaves (brace expansion): no es globbing, pero se parece

```bash
echo archivo{1,2,3}.txt
# archivo1.txt archivo2.txt archivo3.txt

mkdir -p proyecto/{src,docs,tests}
# crea las tres carpetas de una
```

La diferencia clave: `{a,b,c}` genera las palabras **siempre**, exista o no
un archivo con ese nombre — no depende del sistema de archivos. Es puro
texto generado por bash antes incluso de buscar coincidencias de archivos.
Por eso `mkdir -p proyecto/{src,docs,tests}` funciona aunque ninguna de esas
tres carpetas exista todavía: no es un glob que "busca", es una expansión
que "genera".

### 2.6 Clases de caracteres POSIX dentro de un rango

Además de `[a-z]`, bash entiende clases con nombre dentro de corchetes,
útiles cuando el rango que necesitas no es un simple intervalo alfabético:

```bash
ls [[:digit:]]*          # nombres que empiezan con un digito
ls [[:upper:]]*          # nombres que empiezan con mayuscula
```

| Clase | Significa |
|---|---|
| `[:digit:]` | Un dígito (`0-9`) |
| `[:alpha:]` | Una letra |
| `[:alnum:]` | Letra o dígito |
| `[:upper:]` / `[:lower:]` | Mayúscula / minúscula |
| `[:space:]` | Un espacio en blanco |

Esto importa especialmente para evitar depender de que `[a-z]` solo matchee
minúsculas ASCII — en algunas configuraciones regionales (`locale`), un rango
como `[a-z]` puede comportarse distinto de lo esperado. `[[:lower:]]` es
explícito y no depende de esa configuración.

## 3. Cómo se usa

```bash
# Combinaciones utiles
ls semana-0[1-9]*          # semana-01 a semana-09
ls *.{jpg,png,gif}         # combina glob y expansion de llaves
cp archivo.txt{,.bak}      # genera "archivo.txt" y "archivo.txt.bak" - truco
                            # clasico para respaldar antes de editar
```

```bash
# Contar cuantos .sh hay en un directorio, de forma segura con nullglob
shopt -s nullglob
archivos=(*.sh)
echo "hay ${#archivos[@]} archivos .sh"
shopt -u nullglob
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `rm .*` pensando en "todos los ocultos" | `.*` incluye `.` y `..`, que son el directorio actual y el padre — en el peor caso, intento de borrar todo el padre | Usar `rm -- .??* .[!.]*` (patrones más específicos) o herramientas con confirmación |
| Confundir `*` de glob con `.*` de regex | Significan cosas completamente distintas: glob `*` es "cualquier cosa", regex `.*` también, pero glob `.` es literal mientras que regex `.` es "cualquier carácter" | Recordar: glob y regex son sistemas de patrones distintos — se retoma la diferencia explícita en la Semana 06 |
| Asumir que un glob sin coincidencias "no hace nada" | Sin `nullglob`, bash lo pasa literal, que casi siempre produce un error confuso en el comando que lo recibe | Activar `shopt -s nullglob` en scripts que necesiten manejar el caso de cero coincidencias con elegancia |
| Usar glob para filtrar archivos en un script sin comillas en los destinos | Nombres con espacios se parten en múltiples argumentos | Preferir arrays bash (`archivos=(*.sh)`) en vez de concatenar strings |
| Suponer que `*` ordena los resultados de alguna forma en particular | El orden depende de la configuración regional y del sistema de archivos, no está garantizado | Si el orden importa, pasar el resultado por `sort` explícitamente |

## 5. Trucos

- `cp archivo.conf{,.bak}` es el atajo más rápido para respaldar un archivo
  antes de editarlo: expande a `cp archivo.conf archivo.conf.bak` sin
  escribir el nombre dos veces.
- `shopt -s globstar` habilita `**` para coincidir con subdirectorios
  recursivamente (`**/*.sh` encuentra `.sh` en cualquier nivel) — no está
  activo por defecto en todos los sistemas, conviene confirmarlo primero.
- `echo` seguido del patrón, sin ejecutar el comando real, es la forma más
  segura de previsualizar qué va a matchear un glob antes de correr algo
  destructivo con él.

## Resumen

El glob lo expande bash, no el comando que lo recibe — por eso `echo` seguido
del patrón es la forma más barata de previsualizar qué va a matchear algo
antes de ejecutarlo de verdad. `*` no toca ocultos por defecto, un glob sin
coincidencias queda literal salvo que actives `nullglob`, y la expansión de
llaves (`{a,b,c}`) es un mecanismo aparte que genera texto sin mirar el
sistema de archivos. Ninguno de estos tres comportamientos es una expresión
regular, aunque el `*` se parezca de lejos — la diferencia real se retoma en
la Semana 06.

## 📚 Recursos Adicionales

- [Bash Reference Manual — Filename Expansion](https://www.gnu.org/software/bash/manual/bash.html#Filename-Expansion) — la referencia oficial completa de globbing.
- [Bash Reference Manual — Brace Expansion](https://www.gnu.org/software/bash/manual/bash.html#Brace-Expansion) — la expansión de llaves, documentada aparte porque no es glob real.

## ✅ Checklist de Verificación

- [ ] Confirmaste con `echo` que bash expande el glob antes de que el comando lo vea
- [ ] Reprodujiste el error de un glob sin coincidencias y lo corregiste con `nullglob`
- [ ] Usaste expansión de llaves para crear varias carpetas o respaldar un archivo en un solo comando
- [ ] Explicaste la diferencia entre `.*` (glob) y por qué nunca deberías usarlo en un `rm` sin revisar antes
- [ ] Usaste `[1-9]` y `[!a]` (o `[^a]`) en patrones reales, no solo copiados del ejemplo

---

[← 04 — Tipos de archivo y enlaces](04-tipos-de-archivo-y-enlaces.md) · [06 — Navegación eficiente: pushd, popd, CDPATH →](06-navegacion-eficiente-pushd-popd-cdpath.md)
