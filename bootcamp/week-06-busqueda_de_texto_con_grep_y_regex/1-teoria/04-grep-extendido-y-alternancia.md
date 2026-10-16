# grep extendido, alternancia y agrupación

> "Busca `ERROR` **o** `WARN` **o** `CRIT`, en una sola pasada" no se puede
> expresar con lo visto hasta ahora — hace falta alternancia, y para
> aplicarla a un grupo de caracteres en vez de a todo el patrón, agrupación.
> Esta es la regex que convierte a `logscan` (el proyecto de esta semana)
> en una sola línea, no en tres `grep` separados.

## 🎯 Objetivos

- Buscar varias alternativas en una sola expresión con `|`
- Agrupar parte de un patrón con `(...)` para que el cuantificador o la alternancia aplique solo ahí
- Usar referencias hacia atrás (`\1`) para detectar texto repetido
- Combinar alternancia y agrupación para construir un patrón de severidad de logs

## 1. Qué problema resuelve

Un log real no tiene un solo tipo de línea problemática: tiene `ERROR`,
`WARN`, `CRIT`, y a veces variantes como `Error:` o `[ERROR]`. Correr un
`grep` distinto por cada palabra (`grep ERROR`, después `grep WARN`,
después juntar los resultados) multiplica el trabajo y los pasos donde
algo puede salir mal. La alternancia resuelve esto en un solo patrón, una
sola pasada por el archivo.

## 2. Cómo funciona

### 2.1 Alternancia: `|`

```bash
grep -E "ERROR|WARN|CRIT" app.log
```

```bash
printf 'ERROR x\nWARN y\nINFO z\n' | grep -E "ERROR|WARN"
# ERROR x
# WARN y
```

`|` significa "esto **o** esto otro **o** esto otro" — coincide si
**cualquiera** de las alternativas aparece en la línea. En ERE (`grep -E`)
no necesita escape; en BRE, sí: `grep "ERROR\|WARN"` es el equivalente sin
`-E`.

```bash
printf 'ERROR x\nWARN y\nINFO z\n' | grep "ERROR\|WARN"
# ERROR x
# WARN y
```

Esto es exactamente el patrón por defecto de `logscan`, el subcomando de
`toolkit` de esta semana: `ERROR|WARN|CRIT` como alternancia, para
detectar las tres severidades problemáticas en una sola pasada por cada
archivo `.log`.

### 2.2 Agrupación: `(...)`

```bash
grep -E "^(ha){2,3}$"
```

```bash
printf 'hahaha\nhaha\nha\nh\n' | grep -E "^(ha){2,3}$"
# hahaha
# haha
```

Sin agrupar, un cuantificador aplica solo al carácter o clase
**inmediatamente anterior**: `ha{2,3}` repetiría solo la `a` (`haaa`,
`haa`), no el par `ha`. `(ha)` agrupa esos dos caracteres en una sola
unidad, y `{2,3}` ahora repite el grupo completo, no solo la última letra.

```bash
# diferencia exacta: cuantificador sin agrupar vs con agrupar
printf 'haaa\n' | grep -E "ha{2,3}"     # matchea: "a" repetida 2-3 veces
printf 'hahaha\n' | grep -E "(ha){2,3}" # matchea: "ha" repetido 2-3 veces
```

En BRE, la agrupación también necesita escape: `\(...\)`.

### 2.3 Alternancia dentro de un grupo

```bash
grep -E "(ERROR|WARN): .+" app.log
```

Agrupar una alternancia permite aplicarle algo más al resultado completo
de "cualquiera de estas opciones" — en este caso, exigir que después venga
literalmente `: ` seguido de algún texto. Sin el grupo, `|` separaría el
patrón entero en dos mitades independientes, no en una alternancia
seguida de algo en común.

```bash
# sin agrupar: "ERROR" O "WARN: .+" (dos patrones independientes, NO lo que se queria)
grep -E "ERROR|WARN: .+" app.log
```

### 2.4 Referencias hacia atrás: `\1`

```bash
printf 'abcabc\nabcxyz\nxyzxyz\n' | grep -E "^(.+)\1$"
# abcabc
# xyzxyz
```

`\1` se refiere a lo que **efectivamente** coincidió con el primer grupo
`(...)` de ese mismo patrón — no al patrón en sí, sino al texto concreto
que matchéo ahí. `^(.+)\1$` encuentra líneas formadas por **cualquier**
texto repetido exactamente dos veces, sea cual sea ese texto. Esto es una
extensión de GNU (las referencias hacia atrás no forman parte del
estándar POSIX ERE), disponible tanto en BRE como en ERE con `grep`.

```bash
printf 'abcabc\nabcxyz\n' | grep "^\(.\+\)\1$"
# abcabc
```

Útil para detectar, por ejemplo, una palabra duplicada por error en un
archivo de configuración, sin tener que saber de antemano cuál palabra.

### 2.5 Alternancia con más de una condición fija alrededor

```bash
printf 'error 500\nerror 404\nwarn 500\nok 200\n' | grep -E "^(error|warn) (500|404)$"
# error 500
# error 404
# warn 500
```

Dos grupos de alternancia en el mismo patrón se combinan de forma
independiente: cualquier combinación de la primera alternativa con
cualquiera de la segunda cuenta como coincidencia. `ok 200` no aparece
porque `ok` no está en el primer grupo, aunque `200` tampoco esté en el
segundo — ninguno de los dos grupos necesita fallar para que la línea
completa no coincida, alcanza con que falle uno.

## 3. Cómo se usa

```bash
# El patron real de logscan: tres severidades, una sola pasada
grep -rEn --include='*.log' "ERROR|WARN|CRIT" /var/log/app/

# Lineas de error en ingles O en espanol, mismo patron
grep -E "error|fallo" app.log

# Agrupar + cuantificador: una IP con grupos de 1 a 3 digitos
grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" config.conf

# Detectar una palabra inmediatamente repetida (typo comun de copiar y pegar)
grep -E "\b([[:alpha:]]+) \1\b" documento.txt

# Conteo por archivo de las tres severidades, recursivo (anticipo del archivo 06)
grep -rc --include='*.log' -E "ERROR|WARN|CRIT" /var/log/app/
# app/db.log:1
# app/web.log:1
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Correr un `grep` separado por cada alternativa y combinar resultados a mano | Más pasos, más lugares donde el orden o el conteo final puede salir mal | Una sola alternancia: `grep -E "A|B|C"` |
| `|` sin agrupar cuando se necesita aplicar algo al resultado completo | `A|B: texto` se lee como "A, o B seguido de texto" — no como se esperaba | Agrupar la alternancia: `(A|B): texto` |
| Usar `\1` sin verificar qué grupo numera cada paréntesis | Con más de un grupo en el patrón, `\1` puede no referirse al que se piensa | Contar los grupos de izquierda a derecha, empezando en 1, antes de usar cualquier referencia hacia atrás |
| Alternativas que se solapan sin pensar el orden | En algunos motores de regex el orden de las alternativas afecta cuál gana — vale la pena confirmarlo en vez de asumir | Probar el patrón contra casos de borde reales antes de confiar en el orden |

## 5. Trucos

- `grep -E "A|B|C"` escala mejor que agregar cada palabra nueva a un
  patrón BRE con `\|` repetido — más legible con más de dos alternativas.
- Agrupar con `(?:...)` (grupo "no capturante") existe en PCRE
  (`grep -P`, archivo 05) para cuando se necesita agrupar sin que cuente
  como referencia numerada — no disponible en BRE/ERE estándar.
- `grep -E "\b(palabra) \1\b"` es una forma rápida de encontrar palabras
  duplicadas consecutivas en un texto, un error de edición común.

## Resumen

`|` (alternancia) busca cualquiera de varias opciones en una sola pasada
— sin escape en ERE (`grep -E`), con `\|` en BRE. `(...)` agrupa parte de
un patrón para que un cuantificador o la alternancia apliquen solo a ese
grupo, no al patrón completo. `\1` referencia el texto que coincidió con
el primer grupo, útil para detectar repeticiones sin conocerlas de
antemano. La combinación `ERROR|WARN|CRIT` es, literalmente, el patrón por
defecto de `logscan`.

## 📚 Recursos Adicionales

- [GNU Grep Manual — Regular Expressions](https://www.gnu.org/software/grep/manual/grep.html#Regular-Expressions) — alternancia, agrupación y referencias hacia atrás.
- `man 7 regex` — gramática formal de agrupación en BRE y ERE.
- [GNU Grep Manual — Basic vs Extended](https://www.gnu.org/software/grep/manual/grep.html#Basic-vs-Extended) — por qué `\1` funciona en ambos dialectos aunque sea una extensión no estándar.

## ✅ Checklist de Verificación

- [ ] Construiste una alternancia de tres o más opciones con `grep -E "A|B|C"`
- [ ] Reprodujiste la diferencia entre `ha{2,3}` y `(ha){2,3}`
- [ ] Agrupaste una alternancia y la combinaste con texto fijo: `(A|B): texto`
- [ ] Usaste `\1` para detectar un texto repetido sin conocerlo de antemano
- [ ] Reprodujiste el patrón por defecto de `logscan` (`ERROR|WARN|CRIT`) contra un log propio

---

[← 03 — Cuantificadores y BRE vs ERE](03-cuantificadores-y-bre-vs-ere.md) · [05 — Límites de palabra y grep -P →](05-limites-de-palabra-y-grep-perl.md)
