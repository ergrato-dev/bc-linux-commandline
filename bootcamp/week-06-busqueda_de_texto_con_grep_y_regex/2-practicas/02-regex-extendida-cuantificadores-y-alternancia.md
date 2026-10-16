# Práctica 02: Regex extendida, cuantificadores y alternancia

Esta práctica reproduce, dentro de `ubuntu-lab`, la diferencia real entre
BRE y ERE, y construye el patrón de alternancia que usa `logscan`.

## Paso 1: `{n,m}` sin escape en BRE no es un cuantificador

**Por qué**: es el error más silencioso de esta semana — sin `-E` y sin
escapar las llaves, `grep` no interpreta `{n,m}` como "repetir", sino
como texto literal.

**Comando**:

```bash
cd ~/practica-grep
printf "a{2,3}\naaa\naa\na\n" > llaves.txt
grep "a{2,3}" llaves.txt
grep "a\{2,3\}" llaves.txt
```

**Verifica**:

```bash
grep "a{2,3}" llaves.txt
# a{2,3}        <- matcheo el TEXTO LITERAL, llaves incluidas
grep "a\{2,3\}" llaves.txt
# aaa
# aa             <- ahora SI es el cuantificador: 2 a 3 "a" seguidas
```

## Paso 2: El mismo patrón, en ERE

**Por qué**: confirmar que `-E` invierte qué necesita escape — sin tocar
el patrón salvo quitarle las barras invertidas.

**Comando**:

```bash
grep -E "a{2,3}" llaves.txt
```

**Verifica**:

```bash
grep -E "a{2,3}" llaves.txt
# aaa
# aa
```

Mismo resultado que `grep "a\{2,3\}"` del paso anterior, sin ninguna barra
invertida — eso es exactamente lo que cambia `-E`.

## Paso 3: `?` como cuantificador, BRE con escape vs ERE sin escape

**Por qué**: confirmar el mismo patrón de escape invertido con otro
cuantificador, no solo con `{n,m}`.

**Comando**:

```bash
printf "color\ncolour\ncolouur\n" > color.txt
grep "colou\?r" color.txt
grep -E "colou?r" color.txt
```

**Verifica**: ambos comandos dan el mismo resultado — las dos grafías
válidas de la palabra, pero no `colouur` (dos "u" seguidas no cumple "cero
o una").

```bash
grep "colou\?r" color.txt
# color
# colour
```

## Paso 4: Agrupar para que el cuantificador aplique a más de un carácter

**Por qué**: sin agrupar, un cuantificador solo repite el carácter
inmediatamente anterior — agrupar cambia esa unidad.

**Comando**:

```bash
printf "haaa\nhahaha\nhaha\nha\n" > repeticion.txt
grep -E "ha{2,3}" repeticion.txt
grep -E "(ha){2,3}" repeticion.txt
```

**Verifica**: el primer patrón repite solo la `a` (coincide con `haaa`,
donde la `a` se repite 3 veces); el segundo repite el par `ha` completo
(coincide con `hahaha` y `haha`).

```bash
grep -E "ha{2,3}" repeticion.txt
# haaa
grep -E "(ha){2,3}" repeticion.txt
# hahaha
# haha
```

## Paso 5: Alternancia — el patrón real de `logscan`

**Por qué**: este es, literalmente, el patrón por defecto que usa
`toolkit.sh logscan` para detectar las tres severidades problemáticas en
una sola pasada.

**Comando**:

```bash
printf "INFO ok\nERROR disco\nWARN memoria\nCRIT kernel\n" > severidad.log
grep -E "ERROR|WARN|CRIT" severidad.log
grep "ERROR\|WARN\|CRIT" severidad.log
```

**Verifica**: ambos comandos muestran las tres líneas problemáticas, sin
la línea `INFO`.

```bash
grep -E "ERROR|WARN|CRIT" severidad.log | wc -l
# 3
```

## Paso 6: Referencia hacia atrás para encontrar una palabra duplicada

**Por qué**: un error de edición real (copiar y pegar una palabra dos
veces) es exactamente el caso donde una referencia hacia atrás encuentra
algo que no se podría buscar con un patrón fijo, porque no se sabe de
antemano cuál palabra está duplicada.

**Comando**:

```bash
printf "palabra duplicada duplicada aqui\ntexto normal sin repeticion\n" > dup.txt
grep -E "\b([[:alpha:]]+) \1\b" dup.txt
```

**Verifica**:

```bash
grep -E "\b([[:alpha:]]+) \1\b" dup.txt
# palabra duplicada duplicada aqui
```

Solo la línea con la palabra repetida aparece — `\1` exige que el segundo
grupo de palabra sea **exactamente** el mismo texto que el primero,
cualquiera que sea.

## ✅ Resultado

- [ ] Reprodujiste por qué `{n,m}` sin escape en BRE es literal, no un cuantificador
- [ ] Confirmaste el mismo cuantificador funcionando sin escape en ERE (`-E`)
- [ ] Agrupaste con `(...)` y confirmaste que cambia qué repite el cuantificador
- [ ] Construiste el patrón `ERROR|WARN|CRIT` y lo probaste contra un log propio
- [ ] Usaste una referencia hacia atrás (`\1`) para encontrar una palabra duplicada sin conocerla de antemano

```bash
./scripts/verificar-semana.sh 06
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `grep "a{2,3}"` matchea `aaa` igual, sin escape | Puede estar corriendo con `-E` activo por un alias (`alias grep='grep -E'`) sin darte cuenta | Confirmar con `type grep` que no hay un alias activo, o probar en una shell nueva |
| `grep -E "(ha){2,3}"` no encuentra nada | El archivo no tiene ninguna línea con el par repetido 2 o 3 veces exactas | Confirmar el contenido de `repeticion.txt` con `cat -A repeticion.txt` para ver si hay espacios o caracteres invisibles |
| La referencia hacia atrás del Paso 6 no encuentra la línea esperada | El grupo `(...)` no es el primero del patrón, o `\1` no corresponde al grupo que se pensaba | Contar los grupos de izquierda a derecha empezando en 1, y confirmar cuál es realmente el primero |

---

[← Práctica 01 — grep básico y anclas](01-grep-basico-y-anclas.md) · [Práctica 03 →](03-limites-de-palabra-grep-perl-y-busqueda-recursiva.md)
