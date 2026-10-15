# `chown` y `chgrp`: propietario y grupo

> Los permisos (`rwx`) dicen *qué* se puede hacer. Dueño y grupo dicen *a
> quién* le aplica cada ámbito. Sin poder cambiarlos, los permisos de la
> semana son solo la mitad de la historia.

## 🎯 Objetivos

- Cambiar el dueño y el grupo de un archivo con `chown`/`chgrp`
- Explicar por qué cambiar el dueño casi siempre requiere privilegios elevados
- Usar el bit SGID en un directorio para que los archivos nuevos hereden el grupo
- Explicar de dónde salen los nombres de usuario/grupo que muestra `ls -l`

## 1. Qué problema resuelve

Los permisos `rwx` no tienen sentido sin saber a quién aplican. "Dueño" y
"grupo" son esas dos etiquetas, y `chown`/`chgrp` son las herramientas para
cambiarlas — necesarias, por ejemplo, cuando un archivo se crea con un
usuario y tiene que pasar a ser administrado por otro, o cuando una carpeta
compartida necesita que todos los archivos nuevos pertenezcan al mismo
grupo de equipo, sin que cada persona tenga que acordarse de cambiarlo a
mano.

## 2. Cómo funciona

### 2.1 `chown`: cambiar el dueño (y de paso, el grupo)

```bash
chown ana archivo.txt              # cambia solo el dueño
chown ana:desarrollo archivo.txt    # cambia dueño Y grupo en un solo comando
chown :desarrollo archivo.txt       # cambia solo el grupo (alternativa a chgrp)
```

La sintaxis `usuario:grupo` es el atajo para cambiar ambos de una vez —
equivalente a un `chown` seguido de un `chgrp`, pero en una sola operación
atómica.

### 2.2 `chgrp`: cambiar solo el grupo

```bash
chgrp desarrollo archivo.txt
```

Hace exactamente lo mismo que `chown :grupo`, con una sintaxis dedicada —
ambas formas son válidas, es cuestión de cuál prefieres para dejar más claro
qué estás cambiando.

### 2.3 Por qué `chown` casi siempre pide privilegios

`root` (el usuario por defecto de `ubuntu-lab`) puede cambiar cualquier
dueño sin restricción — para ver la restricción real hace falta un usuario
normal (el `estudiante` creado en el archivo 01 de esta semana):

```bash
touch archivo-de-estudiante.txt
chown estudiante archivo-de-estudiante.txt

su estudiante -c 'chown root archivo-de-estudiante.txt'
# chown: changing ownership of 'archivo-de-estudiante.txt': Operation not permitted
```

Cambiar el **dueño** de un archivo (no el grupo) requiere privilegios de
`root` en la mayoría de los sistemas Linux — por diseño. Si cualquier
usuario pudiera regalar la propiedad de sus archivos a otro usuario a
voluntad, se podría usar para evadir cuotas de disco (transferir archivos
grandes a otro usuario para que cuenten contra su cupo, no el tuyo). Por
eso, como usuario normal, hace falta `sudo`:

```bash
sudo chown otro-usuario archivo.txt
```

`chgrp`, en cambio, **sí** se puede usar sin privilegios elevados — pero
solo para cambiar a un grupo del que ya se es miembro. Un usuario normal no
puede asignar un archivo propio a un grupo al que no pertenece, sea cual
sea el motivo (de nuevo, `root` sí puede, sin esa restricción).

### 2.4 Cambiar propiedad recursivamente

```bash
chown -R ana:desarrollo carpeta/
```

Igual que con `chmod -R` en el archivo anterior, `-R` aplica el cambio a
todo el árbol — y acá no hay la misma distinción archivo/directorio que
vimos con permisos (dueño y grupo son el mismo concepto para ambos tipos),
así que `-R` es seguro de usar sin la salvedad anterior.

### 2.5 SGID en un directorio: herencia automática de grupo

Esto conecta con el bit especial que se explica a fondo en el archivo 05,
pero vale la pena adelantarlo acá porque es la solución real al problema de
"carpeta compartida, grupo que se olvida de poner":

```bash
mkdir /tmp/proyecto-equipo
chgrp desarrollo /tmp/proyecto-equipo
chmod g+s /tmp/proyecto-equipo     # activa SGID en el directorio

cd /tmp/proyecto-equipo
touch archivo-nuevo.txt
ls -l archivo-nuevo.txt
# el grupo es "desarrollo", automaticamente, sin que nadie lo haya pedido
```

Con SGID activo en un directorio, **todo archivo nuevo creado ahí dentro
hereda el grupo del directorio**, no el grupo principal de quien lo creó.
Es la forma correcta de garantizar que una carpeta compartida por equipo
mantenga el grupo correcto sin depender de que cada persona se acuerde de
correr `chgrp` manualmente.

### 2.6 De dónde salen los nombres: `/etc/passwd` y `/etc/group`

Cuando `ls -l` muestra `ana` como dueño, en realidad el sistema solo guarda
un número (UID) junto al archivo — `ls` traduce ese número a un nombre
consultando `/etc/passwd`. Lo mismo pasa con el grupo y `/etc/group`:

```bash
grep '^ana:' /etc/passwd
# ana:x:1001:1001:Ana Desarrolladora:/home/ana:/bin/bash
#     uid=1001  gid=1001 (grupo principal)

grep '^desarrollo:' /etc/group
# desarrollo:x:1002:ana,luis

getent passwd ana      # misma consulta, pero a traves de NSS (funciona igual con LDAP/SSSD)
getent group desarrollo
```

Esto explica por qué un UID "huérfano" (de un usuario ya borrado) se ve
como un número en `ls -l` en vez de un nombre: no hay ninguna línea en
`/etc/passwd` para traducirlo. El modelo completo de usuarios y grupos se
retoma a fondo en la Semana 11 — acá alcanza con saber que el nombre que
ves es una traducción, no el dato real que guarda el sistema de archivos.

## 3. Cómo se usa

```bash
# Transferir un archivo a otro usuario (requiere privilegios)
sudo chown nuevo-dueno archivo.txt

# Cambiar dueño y grupo juntos, en un deploy tipico
sudo chown www-data:www-data /var/www/sitio/ -R

# Verificar dueño y grupo actuales antes de cambiar nada
ls -l archivo.txt
stat -c '%U %G' archivo.txt
```

```bash
# Configurar una carpeta compartida con herencia de grupo
sudo mkdir -p /srv/equipo
sudo chgrp desarrollo /srv/equipo
sudo chmod 2775 /srv/equipo    # el 2 inicial es SGID, se explica en el archivo 05
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `sudo chown` como reflejo para "arreglar" cualquier error de permisos | Puede transferir un archivo a un dueño incorrecto, perdiendo de vista quién debería ser el dueño real | Confirmar primero con `ls -l`/`stat` quién es el dueño actual y quién debería ser, antes de cambiar nada |
| Configurar una carpeta compartida sin SGID y esperar que el grupo se mantenga solo | Cada archivo nuevo hereda el grupo *principal* de quien lo crea, no el del directorio | Activar `chmod g+s` en el directorio compartido desde el principio |
| Intentar `chgrp` a un grupo del que no eres miembro | Falla con "Operation not permitted", y no hay forma de evitarlo sin privilegios | Confirmar con `groups` que perteneces al grupo destino antes de intentar el cambio |
| Olvidar que SGID en un directorio no cambia el grupo de los archivos ya existentes | SGID solo afecta a lo que se crea *después* de activarlo | Correr `chgrp -R` una vez para alinear lo existente, y recién después confiar en SGID para lo nuevo |
| Usar `chown -R` sin confirmar que quieres tocar todo el árbol | Puede cambiar la propiedad de archivos que debían quedar con otro dueño (ej. archivos de configuración del sistema dentro de una carpeta de usuario) | Revisar con `find carpeta -maxdepth 1` qué hay antes de aplicar `-R` a ciegas |

## 5. Trucos

- `chown --reference=otro-archivo archivo` copia dueño y grupo exactos de
  otro archivo, igual que `chmod --reference` copia permisos.
- `find carpeta -user usuario-viejo` encuentra todos los archivos que
  todavía pertenecen a un usuario antes de hacer un `chown -R` masivo —
  confirmar el alcance antes de aplicar el cambio (adelanto de `find`,
  Semana 09).
- `ls -ln` (con `n`, "numeric") muestra los UID/GID numéricos en vez de los
  nombres — útil para diagnosticar un usuario borrado que dejó archivos
  "huérfanos" (el nombre ya no existe, pero el número sigue ahí).
- `chown usuario: archivo` (con los dos puntos al final, sin nada después)
  cambia el dueño y además fija el grupo al grupo principal de ese usuario
  — un atajo cuando el objetivo es "que quede todo a nombre de esta
  persona", sin especificar grupo aparte.

## Resumen

`chown` cambia el dueño (y opcionalmente el grupo, con `usuario:grupo`);
`chgrp` cambia solo el grupo. Cambiar dueño requiere privilegios elevados
por diseño (evita evadir cuotas de disco); cambiar grupo solo requiere
pertenecer al grupo destino. SGID en un directorio resuelve el problema
real de carpetas compartidas: hace que los archivos nuevos hereden el
grupo del directorio, no el del usuario que los crea.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — chown invocation](https://www.gnu.org/software/coreutils/manual/html_node/chown-invocation.html) — la referencia completa de `chown`.
- `man chown`, `man chgrp` — las mismas referencias, offline.
- `man 5 passwd`, `man 5 group` — el formato exacto de `/etc/passwd` y `/etc/group`, para quien quiera el detalle completo de cada campo.

## ✅ Checklist de Verificación

- [ ] Cambiaste dueño y grupo de un archivo en un solo comando con `chown usuario:grupo`
- [ ] Confirmaste que `chown` sin privilegios falla, y que `sudo chown` sí funciona
- [ ] Configuraste una carpeta con SGID y confirmaste que los archivos nuevos heredan el grupo
- [ ] Explicaste por qué `chgrp` no requiere privilegios elevados mientras `chown` casi siempre sí
- [ ] Encontraste el UID y GID numéricos de tu propio usuario en `/etc/passwd`/`/etc/group`

---

[← 02 — chmod: octal y simbólico](02-chmod-octal-y-simbolico.md) · [04 — umask →](04-umask.md)
