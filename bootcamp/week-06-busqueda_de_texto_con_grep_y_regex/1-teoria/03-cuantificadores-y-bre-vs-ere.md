# Cuantificadores y BRE vs ERE

> `grep` habla dos dialectos de regex por defecto, no uno — y la mitad de
> los "esto debería funcionar" con `grep` vienen de escribir un patrón en
> el dialecto equivocado sin saber que hay dos.

## 🎯 Objetivos

- Usar `*`, `\?` y `\+` como cuantificadores en BRE (expresión básica)
- Explicar por qué `grep -E` cambia qué caracteres necesitan escape
- Usar `{n,m}` para repeticiones exactas, en ambos dialectos
- Elegir entre BRE y ERE con intención, no por costumbre

## 1. Qué problema resuelve

"Cero o más", "uno o más", "entre dos y cuatro veces" — un patrón literal
o una clase de caracteres (archivo anterior) describen **qué** carácter
buscar, pero no **cuántas veces** puede repetirse. Los cuantificadores
agregan esa dimensión: convierten "un dígito" en "uno o más dígitos
seguidos", sin tener que escribir `[0-9][0-9][0-9]` a mano cada vez que
cambia la cantidad esperada.

## 2. Cómo funciona

### 2.1 BRE (Basic Regular Expressions): el dialecto por defecto de `grep`

Sin ninguna bandera, `grep` interpreta el patrón como **BRE** — el
dialecto más antiguo y más restrictivo, donde algunos metacaracteres
pierden su significado especial y necesitan una barra invertida para
recuperarlo:

```bash
printf 'aaa\n' | grep "a\{2,3\}"
# aaa    (coincide: 2 a 3 repeticiones de "a")
```

```bash
printf 'aaa\n' | grep "a{2,3}"
echo "exit=$?"
# exit=1   (NO matchea "aaa": en BRE, "{" y "}" sin escapar son literales)

printf 'a{2,3}\n' | grep "a{2,3}"
# a{2,3}   (SI matchea: el patron completo se busco como texto literal,
#           llaves incluidas, no como cuantificador)
```

El ejemplo anterior lo deja claro: en BRE, `{` y `}` sin escapar **no son**
un cuantificador — son literales. `grep "a{2,3}"` busca la cadena exacta
`a{2,3}`, con las llaves como caracteres de verdad, no "entre 2 y 3 letras
a". Para que `{n,m}` funcione como "repetir entre n y m veces" en BRE, hace
falta escaparlos:

| Cuantificador | BRE (por defecto) | ERE (`grep -E`) |
|---|---|---|
| Cero o más | `*` | `*` |
| Uno o más | `\+` | `+` |
| Cero o uno | `\?` | `?` |
| Entre n y m veces | `\{n,m\}` | `{n,m}` |
| Agrupar | `\(...\)` | `(...)` |

`*` es el único cuantificador que se comporta igual en ambos dialectos sin
escape — es el más viejo de los cuatro, parte del estándar desde antes de
que existiera la distinción BRE/ERE.

```bash
printf 'color\ncolour\n' | grep "colou\?r"
# color
# colour
```

`\?` en BRE dice "la `u` anterior, cero o una vez" — coincide con ambas
grafías de la palabra sin necesitar dos patrones separados.

### 2.2 ERE (Extended Regular Expressions): `grep -E`

```bash
printf 'aaa\n' | grep -E "a{2,3}"
# aaa    (ahora SI es inequivocamente el cuantificador)

printf 'color\ncolour\n' | grep -E "colou?r"
# color
# colour
```

Con `-E`, los metacaracteres `+`, `?`, `{`, `}`, `(`, `)`, `|` son
especiales **sin** necesitar escape — es el mismo motor de regex, con la
tabla de qué está escapado invertida. `egrep` es un alias histórico de
`grep -E`, documentado como forma obsoleta en el manual de GNU grep —
usar `grep -E` directamente es la forma recomendada hoy.

### 2.3 Por qué existen dos dialectos en vez de uno

BRE es el dialecto original de regex en Unix, de una época donde menos
caracteres se consideraban "especiales" por defecto, para minimizar
sorpresas en patrones simples. ERE llegó después, con más poder
expresivo por defecto, a costa de que más caracteres necesiten escape para
usarse como literales. `grep` mantiene ambos por compatibilidad retroactiva
con scripts de décadas atrás — no es una elección de diseño nueva, es
historia que sigue viva en el comando de hoy.

### 2.4 El mismo escape, en sentido inverso

```bash
grep "a+b" archivo.txt       # BRE: "+" es literal, busca "a+b" tal cual
grep -E "a\+b" archivo.txt   # ERE: "+" escapado, ahora SI busca "a+b" literal
```

Pasar de BRE a ERE no solo habilita cuantificadores nuevos: también
**invierte** qué significa escapar un carácter. Un patrón copiado de BRE a
`-E` sin revisar el escape puede cambiar de significado en silencio, no
solo fallar con un error visible.

### 2.5 El mismo patrón de escape invertido con paréntesis

```bash
printf 'funcion(x)\nfuncionx\n' | grep "funcion(x)"
# funcion(x)
```

En BRE, `(` y `)` **sin** escapar son literales — el patrón anterior
busca el texto exacto `funcion(x)`, paréntesis incluidos, sin agrupar
nada. Para usarlos como agrupación (archivo 04 de esta semana) en BRE,
hace falta escaparlos: `\(...\)`.

```bash
printf 'funcion(x)\nfuncionx\n' | grep -E "funcion\(x\)"
# funcion(x)
```

En ERE, es al revés: `(` y `)` sin escapar agrupan por defecto, así que
para buscarlos como paréntesis literales hay que escaparlos — el mismo
patrón de inversión ya visto con `{`, `+` y `?`, aplicado ahora a la
agrupación.

## 3. Cómo se usa

```bash
# Un numero de puerto de 2 a 5 digitos (BRE)
grep "[0-9]\{2,5\}" config.conf

# Lo mismo, en ERE
grep -E "[0-9]{2,5}" config.conf

# IPv4 simplificada: grupos de 1 a 3 digitos separados por puntos literales
grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" config.conf

# Uno o mas espacios seguidos (BRE, con escape)
grep " \+" archivo.txt
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir `{n,m}`, `+`, `?`, `|` sin `-E` y sin escapar | En BRE no son cuantificadores por defecto — el patrón se interpreta distinto a lo esperado, sin error visible | Usar `grep -E` para esos metacaracteres sin escape, o escaparlos en BRE (`\{`, `\+`, `\?`) |
| Copiar un patrón de BRE a ERE (o viceversa) sin revisar el escape | El mismo carácter significa lo opuesto en cada dialecto — un patrón "portado" a medias puede matchear algo distinto, no solo fallar | Revisar cada metacarácter del patrón al cambiar de dialecto, no asumir que es intercambiable |
| Usar `egrep`/`fgrep` en scripts nuevos | Documentados como obsoletos en el manual de GNU grep desde hace varias versiones | `grep -E` en vez de `egrep`, `grep -F` en vez de `fgrep` |
| Usar `.*` cuando se necesita un cuantificador acotado | `.*` ("cualquier cosa, cualquier cantidad de veces") es impreciso y puede matchear de más | `{n,m}`/`\{n,m\}` cuando se conoce el rango esperado — más preciso, menos sorpresas |
| Mezclar BRE y ERE dentro del mismo script sin dejarlo explícito | Quien lea el script después (incluido tu propio yo futuro) no puede saber, solo mirando el patrón, si falta un `-E` o un escape | Elegir un dialecto por script y mantenerlo, o comentar explícitamente por qué un `grep` puntual usa el otro |

## 5. Trucos

- `grep -E` no solo habilita cuantificadores sin escape: también permite
  alternancia (`|`) y agrupación (`(...)`) sin escape — el archivo 04 de
  esta semana profundiza en ambos.
- Si un patrón con `{`, `+`, `?` o `|` "no hace nada" en `grep` sin más
  banderas, la primera sospecha es que falta `-E` o el escape
  correspondiente en BRE.
- `grep -F "texto.con.puntos"` (fijo, sin regex) es más simple y más
  rápido que escapar cada punto a mano cuando el patrón es completamente
  literal, sin ningún metacarácter real.

## Resumen

`grep` sin banderas usa BRE, donde `+`, `?`, `{n,m}`, `(...)` y `|`
necesitan escape (`\+`, `\?`, `\{...\}`, `\(...\)`) para actuar como
cuantificadores o agrupación — sin escape, son literales. `grep -E` activa
ERE, donde esos mismos caracteres son especiales por defecto y es el
carácter literal el que necesita escape. `*` es el único cuantificador
idéntico en ambos dialectos. `egrep` es el alias histórico (y hoy
obsoleto) de `grep -E`.

## 📚 Recursos Adicionales

- [GNU Grep Manual — Basic vs Extended Regular Expressions](https://www.gnu.org/software/grep/manual/grep.html#Regular-Expressions) — la tabla completa de diferencias entre BRE y ERE.
- `man 7 regex` — sección POSIX de ambos dialectos, con la gramática formal.
- [POSIX — Extended Regular Expressions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html#tag_09_04) — la referencia normativa de ERE.

## ✅ Checklist de Verificación

- [ ] Usaste un cuantificador `\{n,m\}` en BRE y confirmaste que necesita escape
- [ ] Usaste el mismo cuantificador como `{n,m}` con `grep -E`, sin escape
- [ ] Reprodujiste cómo `+` y `?` cambian de literal a cuantificador según el dialecto
- [ ] Explicaste con tus palabras por qué un patrón no es "portable" entre BRE y ERE sin revisión
- [ ] Reemplazaste un uso de `egrep` por `grep -E` en un ejemplo propio
- [ ] Escapaste paréntesis literales en BRE y en ERE, confirmando que el escape también se invierte ahí

---

[← 02 — Anclas, clases de caracteres y clases POSIX](02-anclas-clases-y-clases-posix.md) · [04 — grep extendido, alternancia y agrupación →](04-grep-extendido-y-alternancia.md)
