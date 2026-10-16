# Práctica 03: Límites de palabra, grep -P y búsqueda recursiva

Esta práctica reproduce, dentro de `ubuntu-lab`, cómo evitar coincidencias
parciales de palabra, cómo extraer datos con PCRE, y cómo empezar a
buscar en un árbol de directorios en vez de un solo archivo.

## Paso 1: `-w` evita coincidencias parciales

**Por qué**: confirmar en carne propia el problema que resuelve `-w` —
`grep "cat"` también encuentra `catalog` y `concat`.

**Comando**:

```bash
cd ~/practica-grep
printf "cat\ncatalog\nconcat\n" > palabras.txt
grep "cat" palabras.txt
grep -w "cat" palabras.txt
```

**Verifica**:

```bash
grep "cat" palabras.txt | wc -l
# 3
grep -w "cat" palabras.txt | wc -l
# 1
```

## Paso 2: `\b` dentro de un patrón más grande

**Por qué**: a diferencia de `-w` (que ancla todo el patrón), `\b` permite
anclar solo una parte — necesario cuando el límite de palabra no está en
los extremos del patrón completo.

**Comando**:

```bash
printf "ERRORXXX disco lleno\n" >> servidor.log
grep -E "ERROR.*disco" servidor.log
grep -E "\bERROR\b.*disco" servidor.log
```

**Verifica**: el primer patrón encuentra también la línea `ERRORXXX`
(falso positivo); el segundo, con `\b` después de `ERROR`, lo excluye.

```bash
grep -E "ERROR.*disco" servidor.log | wc -l
# 3
grep -E "\bERROR\b.*disco" servidor.log | wc -l
# 2
```

## Paso 3: `grep -P` y las clases abreviadas

**Por qué**: confirmar que `\d` y `\w` extraen exactamente lo mismo que
las clases POSIX equivalentes, con menos caracteres.

**Comando**:

```bash
printf "usuario123 edad=42 clave=abc\n" > datos.txt
grep -oP "\d+" datos.txt
grep -oP "\w+" datos.txt
```

**Verifica**:

```bash
grep -oP "\d+" datos.txt
# 123
# 42
grep -oP "\w+" datos.txt
# usuario123
# edad
# 42
# clave
# abc
```

## Paso 4: Lookahead — extraer un número sin el texto que lo confirma

**Por qué**: ERE no tiene forma de decir "que venga esto después, pero no
lo incluyas en el resultado" — es la razón real para usar `-P` en vez de
`-E` en este caso puntual.

**Comando**:

```bash
printf "precio: 100USD, 200EUR\n" > precios.txt
grep -oP "\d+(?=USD)" precios.txt
```

**Verifica**:

```bash
grep -oP "\d+(?=USD)" precios.txt
# 100
```

Solo `100` (el monto en USD), no `200` (que es EUR) — el lookahead exige
el texto `USD` inmediatamente después para confirmar la coincidencia, sin
incluirlo en lo extraído.

## Paso 5: Primeros pasos con búsqueda recursiva

**Por qué**: antes de construir la lógica completa de `logscan` (Práctica
04), hay que confirmar que `-r` solo, sin filtrar, revisa de más — y que
`--include` lo corrige.

**Comando**:

```bash
mkdir -p arbol/sub
printf "ERROR x\n" > arbol/a.log
printf "ERROR en un txt que no deberia contar\n" > arbol/sub/b.txt
grep -r "ERROR" arbol
grep -r --include="*.log" "ERROR" arbol
```

**Verifica**: el primer comando encuentra la coincidencia en **ambos**
archivos (el `.log` y el `.txt`); el segundo, filtrado por `--include`,
encuentra solo la del `.log`.

```bash
grep -r "ERROR" arbol | wc -l
# 2
grep -r --include="*.log" "ERROR" arbol | wc -l
# 1
```

## Paso 6: Combinar límite de palabra con búsqueda recursiva

**Por qué**: cerrar el círculo de esta práctica — nada impide combinar lo
visto en los primeros pasos (`\b`) con lo visto en el Paso 5 (`-r`,
`--include`), en un solo comando.

**Comando**:

```bash
mkdir -p arbol2
printf "cat 500\ncatalog 500\nconcat 404\n" > arbol2/a.log
grep -rE --include="*.log" "\bcat\b" arbol2
```

**Verifica**:

```bash
grep -rE --include="*.log" "\bcat\b" arbol2
# arbol2/a.log:cat 500
```

Solo la línea con `cat` como palabra completa — ni `catalog` ni `concat`
aparecen, aunque ambas contienen la subcadena `cat`.

## ✅ Resultado

- [ ] Reprodujiste por qué `grep "cat"` encuentra `catalog` y `concat`, y lo corregiste con `-w`
- [ ] Usaste `\b` para anclar solo una parte de un patrón más grande, no el patrón completo
- [ ] Extrajiste números y palabras con `grep -P` usando `\d` y `\w`
- [ ] Usaste un lookahead (`(?=...)`) para extraer un valor según lo que viene después, sin incluirlo
- [ ] Confirmaste que `-r` sin `--include` revisa archivos de más, y que `--include` lo corrige
- [ ] Combinaste `\b` con `-r` y `--include` en un solo comando

```bash
./scripts/verificar-semana.sh 06
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `grep -oP` da un error de opción no reconocida | El binario de `grep` del sistema no se compiló con soporte PCRE (no debería pasar en `ubuntu-lab`) | Confirmar con `grep -P "" /dev/null; echo $?` — si da `2`, reportarlo como fallo del entorno, no tuyo |
| El lookahead del Paso 4 extrae `200` también | El patrón no tiene `(?=USD)`, o tiene un espacio de más antes del paréntesis | Copiar el patrón exacto del Paso 4, sin espacios extra entre `\d+` y `(?=USD)` |
| `grep -r --include="*.log"` sigue mostrando el `.txt` | El nombre del archivo no coincide con el patrón glob tal cual se escribió (mayúsculas, extensión exacta) | Confirmar el nombre real del archivo con `ls arbol/sub/` |

---

[← Práctica 02 — Regex extendida, cuantificadores y alternancia](02-regex-extendida-cuantificadores-y-alternancia.md) · [Práctica 04 →](04-logscan-con-pipes-y-regex-reales.md)
