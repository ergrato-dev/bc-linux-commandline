# Documentar una herramienta

> Una herramienta sin documentación solo la puede usar quien la escribió, y solo el mes en que la escribió.
> Tres capas bastan: la ayuda en la propia orden, la página de manual y un README que cuenta el porqué.

## 🎯 Objetivos

- Escribir una página de manual mínima en formato `roff` y renderizarla sin `man`
- Comprobar una página de manual con `groff -z -ww`
- Decidir qué va en la ayuda de la orden, qué en el manual y qué en el README
- Documentar los **códigos de salida**, que son parte del contrato
- Incluir la página de manual en el paquete y entender dónde se instala

## 1. Qué problema resuelve

Cada capa de `toolkit` explicó sus opciones en la cabecera del script. Eso sirve
mientras abres el archivo. Un usuario que instala el paquete **no abre el script**:
escribe `man toolkit` o `toolkit` y espera una respuesta. Si la respuesta no
está, o no es la que dice el código, la herramienta pierde confianza antes de
usarse.

## 2. Cómo funciona

### 2.1 Tres capas, tres preguntas

| Capa | Pregunta que responde | Dónde vive | Quién la lee |
|---|---|---|---|
| Ayuda de la orden | «¿Cómo la llamo ahora mismo?» | Salida de `toolkit` sin argumentos | Quien ya sabe qué quiere |
| Página de manual | «¿Qué hace cada opción y qué devuelve?» | `/usr/share/man/man1/toolkit.1.gz` | Quien consulta |
| README | «¿Para qué sirve, cómo se instala y por qué está hecha así?» | El repositorio | Quien llega por primera vez |

Un error frecuente es repetir lo mismo en las tres. Cada una **remite** a la
siguiente: la ayuda corta, el manual completo, el README con el contexto.

### 2.2 La ayuda en la orden

Sin argumentos, `toolkit` imprime un uso breve por `stderr` y sale con `1`
(se usó mal). Las convenciones habituales:

- **`stderr`** para los errores de uso, **`stdout`** para la ayuda pedida
  (`--help`), para que `toolkit --help | less` funcione.
- Una línea `Uso:` seguida de la lista de subcomandos.
- Nunca ayuda que contradiga el comportamiento: si la ayuda dice `0` y el código
  devuelve `2`, el que miente es la documentación.

```bash
toolkit
# Uso: toolkit.sh <subcomando>
# Subcomandos disponibles: doctor, inventory, ..., version, release, selftest
echo $?
# 1
```

### 2.3 Una página de manual en `roff`

`roff` es el lenguaje de las páginas de manual: texto con líneas que empiezan
por un punto y son órdenes. Con seis de ellas se escribe una página decente:

| Orden | Hace |
|---|---|
| `.TH TOOLKIT 1 "" "toolkit 1.0.0" "Comandos de usuario"` | Cabecera: nombre, **sección** (1 = órdenes de usuario), fecha, versión y título |
| `.SH NOMBRE` | Abre una sección (`NAME`, `SYNOPSIS`, `DESCRIPTION`, `EXIT STATUS`…) |
| `.B texto` | Negrita |
| `.I texto` | Cursiva (para valores que el usuario sustituye) |
| `.TP` | Párrafo con etiqueta: la línea siguiente es la etiqueta, la otra el texto |
| `.BR bash (1),` | Referencia a otra página: nombre en negrita, sección normal |

La barra se escribe `\-` y no `-` (un guion de verdad evita que se parta la línea).

```
.TH TOOLKIT 1 "" "toolkit 1.0.0" "Comandos de usuario"
.SH NAME
toolkit \- caja de herramientas personal de sysadmin
.SH SYNOPSIS
.B toolkit
.I subcomando
[opciones]
.SH EXIT STATUS
.TP
.B 0
Todo en orden.
.TP
.B 2
Se encontro algo que reportar.
```

Las secciones tienen **nombres convencionales en inglés** (`NAME`, `SYNOPSIS`,
`EXIT STATUS`) aunque el texto sea español, porque herramientas como `apropos`
las buscan por ese nombre. `NAME` es especialmente importante: su línea
(`nombre \- descripción`) es lo que `apropos` indexa.

### 2.4 Renderizar y comprobar sin `man`

`man` en la imagen mínima no funciona, pero la herramienta que lo hace de verdad
es `groff`. Esto es lo que verá el lector:

```bash
dpkg-deb -x toolkit_1.0.0_all.deb /tmp/x
zcat /tmp/x/usr/share/man/man1/toolkit.1.gz | groff -man -Tascii -P-c | col -b | sed -n 1,9p
# TOOLKIT(1)              Comandos de usuario              TOOLKIT(1)
#
# NAME
#        toolkit - caja de herramientas personal de sysadmin
#
# SYNOPSIS
#        toolkit subcomando [opciones]
#
# DESCRIPTION
```

(`-P-c` pide el formato clásico y `col -b` borra los negritas de los terminales
antiguos; sin ellos aparecen secuencias de escape.) Y para **comprobar** la sintaxis:

```bash
groff -man -z -ww toolkit.1
# (sin salida: la página está bien)
```

`-z` no genera salida, `-ww` activa **todos** los avisos. Con una errata:

```
troff:bad.1:4: warning: macro 'ZZ' not defined
```

Es el equivalente a `shellcheck` para páginas de manual. Fíjate en que el
código de salida sigue siendo 0: como con `systemd-analyze verify`, un aviso
no cambia el código y hay que leer la salida.

### 2.5 Dónde se instala

Por convención del *Filesystem Hierarchy Standard*:

| Ruta | Contenido |
|---|---|
| `/usr/bin/toolkit` | La orden |
| `/usr/share/man/man1/toolkit.1.gz` | Su página de manual, **comprimida** con `gzip -9n` |
| `/usr/share/doc/toolkit/` | README, CHANGELOG, `copyright` |

`gzip -9n`: `-9` máxima compresión y **`-n`** no guarda el nombre ni la fecha del
archivo, para que construir dos veces dé el mismo resultado (reproducible).

### 2.6 El README

Las preguntas que debe responder, en este orden:

1. ¿Qué es? (una frase)
2. ¿Cómo se instala y se desinstala? (los comandos exactos)
3. ¿Cómo se usa? (tres ejemplos reales con su salida)
4. ¿Qué devuelve? (la tabla de códigos de salida)
5. ¿Cómo se prueba? (`toolkit selftest`)
6. ¿Qué **no** hace? (los límites)

La última sección es la que más confianza da: una herramienta que dice lo que
no cubre es más fiable que una que lo promete todo.

## 3. Cómo se usa

### 3.1 Documentación como parte de la entrega

El `release verify` de esta semana comprueba que el paquete **contiene** la página
de manual. Documentar no es un paso aparte: si falta, el paquete no pasa.

### 3.2 Divergencia de distro

- **`man`** viene preinstalado en Ubuntu de escritorio y en RHEL/Fedora; en las
  imágenes Docker mínimas de Ubuntu/Debian hay un sustituto, y en Arch hay que
  instalar `man-db` y `man-pages`.
- **`mandoc`** es otro procesador de `roff` (por defecto en Alpine y Void); en
  Ubuntu y RHEL se usa `groff`, el que has visto aquí.
- La **sección** `1` (órdenes) es la misma en todas. La `5` (formatos de
  archivo) y la `8` (administración) también.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Ayuda que dice una cosa y código que hace otra | El usuario confía en la ayuda | Probar la ayuda con `selftest` |
| Ayuda de 200 líneas en `stderr` | Tapa el error real | Uso corto, y `--help` o `man` para lo demás |
| Manual sin los códigos de salida | Nadie sabe qué es «fallo» | Una sección `EXIT STATUS` |
| Guion `-` en lugar de `\-` | La línea se parte en mitad de una opción | Escribir `\-` |
| Página de manual sin comprobar | Un aviso de `groff` se convierte en texto roto | `groff -man -z -ww` |
| Copiar el README entero dentro del manual | Se desincronizan | Cada capa responde a su pregunta y remite a las otras |
| Documentar solo lo que funciona | El usuario descubre los límites en producción | Una sección de límites |

## 5. Trucos

- **`gzip -9c archivo | md5sum` dos veces, con un `touch` en medio**, da sumas
  distintas porque `gzip` guarda la fecha del archivo; con `-n` (`gzip -9nc`)
  dan la misma. Es la prueba de que tu paquete se construye igual cada vez.
- **`zcat toolkit.1.gz | head`** muestra el `roff` original dentro de un paquete
  ajeno: la forma más rápida de aprender macros leyendo páginas reales.
- **`groff -man -Thtml`** genera HTML, pero necesita el paquete `groff` completo;
  la imagen mínima de `ubuntu-lab` solo trae los dispositivos de texto
  (`-Tascii`, `-Tutf8`).

## 📚 Recursos Adicionales

- `man 7 man` (las macros `.TH`, `.SH`, `.TP`…) y `man groff_man`
- [Convenciones de páginas de manual (man-pages(7))](https://man7.org/linux/man-pages/man7/man-pages.7.html)

## ✅ Checklist de Verificación

- [ ] Escribes una página de manual con `NAME`, `SYNOPSIS` y `EXIT STATUS`
- [ ] La renderizas con `groff -man -Tascii -P-c | col -b`
- [ ] La compruebas con `groff -man -z -ww` y provocas un aviso
- [ ] La comprimes con `gzip -9n` y sabes por qué lleva `-n`
- [ ] Explicas qué va en la ayuda, en el manual y en el README
- [ ] Localizas dónde se instala cada pieza de la documentación

---

[← Instalar, verificar y quitar](03-instalar-verificar-y-quitar.md) · [Probar una herramienta →](05-probar-una-herramienta.md)
