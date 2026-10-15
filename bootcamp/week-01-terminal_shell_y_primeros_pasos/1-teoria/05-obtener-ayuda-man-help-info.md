# Obtener ayuda: man, --help, info

> "Lo busco en Google" funciona hasta que no tienes internet, o hasta que el
> resultado es para una versión distinta del comando que la tuya. El sistema
> ya trae la documentación correcta, instalada, offline.

## 🎯 Objetivos

- Elegir la fuente de ayuda correcta según lo que necesites (man, --help, info, type)
- Navegar `man` con eficiencia: buscar, saltar entre secciones, salir
- Explicar qué son las secciones del manual y por qué `man 5 passwd` no es lo mismo que `man passwd`

## 1. Qué problema resuelve

Cada comando de Linux trae su propia documentación instalada en el sistema,
escrita por quien lo mantiene, para la versión exacta que tienes instalada.
Buscar en internet te da respuestas genéricas, a veces de una versión
distinta, a veces directamente incorrectas para tu caso. Aprender a leer
`man` no es purismo: es más rápido y más confiable que buscar en la web una
vez que pierdes el miedo inicial al formato.

Este archivo también importa porque, a partir de la Semana 02, el material
va a asumir que sabes consultar `man` cuando falte algo — el bootcamp no
repite cada flag de cada comando: te enseña a encontrarlos tú mismo.

## 2. Cómo funciona

### 2.1 Las tres fuentes de ayuda, y cuándo usar cada una

| Fuente | Para qué sirve | Cuándo usarla |
|---|---|---|
| `comando --help` | Resumen rápido de flags, en la terminal, sin paginar | Necesitas recordar un flag puntual, ya conoces el comando |
| `man comando` | Documentación completa: sinopsis, descripción, cada opción, ejemplos, archivos relacionados | Quieres entender el comando a fondo o buscar algo que no sabías que existía |
| `info comando` | Documentación en formato navegable por hipervínculos (GNU) | Para herramientas GNU extensas (`coreutils`, `bash`, `sed`) con manuales muy largos |
| `help builtin` | Ayuda para comandos builtin, que no tienen página de manual propia | Cuando `man cd` falla porque `cd` no es un binario separado |

`man cd` falla (o muestra la página genérica de bash) porque, como viste en
el archivo anterior, `cd` es un builtin: no hay un archivo `/usr/bin/cd` con
su propia página de manual. Para esos casos, `help cd` es la fuente correcta.

```bash
man cd
# No manual entry for cd (o la pagina de bash completa, segun el sistema)

help cd
# cd: cd [-L|[-P [-e]] [-@]] [dir]
#     Change the shell working directory...
```

### 2.2 Las secciones del manual

`man` no es un solo documento: es una colección de manuales organizados en
**secciones numeradas**, y el mismo nombre puede existir en más de una:

| Sección | Contenido |
|---|---|
| 1 | Comandos de usuario ejecutables desde el shell |
| 2 | Llamadas al sistema (syscalls) |
| 3 | Funciones de biblioteca de C |
| 4 | Archivos especiales (`/dev`) |
| 5 | Formatos de archivo y convenciones (`/etc/passwd`, `fstab`) |
| 6 | Juegos |
| 7 | Misceláneo: convenciones, protocolos, estándares |
| 8 | Comandos de administración (normalmente requieren root) |

El caso clásico: `passwd` existe como **comando** (sección 1, para cambiar tu
contraseña) y como **archivo** (sección 5, el formato de `/etc/passwd`). Sin
especificar sección, `man` te da la primera que encuentra — casi siempre la
1 — y si buscabas la otra, ni te enteras de que existía una opción.

```bash
man passwd           # la pagina del comando (seccion 1)
man 5 passwd         # la pagina del formato de archivo (seccion 5)
```

### 2.3 Cómo está organizada una página de `man`

Toda página sigue, más o menos, esta estructura: `NAME` (una línea de qué
es), `SYNOPSIS` (la sintaxis con corchetes para lo opcional), `DESCRIPTION`
(el detalle de cada flag), a veces `EXAMPLES`, y `SEE ALSO` (comandos
relacionados — una de las formas más rápidas de descubrir herramientas que no
sabías que existían).

### 2.4 `info`: cuando `man` se queda corto

Las herramientas del proyecto GNU (`coreutils`, `bash`, `sed`, `gawk`) suelen
tener manuales tan extensos que, además de la página de `man`, traen un
manual en formato `info`: un documento navegable con "nodos" conectados por
hipervínculos de texto, pensado para leerse de principio a fin, no solo para
consultar un flag puntual.

```bash
info coreutils 'ls invocation'
```

No es obligatorio dominar `info` para este bootcamp — `man` alcanza para el
99% de los casos — pero conviene saber que existe, porque algunas opciones
avanzadas de herramientas GNU solo están documentadas ahí, con el comentario
explícito "see the full documentation" al final de la página de `man`
correspondiente.

### 2.5 Herramientas de terceros: un complemento, no un reemplazo

Comandos como `tldr` (si se instalan aparte) muestran ejemplos prácticos
condensados, sin la exhaustividad de `man`. Son útiles como recordatorio
rápido, pero no vienen preinstalados en Ubuntu ni en la mayoría de
distribuciones — depender de ellos en un servidor ajeno donde no están
instalados te deja sin nada. `man` y `--help`, en cambio, están garantizados
en cualquier sistema Linux estándar.

### 2.6 Leer un `SYNOPSIS` sin que la notación asuste

Toda página de manual resume la sintaxis completa de un comando en una sola
línea, usando una notación fija que vale la pena aprender una vez y no
olvidar más:

| Notación | Significa |
|---|---|
| `[algo]` | Opcional |
| `algo...` | Puede repetirse una o más veces |
| `-a\|-b` | Uno u otro, no ambos |
| **negrita** (o sin corchetes) | Literal: se escribe tal cual |
| _cursiva_ (o `MAYÚSCULA`) | Lo reemplazas por tu propio valor |

```
SYNOPSIS
       cp [OPTION]... [-T] SOURCE DEST
       cp [OPTION]... -t DIRECTORY SOURCE...
```

Esto dice, sin necesidad de leer una sola línea de prosa: `cp` acepta cero o
más opciones, y después, o bien un origen y un destino puntuales, o bien
(con `-t`) un directorio destino seguido de uno o más orígenes. Saber leer
esto de corrido es lo que separa "copiar la sintaxis de un ejemplo de
internet" de "entender qué combinaciones son válidas sin probarlas todas".

## 3. Cómo se usa

```bash
# Buscar una palabra dentro de la pagina abierta
man ls
# dentro del pager: /recursive<Enter>   busca "recursive"
#                    n                   siguiente coincidencia
#                    N                   coincidencia anterior
#                    q                   salir
```

```bash
# Buscar que paginas de manual mencionan un termino, sin abrir ninguna
man -k "copy files"
# cp (1)     - copy files and directories
# rsync (1)  - a fast, versatile, remote (and local) file-copying tool
```

`man -k` (equivalente a `apropos`) es la herramienta correcta cuando sabes
*qué quieres hacer* pero no el nombre exacto del comando.

```bash
# Ver solo la sinopsis, sin abrir el pager completo
man -f ls
# o, equivalente:
whatis ls
```

```bash
# El manual completo de bash, con informacion que --help nunca te da
man bash | less
# documento larguisimo: usar / para buscar una seccion puntual, no leerlo entero
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Buscar en internet antes de probar `man`/`--help` | La documentación instalada es exacta para tu versión; un resultado de internet puede ser de otra versión o directamente errónea | Probar `comando --help` primero, `man comando` si necesitas más detalle |
| Hacer `man passwd` esperando el formato del archivo | Sin especificar sección, se abre la del comando (sección 1), no la del archivo (sección 5) | Especificar la sección cuando el nombre es ambiguo: `man 5 passwd` |
| Salir de `man` cerrando la terminal | Es un pager (`less` por debajo): tiene su propia forma de salir | `q` siempre cierra el pager sin tocar la terminal |
| Asumir que `man cd` no funciona por un error del sistema | `cd` es builtin, no tiene página de manual propia por diseño | Usar `help cd` para builtins |

## 5. Trucos

- `man -k .` (un punto como patrón) lista *todas* las páginas de manual
  instaladas — útil para "navegar" el sistema cuando no sabes qué buscar.
- Dentro de `man`, `Ctrl+F` avanza una pantalla completa y `Ctrl+B` retrocede
  — más rápido que apretar flecha abajo cien veces en páginas largas.
- Si tu Ubuntu es muy mínimo y falta `man`, `apt install man-db` lo agrega —
  relevante en contenedores base, que a veces lo omiten para ahorrar espacio.

## 📚 Recursos Adicionales

- `man man` — sí, existe una página de manual sobre el comando `man` mismo, y
  explica las secciones con más detalle que esta guía.
- [GNU Info format overview](https://www.gnu.org/software/texinfo/manual/info/) — si vas a usar `info` seguido con herramientas GNU extensas.

## ✅ Checklist de Verificación

- [ ] Abriste `man ls`, buscaste una palabra con `/`, y saliste con `q`
- [ ] Comparaste `man passwd` con `man 5 passwd` y notaste la diferencia
- [ ] Usaste `help cd` para confirmar por qué `man cd` no te da lo que esperabas
- [ ] Leíste un `SYNOPSIS` completo y explicaste qué significa cada corchete y cada punto suspensivo

---

[← 04 — Builtins, externos y $PATH](04-builtins-externos-y-path.md) · [06 — Historial y edición de línea →](06-historial-y-edicion-de-linea.md)
