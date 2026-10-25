# Práctica 04 — `backup` a mano

> Duración estimada: 120 min · Teoría de apoyo: archivos [01](../1-teoria/01-tar-archivar-sin-comprimir.md), [03](../1-teoria/03-integridad-y-restauracion.md) y [08](../1-teoria/08-construyendo-backup.md)

Aquí rellenas, **un `TODO` cada vez**, el `backup` del
[`starter/toolkit.sh`](../3-proyecto/starter/toolkit.sh) y, tras cada paso,
compruebas lo añadido. Los `TODO` traen en su comentario **todos** los mensajes
y reglas; aquí van las piezas difíciles. Edita el `starter/` en tu **host** y
llévalo al laboratorio con esta función (desde la raíz del repositorio):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-18-archivado_compresion_y_registros_del_sistema/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
docker exec ubuntu-lab apt-get install -y -qq shellcheck >/dev/null
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh backup list; echo "codigo: $?"
# TODO: /root/backups
# codigo: 0
```

Es el punto de partida: las funciones son marcadores. (Desde el host, `/root/bin`,
**no** `~/bin`.) Los pasos 2 a 4 se prueban con `source`, sin ejecutar `main`.

Las pruebas usan una maqueta que se rehace desde cero (solo borra bajo `/tmp/wk18`):

```bash
docker exec ubuntu-lab bash -c '
rm -rf /tmp/wk18 && mkdir -p /tmp/wk18/src/proy/sub /tmp/wk18/src/proy/cache /tmp/wk18/dest && cd /tmp/wk18
echo uno > src/proy/a.txt; echo dos > src/proy/sub/b.txt; echo x > src/proy/cache/c.tmp'
```

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae `backup_archives` (la única función que sabe
cómo se llama una copia) y `cmd_backup` (que reparte entre las cinco acciones).
Y cada `TODO` trae sus mensajes exactos: no los inventes.

**Comando**: abre `starter/toolkit.sh` en el bloque `# --- backup (Semana 18)`
y lee, sin tocar, `backup_archives` y `cmd_backup`.

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-18-archivado_compresion_y_registros_del_sistema/3-proyecto/starter/toolkit.sh
# 8
```

## Paso 2: TODO 1 — `backup_parse`

**Por qué**: cada acción admite **solo** unas opciones. Rechazar `--name` en un
`list` evita que alguien crea que está filtrando cuando no lo hace. Y los
errores de uso salen **aquí**, antes de que otra función toque el disco.

**Comando**: un `while [[ $# -gt 0 ]]` con dos niveles de `case`. La pieza clave
es una lista de opciones permitidas por acción y la prueba contra ella:

```bash
  local permitidas
  case "$BK_ACTION" in
    create) permitidas=" --dest --name --exclude --dry-run " ;;
    list) permitidas=" --dest " ;;
    # ... restore y prune ...
  esac
  ...
      --*)
        if [[ "$permitidas" != *" $1 "* ]]; then
          echo "toolkit backup ${BK_ACTION}: opcion desconocida: $1" >&2
          exit 1
        fi
```

Los espacios alrededor de cada nombre evitan que `*" --dest "*` case `--destino`. `--exclude` se acumula (`BK_EXCL+=("$2")`); `--dry-run` es la única sin valor.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
backup_parse create /origen --dest /d --name n --exclude a --exclude "*.tmp" --dry-run
echo "$BK_POS $BK_DEST $BK_NAME $BK_DRY ${BK_EXCL[*]}"'
# /origen /d n 1 a *.tmp
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; backup_parse list --name x'; echo "rc=$?"
# toolkit backup list: opcion desconocida: --name
# rc=1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; backup_parse prune --keep 0'; echo "rc=$?"
# toolkit backup prune: --keep debe ser un entero >= 1
# rc=1
```

## Paso 3: TODO 2 — `backup_prepare`

**Por qué**: valida que lo pedido **existe** y es **seguro** antes de construir
ninguna ruta: el nombre pasa la regex anclada **antes** de aparecer en un `mkdir`.

**Comando**: un `case` por acción. Lo delicado:

```bash
      BK_SRC=$(cd -- "$BK_POS" && pwd -P)
      if [[ -z "$BK_NAME" ]]; then
        BK_NAME=${BK_SRC##*/}
      fi
      if [[ ! "$BK_NAME" =~ $re ]]; then   # re='^[A-Za-z0-9][A-Za-z0-9._-]*$'
        echo "${pre} nombre invalido: ${BK_NAME}" >&2
        exit 1
      fi
```

El patrón de `=~` va **en una variable sin comillas**: entre comillas se compara
como texto literal. En `restore` la comprobación de «destino vacío» es
`[[ -n "$(ls -A -- "$BK_TO")" ]]`. En `create`, sin `--dry-run`, crea el destino
con `mkdir -p`; con `--dry-run` **no** toca el disco.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh backup create /tmp/wk18/nada --dest /tmp/wk18/dest; echo "rc=$?"
# toolkit backup create: no existe el origen: /tmp/wk18/nada
# rc=1
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && /root/bin/toolkit.sh backup create src/proy --name ../x --dest dest'; echo "rc=$?"
# toolkit backup create: nombre invalido: ../x
# rc=1
```

## Paso 4: TODO 3 — `backup_safe_members`

**Por qué**: un archivo ajeno puede llevar miembros con `..` o con `/`. GNU
`tar` ya se niega a extraer `..`, pero un programa que restaura copias **no debe
depender** de eso (teoría 03). Esta función mira el listado y se detiene
**antes** de extraer nada.

**Comando**: lee el listado con un `while read` y una **sustitución de procesos**.
Con una tubería (`tar -tzf | while ...`) el `exit` saldría solo del subshell y la
función seguiría:

```bash
  while IFS= read -r miembro; do
    if [[ "$miembro" == /* || "/${miembro}/" == */../* ]]; then
      echo "toolkit backup restore: ruta peligrosa en el archivo: ${miembro}" >&2
      exit 2
    fi
  done < <(tar -tzf "$1")
```

El `"/${miembro}/"` con barras a los dos lados hace que `*/../*` case un `..`
**al principio**, **en medio** o **al final**, y no case `..foo`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && echo e > e && tar -czf ok.tar.gz src/proy 2>/dev/null
tar -czf evil.tar.gz --transform "s,^,../fuera/," e 2>/dev/null
source /root/bin/toolkit.sh
backup_safe_members ok.tar.gz; echo "ok rc=$?"
backup_safe_members evil.tar.gz'; echo "rc=$?"
# ok rc=0
# tar: Removing leading `../' from member names
# toolkit backup restore: ruta peligrosa en el archivo: ../fuera/e
# rc=2
```

El aviso de `tar` es suyo; el mensaje que importa es el siguiente, y el código `2`.

## Paso 5: TODO 4 — `backup_create`

**Por qué**: es el corazón. Tres decisiones evitan los fallos de siempre:
escribir en un **temporal** y renombrar (un corte nunca deja una copia a
medias), calcular la suma **desde el directorio** con el nombre sin ruta, y no
pisar una copia existente.

**Comando**: en este orden, con `base` y `archivo` asignados **separados** del `local`
(SC2155): `--dry-run` imprime y `return 0` **antes** de tocar el disco; después
`tmp=$(mktemp "${BK_DEST}/.tmp.XXXXXX")`, y

```bash
  tar -czf "$tmp" -C "${BK_SRC%/*}" "${excl[@]}" -- "${BK_SRC##*/}"   # si falla: rm del temporal
  mv -- "$tmp" "$archivo"
  (cd -- "$BK_DEST" && sha256sum -- "$base" > "${base}.sha256")
```

`-C "${BK_SRC%/*}"` + `"${BK_SRC##*/}"` es el truco del archivo 01: guarda `proy/...`
y no `tmp/wk18/src/proy/...`. Los `--exclude` salen de `BK_EXCL`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh backup create /tmp/wk18/src/proy --dest /tmp/wk18/dest --dry-run; echo "rc=$?"
# [dry-run] crearia /tmp/wk18/dest/proy-20261025-061010.tar.gz
# rc=0
docker exec ubuntu-lab ls -A /tmp/wk18/dest | wc -l
# 0
docker exec ubuntu-lab /root/bin/toolkit.sh backup create /tmp/wk18/src/proy --dest /tmp/wk18/dest --exclude cache
# creado /tmp/wk18/dest/proy-20261025-061010.tar.gz
docker exec ubuntu-lab bash -c 'ls -A /tmp/wk18/dest; tar -tzf /tmp/wk18/dest/proy-*.tar.gz | tr "\n" " "'
# proy-20261025-061010.tar.gz
# proy-20261025-061010.tar.gz.sha256
# proy/ proy/a.txt proy/sub/ proy/sub/b.txt
```

(Tu fecha y hora serán otras.) (Tu fecha y hora serán otras.) **No** hay `.tmp.*` en el directorio, y `cache/` no está en el archivo.

## Paso 6: TODO 5 — `backup_verify`

**Por qué**: la verificación tiene que distinguir **tres** fallos, porque
significan cosas distintas: la suma no existe, el archivo cambió, o el archivo es
ilegible aunque la suma coincida (quien lo creó ya lo había roto).

**Comando**: tres `if` seguidos, cada uno con `exit 2`. La suma se comprueba
**desde el directorio del archivo**, y con `--status` para que el mensaje lo
escribas tú:

```bash
  if ! (cd -- "$dir" && sha256sum --check --status -- "${base}.sha256"); then
    echo "corrupto ${base} (la suma no coincide)" >&2
    exit 2
  fi
```

El `( ... )` es un subshell **solo** para el `cd`: no cambia tu directorio.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk18/dest && /root/bin/toolkit.sh backup verify proy-*.tar.gz'; echo "rc=$?"
# ok proy-20261025-061010.tar.gz
# rc=0
docker exec ubuntu-lab bash -c 'cd /tmp/wk18/dest && cp proy-*.tar.gz malo-20250101-000000.tar.gz
sed "s/proy-[0-9-]*/malo-20250101-000000/" proy-*.tar.gz.sha256 > malo-20250101-000000.tar.gz.sha256
printf zz >> malo-20250101-000000.tar.gz
/root/bin/toolkit.sh backup verify malo-20250101-000000.tar.gz'; echo "rc=$?"
# corrupto malo-20250101-000000.tar.gz (la suma no coincide)
# rc=2
```

Sin la suma (`rm` del `.sha256`), el mensaje es `falta ...sha256` y el código, `2`.

## Paso 7: TODO 6 — `backup_list`

**Por qué**: te deja ver **qué hay** y cuánto pesa; un script de vigilancia la usa
para contar copias. «Qué cuenta como copia» ya lo resuelve `backup_archives`.

**Comando**: un `for` sobre `BK_FILES` con `stat -c %s` y un `printf` con **dos
espacios** entre columnas (el verificador los espera). Sin copias, `copias: 0`
y código `0`: un directorio vacío no es un error.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh backup list --dest /tmp/wk18/dest; echo "rc=$?"
# malo-20250101-000000.tar.gz  189 bytes
# proy-20261025-061010.tar.gz  187 bytes
# copias: 2
# rc=0
```

Los tamaños son los de tu máquina; dentro de una serie el orden es
**cronológico**, el que usa `prune`.

## Paso 8: TODO 7 — `backup_restore`

**Por qué**: restaurar es la razón de todo lo demás, y es también donde más
daño se puede hacer. Orden **fijo**: verificar, comprobar rutas, extraer. Si
cualquiera falla, no se escribe nada.

**Comando**: `backup_verify`, `backup_safe_members "$BK_ARCHIVE"` y, solo entonces,
`tar -xzf ARCHIVO -C DESTINO --no-same-owner`; después cuenta las entradas con
`tar -tzf | wc -l`. `--no-same-owner` hace que lo extraído sea **tuyo** aunque seas
`root`. El destino ya viene validado como vacío.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && mkdir out && /root/bin/toolkit.sh backup restore dest/proy-*.tar.gz --to out'; echo "rc=$?"
# ok proy-20261025-061010.tar.gz
# restaurado en /tmp/wk18/out (4 entradas)
# rc=0
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && diff -r -x cache src/proy out/proy && echo igual'
# igual
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && /root/bin/toolkit.sh backup restore dest/proy-*.tar.gz --to out'; echo "rc=$?"
# toolkit backup restore: el destino no esta vacio: /tmp/wk18/out
# rc=1
```

El rechazo de rutas peligrosas ya lo probaste en el paso 4; aquí actúa **después**
de `verify`, y un archivo con `..` y suma correcta no escribe nada.

## Paso 9: TODO 8 — `backup_prune`

**Por qué**: sin retención el disco se llena y la copia que querías conservar
acaba compitiendo con mil iguales. Y borrar es lo **destructivo** de esta
semana: por eso `--name` y `--keep` son obligatorios y existe `--dry-run`.

> ⚠️ **Antes de borrar de verdad**: haz **siempre** primero la prueba con
> `--dry-run`, y prueba con la serie de juguete de abajo, nunca con tus copias.
> `prune` solo borra los archivos de **la serie** que indicas.

**Comando**: con `backup_archives "$BK_DEST" "$BK_NAME"` ya tienes la serie ordenada
del más antiguo al más reciente. Se borran las **primeras** `total - BK_KEEP` (0 si
es negativo) con `rm -f --` sobre el archivo **y** su `.sha256`, salvo con
`BK_DRY=1`; el `for ((i = 0; i < sobran; i++))` indexa `BK_FILES[i]`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && rm -rf pd && mkdir pd
for d in 01 02 03 04; do echo x > pd/s-202501$d-000000.tar.gz; echo h > pd/s-202501$d-000000.tar.gz.sha256; done
echo y > pd/otra-20250101-000000.tar.gz
/root/bin/toolkit.sh backup prune --name s --keep 2 --dest pd --dry-run; ls pd | wc -l'
# [dry-run] borrado s-20250101-000000.tar.gz
# [dry-run] borrado s-20250102-000000.tar.gz
# [dry-run] conservados: 2, borrados: 2
# 9
docker exec ubuntu-lab bash -c 'cd /tmp/wk18 && /root/bin/toolkit.sh backup prune --name s --keep 2 --dest pd && ls pd | wc -l'
# borrado s-20250101-000000.tar.gz
# borrado s-20250102-000000.tar.gz
# conservados: 2, borrados: 2
# 5
```

Quedan 5: la serie `otra` (1) y las dos últimas de `s` con sus sumas (4). El
`--dry-run` no cambió el recuento (9 archivos).

## Paso 10: `shellcheck`, y programarlo

**Por qué**: un `backup` correcto que `shellcheck` marca es una trampa para quien
lo cambie. Y una copia que no corre sola no es una copia: cierras programándola
con la capa 16.

**Comando**:

```bash
docker exec ubuntu-lab shellcheck /root/bin/toolkit.sh && echo limpio
# limpio
```

Programarlo es una línea con la capa 16 (`schedule gen copias --cron '30 2 * * *' -- ... backup create ...`): lo ves en la [teoría 08](../1-teoria/08-construyendo-backup.md).

**Verifica**: con la versión completa instalada, la verificación de la semana:

```bash
./scripts/verificar-semana.sh 18
# ...
# 18/18 comprobaciones superadas.
```

## ✅ Resultado

- [ ] `backup_parse` rechaza opciones no admitidas, sin valor y un `--keep` inválido con `exit 1`
- [ ] `backup_prepare` valida origen, nombre (regex anclada), destino y destino vacío
- [ ] `backup_safe_members` detiene la restauración ante `..` o `/`, con código `2`
- [ ] `create` escribe en un temporal, renombra y deja la suma con nombre relativo
- [ ] `verify` distingue «falta la suma», «la suma no coincide» y «tar no puede leerlo»
- [ ] `list` cuenta las copias y un directorio vacío no es un error
- [ ] `restore` verifica, comprueba rutas y extrae solo en un directorio vacío
- [ ] `prune` conserva las K últimas de **una** serie y respeta `--dry-run`
- [ ] `shellcheck` limpio y una copia programada con `schedule gen`

Con las ocho funciones, pasa al [proyecto](../3-proyecto/README.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `--exclude` no excluye nada | Patrón sin comillas: la shell lo expandió | `--exclude '*.tmp'` |
| Un nombre `../x` no se rechaza | Validas después de construir la ruta | La regex va en `backup_prepare`, antes |
| `restore` extrae aunque haya `..` | `backup_safe_members` con una tubería | Sustitución de procesos `< <(tar -tzf ...)` |
| `prune` borra la serie equivocada | No pasas el nombre a `backup_archives` | `backup_archives "$BK_DEST" "$BK_NAME"` |
| SC2155 en `local base=$(date ...)` | Asignación y `local` juntos | Sepáralos |

---

[← Práctica 03: registros, `journald` y `logrotate`](03-registros-journald-y-logrotate.md) · [Proyecto: `toolkit backup` →](../3-proyecto/README.md)
