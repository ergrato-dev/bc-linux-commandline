# grep básico: patrones literales y las banderas esenciales

> `grep` no es "buscar una palabra". Es el primer filtro de cualquier
> pipeline de texto, y antes de tocar una sola regex especial ya resuelve
> la mayoría de las búsquedas reales con un patrón literal y unas pocas
> banderas.

## 🎯 Objetivos

- Buscar patrones literales en archivos y en la salida de otros comandos
- Distinguir `-i`, `-v`, `-c`, `-n`, `-l` y `-L` sin confundirlas
- Interpretar los tres códigos de salida nativos de `grep` (`0`, `1`, `2`)
- Reconocer el antipatrón `cat archivo | grep patron` y por qué sale sobrando

## 1. Qué problema resuelve

Un archivo de log de un servidor real tiene decenas de miles de líneas.
Abrirlo en un editor para buscar "¿en qué línea dice `ERROR`?" a simple
vista no escala. `grep` filtra: lee un archivo (o stdin) línea por línea, y
muestra solo las que coinciden con un patrón — el resto desaparece de la
salida, no se procesa a mano.

## 2. Cómo funciona

### 2.1 Sintaxis básica

```bash
grep PATRON ARCHIVO
```

```bash
grep "disco lleno" /var/log/syslog
# Oct 15 10:00:02 servidor kernel: disco lleno en /dev/sda1
```

`grep` imprime la **línea completa** que contiene la coincidencia, no solo
el fragmento que coincidió — esa distinción importa apenas empieces a
construir pipelines: lo que sale de `grep` sigue siendo texto con contexto,
no un valor aislado (para extraer solo la coincidencia, ver `-o` en el
archivo 07 de esta semana).

### 2.2 Patrón literal: sin metacaracteres, busca el texto tal cual

```bash
grep "disco lleno" archivo.log
```

Sin ningún carácter especial de regex (`.`, `*`, `[`, `^`, `$`, etc.), el
patrón se interpreta como texto literal: busca exactamente esa secuencia de
caracteres. Esto es lo que hace que `grep` sea útil desde el primer uso,
sin tener que aprender regex para una búsqueda simple — la profundidad de
regex (archivos 02 a 05) se vuelve necesaria recién cuando el patrón
literal ya no alcanza.

### 2.3 Las banderas esenciales

| Bandera | Qué hace |
|---|---|
| `-i` | Ignora mayúsculas/minúsculas (`ERROR` coincide con `error`) |
| `-v` | Invierte: muestra las líneas que **no** coinciden |
| `-c` | Cuenta cuántas **líneas** coinciden (no cuántas veces aparece el patrón) |
| `-n` | Antepone el número de línea a cada coincidencia |
| `-l` | Lista solo los **nombres de archivo** con al menos una coincidencia |
| `-L` | Lista solo los nombres de archivo **sin ninguna** coincidencia |

```bash
grep -i "error" app.log       # tambien coincide con Error, ERROR, eRRoR
grep -v "INFO" app.log        # todo lo que no sea una linea INFO
grep -c "ERROR" app.log       # cuantas lineas tienen ERROR
grep -n "ERROR" app.log       # con numero de linea
grep -l "ERROR" *.log         # que archivos .log tienen al menos un ERROR
grep -L "ERROR" *.log         # que archivos .log estan limpios de ERROR
```

**`-c` cuenta líneas, no ocurrencias.** Una línea con dos coincidencias del
patrón cuenta como `1`, no como `2`:

```bash
printf 'ERROR ERROR doble\nERROR simple\n' | grep -c "ERROR"
# 2
```

Si lo que necesitas es el número total de ocurrencias (no de líneas), ver
el truco con `-o` más abajo.

### 2.4 Buscando en varios archivos a la vez

```bash
grep "ERROR" app.log sistema.log
# app.log:2:ERROR disco lleno        (si tambien pasaste -n)
# sistema.log:5:ERROR memoria
```

Con más de un archivo, `grep` antepone automáticamente el nombre del
archivo a cada línea. `-h` fuerza a ocultarlo (útil al combinar varios
archivos y no querer saber de cuál vino cada línea); `-H` fuerza a
mostrarlo incluso con un solo archivo (útil en scripts, donde no quieres
que el formato de salida cambie según cuántos archivos se pasaron).

### 2.5 Los tres códigos de salida nativos de `grep`

```bash
grep "patron" archivo.log >/dev/null; echo $?
```

| Código | Significado |
|:--:|---|
| `0` | Encontró al menos una coincidencia |
| `1` | No encontró ninguna coincidencia |
| `2` | Error — archivo inexistente, patrón inválido, permiso denegado |

Esto convierte a `grep` en una herramienta de **decisión**, no solo de
impresión: se puede usar directo como condición de un `if`, sin parsear
ningún texto de salida.

```bash
if grep -q "ERROR" app.log; then
  echo "hay errores"
fi
```

`-q` (silencioso) suprime toda salida — solo interesa el código de salida,
no el texto. Es el patrón más común de usar `grep` dentro de un script.

### 2.6 `grep` dentro de un pipe

```bash
ps aux | grep nginx
journalctl -u ssh | grep "Failed password"
```

`grep` lee de stdin igual que de un archivo cuando no se le pasa ningún
nombre de archivo — reutiliza exactamente el mecanismo de pipes de la
Semana 05: el comando anterior produce líneas, `grep` las filtra, lo que
sigue en la cadena recibe solo las que coincidieron.

## 3. Cómo se usa

```bash
# Cuantas lineas de un log de acceso corresponden a errores 500
grep -c " 500 " access.log

# Que servicios de systemd fallaron al arrancar
systemctl list-units --state=failed | grep -v "^UNIT"

# Encontrar el proceso de un servicio especifico (y el antipatron de abajo)
ps aux | grep nginx
```

```bash
# ps aux | grep nginx tambien matchea a su propio proceso grep:
ps aux | grep nginx
# usuario   1234  ...  nginx: worker process
# usuario   5678  ...  grep nginx          <- esto es el grep mismo

# el truco [n]ginx evita que el patron se matchee a si mismo:
ps aux | grep "[n]ginx"
# usuario   1234  ...  nginx: worker process
```

El truco funciona porque la línea del propio `grep` contiene literalmente
`grep [n]ginx` — y `[n]ginx` como regex busca una `n` seguida de `ginx`, que
no coincide con el texto literal `[n]ginx` de la línea del proceso `grep`,
pero sí coincide con `nginx` de las líneas reales del servicio.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `cat archivo | grep patron` | Un proceso (`cat`) que solo existe para alimentar a otro — `grep` ya lee archivos directamente | `grep patron archivo`, sin `cat` de por medio (UUOC: *Useless Use of Cat*) |
| Asumir que `-c` cuenta ocurrencias totales | Una línea con varias coincidencias cuenta como una sola | Usar `grep -o patron archivo | wc -l` para contar ocurrencias reales |
| `ps aux | grep servicio` sin filtrar el propio `grep` | El resultado incluye una línea extra que es el proceso `grep` mismo buscándose | `ps aux | grep "[s]ervicio"`, o mejor, `pgrep servicio` |
| Patrones con espacios o metacaracteres sin comillas | El shell expande el patrón antes de que `grep` lo vea, con resultados inesperados | Comillar siempre el patrón: `grep "mi patron"`, nunca `grep mi patron` |
| Usar `grep` para buscar por **nombre de archivo** | `grep` busca contenido, no nombres — un error común al confundirlo con `find -name` | `find . -name "*patron*"` para nombres, `grep` para contenido |

## 5. Trucos

- `grep -o patron archivo | wc -l` cuenta ocurrencias totales, no líneas —
  la combinación real para "¿cuántas veces aparece?" en vez de "¿en
  cuántas líneas aparece?".
- `grep -m1 patron archivo` se detiene en la primera coincidencia — más
  rápido que dejar que `grep` siga leyendo un archivo enorme después de
  que ya encontraste lo que buscabas.
- `command | grep "[p]atron"` evita que la línea del propio `grep` aparezca
  en el resultado de buscar un proceso con `ps aux | grep`.
- `grep -q patron archivo && echo si || echo no` es el patrón más compacto
  para una decisión de una sola línea basada en si algo existe en un
  archivo.

## Resumen

`grep PATRON ARCHIVO` filtra líneas que contienen un texto literal, con
tres códigos de salida nativos (`0` encontrado, `1` no encontrado, `2`
error) que lo vuelven útil directo en condiciones de scripts. `-c` cuenta
líneas coincidentes, no ocurrencias; `-i`, `-v`, `-n`, `-l`, `-L`, `-q`
cubren la mayoría de los usos diarios sin necesitar ninguna regex especial
todavía — eso viene en los próximos archivos.

## 📚 Recursos Adicionales

- [GNU Grep Manual](https://www.gnu.org/software/grep/manual/grep.html) — referencia completa de banderas y comportamiento.
- `man grep` — la misma referencia, disponible sin conexión en cualquier distro.
- [GNU Coreutils Manual — `wc`](https://www.gnu.org/software/coreutils/manual/coreutils.html#wc-invocation) — para combinar `grep -o` con `wc -l` al contar ocurrencias.

## ✅ Checklist de Verificación

- [ ] Buscaste un patrón literal en un archivo con `grep PATRON ARCHIVO`
- [ ] Usaste `-i`, `-v`, `-c`, `-n`, `-l` y `-L` cada una al menos una vez contra `ubuntu-lab`
- [ ] Confirmaste los tres códigos de salida de `grep` (`0`, `1`, `2`) con `echo $?`
- [ ] Reprodujiste el antipatrón `ps aux | grep servicio` matcheándose a sí mismo, y lo corregiste con `[s]ervicio`
- [ ] Usaste `grep -q` como condición de un `if`

---

[← Semana 06](../README.md) · [02 — Anclas, clases de caracteres y clases POSIX →](02-anclas-clases-y-clases-posix.md)
