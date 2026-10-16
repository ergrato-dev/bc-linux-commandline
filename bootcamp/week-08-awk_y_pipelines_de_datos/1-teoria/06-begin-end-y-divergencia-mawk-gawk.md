# BEGIN, END y la divergencia mawk/gawk

> "El `awk` del sistema" no es una sola cosa. `ubuntu-lab` y Debian traen
> `mawk` por defecto; RHEL/Fedora y Arch traen `gawk`. La mayoría de lo
> visto esta semana funciona igual en ambos — pero no todo, y confundir
> los dos es el riesgo real de divergencia de esta semana, no una
> diferencia de versión.

## 🎯 Objetivos

- Usar `BEGIN` y `END` para código que corre antes o después de procesar líneas
- Cambiar `FS`, `OFS`, `ORS` y entender cuándo cada cambio toma efecto
- Pasar variables externas con `-v`, y distinguir `NR` de `FNR` con varios archivos
- Confirmar qué `awk` corre en tu sistema antes de depender de una extensión

## 1. Qué problema resuelve

Inicializar un contador en cero, imprimir un encabezado antes de
procesar cualquier dato, o un resumen después de procesar todo — ningún
patrón normal de `awk` corre "antes de la primera línea" o "después de
la última" por sí solo. `BEGIN` y `END` son los dos bloques especiales
que sí lo hacen.

## 2. Cómo funciona

### 2.1 `BEGIN`: código antes de leer ninguna línea

```bash
awk 'BEGIN { print "procesando..." } { print $1 }' datos.txt
```

El bloque `BEGIN` corre **una sola vez**, antes de leer la primera
línea de entrada — el lugar correcto para inicializar variables,
imprimir un encabezado, o fijar `FS` para todo el archivo.

### 2.2 `END`: código después de la última línea

```bash
awk '{ total += $1 } END { print "total:", total }' numeros.txt
```

`END` corre una sola vez, después de procesar la última línea —
exactamente donde `toolkit.sh sumfield` imprime el resultado final del
array asociativo acumulado línea por línea.

### 2.3 `FS` en `BEGIN` vs. asignado durante el procesamiento

```bash
printf 'a:b\nc:d\n' | awk 'BEGIN { FS = ":" } { print $1 }'
# a
# c
```

```bash
printf 'a:b\nc:d\n' | awk '{ print $1; FS = ":" }'
# a:b
# c
```

Asignar `FS` en `BEGIN` afecta **todas** las líneas, porque se fija
antes de leer la primera. Asignarlo dentro del cuerpo normal (por cada
línea) afecta solo las líneas **siguientes** — la línea actual ya se
dividió con el `FS` anterior antes de que la asignación corriera.

### 2.4 `OFS`: separador de salida, pero solo al reconstruir `$0`

```bash
printf 'a:b:c\n' | awk 'BEGIN { FS = ":"; OFS = "-" } { $1 = $1; print }'
# a-b-c
```

`OFS` controla con qué separador `awk` reconstruye `$0` cuando se
imprime con `print` (sin argumentos) — pero **solo** si `$0` se
reconstruyó, lo cual pasa cuando se modifica al menos un campo. `$1 =
$1` (reasignar un campo a sí mismo) es el truco estándar para forzar esa
reconstrucción sin cambiar ningún valor real.

### 2.5 `-v`: variables desde la línea de comandos

```bash
awk -v umbral=100 '$2 > umbral { print $1 }' datos.txt
```

`-v nombre=valor` define una variable **antes** de que corra `BEGIN` —
la forma de pasarle a un programa de `awk` un valor que viene de fuera
(un argumento de script, una variable de bash), sin tener que editar el
programa.

### 2.6 `NR` vs `FNR` con varios archivos

```bash
awk 'FNR==1 { print "--- nuevo archivo:", FILENAME, "---" } { print }' fa.txt fb.txt
```

```
--- nuevo archivo: fa.txt ---
1
2
--- nuevo archivo: fb.txt ---
3
4
```

Con más de un archivo de entrada, `NR` sigue contando de forma
acumulada a través de todos los archivos; `FNR` se reinicia a `1` en
cada archivo nuevo. `FNR==1` es el patrón estándar para detectar "este
es el primer registro de un archivo nuevo" — útil, por ejemplo, para
saltear la cabecera de **cada** archivo en un conjunto de varios CSV.

### 2.7 La divergencia real de esta semana: `mawk` vs `gawk`

```bash
awk --version
readlink -f "$(command -v awk)"
```

En `ubuntu-lab` (y en Debian), `/usr/bin/awk` apunta a **`mawk`** — una
implementación liviana y rápida, pero incompleta frente al estándar
POSIX extendido. En RHEL/Fedora y en Arch, `/usr/bin/awk` apunta a
**`gawk`** (GNU Awk), que además de POSIX agrega varias extensiones
propias.

| Función/característica | `mawk` (Ubuntu/Debian) | `gawk` (RHEL/Fedora, Arch) |
|---|:--:|:--:|
| `BEGIN`/`END`, `FS`/`OFS`/`ORS`, `-v`, `NR`/`FNR` | ✅ | ✅ |
| Arrays asociativos, `for...in`, `delete` | ✅ | ✅ |
| `sub`/`gsub`/`substr`/`split`/`sprintf` | ✅ | ✅ |
| `length(array)` | ✅ | ✅ |
| `gensub` (sustitución con regex que **devuelve** el resultado) | ❌ | ✅ |
| `asort`/`asorti` (ordenar un array dentro del programa) | ❌ | ✅ |
| `strftime`, manejo de fechas | ❌ | ✅ |

Todo lo construido en los archivos 01 a 05 de esta semana — y el
proyecto `sumfield` — usa solo la fila de arriba (✅ en ambos), a
propósito: corre igual en los cuatro contenedores del laboratorio. Las
filas de abajo son extensiones de `gawk` que simplemente **no
existen** en `mawk` — no es una versión vieja, es una función ausente,
y usarla sin confirmar primero rompe el script en cualquier sistema con
`mawk` como `awk` por defecto.

```bash
awk 'BEGIN { print gensub(/a/, "X", "g", "banana") }'
```

```
awk: line 2: function gensub never defined
```

## 3. Cómo se usa

```bash
# Encabezado, procesamiento y resumen en un solo programa
awk 'BEGIN { print "=== reporte ===" }
     { total += $2 }
     END { print "total:", total }' ventas.log

# Pasar un umbral configurable desde bash
umbral=500
awk -v umbral="$umbral" '$2 > umbral { print $1 }' ventas.log

# Saltear la cabecera de CADA archivo en un conjunto de varios CSV
awk -F, 'FNR==1 { next } { total += $3 } END { print total+0 }' *.csv

# Confirmar que awk es compatible antes de usar una extension de gawk
awk --version | head -1
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Asignar `FS` fuera de `BEGIN` esperando que afecte toda la línea actual | La línea actual ya se dividió con el `FS` anterior — el cambio solo aplica desde la próxima línea | Asignar `FS` en `BEGIN` cuando debe aplicar desde el principio |
| Esperar que `OFS` cambie la salida sin modificar ningún campo | `$0` solo se reconstruye con el nuevo `OFS` si se reasigna al menos un campo | `$1 = $1` (u otra reasignación) para forzar la reconstrucción |
| Confundir `NR` con `FNR` al procesar varios archivos | `NR` sigue la cuenta entre archivos; `FNR` se reinicia — usar el equivocado da un número de línea que no corresponde al archivo actual | `FNR` cuando el conteo debe ser relativo a cada archivo, `NR` cuando debe ser global |
| Usar una función de `gawk` (`gensub`, `asort`) sin confirmar qué `awk` corre | El script funciona en tu laptop (con `gawk`) y falla en `ubuntu-lab` o en producción (con `mawk`), con un error que no deja claro por qué | `awk --version` antes de depender de cualquier extensión, y preferir las funciones POSIX compartidas cuando el script debe ser portable |

## 5. Trucos

- `awk --version | head -1` (o `readlink -f "$(command -v awk)"` si
  `--version` no está disponible) confirma en segundos cuál `awk` está
  corriendo, antes de perder tiempo depurando un error de "función no
  definida".
- Si un script necesita específicamente `gawk`, invocarlo como `gawk
  '...'` en vez de `awk '...'` lo deja explícito y evita que corra
  accidentalmente con `mawk` en un sistema donde ambos están instalados.
- `FNR==NR` (verdadero solo mientras se procesa el **primer** archivo de
  una lista de varios) es un patrón clásico para comparar dos archivos
  línea por línea dentro de un mismo programa `awk`.

## Resumen

`BEGIN` corre antes de la primera línea, `END` después de la última.
`FS` en `BEGIN` afecta todo el archivo; asignado durante el
procesamiento, solo las líneas siguientes. `OFS` requiere reconstruir
`$0` (con `$1=$1`) para tomar efecto. `-v` pasa variables externas;
`FNR` se reinicia por archivo, `NR` no. `mawk` (Ubuntu/Debian) cubre
POSIX pero no las extensiones de `gawk` (RHEL/Fedora, Arch) como
`gensub` o `asort` — confirmar con `awk --version` antes de depender de
cualquiera de ellas.

## 📚 Recursos Adicionales

- [GNU Awk User's Guide — Built-in Variables](https://www.gnu.org/software/gawk/manual/gawk.html#Built_002din-Variables) — `FS`, `OFS`, `ORS`, `NR`, `FNR` y el resto.
- [mawk — man page](https://invisible-island.net/mawk/manpage/mawk.html) — documentación del `awk` por defecto de Ubuntu/Debian.
- [GNU Awk User's Guide — Extensions](https://www.gnu.org/software/gawk/manual/gawk.html#Awk-Summary) — qué funciones son extensiones propias de `gawk`, no POSIX.

## ✅ Checklist de Verificación

- [ ] Usaste `BEGIN` para un encabezado y `END` para un resumen, en el mismo programa
- [ ] Reprodujiste por qué `FS` asignado fuera de `BEGIN` no afecta la línea actual
- [ ] Forzaste la reconstrucción de `$0` con `OFS` usando `$1=$1`
- [ ] Distinguiste `NR` de `FNR` procesando dos archivos en una sola invocación
- [ ] Confirmaste con `awk --version` cuál `awk` corre en `ubuntu-lab`, y reprodujiste un error de `gensub` por no estar disponible en `mawk`

---

[← 05 — Funciones de cadena y printf](05-funciones-de-cadena-y-printf.md) · [07 — awk como pipeline completo →](07-awk-como-pipeline-completo.md)
