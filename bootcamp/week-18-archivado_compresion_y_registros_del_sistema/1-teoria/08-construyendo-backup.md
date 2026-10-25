# Construyendo `backup`

> Todo lo de esta semana (`tar`, `gzip`, `sha256sum`, rotación) cabe en un subcomando de `toolkit`.
> Lo difícil no es crear la copia: es que **no se estropee en silencio** y que se pueda restaurar.

## 🎯 Objetivos

- Leer el diseño de `toolkit.sh backup` (cinco acciones) y sus códigos de salida
- Explicar cada decisión: temporal y renombrado, suma relativa, rutas peligrosas, destino vacío, series
- Entender qué pieza de las semanas anteriores reutiliza cada función
- Programar `backup` con `schedule` y `guard` para que corra solo y deje registro
- Saber qué **no** hace, y por qué no es un sistema de copias completo

## 1. Qué problema resuelve

Tienes la teoría suelta: `tar -czf`, `sha256sum`, `tar -tf`, `logrotate`. Falta
convertirla en **una orden fiable**. Una copia hecha con la línea de comandos a
mano falla de formas conocidas: se llama igual que la anterior y la pisa, queda a
medias si se corta, no se comprueba, y se restaura sobre lo que no debía. `backup`
las cierra una a una.

## 2. Cómo funciona

### 2.1 El diseño

```
toolkit.sh backup create ORIGEN [--dest DIR] [--name N] [--exclude PAT]... [--dry-run]
toolkit.sh backup verify ARCHIVO
toolkit.sh backup list [--dest DIR]
toolkit.sh backup restore ARCHIVO --to DIR
toolkit.sh backup prune --name N --keep K [--dest DIR] [--dry-run]
```

`--dest` por defecto es `$BACKUP_DEST` o `~/backups`. Cada copia es un **par de
archivos**: `NOMBRE-AAAAMMDD-HHMMSS.tar.gz` y `NOMBRE-AAAAMMDD-HHMMSS.tar.gz.sha256`.
La fecha en el nombre ordena las copias solo, sin base de datos; el nombre
(`proy`, `etc`) distingue **series**.

Los códigos de salida:

| Código | Cuándo |
|---|---|
| `0` | hecho, o `verify` correcto |
| `1` | uso inválido: opción desconocida, falta un dato, origen o destino inexistente, destino no vacío |
| `2` | la copia no es fiable: suma que no coincide, falta la suma, `tar` no puede leerla, o rutas peligrosas |

El `2` significa **«no uses esta copia»**; es lo que un script de vigilancia debe
tratar como alarma, distinto de un error de uso (`1`).

### 2.2 Las ocho funciones

| Función | Hace | Reutiliza |
|---|---|---|
| `backup_parse` | lee opciones y las valida por acción | `case` y `shift` (Semana 14), `[[ =~ ]]` |
| `backup_prepare` | valida rutas, nombre y destino | listas blancas (Semana 16), `pwd -P` (Semana 17) |
| `backup_safe_members` | rechaza `..` y `/` en el listado del archivo | `while read` con sustitución de procesos |
| `backup_create` | temporal, `tar`, renombrar, suma | `mktemp` (Semana 15), este archivo y el 01 |
| `backup_verify` | suma, legibilidad con `tar -t` | archivo 03 |
| `backup_list` | lista y cuenta las copias | `stat`, `printf` |
| `backup_restore` | verifica, comprueba rutas, extrae | `-C` y `--no-same-owner` |
| `backup_prune` | conserva las K últimas de la serie | aritmética, `rm --`, prefijo de `--dry-run` |

`backup_archives` (ya hecha) rellena `BK_FILES` con las copias de una serie en
orden: es la única función que sabe **cómo se llama una copia**.

### 2.3 Una sesión completa

```bash
mkdir -p /tmp/b18/src/proy/sub /tmp/b18/src/proy/cache /tmp/b18/dest && cd /tmp/b18
echo uno > src/proy/a.txt; echo dos > src/proy/sub/b.txt; echo x > src/proy/cache/c.tmp
toolkit.sh backup create src/proy --dest dest --exclude cache --exclude '*.tmp'
# creado /tmp/b18/dest/proy-20261025-055843.tar.gz
ls -A dest
# proy-20261025-055843.tar.gz
# proy-20261025-055843.tar.gz.sha256
tar -tzf dest/proy-*.tar.gz
# proy/
# proy/a.txt
# proy/sub/
# proy/sub/b.txt
toolkit.sh backup list --dest dest
# proy-20261025-055843.tar.gz  216 bytes
# copias: 1
```

Observa que `cache/` y `*.tmp` no están dentro, que la ruta guardada es
`proy/...` (por `-C` al directorio padre, como en el archivo 01) y que el `ls`
**no** muestra el temporal: se renombró al terminar.

Verificar y restaurar:

```bash
toolkit.sh backup verify dest/proy-*.tar.gz
# ok proy-20261025-055843.tar.gz
mkdir out && toolkit.sh backup restore dest/proy-*.tar.gz --to out
# ok proy-20261025-055843.tar.gz
# restaurado en /tmp/b18/out (5 entradas)
diff -r -x cache src/proy out/proy && echo igual
# igual
toolkit.sh backup restore dest/proy-*.tar.gz --to out; echo "rc=$?"
# toolkit backup restore: el destino no esta vacio: /tmp/b18/out
# rc=1
```

`restore` **se niega a escribir sobre algo**, aunque tú lo pidas: la restauración
va a un directorio vacío y tú decides después qué mover.

### 2.4 Las copias malas

Cuando algo no encaja, el código es `2` y el mensaje dice qué:

```bash
printf 'zz' >> dest/malo-20250101-000000.tar.gz     # una copia que cambió
toolkit.sh backup verify dest/malo-20250101-000000.tar.gz; echo "rc=$?"
# corrupto malo-20250101-000000.tar.gz (la suma no coincide)
# rc=2
rm dest/malo-20250101-000000.tar.gz.sha256
toolkit.sh backup verify dest/malo-20250101-000000.tar.gz; echo "rc=$?"
# falta malo-20250101-000000.tar.gz.sha256
# rc=2
```

Y un archivo con rutas peligrosas (el del archivo 03) **se detiene antes de
extraer nada**, aunque su suma sea correcta:

```bash
toolkit.sh backup restore dest/ev-20250101-000000.tar.gz --to out2; echo "rc=$?"
# ok ev-20250101-000000.tar.gz
# toolkit backup restore: ruta peligrosa en el archivo: ../fuera/f
# rc=2
ls -A out2
```

(`ls -A out2` sale vacío: no se escribió **nada**.)

### 2.5 Las decisiones de diseño

| Decisión | Por qué |
|---|---|
| Escribir en un temporal (`mktemp`) y **renombrar** | Un `create` interrumpido nunca deja un `.tar.gz` a medias con aspecto de buena copia |
| `mktemp` crea con `600` | La copia no debe poder leerla cualquiera (archivo 03) |
| La suma se calcula **desde el directorio de las copias**, con el nombre sin ruta | Funciona donde muevas el par; no depende de dónde estés |
| Si el archivo ya existe, error `1` y no se pisa | Dos copias en el mismo segundo no se sobrescriben |
| `restore` verifica **antes** de extraer | No se extrae una copia en la que no se confía |
| `backup_safe_members` aunque GNU `tar` ya rechace `..` | La defensa no debe depender de qué `tar` haya; y el mensaje es claro |
| `restore` solo a un directorio **vacío** | Nunca sobrescribe; `--no-same-owner` evita adoptar propietarios ajenos |
| `prune` exige `--name` y `--keep` | Nunca borra «lo viejo» de toda la carpeta; solo una serie |
| `prune` borra también el `.sha256` | No quedan sumas huérfanas |
| `--dry-run` en `create` y `prune` | Ves qué haría antes de que escriba o borre |
| Nombre validado con una regex anclada **antes** de construir rutas | Un `--name ../x` no escribe fuera del destino |

### 2.6 Qué no hace

- **No cifra**: la copia en claro es tan sensible como el original. Cifrar es
  `gpg` o `age`, fuera de este bootcamp.
- **No copia fuera de la máquina**: el «1 fuera de casa» de la regla 3-2-1 lo
  haces tú (`scp`, `rsync`, un disco externo). Un `--dest` en un punto montado es
  la forma de enlazarlo.
- **No es incremental**: cada copia es completa. Con pocos datos es lo más
  simple y lo más fácil de restaurar (archivo 01, apartado 3.5).
- **No conserva ACL ni atributos extendidos** salvo que `tar` los lleve con sus
  opciones (`--acls`, `--xattrs`): no están activadas.

## 3. Cómo se usa

### 3.1 Programarlo: `schedule` y `guard`

Es exactamente para lo que se construyeron las capas 15 y 16. `schedule gen`
envuelve la orden en `guard` (bloqueo, límite de tiempo, registro) y escribe los
tres archivos:

```bash
toolkit.sh schedule gen copias --cron '30 2 * * *' --salida /tmp/sg \
  -- /root/bin/toolkit.sh backup create /etc --dest /var/backups/toolkit --name etc
# generado: /tmp/sg/copias.cron
# calendario: *-*-* 2:30:00
grep -v '^#' /tmp/sg/copias.cron | tail -1
# 30 2 * * * /root/bin/toolkit.sh guard -k /var/tmp/toolkit-copias.lock -t 300 -- /root/bin/toolkit.sh backup create /etc --dest /var/backups/toolkit --name etc >> /var/tmp/toolkit-copias.log 2>&1
```

Hay un detalle: `guard` corta a los 300 segundos por defecto. Para una carpeta
grande, `schedule gen --timeout 3600`. Y la **poda** es otra tarea (otra línea,
otro `schedule gen`): `backup prune --name etc --keep 7`.

### 3.2 Vigilar que se ha hecho

Un trabajo programado que deja de correr **no avisa**. La comprobación mínima: que
la última copia no sea más vieja que lo esperado. `backup list` ya da el nombre
con fecha, y con `find` basta:

```bash
find /var/backups/toolkit -name 'etc-*.tar.gz' -mtime -2 | grep -q . || echo "sin copia reciente" >&2
```

### 3.3 Restaurar de prueba, periódicamente

Lo que el diseño **no** hace por ti: usar la copia. Una vez al mes, restaura la
última en un directorio vacío y compara (archivo 03). `backup verify` solo
dice que el archivo es el mismo que se escribió, no que contenga lo que
necesitas.

### 3.4 Divergencia de distro

`backup` usa `tar` (GNU), `gzip`, `sha256sum`, `mktemp` y `stat -c`, todos de
`coreutils` o `tar` en las cuatro familias: **no depende de ninguna distribución**.
La única diferencia: `-c %s` de `stat` es GNU; en macOS sería `stat -f %z`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Crear la copia directamente en su nombre final | Un corte la deja a medias, con aspecto bueno | Temporal y `mv` |
| Una suma con ruta absoluta | No se puede comprobar en otra máquina | `cd` al directorio y nombre sin ruta |
| Restaurar sobre el directorio original | Pisas lo que querías proteger | Directorio vacío |
| `prune` sin límite de serie | Borra copias de otras cosas | `--name` obligatorio |
| La copia y el original en el mismo disco | Un fallo se lleva los dos | Otro disco y otro lugar (3-2-1) |
| Copias legibles por todos | Exponen claves y datos | `mktemp` con `600` y directorio `700` |
| Confiar en que «corrió» sin mirar | El trabajo programado puede dejar de ejecutarse | Comprobar la antigüedad de la última |
| No probar nunca la restauración | La copia puede no servir | Una restauración periódica |

## 5. Trucos

- **`backup create ... --dry-run`** antes de programarlo: ves el nombre y el
  destino exactos sin escribir nada.
- **`BACKUP_DEST=/mnt/disco toolkit.sh backup list`**: el destino por variable,
  sin repetir `--dest` en cada línea del `crontab`.
- **`tar -tzf copia.tar.gz | head`** para ver el nombre del directorio raíz antes de
  restaurar a mano con `tar -xzf`.

## 📚 Recursos Adicionales

- `man tar`, `man sha256sum`, `man mktemp`
- [`schedule gen` en la capa 16](../../week-16-automatizacion_y_tareas_programadas/1-teoria/08-construyendo-schedule.md)

## ✅ Checklist de Verificación

- [ ] Describes las cinco acciones y los códigos `0`, `1` y `2`
- [ ] Explicas por qué `create` escribe en un temporal y renombra
- [ ] Verificas una copia buena, una cambiada y una sin suma, y lees cada mensaje
- [ ] Restauras en un directorio vacío y comparas con `diff -r`
- [ ] Ves que `restore` se detiene con un archivo de rutas `..`
- [ ] Programas una copia con `schedule gen` y localizas el `guard` en la línea de `cron`
- [ ] Citas tres cosas que `backup` no hace

---

[← Escribir en los registros](07-escribir-en-los-registros.md) · [Práctica 01: `tar` y compresión →](../2-practicas/01-tar-y-compresion.md)
