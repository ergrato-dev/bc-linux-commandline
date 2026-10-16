# tr: traducir, borrar y comprimir caracteres

> `sed` opera sobre patrones; `tr` opera **carácter por carácter**, sin
> ningún concepto de "patrón" ni de línea — ni siquiera sabe qué es una
> línea, lo cual explica el antipatrón más peligroso de este archivo:
> `-c` puede comerse tus saltos de línea sin ningún aviso.

## 🎯 Objetivos

- Traducir un conjunto de caracteres a otro con `tr SET1 SET2`
- Borrar caracteres con `-d` y comprimir repeticiones con `-s`
- Usar `-c` (complemento) entendiendo que también afecta al salto de línea
- Usar clases POSIX (`[:upper:]`, `[:digit:]`, etc.) igual que en `grep`

## 1. Qué problema resuelve

Convertir todo a mayúsculas, quitar los retornos de carro (`\r`) de un
archivo editado en Windows, o comprimir espacios múltiples a uno solo —
ninguna de estas tareas busca un patrón: son transformaciones de
**caracteres individuales**, exactamente lo que `tr` hace, sin la
sobrecarga de un motor de regex para algo que no lo necesita.

## 2. Cómo funciona

### 2.1 Traducir: `tr SET1 SET2`

```bash
printf 'hola mundo\n' | tr 'a-z' 'A-Z'
# HOLA MUNDO
```

Cada carácter de `SET1` se traduce al carácter en la **misma posición**
de `SET2` — la `a` (primera de `a-z`) se convierte en `A` (primera de
`A-Z`), y así con cada par. No hay patrón ni contexto: es una tabla de
sustitución, carácter por carácter.

### 2.2 Sets de distinto largo: el último carácter se repite

```bash
printf 'abcdef\n' | tr 'a-f' 'XY'
# XYYYYY
```

Si `SET2` es más corto que `SET1`, GNU `tr` repite el **último**
carácter de `SET2` para completar — acá, todo después de la `b` se
traduce a `Y`. Es un comportamiento real, no un error, pero vale la pena
conocerlo antes de que sorprenda.

### 2.3 `-t`: truncar en vez de extender

```bash
printf 'abcdef\n' | tr -t 'a-f' 'XY'
# XYcdef
```

`-t` cambia el comportamiento de la sección anterior: en vez de repetir
el último carácter de `SET2` para completar, **trunca** `SET1` al largo
de `SET2` — solo traduce `a` y `b` (los primeros dos caracteres de
`a-f`), dejando el resto de `SET1` sin tocar. Útil cuando la intención
real era traducir solo esos primeros caracteres, no "lo que sobra,
traducilo igual al último".

### 2.4 `-d`: borrar caracteres

```bash
printf 'h3ll0 w0rld\n' | tr -d '0-9'
# hll wrld
```

Sin un `SET2`, `-d` simplemente elimina cada carácter que coincide con
`SET1` — no los traduce a nada, los quita.

### 2.5 `-s`: comprimir repeticiones consecutivas

```bash
printf 'aaa   bbb\n' | tr -s ' '
# aaa bbb
```

`-s` colapsa una secuencia de caracteres **repetidos consecutivos** del
set indicado a una sola aparición — útil para normalizar espacios
múltiples a uno solo antes de un `cut -d' '` (archivo 03 de esta semana),
que de otro modo trataría cada espacio de más como un campo vacío.

### 2.6 Clases POSIX, igual que en `grep`

```bash
printf 'Hola Mundo 123\n' | tr '[:lower:]' '[:upper:]'
# HOLA MUNDO 123

printf 'Hola Mundo 123\n' | tr -d '[:digit:]'
# Hola Mundo
```

Las mismas clases POSIX de la Semana 06 (`[:upper:]`, `[:lower:]`,
`[:digit:]`, `[:alpha:]`, `[:space:]`, etc.) funcionan como sets de `tr`,
sin depender de un rango ASCII fijo como `a-z`.

### 2.7 `-c`: complemento — y el peligro de que incluye el salto de línea

```bash
printf 'abc123\n' | tr -c '0-9' '_'
```

```
___123_
```

`-c` invierte el set: en vez de "estos caracteres", significa "todo
**excepto** estos caracteres". El resultado anterior parece correcto a
primera vista (`abc` se volvió `___`), pero mirá de cerca el final: el
**salto de línea también se tradujo**, porque `\n` tampoco está en el set
`0-9`. La línea perdió su `\n` final, reemplazado por `_`.

```bash
printf 'abc123\ndef456\n' | tr -sc '[:alpha:]' ' '
```

```
abc def
```

Este es el caso donde el problema se vuelve grave: **dos líneas
distintas** (`abc123` y `def456`) se fusionaron en **una sola**. `-c`
hizo que el salto de línea entrara en el complemento (no es `[:alpha:]`),
y `-s` comprimió esa secuencia completa de "no-letras" — dígitos, el
`\n`, más dígitos — en un único espacio, borrando la separación entre
líneas por completo.

## 3. Cómo se usa

```bash
# Quitar retornos de carro de un archivo editado en Windows
tr -d '\r' < archivo-windows.txt > archivo-unix.txt

# Comprimir espacios multiples antes de usar cut por columnas
cat -A archivo-con-columnas.txt | tr -s ' ' | cut -d' ' -f2

# Convertir todo a minusculas para comparar sin distinguir caso
tr '[:upper:]' '[:lower:]' < nombres.txt | sort -u

# Contar solo los caracteres alfabeticos de un archivo (tr -d + wc -c)
tr -cd '[:alpha:]' < archivo.txt | wc -c
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `-c` sin pensar en el salto de línea | `\n` entra en el complemento de casi cualquier set — puede traducirse, borrarse o comprimirse junto con todo lo demás, fusionando o rompiendo líneas sin ningún aviso | Agregar `\n` explícitamente al set cuando se usa `-c` y las líneas deben conservarse: `tr -c '0-9\n' '_'` |
| Asumir que `SET1` y `SET2` deben tener el mismo largo | GNU `tr` repite el último carácter de `SET2` para completar — un set más corto "funciona" pero probablemente no como se esperaba | Igualar los largos de ambos sets explícitamente, o usar `-d`/clases POSIX cuando la intención no es una traducción 1-a-1 |
| Usar `tr` esperando que opere sobre patrones o palabras completas | `tr` no tiene concepto de "patrón" — opera carácter por carácter, sin contexto de lo que lo rodea | `sed` (archivos 01-02 de esta semana) cuando la transformación depende de texto, no de caracteres individuales |
| Pasar un rango de caracteres fuera de orden (`z-a`) esperando que `tr` lo invierta | `tr` no reordena rangos — un rango inválido es un error, no una instrucción de ir "al revés" | Escribir los rangos siempre de menor a mayor: `a-z`, nunca `z-a` |
| Escribir un set como `[0-9]`, copiando el hábito de `grep`/`sed` | `tr` no interpreta corchetes como delimitador de clase — además de tratar `0-9` como rango, también trata `[` y `]` como caracteres literales del set, afectándolos también sin querer | Escribir el rango sin corchetes (`0-9`), o una clase POSIX con doble corchete (`[:digit:]`) cuando la intención es esa |

## 5. Trucos

- `tr -d '[:punct:]'` quita toda la puntuación de un texto de una sola
  vez, sin enumerar cada símbolo a mano.
- `tr -d '\n'` convierte un archivo multilínea en una sola línea larga —
  útil antes de un `grep`/`sed` que necesita ver todo el contenido como
  una unidad (con cuidado: pierde la noción de "línea" por completo).
- `tr -cd '[:print:]\n'` elimina caracteres de control invisibles de un
  archivo (como los que a veces vienen de un copy-paste con formato),
  conservando el texto imprimible y los saltos de línea.
- `tr ' ' '\n'` convierte una lista separada por espacios en una lista de
  una palabra por línea — un primer paso común antes de `sort | uniq -c`.

## Resumen

`tr SET1 SET2` traduce carácter por carácter, sin ningún concepto de
patrón ni de línea — ni siquiera de corchetes como clase, a diferencia
de `grep`/`sed`. `-d` borra; `-s` comprime repeticiones consecutivas.
Las clases POSIX de `grep` funcionan igual acá. `-c` invierte el set —
pero como el salto de línea casi nunca está incluido explícitamente,
`-c` puede traducir, borrar o comprimir los saltos de línea junto con
todo lo demás, fusionando líneas sin ningún error visible. Si la
transformación depende de texto o contexto, no de caracteres sueltos, el
archivo 01 de esta semana (`sed`) es la herramienta correcta. El archivo
07 cierra la semana combinando `tr` con `cut`, `sort` y `uniq` en un solo
pipeline.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — tr invocation](https://www.gnu.org/software/coreutils/manual/coreutils.html#tr-invocation) — referencia completa de banderas y sets.
- `man tr` — disponible sin conexión en cualquier distro.

## ✅ Checklist de Verificación

- [ ] Tradujiste un set de caracteres a otro con `tr SET1 SET2`
- [ ] Reprodujiste la diferencia entre el comportamiento por defecto (repetir el último carácter) y `-t` (truncar)
- [ ] Borraste caracteres con `-d` y comprimiste repeticiones con `-s`
- [ ] Reprodujiste cómo `-c` traduce también el salto de línea, y por qué eso fusiona líneas al combinarlo con `-s`
- [ ] Usaste al menos dos clases POSIX como sets de `tr`
- [ ] Corregiste el gotcha de `-c` agregando `\n` explícitamente al set
- [ ] Confirmaste que `tr` no interpreta corchetes como clase de regex, a diferencia de `grep`/`sed`

---

[← 05 — uniq: duplicados adyacentes](05-uniq-duplicados-adyacentes.md) · [07 — Combinando el pipeline: cut, tr, sort y uniq →](07-combinando-el-pipeline-cut-tr-sort-uniq.md)
