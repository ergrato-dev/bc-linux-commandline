# Rúbrica de Evaluación — Semana 18

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. Escribes `tar -cfv copia.tar datos` y falla. ¿Qué ha pasado exactamente y cómo se escribe bien?

<details>
<summary>Ver respuesta</summary>

La opción `-f` toma como argumento **lo que viene justo después**, así que `v`
se interpreta como el nombre del archivo: `tar` crea un archivo llamado `v` y
`copia.tar` pasa a ser un directorio a archivar, que no existe
(`tar` se queja con `Cannot stat`). Se escribe `tar -cvf copia.tar datos`: la `f` va la
**última** de las letras, para que su argumento sea el nombre.

</details>

2. ¿Por qué el archivo guarda `proy/a.txt` y no `tmp/wk18/src/proy/a.txt`, y qué papel juega `-C`?

<details>
<summary>Ver respuesta</summary>

`tar` guarda la ruta tal como se la das, quitando la `/` inicial (con aviso).
`-C DIR` hace un `cd` interno antes de leer los nombres: con
`tar -czf x.tar.gz -C /tmp/wk18/src proy` el miembro se llama `proy/...`,
independientemente de dónde estés. Así la restauración crea una carpeta con el
nombre esperado y no recrea toda la ruta del origen.

</details>

3. Comprimes datos aleatorios con `gzip` y el resultado pesa más. ¿Por qué, y qué elegirías entre `gzip`, `xz` y `zstd` para una copia diaria de texto?

<details>
<summary>Ver respuesta</summary>

Comprimir busca **redundancia**; los datos aleatorios (o ya comprimidos: JPEG,
vídeo, otro `.gz`) no la tienen, y el formato añade cabeceras: 100 000 bytes
pasaron a 100 042. Para texto, `xz -9` y `zstd -19` ahorran mucho más que `gzip`
(en nuestros datos, ~950 kB frente a ~1 970 kB), pero `xz` tarda varias veces
más; `zstd -3` da un tamaño intermedio con muy poca CPU. Para una copia diaria la
velocidad pesa: `zstd` si está en todas tus máquinas, `gzip` si necesitas que lo
lea cualquiera sin instalar nada.

</details>

4. ¿Qué garantiza un `.sha256` y qué **no** garantiza? ¿Por qué se calcula con el nombre sin ruta?

<details>
<summary>Ver respuesta</summary>

Garantiza que el archivo es **idéntico bit a bit** al que se sumó: detecta
corrupción de disco, transferencias cortadas o cambios. **No** garantiza que el
contenido sea el que necesitas (si la copia se hizo mal, la suma es de la copia
mala), ni autenticidad: quien cambie el archivo también puede cambiar la suma
guardada al lado. Se calcula desde el directorio de la copia, con el nombre sin
ruta, para que `sha256sum -c` funcione en cualquier sitio donde muevas el par;
con una ruta absoluta solo se puede comprobar donde esa ruta existe.

</details>

5. `sha256sum -c` devuelve `1` en tres situaciones distintas. ¿Cuáles son y cómo las distingues?

<details>
<summary>Ver respuesta</summary>

(a) El archivo cambió: `NOMBRE: FAILED` y `WARNING: 1 computed checksum did NOT
match`. (b) El archivo no existe: `FAILED open or read` y `No such file or
directory`. (c) El archivo de sumas no tiene líneas válidas: `no properly
formatted checksum lines found`. Un script debe tratar las tres como «no uses
esto», pero el mensaje dice qué hacer: rehacer la copia, restaurar un archivo
perdido o regenerar la suma. `--ignore-missing` convierte (b) en «ningún archivo
verificado», que sigue siendo fallo cuando era el único.

</details>

6. ¿Cómo puede un `.tar.gz` ajeno escribir fuera del directorio donde lo extraes, y qué comprueba `backup restore` para evitarlo?

<details>
<summary>Ver respuesta</summary>

Un archivo puede contener miembros con nombre absoluto (`/etc/cron.d/x`) o con
`..` (`../../.bashrc`). GNU `tar` hoy rechaza los `..` (`Member name contains
'..'`) y quita la `/` inicial, pero un programa que restaura copias no debe
depender de qué `tar` haya. `backup_safe_members` lee el listado con `tar -tzf`
y sale con código `2` ante un miembro que empiece por `/` o tenga un componente
`..`, **antes** de extraer nada; por eso no se escribe ni un archivo. Es
importante que la lectura use sustitución de procesos: con una tubería el
`exit` saldría solo del subshell.

</details>

7. ¿Por qué `backup create` escribe en un temporal y renombra, en lugar de crear directamente `proy-AAAAMMDD.tar.gz`?

<details>
<summary>Ver respuesta</summary>

Si el proceso se interrumpe (disco lleno, `kill`, corte de luz) a mitad de `tar`,
un archivo con el nombre final quedaría **a medias pero con aspecto de copia
buena**, y `list` y `prune` lo contarían. En un temporal (`mktemp` en el mismo
directorio, oculto por el prefijo `.tmp.`) el nombre final solo aparece cuando
`tar` terminó bien: el `mv` dentro del mismo sistema de archivos es atómico.
Además `mktemp` crea el archivo con permisos `600`, lo que evita que la copia sea
legible por otros usuarios.

</details>

8. Un script nocturno de `cron` ejecuta `logger -t miscript "copia hecha"`, pero `journalctl -t miscript` no muestra nada y el código de salida fue `0`. ¿Qué pasa y cómo lo compruebas?

<details>
<summary>Ver respuesta</summary>

`logger` escribe en el socket `/dev/log`; si nadie lo ha creado (no hay
`rsyslog` ni el enlace de `journald`), el mensaje se **pierde en silencio** y
`logger` devuelve `0`. Se comprueba con `ls -l /dev/log` y enviando un mensaje de
prueba que se lee de vuelta con `journalctl -t` (o buscando en `/var/log/syslog`).
En una máquina con systemd, `/dev/log` apunta al socket de `journald`; en un
contenedor sin él hay que arrancar un demonio o usar otro camino
(`systemd-cat`, un archivo propio).

</details>

9. Quieres «los errores de `ssh` de hoy» en el diario. ¿Qué órdenes usas y qué hace cada filtro?

<details>
<summary>Ver respuesta</summary>

`journalctl -u ssh -p err --since today` (en RHEL, la unidad es `sshd`). `-u`
filtra por unidad; `-p err` muestra prioridad `err` **y todo lo más grave**
(`crit`, `alert`, `emerg`), mientras que `-p err..err` pide solo ese nivel;
`--since today` acota desde las 00:00. Se puede añadir `-g` (expresión regular
sobre el mensaje), `-o json` para ver todos los campos, `-n 20 -r` para los 20
últimos con el más reciente primero, y `-b` para limitar al arranque actual.

</details>

10. Un servicio escribe en `/var/log/app.log` y tras la rotación nocturna el archivo nuevo está vacío mientras el viejo (`app.log.1`) sigue creciendo. ¿Por qué ocurre y qué dos soluciones hay?

<details>
<summary>Ver respuesta</summary>

El programa abrió el archivo una vez y escribe por su **descriptor** (inodo), no
por el nombre. `create` renombra `app.log` a `app.log.1` y crea uno nuevo, pero el
programa sigue escribiendo en el inodo antiguo, ahora llamado `app.log.1`. Se
resuelve (1) avisando al programa para que reabra el registro en un `postrotate`
(`systemctl reload servicio` o una señal `HUP`), o (2) con `copytruncate`, que
copia el contenido y **vacía** el original sin cambiar su inodo. Esta última puede
perder las líneas escritas entre la copia y el vaciado, por eso es el último
recurso.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — `tar` y compresión | Crea, lista y extrae, entiende `-C` y el aviso de la `/`, extrae partes, usa `--exclude` y `-T`, compara con `-d`, mide los cuatro compresores y reconoce los formatos por sus bytes | 10 |
| 02 — Integridad y restauración | Crea la suma con nombre relativo, distingue `FAILED` de `FAILED open or read`, usa `--status`, detecta un truncado con `gzip -t`/`tar -t`, restaura y compara con `diff -r`, detecta `..` y `/` antes de extraer | 10 |
| 03 — Registros, `journald` y `logrotate` | Arranca `rsyslogd` y `journald` a mano, lee `auth.log`/`syslog`, filtra con `journalctl` (`-t`, `-p`, `-g`, `-o`, `--since`), prueba `logrotate` con `-d`/`-f`/`-s` y demuestra `create` frente a `copytruncate` | 10 |
| 04 — `backup` a mano | Rellena los ocho `TODO` con su verificación: `backup_parse`, `backup_prepare`, `backup_safe_members`, `backup_create` con temporal y suma relativa, `verify`, `list`, `restore` y `prune`; cierra con `shellcheck` | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (6 checks) | 4 |
| `backup create` crea el `.tar.gz` y su `.sha256` (1 check) | 2 |
| `backup create --exclude` deja fuera lo que casa con el patrón (1 check) | 1 |
| `backup create --dry-run` no escribe nada (1 check) | 1 |
| `backup create` sale con `1` si el origen no existe (1 check) | 1 |
| `backup create` rechaza un nombre que sale del directorio de copias (1 check) | 2 |
| `backup verify` da `ok` en una copia buena y sale con `2` si cambió (1 check) | 2 |
| `backup list` muestra cada copia y `copias: N` (1 check) | 1 |
| `backup restore` devuelve un directorio idéntico (1 check) | 2 |
| `backup restore` sale con `1` y no toca un destino con contenido (1 check) | 1 |
| `backup restore` sale con `2` ante rutas `..` y no escribe fuera (1 check) | 2 |
| `backup prune --keep 2` conserva las dos últimas con sus sumas (1 check) | 2 |
| `backup prune --dry-run` no borra nada (1 check) | 1 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `backup_create` escribe en un `mktemp` y renombra; la suma se calcula desde el directorio con el nombre sin ruta; el nombre pasa la regex anclada antes de construir rutas | 2 |
| `restore` verifica, comprueba rutas con sustitución de procesos y solo entonces extrae, con `--no-same-owner`; nunca se usa `tar -P` | 2 |
| `prune` filtra por serie y borra también el `.sha256`; `--dry-run` imprime las mismas líneas con prefijo y no crea ni borra nada | 2 |
| Cero `# shellcheck disable` sin justificar, asignación y `local` separados donde se captura una salida, errores de uso a `stderr` con `1`, sin `eval` ni `export` innecesarios | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave o token con formato real comiteado (también dentro de una copia de ejemplo) | Grave |
| `rm -rf`, `prune` real o `kill` sobre algo real sin aviso ni respaldo | Grave |
| Crear copias con `tar -P` o restaurar sin comprobar rutas | Grave |
| Probar `logrotate -f` o `--vacuum-*` contra los registros reales del sistema sin `-d` ni respaldo | Grave |
| Copias o registros con permisos legibles por todos cuando contienen datos privados | Moderada |
| `create` que deja un `.tar.gz` a medias tras un fallo | Moderada |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 18 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
