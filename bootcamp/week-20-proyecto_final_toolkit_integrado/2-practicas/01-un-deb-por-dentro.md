# Práctica 01: Un `.deb` por dentro

> Construyes un paquete a mano con `dpkg-deb`, lo abres sin instalarlo y provocas sus dos fallos clásicos.
> Aprendes primero lo que `release build` automatizará después.

**Teoría de apoyo**: [01 · Empaquetar una herramienta](../1-teoria/01-empaquetar-una-herramienta.md) y [02 · Control, versión y numeración](../1-teoria/02-control-version-y-numeracion.md).
**Duración estimada**: 1 h · **Entorno**: `ubuntu-lab`

## Preparación

Todo ocurre dentro del contenedor y en un directorio desechable. Nada de esta práctica instala ni borra nada fuera de `/tmp/wk20`.

```bash
# Entra al laboratorio y crea el directorio de trabajo vacio.
docker exec -it ubuntu-lab bash
rm -rf /tmp/wk20 && mkdir -p /tmp/wk20 && cd /tmp/wk20
```

Necesitas el `toolkit.sh` de las semanas anteriores en `~/bin`:

```bash
test -x ~/bin/toolkit.sh && echo listo
# listo
```

---

## Paso 1: Montar el árbol del paquete

**Por qué**: un `.deb` es la foto de un árbol de directorios con la forma del sistema de destino. Si quieres que `toolkit` acabe en `/usr/bin/toolkit`, el archivo tiene que estar en `staging/usr/bin/toolkit`. Montarlo a mano es la mejor forma de entender qué hará `release build` por ti.

**Comando**:

```bash
# DEBIAN/ guarda los metadatos; el resto del arbol es lo que se instalara.
mkdir -p staging/DEBIAN staging/usr/bin
# install copia y fija el modo en un solo paso (0755: ejecutable para todos).
install -m 0755 ~/bin/toolkit.sh staging/usr/bin/toolkit
```

**Verifica**:

```bash
ls -l staging/usr/bin/toolkit | cut -c1-10
# -rwxr-xr-x
ls -ld staging staging/DEBIAN | awk '{print $1, $NF}'
# drwxr-xr-x staging
# drwxr-xr-x staging/DEBIAN
```

---

## Paso 2: Escribir el archivo `control`

**Por qué**: sin `control` no hay paquete. Es la ficha que `dpkg` consulta para saber el nombre, la versión y las dependencias. Un campo mal escrito no rompe la construcción; rompe después, al instalar o al actualizar.

**Comando**:

```bash
# Version 0.1.0: es una prueba, no la version final del toolkit.
# La descripcion extendida empieza cada linea con un espacio.
cat > staging/DEBIAN/control <<'EOF'
Package: toolkit
Version: 0.1.0
Architecture: all
Maintainer: Toolkit <toolkit@example.invalid>
Depends: bash (>= 5.0)
Description: caja de herramientas personal de sysadmin
 Prueba de empaquetado a mano.
EOF
```

**Verifica**:

```bash
grep -c '^[A-Z]' staging/DEBIAN/control
# 6
```

Seis líneas de campo y una de continuación (la que empieza por espacio): por eso `grep` cuenta seis.

---

## Paso 3: Construir el paquete

**Por qué**: `--root-owner-group` guarda todos los archivos como `root:root`. Aquí ya eres root dentro del contenedor y no se nota, pero en tu máquina real sin esa opción el paquete llevaría **tu** usuario, que no existe en el destino. Hazlo siempre.

**Comando**:

```bash
# El nombre sigue la convencion NOMBRE_VERSION_ARQUITECTURA.deb
dpkg-deb --build --root-owner-group staging toolkit_0.1.0_all.deb
```

**Verifica**:

```bash
# dpkg-deb: building package 'toolkit' in 'toolkit_0.1.0_all.deb'.
test -f toolkit_0.1.0_all.deb && head -c 8 toolkit_0.1.0_all.deb; echo
# !<arch>
```

Si no ves `!<arch>`, no es un archivo `ar` y no es un `.deb`.

---

## Paso 4: Leer los metadatos sin instalar

**Por qué**: antes de instalar algo, pregunta qué es. `dpkg-deb -I` muestra la ficha completa y `-f` un campo concreto, que es lo que usan los scripts. Esta es la comprobación que deberías hacer a **todo** `.deb` que no hayas construido tú.

**Comando**:

```bash
# -I: ficha completa. -f: solo los campos que pidas.
dpkg-deb -I toolkit_0.1.0_all.deb
dpkg-deb -f toolkit_0.1.0_all.deb Package Version
```

**Verifica**:

```bash
dpkg-deb -f toolkit_0.1.0_all.deb Package Version
# Package: toolkit
# Version: 0.1.0
```

En `-I` verás también una línea `size N bytes: control archive=M bytes`: el tamaño total y lo que ocupa solo la parte de control.

---

## Paso 5: Listar el contenido y comprobar propietario y modo

**Por qué**: `dpkg-deb -c` es el `ls -l` de un paquete. Aquí es donde se descubre un archivo con el propietario equivocado o un script sin bit de ejecución, **antes** de repartirlo.

**Comando**:

```bash
# Columnas: permisos, propietario/grupo, tamaño, fecha, ruta.
dpkg-deb -c toolkit_0.1.0_all.deb
```

**Verifica**:

```bash
dpkg-deb -c toolkit_0.1.0_all.deb | grep -E '^-rwxr-xr-x root/root .* \./usr/bin/toolkit$' | wc -l
# 1
```

---

## Paso 6: Abrir las dos mitades del paquete

**Por qué**: un `.deb` son dos `tar` dentro de un `ar`: uno de **control** (metadatos) y uno de **datos** (lo que se instala). Verlos por separado fija el modelo mental. No necesitas la orden `ar`, que no existe en `ubuntu-lab`: `dpkg-deb` te da cada mitad como un flujo `tar`.

**Comando**:

```bash
# --ctrl-tarfile: la mitad de metadatos. --fsys-tarfile: la mitad que se instala.
dpkg-deb --ctrl-tarfile toolkit_0.1.0_all.deb | tar -t
dpkg-deb --fsys-tarfile toolkit_0.1.0_all.deb | tar -t
```

**Verifica**:

```bash
dpkg-deb --ctrl-tarfile toolkit_0.1.0_all.deb | tar -t
# ./
# ./control
dpkg-deb --fsys-tarfile toolkit_0.1.0_all.deb | tar -t | tail -1
# ./usr/bin/toolkit
```

Observa que este paquete **no** tiene `md5sums`: lo escribiste a mano y no lo generaste. `release build` sí lo hace, y por eso `dpkg --verify` podrá comprobar sus archivos.

---

## Paso 7: Extraer sin instalar y ejecutar

**Por qué**: `-x` extrae a un directorio cualquiera sin tocar `/usr`. Es la forma segura de probar un paquete ajeno, y la que usarán los chequeos de esta semana para ejecutar lo que `release build` empaqueta.

**Comando**:

```bash
# probe/ es un directorio nuevo; nada se instala en el sistema.
dpkg-deb -x toolkit_0.1.0_all.deb probe
probe/usr/bin/toolkit version
```

**Verifica**:

```bash
probe/usr/bin/toolkit version
# toolkit 1.0.0
```

El paquete se llama `0.1.0` pero el programa dice `1.0.0`: la versión del `control` y la del script son **independientes**. Esta contradicción es exactamente lo que `release build` evitará estampando la versión (lo verás en la práctica 05).

---

## Paso 8: Provocar el error de permisos

**Por qué**: `mktemp -d` crea directorios con modo `0700`. Si usas uno como raíz del paquete, `dpkg-deb` lo rechaza. Conviene haber visto este error **antes** de que aparezca dentro de un script.

> **Aviso**: solo cambias el modo de `staging/DEBIAN`, dentro de tu directorio de trabajo. No hay nada que respaldar, y lo restauras en la misma línea.

**Comando**:

```bash
chmod 700 staging/DEBIAN
dpkg-deb --build --root-owner-group staging x.deb; echo "rc=$?"
chmod 755 staging/DEBIAN
```

**Verifica**:

```bash
# dpkg-deb: error: control directory has bad permissions 700 (must be >=0755 and <=0775)
# rc=2
ls x.deb 2>&1 | grep -c 'No such file'
# 1
```

El paquete **no** se crea: un error de permisos es limpio, a diferencia del siguiente.

---

## Paso 9: Provocar el aviso silencioso

**Por qué**: faltar un campo obligatorio **no detiene** la construcción. Sale con código 0 y el archivo existe, pero está mal formado. Ver este caso te enseña a no fiarte del código de salida de `dpkg-deb` y a leer sus avisos.

**Comando**:

```bash
# Quita la descripcion (y su continuacion) del control y reconstruye.
sed -i '/^Description/,$d' staging/DEBIAN/control
dpkg-deb --build --root-owner-group staging y.deb; echo "rc=$?"
```

**Verifica**:

```bash
# dpkg-deb: building package 'toolkit' in 'y.deb'.
# dpkg-deb: warning: parsing file 'staging/DEBIAN/control' near line 6 package 'toolkit':
#  missing 'Description' field
# dpkg-deb: warning: ignoring 1 warning about the control file(s)
# rc=0
test -f y.deb && echo existe
# existe
```

Código `0`, el paquete existe y está defectuoso. Esta es la razón de que `release verify` compruebe el contenido y no solo que el archivo exista.

---

## Paso 10: Limpiar

**Por qué**: dejar paquetes de prueba en `/tmp` confunde las prácticas siguientes. Usa una ruta que no pueda coincidir con nada tuyo.

> **Aviso**: `rm -rf` es destructivo. Comprueba la ruta con `pwd` antes y borra solo `/tmp/wk20`, que es de usar y tirar.

**Comando**:

```bash
pwd
# /tmp/wk20
cd / && rm -rf /tmp/wk20
```

**Verifica**:

```bash
test ! -e /tmp/wk20 && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] Montaste el árbol de un paquete con `install -m 0755`
- [ ] Escribiste un `control` válido y construiste `toolkit_0.1.0_all.deb`
- [ ] Leíste su ficha con `dpkg-deb -I` y `-f`
- [ ] Listaste su contenido y comprobaste `root/root` y el modo `755`
- [ ] Abriste control y datos por separado con `--ctrl-tarfile` y `--fsys-tarfile`
- [ ] Extraste con `-x` y viste que el paquete y el script declaran versiones distintas
- [ ] Provocaste el error de permisos `700` y el aviso por campo ausente

```bash
bash scripts/verificar-semana.sh 20
# (sin comprobación propia: las de release llegan en las prácticas 05 y 06)
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ar: command not found` | `ubuntu-lab` no trae `binutils` | No lo necesitas: usa `dpkg-deb --ctrl-tarfile` y `--fsys-tarfile` |
| `control directory has bad permissions 700` | Raíz o `DEBIAN/` con modo `0700` | `chmod 755 staging staging/DEBIAN` |
| `error: failed to open package info file 'staging/DEBIAN/control'` | Falta `DEBIAN/control` | Vuelve al paso 2 |
| `warning: ... missing 'Description' field` | Campo obligatorio ausente | Restaura la descripción en `control` |
| `error: parsing file ... empty field name` | Una línea del `control` empieza por espacio sin campo anterior | Elimina espacios iniciales de más |
| El `.deb` no aparece | Construyes con una ruta de salida distinta | Revisa el segundo argumento de `--build` |

---

[← Repaso y siguientes pasos](../1-teoria/07-repaso-y-siguientes-pasos.md) · [Práctica 02: Manual, versión y documentación →](02-manual-version-y-documentacion.md)
