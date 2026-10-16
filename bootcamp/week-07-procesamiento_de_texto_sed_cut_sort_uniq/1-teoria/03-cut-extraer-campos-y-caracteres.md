# cut: extraer campos y caracteres

> `grep` filtra líneas completas; `cut` recorta cada línea a solo la
> parte que importa — una columna de un CSV, el primer campo de
> `/etc/passwd`, los primeros tres caracteres de un código. Simple a
> propósito: para algo más flexible que una posición fija, la Semana 08
> trae `awk`.

## 🎯 Objetivos

- Extraer una o varias columnas de texto delimitado con `-d` y `-f`
- Extraer rangos de caracteres por posición con `-c`
- Invertir la selección con `--complement`
- Reconocer cuándo una línea sin el delimitador esperado puede dar un resultado inesperado

## 1. Qué problema resuelve

Un archivo como `/etc/passwd` tiene siete campos por línea separados por
`:`, pero la mayoría de las tareas solo necesitan uno (el nombre de
usuario, el shell). Leer la línea completa y descartar el resto a ojo no
escala — `cut` extrae exactamente la columna que importa, directo desde
la línea de comandos.

## 2. Cómo funciona

### 2.1 Campos delimitados: `-d` y `-f`

```bash
cut -d: -f1 /etc/passwd
```

```bash
printf 'root:x:0:0:root:/root:/bin/bash\n' | cut -d: -f1
# root
```

`-d` fija el delimitador (un solo carácter); `-f` indica qué campo(s)
extraer, contando desde 1.

### 2.2 Varios campos: lista o rango

```bash
printf 'root:x:0:0:root:/root:/bin/bash\n' | cut -d: -f1,5
# root:root

printf 'root:x:0:0:root:/root:/bin/bash\n' | cut -d: -f1-3
# root:x:0
```

`-f1,5` extrae esos dos campos puntuales (separados por coma); `-f1-3`
extrae un rango inclusive. `cut` conserva el delimitador original entre
los campos extraídos — el resultado sigue pareciendo una línea del mismo
formato, solo más corta.

### 2.3 Caracteres por posición: `-c`

```bash
printf 'abcdefgh\n' | cut -c1-3
# abc

printf 'abcdefgh\n' | cut -c3-
# cdefgh
```

`-c` ignora cualquier delimitador y corta por **posición de carácter** —
útil para formatos de ancho fijo (como la salida de algunos comandos de
sistema, o archivos de datos legados) donde no hay un separador real,
solo columnas de ancho constante. Un rango abierto (`3-`) llega hasta el
final de la línea.

### 2.4 `--complement`: invertir la selección

```bash
printf 'root:x:0:0:root:/root:/bin/bash\n' | cut -d: -f1 --complement
# x:0:0:root:/root:/bin/bash
```

En vez de elegir qué campos **sí** mostrar, `--complement` muestra
**todos menos** los indicados — útil cuando es más simple describir qué
excluir que enumerar todo lo demás.

### 2.5 El caso de una línea sin el delimitador esperado

```bash
printf 'sinseparador\n' | cut -d: -f2
# sinseparador
```

Si una línea no tiene el delimitador, `cut` por defecto imprime la línea
**completa**, no vacío ni un error — porque, técnicamente, esa línea
tiene un solo campo (ella misma), y pedir el campo 2 cuando solo existe
el 1 no se considera un error. Esto puede generar sorpresas en un
pipeline que espera que todas las líneas tengan el mismo formato.

```bash
printf 'a:b\nsindelimitador\n' | cut -d: -f2 -s
# b
```

`-s` (*suppress*) corrige esto: omite por completo las líneas que no
contienen el delimitador, en vez de imprimirlas tal cual.

### 2.6 `cut` no reordena campos, aunque los pidas en otro orden

```bash
printf 'a:b:c\n' | cut -d: -f3,1
# a:c
```

Pedir `-f3,1` no invierte el orden para dar `c:a` — `cut` siempre
devuelve los campos en su posición **original** dentro de la línea, sin
importar en qué orden se los pidió. Reordenar de verdad columnas es
trabajo para `awk` (Semana 08), no para `cut`.

```bash
printf 'a:b:c\n' | cut -d: -f1,1,1
# a
```

Pedir el mismo campo varias veces tampoco lo repite en la salida — `cut`
deduplica los números de campo solicitados antes de extraer.

### 2.7 El delimitador de `cut` es siempre un solo carácter

```bash
printf 'a::b::c\n' | cut -d: -f2
# (vacío)
```

`cut` no entiende `::` como "un delimitador de dos caracteres" — cada
`:` cuenta como un delimitador separado. La línea `a::b::c` tiene, para
`cut`, **cinco** campos (`a`, vacío, `b`, vacío, `c`), no tres. El campo
2 es la cadena vacía entre los dos `:` consecutivos, no `b`. Para
delimitadores de más de un carácter, `cut` no es la herramienta
correcta — hace falta `awk` o `tr -s` primero para colapsar el separador
a un solo carácter.

## 3. Cómo se usa

```bash
# Lista de usuarios del sistema (primer campo de /etc/passwd)
cut -d: -f1 /etc/passwd

# Shell de cada usuario (ultimo campo)
cut -d: -f7 /etc/passwd

# Las primeras 10 columnas de una salida de ancho fijo (como "ps" sin formatear)
ps aux | cut -c1-10

# Todo excepto la contrasena cifrada de un /etc/shadow (ejemplo, no se corre sin privilegios)
cut -d: -f2 --complement /etc/shadow
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Asumir que una línea sin el delimitador da un campo vacío o un error | Por defecto, `cut` imprime la línea completa tal cual, silenciosamente | Usar `-s` cuando el pipeline espera que todas las líneas tengan el delimitador |
| Usar `cut -d' '` sobre texto con espacios múltiples o irregulares | Cada espacio cuenta como un delimitador distinto — dos espacios seguidos crean un campo vacío en el medio | Comprimir espacios repetidos primero con `tr -s ' '` (archivo 06 de esta semana) antes de `cut` |
| Usar `-c` sobre datos que en realidad tienen un delimitador real | La posición de cada columna puede variar si algún valor es más corto o más largo de lo esperado | `-d`/`-f` cuando existe un delimitador real, `-c` solo para formato de ancho verdaderamente fijo |
| Pedir `cut -d: -f5-2` (rango invertido) esperando que funcione igual que `-f2-5` | `cut` no reordena: directamente falla con `invalid decreasing range`, cortando cualquier script que no valide el orden del rango antes | Escribir el rango siempre de menor a mayor: `-f2-5` |
| Usar `-d` con un separador de más de un carácter (como `::` o ` - `) | `cut` solo entiende delimitadores de un solo carácter — cada aparición individual cuenta como separador, generando campos vacíos donde no se esperaban | Colapsar el separador a un solo carácter con `tr -s` antes de `cut`, o usar `awk` (Semana 08) cuando el delimitador real tiene más de un carácter |

## 5. Trucos

- `cut -d: -f1 /etc/passwd | sort` da la lista de usuarios del sistema en
  orden alfabético en una sola línea de pipeline.
- `cut -d: -f2-` (rango abierto) extrae desde el campo 2 hasta el final
  de la línea, sin necesitar saber cuántos campos tiene en total; `-f-2`
  hace lo mismo desde el campo 1 hasta el 2.
- `cut --output-delimiter=', '` cambia el delimitador de **salida** sin
  afectar cuál se usa para dividir la entrada — útil para convertir un
  formato delimitado por `:` a uno separado por `, ` en el mismo paso.
- Cuando el delimitador es un tab real (no espacios), `-d$'\t'` (con la
  sintaxis de comilla de bash `$'...'`) lo especifica sin ambigüedad.

## Resumen

`cut -d DELIM -f N[,M][-M]` extrae columnas delimitadas; `cut -c N[-M]`
extrae por posición de carácter, ignorando cualquier delimitador.
`--complement` invierte la selección. Una línea sin el delimitador se
imprime completa por defecto — `-s` la omite en vez de dejarla pasar tal
cual. `cut` es deliberadamente simple: para lógica de columnas más
compleja (campos calculados, condiciones), la Semana 08 trae `awk`.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — cut invocation](https://www.gnu.org/software/coreutils/manual/coreutils.html#cut-invocation) — referencia completa de banderas.
- `man cut` — disponible sin conexión en cualquier distro.

## ✅ Checklist de Verificación

- [ ] Extrajiste un campo y un rango de campos delimitados con `-d`/`-f`
- [ ] Extrajiste un rango de caracteres por posición con `-c`
- [ ] Usaste `--complement` para invertir una selección de campos
- [ ] Reprodujiste el comportamiento por defecto de `cut` ante una línea sin el delimitador esperado, y lo corregiste con `-s`

---

[← 02 — sed: direcciones, múltiples comandos y edición in-place](02-sed-direcciones-multiples-comandos-y-edicion-in-place.md) · [04 — sort: ordenar con criterio →](04-sort-ordenar-con-criterio.md)
