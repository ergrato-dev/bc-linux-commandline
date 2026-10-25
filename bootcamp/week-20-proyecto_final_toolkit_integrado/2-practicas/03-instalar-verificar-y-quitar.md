# Práctica 03: Instalar, verificar y quitar

> Construyes dos versiones de `toolkit`, las instalas con `dpkg` dentro del laboratorio, detectas una manipulación y recorres el ciclo completo: instalar, actualizar, degradar, quitar.
> Aquí `dpkg` deja de ser una orden de la Semana 11 y se convierte en tu gestor de **tu** paquete.

**Teoría de apoyo**: [03 · Instalar, verificar y quitar](../1-teoria/03-instalar-verificar-y-quitar.md).
**Duración estimada**: 1 h · **Entorno**: `ubuntu-lab`

> **Aviso**: esta práctica **instala y desinstala un paquete de verdad**, pero dentro del contenedor `ubuntu-lab`, que es desechable. No la ejecutes en tu máquina principal. Al final del todo dejas el laboratorio como lo encontraste (paso 11).

## Preparación

Necesitas el `toolkit.sh` del starter en `~/bin` (práctica 02) y, aún, **no** hace falta que `release build` funcione: construirás los paquetes con una función auxiliar que reproduce a mano lo que esa orden automatizará.

```bash
docker exec -it ubuntu-lab bash
rm -rf /tmp/wk20 && mkdir -p /tmp/wk20 && cd /tmp/wk20
test -x ~/bin/toolkit.sh && echo listo
# listo
```

---

## Paso 1: Una función para construir paquetes de prueba

**Por qué**: necesitas dos paquetes casi idénticos (versiones `1.0.0` y `1.1.0`) para probar la actualización y la degradación. En lugar de repetir diez comandos, los metes en una función. Es la misma secuencia que automatizará `release_stage` en la práctica 05, así que léela con calma: cada línea tiene un motivo.

**Comando**:

```bash
mk() {
  local v=$1 d
  d=$(mktemp -d)
  chmod 0755 "$d"                                  # mktemp -d da 0700 y dpkg-deb lo rechaza
  install -d -m 0755 "$d/DEBIAN" "$d/usr/bin" "$d/usr/share/man/man1"
  install -m 0755 ~/bin/toolkit.sh "$d/usr/bin/toolkit"
  # Estampa la version en la copia del paquete, no en tu script de trabajo.
  sed -i "s/^TOOLKIT_VERSION=\".*\"\$/TOOLKIT_VERSION=\"$v\"/" "$d/usr/bin/toolkit"
  bash -c "source ~/bin/toolkit.sh; RL_VERSION=$v; release_manpage" | gzip -9n > "$d/usr/share/man/man1/toolkit.1.gz"
  chmod 0644 "$d/usr/share/man/man1/toolkit.1.gz"
  printf 'Package: toolkit\nVersion: %s\nArchitecture: all\nMaintainer: Toolkit <toolkit@example.invalid>\nDepends: bash (>= 5.0)\nDescription: caja de herramientas personal de sysadmin\n' "$v" > "$d/DEBIAN/control"
  # md5sums con rutas relativas: es lo que dpkg --verify comparara despues.
  (cd "$d" && find usr -type f -print0 | LC_ALL=C sort -z | xargs -0 md5sum) > "$d/DEBIAN/md5sums"
  dpkg-deb --build --root-owner-group "$d" "toolkit_${v}_all.deb" >/dev/null
  rm -rf "$d"
}
mk 1.0.0
mk 1.1.0
```

**Verifica**:

```bash
ls toolkit_*.deb
# toolkit_1.0.0_all.deb  toolkit_1.1.0_all.deb
dpkg-deb -f toolkit_1.1.0_all.deb Version
# 1.1.0
```

---

## Paso 2: Instalar

**Por qué**: `dpkg -i` desempaqueta, copia los archivos y registra el paquete en `/var/lib/dpkg/`. Desde ese momento el sistema **sabe** que `toolkit` existe.

**Comando**:

```bash
dpkg -i toolkit_1.0.0_all.deb
```

**Verifica**:

```bash
# Selecting previously unselected package toolkit.
# Unpacking toolkit (1.0.0) ...
# Setting up toolkit (1.0.0) ...
dpkg -l toolkit | tail -1 | awk '{print $1, $2, $3, $4}'
# ii toolkit 1.0.0 all
command -v toolkit && toolkit version
# /usr/bin/toolkit
# toolkit 1.0.0
```

`ii` significa «deseado: instalado / estado: instalado». Ahora `toolkit` está en el `PATH` de todos los usuarios, sin tocar tu `~/bin`.

---

## Paso 3: Preguntar al sistema qué instaló

**Por qué**: tres preguntas, tres órdenes. `-s` da la ficha, `-L` lista archivos y `-S` busca el dueño de una ruta. Esta última es la que usarás de por vida para saber de dónde sale un archivo misterioso.

**Comando**:

```bash
dpkg -s toolkit | grep -E '^(Package|Status|Version|Architecture|Depends)'
dpkg -L toolkit
dpkg -S /usr/bin/toolkit
dpkg -S /usr/bin/ls
dpkg -S /usr/local/bin/nada
```

**Verifica**:

```bash
# Package: toolkit
# Status: install ok installed
# Architecture: all
# Version: 1.0.0
# Depends: bash (>= 5.0)
#
# /.
# /usr
# /usr/bin
# /usr/bin/toolkit
# /usr/share
# /usr/share/man
# /usr/share/man/man1
# /usr/share/man/man1/toolkit.1.gz
#
# toolkit: /usr/bin/toolkit
# coreutils: /usr/bin/ls
# dpkg-query: no path found matching pattern /usr/local/bin/nada
```

El último mensaje es la señal que buscas en una auditoría: un archivo del que `dpkg -S` dice «no path found» **no lo instaló ningún paquete**.

---

## Paso 4: Ver por qué falta la página de manual

**Por qué**: `dpkg -L` dice que la página de manual existe, pero ¿está en el disco? La verificación te lo cuenta. Es un efecto de la imagen mínima de Docker, no un error tuyo, y entenderlo ahora te ahorra una hora de dudas.

**Comando**:

```bash
dpkg --verify toolkit
ls /usr/share/man/man1/toolkit.1.gz
grep man /etc/dpkg/dpkg.cfg.d/excludes
```

**Verifica**:

```bash
# missing     /usr/share/man/man1/toolkit.1.gz
# ls: cannot access '/usr/share/man/man1/toolkit.1.gz': No such file or directory
# # Drop all man pages
# path-exclude=/usr/share/man/*
```

La imagen configura `dpkg` para **no instalar** nada bajo `/usr/share/man/`. El paquete lo contiene (`-L` lo lista), pero `dpkg` lo salta. En un Ubuntu de escritorio no ocurre.

---

## Paso 5: Reinstalar incluyendo el manual

**Por qué**: para que `--verify` vuelva a salir limpio necesitas la página en disco. `--path-include` anula la exclusión **solo para esta instalación**. Observa también que reinstalar la misma versión es una operación legítima.

**Comando**:

```bash
dpkg -i --path-include='/usr/share/man/*' toolkit_1.0.0_all.deb
```

**Verifica**:

```bash
# Unpacking toolkit (1.0.0) over (1.0.0) ...
# Setting up toolkit (1.0.0) ...
dpkg --verify toolkit; echo "(sin salida arriba = limpio)"
# (sin salida arriba = limpio)
ls /usr/share/man/man1/toolkit.1.gz
# /usr/share/man/man1/toolkit.1.gz
```

---

## Paso 6: Detectar una manipulación

**Por qué**: esta es la razón de que existan las sumas. Modificas un archivo instalado y compruebas que `dpkg --verify` lo delata. Después descubrirás una limitación importante.

> **Aviso**: modificas `/usr/bin/toolkit` **dentro del contenedor**. Es seguro porque en el paso 7 una actualización lo restituye. Si quieres un respaldo antes: `cp /usr/bin/toolkit /tmp/wk20/toolkit.orig`.

**Comando**:

```bash
echo "# x" >> /usr/bin/toolkit
dpkg --verify toolkit; echo "rc=$?"
[ -z "$(dpkg --verify toolkit)" ] && echo limpio || echo sucio
```

**Verifica**:

```bash
# ??5??????   /usr/bin/toolkit
# rc=0
# sucio
```

Dos lecciones en tres líneas. El `5` en la tercera posición es «el contenido cambió». Y `rc=0`: **`dpkg --verify` sale con éxito aunque encuentre diferencias**. Un script debe leer su salida, no su código, como en la práctica 02 con `groff`.

Ahora la limitación: cambia solo los permisos y el propietario.

```bash
dpkg -i --path-include='/usr/share/man/*' toolkit_1.0.0_all.deb >/dev/null 2>&1   # restituye el archivo
chmod 777 /usr/bin/toolkit && chown nobody /usr/bin/toolkit
dpkg --verify toolkit; echo "(sin salida: no lo ve)"
# (sin salida: no lo ve)
```

`dpkg --verify` solo compara el **contenido**. Un archivo con permisos `777` y de otro dueño pasa limpio. Por eso `release verify` revisa los permisos **dentro del paquete**, antes de instalarlo.

Restituye el estado correcto:

```bash
dpkg -i --path-include='/usr/share/man/*' toolkit_1.0.0_all.deb >/dev/null 2>&1
ls -l /usr/bin/toolkit | cut -c1-10
# -rwxr-xr-x
```

---

## Paso 7: Actualizar

**Por qué**: instalar una versión mayor encima es una **actualización**. `dpkg` desempaqueta la nueva, sustituye los archivos del paquete anterior y elimina los que ya no existan. Observa la frase `over (1.0.0)`.

**Comando**:

```bash
dpkg -i --path-include='/usr/share/man/*' toolkit_1.1.0_all.deb
toolkit version
```

**Verifica**:

```bash
# Preparing to unpack toolkit_1.1.0_all.deb ...
# Unpacking toolkit (1.1.0) over (1.0.0) ...
# Setting up toolkit (1.1.0) ...
toolkit version
# toolkit 1.1.0
dpkg --verify toolkit; echo "(limpio)"
# (limpio)
```

---

## Paso 8: Degradar y leer el aviso

**Por qué**: instalar una versión **menor** que la actual funciona, pero `dpkg` avisa. Ese aviso es la última barrera contra instalar el paquete equivocado. En producción, una degradación casi nunca es deliberada.

**Comando**:

```bash
dpkg -i --path-include='/usr/share/man/*' toolkit_1.0.0_all.deb
toolkit version
```

**Verifica**:

```bash
# dpkg: warning: downgrading toolkit from 1.1.0 to 1.0.0
# Unpacking toolkit (1.0.0) over (1.1.0) ...
# Setting up toolkit (1.0.0) ...
toolkit version
# toolkit 1.0.0
```

---

## Paso 9: Quitar el paquete

**Por qué**: `dpkg -r` quita los archivos del paquete y deja las configuraciones; `dpkg -P` (purgar) quita también la configuración. `toolkit` no tiene configuración, así que aquí son equivalentes. Lo importante es comprobar que **no queda rastro**.

**Comando**:

```bash
dpkg -r toolkit
dpkg-query -W toolkit
ls /usr/bin/toolkit
dpkg -l toolkit | tail -1
```

**Verifica**:

```bash
# Removing toolkit (1.0.0) ...
# dpkg-query: no packages found matching toolkit
# ls: cannot access '/usr/bin/toolkit': No such file or directory
# dpkg-query: no packages found matching toolkit
```

---

## Paso 10: Instalar con `apt` y purgar

**Por qué**: `apt-get install ./archivo.deb` instala un paquete local **y resuelve sus dependencias** desde los repositorios; `dpkg -i` no. La `./` es obligatoria: sin ella `apt` busca el nombre en los repositorios.

**Comando**:

```bash
apt-get install -y ./toolkit_1.0.0_all.deb
dpkg -l toolkit | tail -1 | awk '{print $1, $2, $3}'
dpkg -P toolkit
```

**Verifica**:

```bash
# Unpacking toolkit (1.0.0) ...
# Setting up toolkit (1.0.0) ...
# ii toolkit 1.0.0
# Removing toolkit (1.0.0) ...
dpkg-query -W toolkit 2>&1
# dpkg-query: no packages found matching toolkit
```

(La salida de `apt-get` incluye más líneas, entre ellas un indicador de progreso muy largo: `grep -E 'Unpacking|Setting'` deja solo las importantes.)

---

## Paso 11: Limpiar

**Por qué**: deja el laboratorio como estaba, sin paquetes ni archivos de prueba.

> **Aviso**: `rm -rf` es destructivo. Comprueba con `pwd` que estás en `/tmp/wk20` antes.

**Comando**:

```bash
pwd
# /tmp/wk20
cd / && rm -rf /tmp/wk20
```

**Verifica**:

```bash
test ! -e /tmp/wk20 && ! dpkg -s toolkit >/dev/null 2>&1 && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] Construiste `toolkit` 1.0.0 y 1.1.0 con `md5sums`
- [ ] Instalaste con `dpkg -i` y comprobaste el estado `ii`
- [ ] Usaste `dpkg -s`, `-L` y `-S` (incluido el caso «no path found»)
- [ ] Entendiste por qué falta la página de manual en `ubuntu-lab`
- [ ] Detectaste una modificación con `dpkg --verify` y conoces su límite (permisos y dueño no se ven)
- [ ] Actualizaste (`over`), degradaste (`downgrading`) y quitaste el paquete
- [ ] Instalaste con `apt-get install ./` y purgaste con `dpkg -P`

```bash
bash scripts/verificar-semana.sh 20
# Esta práctica no tiene un chequeo propio: afianza lo que usan los de la práctica 05
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `dpkg-deb: error: control directory has bad permissions 700` | `chmod 0755 "$d"` ausente en `mk` | Revisa la función del paso 1 |
| `dpkg: dependency problems prevent configuration of toolkit` | `bash (>= 5.0)` no está satisfecha | Lo trae `ubuntu-lab`; en otro entorno, instala `bash` |
| `missing /usr/share/man/man1/toolkit.1.gz` tras instalar | La imagen excluye el manual | Reinstala con `--path-include='/usr/share/man/*'` (paso 5) |
| `dpkg --verify` no muestra nada pero modifiqué permisos | Solo compara contenido | Revisa permisos con `dpkg-deb -c` antes de instalar |
| `apt-get install` dice `Unable to locate package` | Falta la `./` | Escribe `./toolkit_1.0.0_all.deb` |
| `dpkg: warning: downgrading` y no lo querías | Elegiste el `.deb` equivocado | Instala el correcto; el aviso es la barrera |

---

[← Práctica 02: Manual, versión y documentación](02-manual-version-y-documentacion.md) · [Práctica 04: Probar con selftest →](04-probar-con-selftest.md)
