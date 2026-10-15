# Copiar archivos y directorios

> `cp` sin flags copia un archivo. `cp` con los flags correctos preserva
> permisos, sigue o no enlaces, y copia árboles completos sin sorpresas.
> La diferencia entre ambos casos es constante en el trabajo real.

## 🎯 Objetivos

- Copiar archivos y directorios completos con los flags correctos
- Explicar qué preserva `-p`/`-a` y por qué una copia "simple" puede perder metadatos
- Anticipar qué pasa cuando el destino ya existe

## 1. Qué problema resuelve

Copiar un archivo suelto es trivial. Copiar un árbol completo de carpetas,
preservando permisos y fechas, sin seguir enlaces simbólicos por accidente,
sin sobrescribir algo importante sin aviso — eso ya no es trivial, y es
exactamente donde la mayoría de la gente usa `cp` a medias, sin saber qué
se perdió en el camino.

## 2. Cómo funciona

### 2.1 `cp` básico

```bash
cp origen.txt destino.txt
cp origen.txt /otra/carpeta/           # mantiene el nombre, cambia de carpeta
cp origen.txt /otra/carpeta/otro-nombre.txt
```

Si el destino es una carpeta existente, `cp` copia *dentro* de ella con el
mismo nombre. Si el destino es un nombre de archivo, copia *a* ese nombre
exacto, lo sobrescriba o no.

### 2.2 Copiar directorios: `-r` es obligatorio

```bash
cp carpeta-origen carpeta-destino
# cp: -r not specified; omitting directory 'carpeta-origen'

cp -r carpeta-origen carpeta-destino
```

Sin `-r` ("recursive"), `cp` se niega a copiar un directorio — es una
protección deliberada, no una limitación: copiar un árbol completo por
accidente, cuando solo querías un archivo, sería una sorpresa cara.

### 2.3 Qué preserva una copia simple, y qué no

```bash
touch -d "2020-01-01" original.txt
chmod 600 original.txt
cp original.txt copia.txt
ls -l --time-style=long-iso original.txt copia.txt
```

Una copia simple (`cp` sin flags) actualiza la fecha de modificación al
momento de la copia y usa tus permisos por defecto (según tu `umask`), **no**
los del original. Si necesitas preservar exactamente fecha, permisos y
dueño, hace falta pedirlo explícitamente.

### 2.4 `-p`: preservar metadatos

```bash
cp -p original.txt copia-preservada.txt
ls -l --time-style=long-iso original.txt copia-preservada.txt
```

`-p` preserva modo (permisos), dueño/grupo (si tienes privilegios para
eso) y las fechas de modificación y acceso. Sin `-p`, una copia es un
archivo "nuevo" en todos los sentidos salvo el contenido.

### 2.5 `-a`: el preset completo para copiar árboles

```bash
cp -a carpeta-origen/ carpeta-destino/
```

`-a` ("archive") combina `-r` (recursivo) + `-p` (preserva metadatos) +
`--no-dereference` (no sigue enlaces simbólicos, los copia *como enlaces*,
no como el contenido al que apuntan) + preserva la estructura de enlaces
duros cuando es posible. Es el flag que usarías para "clonar" un árbol de
carpetas tal cual es, sin perder nada en el camino.

### 2.6 Enlaces simbólicos: seguir o no seguir

```bash
ln -s /etc/hostname enlace.txt

cp enlace.txt copia-siguiendo.txt       # copia el CONTENIDO del destino
cp -d enlace.txt copia-sin-seguir.txt    # copia el ENLACE, no su contenido
# -a ya incluye el comportamiento de -d
```

Por defecto, `cp` sigue el enlace y copia el contenido al que apunta — el
resultado es un archivo regular, no un enlace. Con `-d` (o `-a`, que lo
incluye), `cp` recrea el enlace simbólico tal cual, apuntando a la misma
ruta que el original.

### 2.7 Qué pasa si el destino ya existe

```bash
cp -i origen.txt destino-existente.txt
# cp: sobrescribir 'destino-existente.txt'? (y/n)
```

`-i` ("interactive") pregunta antes de sobrescribir. Sin `-i`, `cp`
sobrescribe en silencio si tienes permiso para hacerlo — sin aviso, sin
posibilidad de arrepentirte después del hecho.

```bash
cp -n origen.txt destino-existente.txt
# -n: nunca sobrescribe, ni pregunta; si el destino existe, simplemente lo salta
```

`-n` ("no-clobber") es la opción más segura para scripts: nunca sobrescribe
nada, nunca se detiene a esperar una respuesta interactiva que un script no
puede dar.

### 2.8 Copias dispersas y reflink: cuando copiar no duplica bytes

Dos casos especiales valen la pena conocer, aunque no cambien el comando
que escribes todos los días:

- **Archivos dispersos** (*sparse files*): un archivo puede tener "huecos"
  — rangos marcados como ceros que no ocupan espacio real en disco. `cp`
  normal puede rellenar esos huecos con ceros reales al copiar (perdiendo la
  dispersión); `cp --sparse=always` preserva el hueco en el destino.
- **`--reflink=auto`**: en sistemas de archivos con *copy-on-write* (como
  `btrfs` o `xfs` con soporte reflink), le pide al sistema de archivos una
  copia instantánea que no duplica datos hasta que alguno de los dos lados
  se modifique. En `ext4` (el filesystem típico de estos contenedores) esta
  opción simplemente no aplica y `cp` cae al comportamiento normal, sin
  error.

```bash
cp --sparse=always origen-disperso.img destino.img
cp --reflink=auto archivo-grande.iso copia.iso
```

No hace falta usarlos a diario, pero reconocerlos evita la sorpresa de "por
qué esta copia fue instantánea" (reflink) o "por qué este archivo disperso
ocupa de golpe mucho más en el destino" (sin `--sparse`).

## 3. Cómo se usa

```bash
# Clonar un arbol de carpetas completo, preservando todo
cp -a proyecto/ proyecto-respaldo/

# Copiar solo los .txt de una carpeta a otra
cp *.txt /tmp/destino/

# Copiar sin sobrescribir nada existente (seguro para scripts)
cp -n -r origen/ destino/

# Ver exactamente que se copio, archivo por archivo
cp -v -r origen/ destino/
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `cp` sin `-p`/`-a` esperando que preserve permisos y fechas | Una copia simple usa tu `umask` y la fecha actual, no los del original | Usar `-p` o `-a` explícitamente cuando los metadatos importan |
| Copiar un árbol con `-r` sin pensar en los enlaces simbólicos que contiene | Por defecto `cp` sigue los enlaces y copia el contenido destino, duplicando datos y perdiendo la relación de enlace | Usar `-a` (que incluye `-d`) cuando el árbol tiene enlaces que quieres preservar como tales |
| Correr `cp` sobre un destino existente sin `-i` ni `-n` en un script interactivo | Sobrescribe en silencio, sin posibilidad de deshacerlo | Usar `-i` en uso interactivo, `-n` en scripts no interactivos |
| Asumir que `cp carpeta otra-carpeta` copia el contenido *dentro* de `otra-carpeta` | Si `otra-carpeta` no existe, `cp -r` la crea con el nombre `otra-carpeta` y copia el contenido ahí — pero si ya existe, copia `carpeta` *dentro* de ella, un nivel más de lo esperado | Confirmar con `ls` si el destino ya existe antes de interpretar el resultado |

## 5. Trucos

- `cp -v` es el flag más subestimado al copiar árboles grandes: ver cada
  archivo mientras se copia confirma que el comando está haciendo lo
  esperado, no solo "colgado".
- `cp --backup=numbered origen destino` crea una copia de seguridad
  numerada (`destino.~1~`, `destino.~2~`...) del destino existente antes de
  sobrescribirlo, en vez de perderlo sin rastro.
- Para copiar **solo la estructura** de carpetas sin los archivos, `find
  origen -type d -exec mkdir -p destino/{} \;` es el patrón (usa `find`,
  que se profundiza recién en la Semana 09 — vale la pena como referencia
  anticipada).

## Resumen

`cp` simple copia contenido pero no metadatos; `-p` preserva permisos y
fechas; `-a` es el preset completo para clonar árboles tal cual, enlaces
incluidos. `-i`/`-n` deciden qué pasa cuando el destino ya existe — uno
pregunta, el otro nunca sobrescribe. Ninguno de estos flags es el
comportamiento por defecto: hay que pedirlos explícitamente cada vez que
los metadatos o la seguridad frente a sobrescritura importan.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — cp invocation](https://www.gnu.org/software/coreutils/manual/html_node/cp-invocation.html) — la referencia completa de todos los flags de `cp`.
- `man cp` — la misma referencia, offline.

## ✅ Checklist de Verificación

- [ ] Copiaste un árbol de carpetas completo con `-a` y confirmaste que los permisos y fechas quedaron idénticos
- [ ] Reprodujiste la diferencia entre copiar un enlace simbólico con y sin `-d`
- [ ] Usaste `-n` para confirmar que una copia no sobrescribe nada existente
- [ ] Explicaste con tus palabras cuándo `cp carpeta destino` copia *a* destino y cuándo copia *dentro* de destino
- [ ] Usaste `--backup=numbered` para confirmar que el destino anterior queda respaldado, no perdido

---

[← 01 — Crear archivos y directorios](01-crear-archivos-y-directorios.md) · [03 — Mover y renombrar →](03-mover-y-renombrar.md)
