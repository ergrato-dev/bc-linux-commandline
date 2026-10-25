# Práctica 02: Navegar la ayuda y el manual

Esta práctica entrena el reflejo que vas a necesitar las próximas veinte
semanas: cuando no sepas un flag, buscarlo tú mismo en segundos, no
esperarlo del material.

## Paso 1: Comparar `--help` contra `man` en el mismo comando

**Por qué**: `--help` es rápido pero parcial; `man` es completo pero más
largo. Saber cuál pedir ahorra tiempo real.

**Comando**:

```bash
cp --help | head -15
```

```bash
man cp
# dentro del pager: /preserve<Enter> para ir directo a la opcion --preserve
```

**Verifica**: `--help` te dio una lista de flags sin explicación extensa;
`man cp` tiene una sección `DESCRIPTION` con cada flag detallado, incluido
`--preserve`, que `--help` solo menciona de pasada.

## Paso 2: Resolver la ambigüedad de sección con `passwd`

**Por qué**: es el ejemplo canónico de un nombre que existe en más de una
sección del manual, y el que mejor enseña a especificar cuál quieres.

**Comando**:

```bash
man passwd
# que seccion aparece primero?

man 5 passwd
# el formato del archivo /etc/passwd
```

**Verifica**:

```bash
man -f passwd
# passwd (1)       - change user password
# passwd (5)       - the password file
```

`man -f` (equivalente a `whatis`) confirma cuántas páginas existen con ese
nombre, antes de abrir ninguna.

## Paso 3: Buscar un comando por lo que hace, no por su nombre

**Por qué**: en un sistema real vas a necesitar resolver "¿cómo sincronizo
dos carpetas?" sin saber de antemano que el comando se llama `rsync`.

**Comando**:

```bash
man -k "synchronize files"
```

**Verifica**: la salida incluye al menos `rsync (1)` entre los resultados.
Repite la búsqueda con otra frase ("list open files", "show disk usage") y
confirma que `apropos` siempre te acerca al comando correcto sin que lo
conocieras antes.

## Paso 4: Usar `help` para un builtin, donde `man` no aplica

**Por qué**: confundir builtins con comandos externos lleva a buscar en el
lugar equivocado — ya lo viste en la teoría, ahora lo confirmas en la
práctica.

**Comando**:

```bash
man cd
echo "codigo de salida de man cd: $?"

help cd | head -10
```

**Verifica**: `man cd` falla o no da la página específica de `cd` (según la
instalación, puede mostrar la página genérica de bash); `help cd` sí
devuelve la sintaxis exacta del builtin.

## Paso 5: Encontrar la sección `SEE ALSO` y descubrir algo nuevo

**Por qué**: `SEE ALSO` es, en la práctica, el mecanismo de descubrimiento
más subestimado del sistema de manuales.

**Comando**:

```bash
man find | grep -A 10 "^SEE ALSO"
```

**Verifica**: la lista incluye comandos relacionados (`locate`, `xargs`,
`updatedb`) que vas a usar recién en la Semana 09 — anótalos, no hace falta
entenderlos todavía.

## ✅ Resultado

- [ ] Distinguiste cuándo usar `--help` y cuándo `man`
- [ ] Resolviste la ambigüedad de sección en `passwd` con `man -f`
- [ ] Encontraste `rsync` buscando solo por descripción, con `man -k`
- [ ] Confirmaste por qué `man cd` no funciona igual que con un comando externo
- [ ] Leíste la sección `SEE ALSO` de al menos una página de manual

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `man -k` dice "nothing appropriate" para todo | La base de datos de `apropos` no está indexada | Correr `sudo mandb` dentro de `ubuntu-lab` para reconstruir el índice |
| `man` no pagina, tira todo el texto de una sola vez | Falta el paginador configurado (`less`) | Confirmar que `less` está instalado: `which less`; si falta, `apt install less` |
| `man passwd` siempre abre la misma sección sin importar qué pides | Olvidaste el número de sección antes del nombre | La sintaxis es `man <sección> <nombre>`, con espacio, número primero |

---

[← Práctica 01](01-primer-contacto-con-ubuntu-lab.md) · [Práctica 03 →](03-dominar-historial-y-atajos.md)
