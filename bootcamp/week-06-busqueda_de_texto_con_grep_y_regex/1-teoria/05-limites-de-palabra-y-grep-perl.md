# Límites de palabra y grep -P

> `grep "cat" archivo` también encuentra `catalog` y `concat` — porque
> "cat" es una subcadena válida de ambas. Un límite de palabra resuelve
> exactamente ese problema: coincidir con la palabra, no con cualquier
> texto que la contenga.

## 🎯 Objetivos

- Usar `-w` para que un patrón coincida solo con palabras completas
- Usar `\b`, `\<` y `\>` para límites de palabra dentro de un patrón más grande
- Usar `grep -P` (PCRE) y las clases abreviadas `\d`, `\w`, `\s`
- Reconocer qué ofrece PCRE que ERE no tiene (lookahead, cuantificadores perezosos)

## 1. Qué problema resuelve

```bash
printf 'cat\ncatalog\nconcat\n' | grep "cat"
# cat
# catalog
# concat
```

El patrón `cat` es una subcadena literal de las tres líneas — `grep` hace
exactamente lo que se le pidió, pero lo que se pidió no fue lo que se
quería. Buscar la **palabra** `cat`, no cualquier texto que la contenga,
necesita una forma de decir "acá termina o empieza una palabra", no solo
"estos caracteres en este orden".

## 2. Cómo funciona

### 2.1 `-w`: coincidir solo con palabras completas

```bash
printf 'cat\ncatalog\nconcat\n' | grep -w "cat"
# cat
```

`-w` es la forma más simple: le agrega automáticamente límites de palabra
a los dos extremos del patrón completo. Sirve cuando el patrón entero debe
ser una palabra — no sirve si el límite de palabra se necesita solo en una
parte de un patrón más largo.

### 2.2 `\b`: límite de palabra dentro del patrón

```bash
printf 'cat\ncatalog\nconcat\n' | grep -o "\bcat\b"
# cat
```

`\b` es una extensión de GNU disponible tanto en BRE como en ERE (no es
parte del estándar POSIX): coincide con la posición **entre** un carácter
de palabra (letra, dígito, guión bajo) y uno que no lo es — sin consumir
ningún carácter. Permite aplicar el límite solo donde hace falta, dentro
de un patrón más grande:

```bash
grep -E "\bERROR\b.*disco" app.log
```

### 2.3 `\<` y `\>`: inicio y fin de palabra por separado

```bash
printf 'cat\ncatalog\nconcat\n' | grep -o "\<cat\>"
# cat
```

`\<` coincide solo con el **inicio** de una palabra, `\>` solo con el
**final** — otra extensión GNU. Útil cuando solo se necesita anclar un
extremo: `\<cat` encuentra `cat` y `catalog` (empiezan con la palabra
`cat`), pero no `concat`.

### 2.4 `grep -P`: expresiones PCRE (Perl Compatible Regular Expressions)

```bash
printf 'user123 = valor_42\n' | grep -oP "\d+"
# 123
# 42
```

`-P` cambia el motor de regex completo a PCRE, con clases abreviadas que
no existen en BRE/ERE:

| Clase PCRE | Equivalente POSIX | Significa |
|---|---|---|
| `\d` | `[[:digit:]]` | Un dígito |
| `\w` | `[[:alnum:]_]` | Un carácter de palabra |
| `\s` | `[[:space:]]` | Un espacio en blanco |
| `\D`, `\W`, `\S` | negación de las anteriores | Lo que no es dígito/palabra/espacio |

```bash
printf 'user123 = valor_42\n' | grep -oP "\w+"
# user123
# valor_42
```

### 2.5 Lo que PCRE ofrece y ERE no: lookahead y cuantificadores perezosos

```bash
printf 'precio: 100USD\n' | grep -oP "\d+(?=USD)"
# 100
```

`(?=USD)` es un **lookahead**: exige que después del número venga
literalmente `USD`, pero no incluye `USD` en lo que se extrae. ERE no
tiene equivalente — es una de las razones reales para elegir `-P` sobre
`-E`, no solo una preferencia de sintaxis.

```bash
printf '<a><b>\n' | grep -oP "<.+?>"
# <a>
# <b>
```

`.+?` es un cuantificador **perezoso** (no voraz): se detiene en la
primera coincidencia posible, en vez de extenderse lo más posible. Sin el
`?`, `<.+>` sería voraz por defecto y devolvería `<a><b>` completo, de la
primera `<` a la última `>`, no cada etiqueta por separado.

```bash
printf '<a><b>\n' | grep -oP "<.+>"
# <a><b>
```

### 2.6 Lookbehind: lo mismo que lookahead, pero mirando hacia atrás

```bash
printf 'USD100 EUR200\n' | grep -oP "(?<=USD)[0-9]+"
# 100
```

`(?<=USD)` es un **lookbehind**: exige que **antes** del número venga
literalmente `USD`, sin incluir `USD` en el resultado extraído — el
complemento exacto del lookahead de la sección 2.5, mirando hacia el
lado contrario del patrón principal.

### 2.7 Disponibilidad de `-P`

`grep -P` depende de que el binario de `grep` se haya compilado con
soporte de PCRE — en Ubuntu, Debian, RHEL/Fedora y Arch (los cuatro
contenedores de este bootcamp), GNU grep viene compilado con ese soporte
por defecto. En builds minimalistas de `grep` (como el de BusyBox, usado
en algunas imágenes de contenedor muy reducidas), `-P` puede no estar
disponible — fuera del alcance de los labs de este bootcamp, pero vale
saber que no es una garantía universal de cualquier `grep`.

## 3. Cómo se usa

```bash
# Encontrar la palabra "root" exacta, no "rootkit" ni "chroot"
grep -w "root" /etc/passwd

# Extraer solo las direcciones IP de un log, sin el resto de la linea
grep -oP "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" acceso.log

# Extraer el contenido entre comillas, sin ser voraz
grep -oP '"\K[^"]+' config.json

# Limite de palabra combinado con alternancia
grep -E "\b(ERROR|WARN)\b" app.log
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `grep "cat"` para buscar la palabra exacta | También coincide con `catalog`, `concat`, cualquier subcadena | `grep -w "cat"` o `grep "\bcat\b"` |
| Usar `.*` (voraz) cuando se necesita el límite más corto posible | Puede extenderse hasta la última coincidencia posible de la línea, no la primera | `grep -P` con un cuantificador perezoso (`.+?`, `.*?`) cuando el motor lo soporta |
| Asumir que `-P` está disponible en cualquier `grep` de cualquier sistema | Depende de que el binario se haya compilado con soporte PCRE — no es universal | Confirmar con `grep -P "" /dev/null; echo $?` antes de depender de `-P` en un script portable |
| Reinventar `\d`, `\w`, `\s` con clases POSIX cuando ya se tiene `-P` disponible | Más caracteres, mismo resultado, sin ninguna ventaja | Usar las clases abreviadas de PCRE cuando `-P` ya es parte del patrón |

## 5. Trucos

- `grep -oP '"\K[^"]+' archivo.json` extrae el contenido entre comillas sin
  incluirlas: `\K` (otra extensión PCRE) descarta todo lo que coincidió
  antes de esa posición, sin necesitar un grupo de captura.
- `\<` y `\>` son más precisos que `\b` cuando solo interesa un extremo de
  la palabra, no los dos.
- `grep -P "" /dev/null; echo $?` es una forma rápida de confirmar si `-P`
  está disponible antes de depender de él en un script que debe correr en
  sistemas desconocidos.

## Resumen

`-w` agrega límites de palabra a todo el patrón; `\b` (GNU) los agrega en
un punto específico dentro de un patrón más grande; `\<` y `\>` anclan
solo el inicio o el final de una palabra. `grep -P` cambia el motor a
PCRE, con `\d`, `\w`, `\s` como abreviaturas y, más importante, con
lookahead y cuantificadores perezosos que ERE no tiene — la razón real
para elegir `-P` sobre `-E` en patrones que lo necesitan.

## 📚 Recursos Adicionales

- [GNU Grep Manual — Perl Compatible Regular Expressions](https://www.gnu.org/software/grep/manual/grep.html#PCRE) — alcance y limitaciones de `-P` en `grep`.
- [PCRE2 Syntax Reference](https://www.pcre.org/current/doc/html/pcre2syntax.html) — la referencia completa del dialecto PCRE.
- `man pcresyntax` — disponible localmente en sistemas con `libpcre` instalado.

## ✅ Checklist de Verificación

- [ ] Reprodujiste por qué `grep "cat"` encuentra `catalog` y `concat` sin querer
- [ ] Corregiste ese caso con `-w` y con `\bcat\b`
- [ ] Usaste `grep -P` con `\d`, `\w` o `\s` para extraer datos de una línea
- [ ] Reprodujiste la diferencia entre un cuantificador voraz (`.+`) y uno perezoso (`.+?`) con `-P`
- [ ] Confirmaste si `-P` está disponible en `ubuntu-lab` con `grep -P "" /dev/null; echo $?`

---

[← 04 — grep extendido, alternancia y agrupación](04-grep-extendido-y-alternancia.md) · [06 — grep recursivo y por nombre de archivo →](06-grep-recursivo-y-por-nombre-de-archivo.md)
