# Práctica 02 — Integridad y restauración

> Duración estimada: 60 min · Teoría de apoyo: [archivo 03](../1-teoria/03-integridad-y-restauracion.md)

Una copia que no se puede comprobar ni restaurar es una esperanza, no una copia.
Aquí rompes archivos **a propósito** para ver cómo fallan `sha256sum`, `gzip` y
`tar`, y practicas restaurar sin pisar nada. Todo ocurre en `/tmp/p18b`, dentro
de `ubuntu-lab`.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Crear un archivo y su suma

**Por qué**: la suma SHA-256 es la huella del archivo. Se guarda **al lado**, con
el nombre **sin ruta**, para que se pueda comprobar desde cualquier máquina donde
copies el par.

**Comando**:

```bash
rm -rf /tmp/p18b && mkdir -p /tmp/p18b/datos/docs && cd /tmp/p18b
echo hola > datos/docs/a.txt; echo mundo > datos/docs/b.txt
tar -czf d.tar.gz datos
# Sin ruta en el nombre: se ejecuta desde el directorio del archivo.
sha256sum d.tar.gz > d.tar.gz.sha256
awk '{print length($1), $2}' d.tar.gz.sha256
# 64 d.tar.gz
```

**Verifica**:

```bash
sha256sum -c d.tar.gz.sha256; echo "rc=$?"
# d.tar.gz: OK
# rc=0
```

## Paso 2: Una copia que cambió

**Por qué**: un solo byte distinto hace fallar la suma. Es lo que detecta un
disco que corrompe datos, una transferencia cortada o una manipulación.

**Comando**:

```bash
cp d.tar.gz m.tar.gz
sed 's/d.tar.gz/m.tar.gz/' d.tar.gz.sha256 > m.tar.gz.sha256
printf zz >> m.tar.gz                 # "corrompemos" la copia
sha256sum -c m.tar.gz.sha256; echo "rc=$?"
# m.tar.gz: FAILED
# sha256sum: WARNING: 1 computed checksum did NOT match
# rc=1
```

**Verifica**:

```bash
# --status no imprime nada: solo el codigo de salida (lo que usa un script).
sha256sum --status -c m.tar.gz.sha256; echo "rc=$?"
# rc=1
```

## Paso 3: Un archivo que falta

**Por qué**: «no coincide» y «no existe» son fallos distintos, aunque los dos den
código `1`. El mensaje cambia, y `--ignore-missing` puede **ocultar** el segundo:
cuidado con usarlo a ciegas.

**Comando**:

```bash
rm m.tar.gz
sha256sum -c m.tar.gz.sha256; echo "rc=$?"
# m.tar.gz: FAILED open or read
# sha256sum: m.tar.gz: No such file or directory
# sha256sum: WARNING: 1 listed file could not be read
# rc=1
sha256sum --ignore-missing -c m.tar.gz.sha256; echo "rc=$?"
# sha256sum: m.tar.gz.sha256: no file was verified
# rc=1
```

**Verifica**: ambos códigos son `1`. Con `--ignore-missing` el error cambia a
«ningún archivo verificado», que sigue siendo fallo porque era el único.

## Paso 4: Un archivo de sumas que no lo es

**Por qué**: pasarle a `-c` un archivo cualquiera no es «todo bien»: es un error.

**Comando**:

```bash
echo basura > x.sha256
sha256sum -c x.sha256; echo "rc=$?"
# sha256sum: x.sha256: no properly formatted checksum lines found
# rc=1
```

**Verifica**:

```bash
sha256sum -c x.sha256 >/dev/null 2>&1 || echo "falla, como debe"
# falla, como debe
```

## Paso 5: Un archivo truncado

**Por qué**: una copia cortada a medias (disco lleno, red caída) puede dar una
suma correcta **si la suma también se hizo tras el corte**. `gzip -t` y `tar -t`
detectan que el contenido no se puede leer entero, y son la segunda defensa.

**Comando**:

```bash
head -c 100 d.tar.gz > t.tar.gz
gzip -t t.tar.gz; echo "rc=$?"
#
# gzip: t.tar.gz: unexpected end of file
# rc=1
tar -tzf t.tar.gz >/dev/null; echo "rc=$?"
#
# gzip: stdin: unexpected end of file
# tar: Child returned status 1
# tar: Error is not recoverable: exiting now
# rc=2
```

**Verifica**: `gzip -t` devuelve `1` y `tar -t` devuelve `2`. Cualquiera de los
dos distinto de `0` significa «no uses este archivo».

## Paso 6: Restaurar y comparar

**Por qué**: la prueba definitiva de una copia es restaurarla y comparar con el
original. `diff -r` compara dos árboles entero.

**Comando**:

```bash
mkdir out && tar -xzf d.tar.gz -C out
diff -r datos out/datos && echo igual
# igual
echo cambio >> out/datos/docs/a.txt
diff -r datos out/datos; echo "rc=$?"
# diff -r datos/docs/a.txt out/datos/docs/a.txt
# 1a2
# > cambio
# rc=1
```

**Verifica**: tras restaurar limpio, `diff -r` no imprime nada y devuelve `0`;
tras el cambio, devuelve `1` y te dice qué archivo difiere.

## Paso 7: Rutas peligrosas en un archivo

**Por qué**: un `.tar` ajeno puede traer miembros con `..` o con `/` para
escribir **fuera** del destino. GNU `tar` ya protege, pero un programa que
restaura copias debe **mirar el listado él mismo** (teoría 03, apartado 2.4).

> ⚠️ Fabricas el archivo malicioso **tú**, en `/tmp/p18b`, y lo extraes dentro de
> un directorio vacío. No lo extraigas fuera del laboratorio.

**Comando**:

```bash
echo e > e
# --transform antepone ../fuera/ al nombre del miembro (2>/dev/null: oculta el aviso de tar).
tar -czf evil.tar.gz --transform 's,^,../fuera/,' e 2>/dev/null
tar -tzf evil.tar.gz 2>/dev/null
# ../fuera/e
mkdir o5 && tar -xzf evil.tar.gz -C o5; echo "rc=$?"
# tar: Removing leading `../' from member names
# tar: ../fuera/e: Member name contains '..'
# tar: Exiting with failure status due to previous errors
# rc=2
ls -A o5 | wc -l
# 0
```

**Verifica**: la comprobación que usa `toolkit backup restore`:

```bash
tar -tzf evil.tar.gz 2>/dev/null | grep -E '(^/|(^|/)\.\.(/|$))'
# ../fuera/e
```

Si el `grep` imprime algo, **no extraigas**.

## Paso 8: Rutas absolutas

**Por qué**: con `-P` se guarda la ruta absoluta tal cual. Al extraer, `tar`
**quita la barra inicial** y la restaura bajo el destino, pero esa copia nunca
debió crearse así: al restaurar en otra máquina, un `-P` mal usado puede pisar
rutas reales.

**Comando**:

```bash
tar -czPf abs.tar.gz /tmp/p18b/e 2>/dev/null
tar -tzf abs.tar.gz 2>/dev/null
# /tmp/p18b/e
mkdir o6 && tar -xzf abs.tar.gz -C o6 2>/dev/null; find o6 -type f
# o6/tmp/p18b/e
```

**Verifica**:

```bash
tar -tzf abs.tar.gz 2>/dev/null | grep -c '^/'
# 1
```

El mismo `grep` de antes lo detecta (`^/`). La regla: **nunca uses `-P`** al
crear copias.

## Paso 9: Permisos de la copia

**Por qué**: una copia contiene todo lo que el original: claves, configuración,
datos privados. `mktemp` crea con `600` por una razón; un `tar -czf` normal sale
con tu `umask`, normalmente `644`.

**Comando**:

```bash
umask
# 0022
mktemp /tmp/p18b/XXXXXX | xargs ls -l | cut -c1-10
# -rw-------
ls -l d.tar.gz | cut -c1-10
# -rw-r--r--
chmod 600 d.tar.gz && ls -l d.tar.gz | cut -c1-10
# -rw-------
```

**Verifica**: tu `d.tar.gz` ya es `-rw-------`. En `toolkit backup create` esto
se obtiene gratis porque se escribe en un temporal de `mktemp` y se **renombra**.

## Paso 10: Otras sumas

**Por qué**: `sha256sum` es lo habitual, pero hay más. Sirve saber que existen y
que **producen huellas distintas** de longitud distinta.

**Comando**:

```bash
sha256sum d.tar.gz | cut -c1-16
# 936f159d7f0c883a
sha512sum d.tar.gz | cut -c1-16
# 307197e0bfffb896
b2sum d.tar.gz | cut -c1-16
# 0c327b36f4b18520
```

**Verifica**: los tres prefijos son distintos. (Si no cambiaste nada, tus valores
serán otros: dependen de la fecha de modificación guardada en el `.tar`.)

## ✅ Resultado

- [ ] Creaste un archivo y su suma con el nombre sin ruta, y `-c` dio `OK`
- [ ] Viste `FAILED` en un archivo cambiado y `FAILED open or read` en uno ausente
- [ ] Sabes qué hace `--status` y por qué sirve en scripts
- [ ] Detectaste un truncado con `gzip -t` y `tar -t`
- [ ] Restauraste a un directorio vacío y comparaste con `diff -r`
- [ ] Fabricaste un archivo con `..`, comprobaste que `tar` se niega y lo detectaste con `grep`
- [ ] Viste el efecto de `-P` y por qué no se usa
- [ ] Sabes por qué una copia debe ser `600`

Siguiente: la [práctica 03](03-registros-journald-y-logrotate.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `sha256sum -c` dice `No such file` aunque el archivo existe | Estás en otro directorio | `cd` al directorio del par |
| `FAILED` sin haber tocado nada | La suma se hizo antes de terminar de escribir | Rehaz la copia y la suma |
| `diff -r` dice `No such file` | Compara con la ruta equivocada | Restauraste en `out/`; el árbol está en `out/datos` |
| `tar` extrae el `evil.tar.gz` sin quejarse | Tu `tar` no es GNU o es muy antiguo | Usa la comprobación con `grep` antes de extraer |
| El prefijo de `sha256sum` no coincide con el de arriba | El `.tar` lleva fechas | Normal: solo importa que coincida consigo mismo |

---

[← Práctica 01: `tar` y compresión](01-tar-y-compresion.md) · [Práctica 03: registros, `journald` y `logrotate` →](03-registros-journald-y-logrotate.md)
