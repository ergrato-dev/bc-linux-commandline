# find por tiempo y tamaño

> "Archivos más viejos que una semana", "logs de más de 100MB" — ningún
> patrón de nombre resuelve esto. `find` compara fechas y tamaños
> directamente, con una sintaxis de signos (`+`/`-`) que es fácil de leer
> al revés si no se presta atención la primera vez.

## 🎯 Objetivos

- Filtrar por antigüedad con `-mtime`, `-atime` y `-ctime`, entendiendo qué mide cada uno
- Usar `-newer` para comparar contra la fecha de otro archivo, no un número fijo
- Filtrar por tamaño con `-size`, con sufijos de unidad
- Interpretar correctamente `+N` ("más de N") y `-N` ("menos de N")

## 1. Qué problema resuelve

Limpiar logs viejos, encontrar qué archivo se modificó justo antes de
que algo se rompiera, o detectar archivos sospechosamente grandes — todo
esto depende de metadatos de tiempo y tamaño que `-name`/`-type` no
pueden expresar. `find` los compara directamente, sin necesitar
`stat` archivo por archivo.

## 2. Cómo funciona

### 2.1 `-mtime`, `-atime`, `-ctime`: tres fechas distintas

| Bandera | Compara contra |
|---|---|
| `-mtime` | **m**odification time — última vez que cambió el **contenido** |
| `-atime` | **a**ccess time — última vez que se **leyó** |
| `-ctime` | **c**hange time — última vez que cambió el contenido **o los metadatos** (permisos, dueño) |

La misma distinción de `stat` vista en la Semana 03 — `find` simplemente
la usa como criterio de búsqueda, en vez de solo mostrarla.

### 2.2 El signo importa: `+N` es "más de", `-N` es "menos de"

```bash
find . -name "*.txt" -mtime +5
# ./viejo.txt         (modificado hace MAS de 5 dias)

find . -name "*.txt" -mtime -1
# ./nuevo.txt
# ./sub/anidado.txt   (modificados hace MENOS de 1 dia)
```

`+N` significa "hace más de N días completos"; `-N` significa "hace
menos de N días completos"; `N` sin signo significa "exactamente ese
rango de un día". Esta sintaxis de signo se repite en `-size` (sección
2.4) — una vez que se entiende acá, es la misma lógica en todos lados.

### 2.3 `-newer`: comparar contra la fecha de otro archivo, no un número

```bash
find . -name "*.txt" -newer viejo.txt
# ./nuevo.txt
# ./sub/anidado.txt
```

En vez de un número fijo de días, `-newer archivo` encuentra todo lo
modificado **después** que ese archivo de referencia — útil cuando lo
que importa es "qué cambió desde el último respaldo" o "qué se modificó
después de este evento conocido", sin tener que calcular cuántos días
exactos pasaron.

### 2.4 `-size`: filtrar por tamaño, con sufijos de unidad

```bash
find . -type f -size +1k
# ./grande.txt

find . -type f -size -1k
# ./sub/anidado.txt
# ./viejo.txt
# ./nuevo.txt
```

Mismo signo que `-mtime`: `+1k` es "más de 1 kilobyte", `-1k` es "menos
de 1 kilobyte". Los sufijos más comunes son `c` (bytes), `k`
(kilobytes), `M` (megabytes), `G` (gigabytes) — sin sufijo, la unidad
por defecto son bloques de 512 bytes, una convención histórica que casi
siempre conviene evitar siendo explícito con un sufijo.

### 2.5 Combinando tiempo y tamaño en un solo criterio

```bash
find /var/log -name "*.log" -mtime +30 -size +10M
```

Por defecto, varios criterios seguidos se combinan con **Y** implícito
— esta búsqueda encuentra logs que son, a la vez, más viejos de 30 días
**y** más grandes de 10MB. El archivo 03 de esta semana profundiza en
cómo combinar criterios explícitamente con `-a`, `-o` y `-not`.

### 2.6 `-daystart`: medir "hoy" desde medianoche, no desde ahora

```bash
find . -name "nuevo.txt" -mtime 0
```

Por defecto, `-mtime 0` mide "menos de 24 horas desde este instante
exacto" — si corres el comando a las 23:00, cualquier archivo de las
08:00 de ese mismo día ya cuenta como "hace más de 0 días completos" en
ese cálculo, aunque intuitivamente diríamos que fue "hoy".

```bash
find . -name "nuevo.txt" -daystart -mtime 0
```

`-daystart` cambia el punto de referencia a la medianoche más reciente,
en vez del instante exacto en que corre `find` — "hoy" pasa a significar
lo que el calendario diría que es hoy, no "las últimas 24 horas".

### 2.7 Combinar `-size`/`-printf` para calcular el peso total de una búsqueda

```bash
find . -type f -name "*.txt" -printf "%s\n" | awk '{s+=$1} END{print s+0}'
# 2000
```

`find` no suma tamaños por sí solo — pero combinado con `-printf "%s\n"`
(imprime solo el tamaño en bytes de cada resultado) y el patrón de
acumulación de `awk` ya visto en la Semana 08, calcular el peso total
de un conjunto de archivos encontrados es una línea más, no una
herramienta nueva.

## 3. Cómo se usa

```bash
# Archivos modificados en la ultima hora (util para depurar "que tocaste recien")
find . -mmin -60

# Logs rotados mas viejos de 90 dias, candidatos a comprimir o borrar
find /var/log -name "*.log.*" -mtime +90

# Todo lo modificado despues de instalar un paquete (usando su archivo de marca)
find /etc -newer /var/log/apt/history.log

# Archivos sospechosamente grandes en el home del usuario
find ~ -type f -size +500M
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Confundir `+N` con "los últimos N días" | `+N` es "más viejo que N días", no "dentro de los últimos N días" — es exactamente lo contrario de lo que suena a primera lectura | Leer `+N` como "más de", `-N` como "menos de", cada vez, sin asumir por intuición |
| Usar `-atime` para encontrar "qué se modificó" | `-atime` mide **lectura**, no modificación — un archivo leído pero no tocado tiene `-atime` reciente sin haber cambiado | `-mtime` para contenido modificado; `-atime` solo cuando de verdad importa cuándo se leyó |
| Olvidar el sufijo de unidad en `-size` | Sin sufijo, la unidad son bloques de 512 bytes, no bytes — un `-size +100` no significa "100 bytes" | Siempre un sufijo explícito: `c` (bytes), `k`, `M`, `G` |
| Asumir que muchos sistemas de archivos registran `atime` con precisión | Varias configuraciones modernas (`noatime`, `relatime`) no actualizan `atime` en cada lectura, por rendimiento — el valor puede no reflejar la última lectura real | Confirmar las opciones de montaje (`mount | grep atime`) antes de confiar en `-atime` para algo crítico |

## 5. Trucos

- `-mmin`/`-amin`/`-cmin` son las versiones en **minutos** de
  `-mtime`/`-atime`/`-ctime` — útiles para ventanas de tiempo más
  cortas que un día completo (`-mmin -30` para "en los últimos 30
  minutos").
- `-newer` acepta cualquier archivo como referencia — crear un archivo
  vacío con `touch marca.txt` antes de una operación, y comparar
  después con `-newer marca.txt`, es un patrón simple para "qué cambió
  desde este punto".
- `find . -printf '%s %p\n'` (extensión de GNU find) imprime el tamaño
  en bytes junto a la ruta de cada resultado, sin necesitar un `stat`
  aparte por archivo.
- `find . -printf '%TY-%Tm-%Td %p\n'` imprime la fecha de modificación
  en formato legible junto a cada resultado, sin depender de `stat`
  por separado.

## Resumen

`-daystart` ajusta el punto de referencia de cualquier criterio de
tiempo a la medianoche más reciente, en vez del instante exacto en que
corre `find`. `-mtime`/`-atime`/`-ctime` filtran por antigüedad de contenido, lectura
o metadatos respectivamente, con `+N`/`-N` significando "más de"/"menos
de" N días. `-newer archivo` compara contra la fecha de otro archivo en
vez de un número. `-size` filtra por tamaño con el mismo signo, con
sufijos `c`/`k`/`M`/`G` — sin sufijo, la unidad son bloques de 512
bytes, casi nunca lo que se quiere decir.

`-printf` acepta muchos más especificadores que `%s` y `%p` — `%u`/`%g`
(dueño/grupo), `%m` (permisos en octal) — convirtiendo a `find` en una
alternativa a `stat` cuando el resultado ya viene de una búsqueda, no
de un archivo puntual conocido de antemano.

## 📚 Recursos Adicionales

- [GNU Findutils Manual — Comparing Dates](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Comparing-Dates) — referencia completa de `-mtime`, `-newer` y variantes.
- [GNU Findutils Manual — Size](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Size) — sufijos de unidad de `-size`.

## ✅ Checklist de Verificación

- [ ] Distinguiste `-mtime`, `-atime` y `-ctime` explicando qué mide cada uno
- [ ] Reprodujiste la diferencia entre `+N` y `-N` con `-mtime`
- [ ] Usaste `-newer` para comparar contra la fecha de otro archivo
- [ ] Filtraste por tamaño con `-size`, usando un sufijo de unidad explícito
- [ ] Combinaste un criterio de tiempo y uno de tamaño en la misma búsqueda
- [ ] Usaste `-daystart` y confirmaste cómo cambia el cálculo de "hoy"
- [ ] Calculaste el peso total de un conjunto de archivos encontrados con `-printf` y `awk`

---

[← 01 — find básico: criterios de búsqueda](01-find-basico-criterios-de-busqueda.md) · [03 — find con lógica combinada y acciones directas →](03-find-logica-combinada-y-acciones.md)
