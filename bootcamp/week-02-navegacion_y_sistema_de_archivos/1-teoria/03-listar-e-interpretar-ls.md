# Listar e interpretar `ls`

> `ls -la` es probablemente el comando que más vas a escribir en tu vida de
> terminal. La mayoría de la gente nunca aprende a leer lo que imprime.

## 🎯 Objetivos

- Usar los flags de `ls` con criterio, no por costumbre
- Leer cada columna de `ls -l` e interpretar qué significa
- Ordenar y filtrar listados según lo que necesites ver

## 1. Qué problema resuelve

`ls` sin flags apenas muestra nombres. La información realmente útil —
tamaño, dueño, permisos, fecha de modificación, si es un enlace— está detrás
de `-l`, y la mayoría de la gente la mira sin entenderla columna por
columna. Aprender a leer `ls -l` de corrido es lo que te permite responder
"¿quién puede escribir este archivo?" o "¿hace cuánto se modificó esto?" sin
correr un comando aparte para cada pregunta.

## 2. Cómo funciona

### 2.1 Flags esenciales

| Flag | Qué hace |
|---|---|
| `-l` | Formato largo: permisos, dueño, grupo, tamaño, fecha, nombre |
| `-a` | Incluye archivos ocultos (los que empiezan con `.`) |
| `-h` | Tamaños legibles (`4.0K`, `1.2M`) en vez de bytes exactos — se usa junto a `-l` |
| `-t` | Ordena por fecha de modificación, más reciente primero |
| `-r` | Invierte el orden (combinable con `-t`: más viejo primero) |
| `-S` | Ordena por tamaño, más grande primero |
| `-R` | Lista recursivamente, subcarpeta por subcarpeta |
| `-d` | Muestra la carpeta misma, no su contenido (útil con glob patterns) |
| `-i` | Muestra el número de inodo de cada entrada |

Estos flags se combinan: `ls -laht` es probablemente la combinación más
común en la práctica real (formato largo, ocultos, legible, por fecha).

### 2.2 Archivos ocultos: la convención del punto inicial

En Linux, "oculto" no es un atributo especial del archivo — es pura
convención: cualquier nombre que empiece con `.` queda fuera de un listado
normal, y `ls` lo respeta por default.

```bash
ls
# (no muestra .bashrc, .bash_history, etc.)

ls -a
# .  ..  .bashrc  .bash_history  bin  documentos
```

Notá que `-a` también muestra `.` (el directorio actual) y `..` (el padre) —
son entradas reales del sistema de archivos, no decoración.

### 2.3 Leer `ls -l`, columna por columna

```bash
ls -l /etc/hostname
# -rw-r--r-- 1 root root 12 ene  1 10:00 /etc/hostname
```

| Columna | Valor del ejemplo | Qué es |
|---|---|---|
| 1 | `-rw-r--r--` | Tipo de archivo (primer carácter) + permisos (nueve siguientes) |
| 2 | `1` | Cantidad de enlaces duros a este archivo |
| 3 | `root` | Usuario dueño |
| 4 | `root` | Grupo dueño |
| 5 | `12` | Tamaño en bytes |
| 6 | `ene  1 10:00` | Fecha de última modificación |
| 7 | `/etc/hostname` | Nombre (o ruta, si la diste así) |

El **primer carácter** de la columna 1 no es parte de los permisos: indica
el *tipo* de archivo (`-` regular, `d` directorio, `l` enlace simbólico,
entre otros) — se profundiza en el archivo siguiente de esta semana. Los
permisos en sí (los nueve caracteres restantes) se explican a fondo recién
en la Semana 04; acá alcanza con reconocer que esa columna existe y dónde
está cada parte.

### 2.4 El total que aparece arriba de `ls -l`

```bash
ls -l /etc | head -3
# total 1544
# drwxr-xr-x  2 root root  4096 ene  1 10:00 NetworkManager
# -rw-r--r--  1 root root   92 ene  1 10:00 adduser.conf
```

Esa línea `total 1544` **no** es la suma de los tamaños que ves abajo — es
la cantidad de bloques de disco (típicamente de 1 KB) que ocupan los
*metadatos* de las entradas listadas. Confundirla con "el tamaño total de la
carpeta" es un error común; para eso existe `du -sh`, no `ls`.

### 2.5 Los colores de `ls` no son decoración

Cuando corres `ls --color=auto` (lo que hace el alias `ll` que configuraste
en la Semana 01), cada color codifica el tipo de entrada: azul para
directorios, verde para ejecutables, celeste para enlaces simbólicos, rojo
parpadeante para enlaces rotos (que apuntan a algo que ya no existe), entre
otros. Esta paleta la define la variable de entorno `LS_COLORS`:

```bash
echo "$LS_COLORS" | tr ':' '\n' | head -5
# rs=0
# di=01;34
# ln=01;36
# mh=00
# pi=40;33;01
```

No hace falta memorizar los códigos — alcanza con saber que **existen** y
que un color inesperado (por ejemplo, un enlace en rojo parpadeante) es una
señal real: ese enlace simbólico apunta a algo que ya no está.

### 2.6 Fechas: formato por defecto versus `--time-style`

El formato de fecha de `ls -l` cambia según qué tan vieja sea la
modificación (muestra la hora si es reciente, el año si es antigua), lo cual
dificulta comparar fechas a simple vista o parsear la salida:

```bash
ls -l --time-style=long-iso /etc/hostname
# -rw-r--r-- 1 root root 12 2026-01-01 10:00 /etc/hostname
```

`--time-style=long-iso` fuerza un formato de fecha único y sin ambigüedad
(`AAAA-MM-DD HH:MM`) — preferible tanto para leer a simple vista como para
cualquier procesamiento posterior.

## 3. Cómo se usa

```bash
# La combinacion mas comun en el uso diario
ls -laht /var/log

# Los 5 archivos mas grandes de un directorio
ls -lhS /var/log | head -6

# Los 5 modificados mas recientemente
ls -lt /var/log | head -6

# Solo directorios, no su contenido
ls -ld /etc/*/
```

```bash
# Ver el inodo de un archivo (dos nombres distintos pueden compartir inodo:
# son enlaces duros al mismo contenido, tema que se retoma en el archivo 04)
ls -li /etc/hostname
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Leer el "total" de `ls -l` como el tamaño de la carpeta | Es metadatos de bloques, no una suma de tamaños reales | Usar `du -sh carpeta` para el tamaño real en disco |
| Usar `ls` para scripts que necesitan procesar nombres de archivo | La salida de `ls` cambia de formato entre configuraciones/aliases y no maneja bien nombres con espacios o saltos de línea | Usar `find` (Semana 09) o globbing (archivo 05 de esta semana) dentro de scripts |
| Olvidar `-a` y asumir que un directorio está vacío | Un directorio con solo archivos ocultos (como un repo git recién clonado con solo `.git`) parece vacío sin `-a` | Probar `ls -a` antes de concluir que algo está vacío |
| Confundir el primer carácter de los permisos con parte de ellos | Lleva a contar mal los bits de permiso (p. ej. pensar que hay diez permisos en vez de nueve) | Recordar: 1 carácter de tipo + 9 de permisos, siempre |
| Comparar fechas de `ls -l` entre archivos viejos y recientes a simple vista | El formato cambia solo (hora vs. año) según la antigüedad, lo que hace la comparación visual poco confiable | Forzar `--time-style=long-iso` antes de comparar fechas con precisión |

## 5. Trucos

- `ls -lhS | head` es el chequeo de dos segundos para "¿qué se está comiendo
  el espacio acá" antes de recurrir a herramientas más pesadas.
- `ls -d */` lista solo subdirectorios del nivel actual, aprovechando que el
  glob `*/` solo matchea nombres que terminan en `/` (es decir, carpetas).
- Muchas distros ya traen `alias ll='ls -la'` o similar por defecto —
  revisar `alias` antes de definir el tuyo propio evita redefinir algo que
  ya existía (viste esto en la Semana 01, vale la pena el recordatorio acá).
- `ls -1` (el número uno, no la letra ele) fuerza una entrada por línea sin
  columnas — útil al redirigir la salida a un archivo o al contarla con `wc -l`.

## Resumen

`ls -l` empaqueta siete columnas de información en una línea densa; leerla
de corrido (tipo, permisos, enlaces duros, dueño, grupo, tamaño, fecha,
nombre) reemplaza media docena de comandos sueltos. El "total" de arriba no
es tamaño real, los colores no son decorativos, y el formato de fecha por
defecto conviene fijarlo con `--time-style` en cuanto necesitas comparar
fechas con precisión.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — `ls` invocation](https://www.gnu.org/software/coreutils/manual/html_node/ls-invocation.html) — la lista completa de flags, más allá de los esenciales de este archivo.
- `man ls` — la misma referencia, offline.
- `dircolors --print-database` — vuelca la paleta completa que interpreta `LS_COLORS`, con el significado de cada código.

## ✅ Checklist de Verificación

- [ ] Leíste una línea de `ls -l` completa, columna por columna, sin mirar esta tabla
- [ ] Usaste `-t`, `-S` y `-h` combinados para encontrar el archivo más grande y el más reciente de un directorio
- [ ] Explicaste por qué el "total" de `ls -l` no es el tamaño de la carpeta
- [ ] Encontraste un enlace simbólico roto por su color (o creaste uno a propósito para verlo)
- [ ] Forzaste `--time-style=long-iso` y comparaste con el formato por defecto

---

[← 02 — El estándar FHS](02-el-estandar-fhs.md) · [04 — Tipos de archivo y enlaces →](04-tipos-de-archivo-y-enlaces.md)
