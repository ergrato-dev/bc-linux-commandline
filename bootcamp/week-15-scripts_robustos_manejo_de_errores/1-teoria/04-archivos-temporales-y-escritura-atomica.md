# Archivos temporales y escritura atómica

> Casi todo script serio necesita un archivo o un directorio de trabajo. Hacerlo
> mal produce basura en `/tmp`, **agujeros de seguridad** y archivos a medio
> escribir que otro programa lee como si estuvieran completos.

## 🎯 Objetivos

- Crear temporales con `mktemp` y explicar por qué un nombre predecible (`/tmp/x.$$`) es un riesgo
- Limpiarlos con `trap ... EXIT`, protegiendo el `rm -rf` con `${var:?}`
- Escribir un archivo de forma **atómica**: temporal en el mismo directorio y `mv`
- Usar `noclobber` y `umask` para evitar pisar archivos o dejarlos legibles de más
- Distinguir cuándo un temporal es un directorio (`mktemp -d`)

## 1. Qué problema resuelve

Dos problemas distintos con la misma solución:

1. **Basura y colisiones.** Dos ejecuciones simultáneas de `/tmp/resultado.txt`
   se pisan; un script que muere deja su temporal para siempre.
2. **Lectores que ven a medias.** Si un script reescribe `config.txt` con `>`,
   durante unos instantes el archivo está **vacío o a medias**; otro proceso que
   lo lea entonces ve datos rotos. El objetivo es que el archivo cambie de un
   estado completo a otro completo, sin estados intermedios.

## 2. Cómo funciona

### 2.1 `mktemp`

```bash
f=$(mktemp); ls -l "$f" | cut -c1-10
# -rw-------
d=$(mktemp -d); ls -ld "$d" | cut -c1-10
# drwx------
```

`mktemp` crea el archivo (o directorio con `-d`) **ya**, con un nombre
aleatorio y permisos `600`/`700` (solo tu usuario), y te imprime la ruta. La
creación es atómica: si el nombre ya existe, prueba otro. Variantes útiles:

| Orden | Resultado |
|---|---|
| `mktemp` | `/tmp/tmp.XXXXXXXXXX` (diez caracteres aleatorios) |
| `mktemp /tmp/miapp.XXXXXX` | Plantilla propia: las `X` finales se sustituyen (mínimo **3**; con menos da error) |
| `mktemp -d` | Un **directorio** temporal |
| `mktemp -p DIR` | En `DIR` en lugar de `/tmp` |
| `mktemp -t miapp.XXXXXX` | En `$TMPDIR` (o `/tmp`) con ese prefijo |
| `mktemp --suffix=.txt /tmp/z.XXXXXX` | Con extensión final (`/tmp/z.AbC123.txt`) |

`TMPDIR=/var/tmp mktemp` respeta la variable de entorno `TMPDIR`: es como
`guard` elige el directorio.

> **Evita `mktemp -u`** (modo "seco": solo imprime un nombre sin crearlo):
> deja el hueco que `mktemp` existe para cerrar.

### 2.2 Por qué no `/tmp/algo.$$`

`$$` es el PID, y los PID son **predecibles**. En un `/tmp` compartido, otro
usuario puede **crear de antemano** un enlace simbólico con el nombre que tu
script va a usar, y tu `>` escribirá **a través del enlace**, sobre el
archivo al que apunte:

```bash
cd /tmp && rm -rf tt && mkdir tt && cd tt
echo "datos importantes" > victima
ln -s /tmp/tt/victima predecible.1234          # el atacante prepara el enlace
echo "malicioso" > predecible.1234             # tu script cree que crea un archivo
cat victima
# malicioso
```

`mktemp` evita esto: crea el archivo con la opción "falla si ya existe"
(`O_EXCL`), así que **nunca** sigue un enlace puesto de antemano. (En una
máquina de un solo usuario el riesgo es pequeño, pero el hábito no cuesta
nada y los scripts de sistema se ejecutan como `root`.)

### 2.3 Limpieza con `trap EXIT`

```bash
cat > cd.sh <<'EOS'
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf -- "${work:?}"' EXIT
touch "$work/a" "$work/b"
ls "$work" | wc -l
exit 3
EOS
bash cd.sh; echo "codigo: $?"
# 2
# codigo: 3
```

El directorio se borra **aunque el script salga con error** (`exit 3`). Dos
detalles de seguridad:

- **`rm -rf -- "${work:?}"`**: si `work` estuviera vacía, `rm -rf "$work/"`
  sería `rm -rf /`. `${work:?}` **aborta** antes de ejecutar el `rm` si la
  variable no existe o está vacía. (Prueba la idea sin riesgo con `echo`:
  `dir=""; echo rm -rf "$dir/"` imprime `rm -rf /`, y con `"${dir:?}/"`
  aborta con `parameter null or not set`.)
- **`--`** por si el nombre empezara por `-`.

> ⚠️ **Antes de un `rm -rf`**: imprímelo primero con `echo` y comprueba la
> ruta. El respaldo es **no borrar nada que no hayas creado tú con
> `mktemp`**: por eso se borra solo `$work`, nunca una ruta calculada.

### 2.4 Escritura atómica: temporal + `mv`

```bash
cat > aw.sh <<'EOS'
set -euo pipefail
destino=$1
tmp=$(mktemp "${destino}.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
printf 'linea1\nlinea2\n' > "$tmp"
chmod 644 "$tmp"
mv -- "$tmp" "$destino"
EOS
bash aw.sh salida.txt; ls -l salida.txt | cut -c1-10
# -rw-r--r--
```

El patrón: **escribir todo en un temporal y, al final, `mv` al destino**. Un
`mv` dentro del mismo sistema de archivos es un `rename()` del kernel:
**atómico**. El lector ve el archivo viejo completo o el nuevo completo, nunca
a medias. Tres condiciones:

1. **El temporal debe estar en el mismo sistema de archivos que el
   destino**, por eso la plantilla es `"${destino}.XXXXXX"` y no el `/tmp` por
   defecto. Entre sistemas distintos, `mv` copia y borra (no atómico):

   ```bash
   stat -c '%d %n' /tmp /dev/shm
   # 105 /tmp
   # 155 /dev/shm
   ```

   (`%d` es el identificador del dispositivo; números distintos son sistemas
   de archivos distintos.)
2. **Fija los permisos antes del `mv`**: `mktemp` crea con `600`, y si el
   archivo final debe ser legible, `chmod 644` antes.
3. Tras el `mv` el temporal **ya no existe**, y el `rm -f` del trap no hace
   nada (`-f` no se queja si no está).

### 2.5 `noclobber` y `umask`

```bash
echo uno > nc; set -o noclobber
echo dos > nc
# bash: nc: cannot overwrite existing file
echo dos >| nc; cat nc
# dos
set +o noclobber
```

Con `noclobber`, `>` **se niega a pisar** un archivo existente; `>|` lo
fuerza expresamente. Es una red de seguridad barata para un script que
escribe informes.

```bash
(umask 077; touch u1; ls -l u1 | cut -c1-10)
# -rw-------
(umask 022; touch u2; ls -l u2 | cut -c1-10)
# -rw-r--r--
```

`umask` define los permisos que **se quitan** a los archivos nuevos
(Semana 04). Un script que escribe secretos o informes privados abre con
`umask 077` (entre paréntesis o al inicio del script).

## 3. Cómo se usa

Resumen de decisiones:

| Necesitas | Haz |
|---|---|
| Un archivo de trabajo | `tmp=$(mktemp)` + `trap 'rm -f -- "$tmp"' EXIT` |
| Un directorio de trabajo | `work=$(mktemp -d)` + `trap 'rm -rf -- "${work:?}"' EXIT` |
| Publicar un resultado sin que se vea a medias | Temporal **en el directorio del destino** + `mv` |
| No pisar un informe previo por accidente | `set -o noclobber` y `>|` donde sí quieras sobrescribir |
| Secretos o informes privados | `umask 077` |

`guard` esta semana usa justo el primer caso: un temporal para capturar la
salida del comando, borrado por el `trap EXIT`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `/tmp/resultado.txt` o `/tmp/x.$$` | Colisiones y enlaces simbólicos preparados | `mktemp` |
| `mktemp -u` | Solo da un nombre: otro puede crearlo antes | `mktemp` sin `-u` |
| Temporal sin `trap EXIT` | Queda en `/tmp` si el script falla | `trap ... EXIT` |
| `rm -rf "$dir/"` con `$dir` sin validar | Con `$dir` vacío es `rm -rf /` | `rm -rf -- "${dir:?}"` y solo sobre lo que creaste |
| Reescribir con `> destino` mientras otros lo leen | Lectores ven el archivo vacío o a medias | Temporal + `mv` |
| El temporal en `/tmp` y el destino en otro disco | `mv` deja de ser atómico | `mktemp "${destino}.XXXXXX"` |
| Olvidar los permisos del archivo final | `mktemp` lo crea `600` | `chmod` antes del `mv` |
| Datos sensibles en archivos temporales con permisos de `umask 022` | Otros usuarios los leen | `umask 077` o `mktemp` (ya es `600`) |

## 5. Trucos

- **`mktemp -d` + `cd`** crea un directorio de trabajo aislado: `cd "$work"` y
  todo lo que el script haga en rutas relativas queda ahí y se borra solo.
- **`install -m 644 "$tmp" "$destino"`** copia con permisos y propietario
  concretos en un solo paso (menos limpio que `chmod` + `mv`, pero sirve
  entre sistemas de archivos).
- **`sync`** fuerza la escritura a disco: solo hace falta si te importa
  sobrevivir a un corte de luz; para la atomicidad frente a otros procesos,
  `mv` basta.
- **`ls /tmp | grep '^tmp\.'`** es la forma rápida de ver qué temporales se
  están quedando en una máquina: si ves muchos, algún script no limpia.

## 📚 Recursos Adicionales

- `man mktemp` y `man 3 mkstemp` (la función de C que `mktemp` usa por debajo)
- [BashFAQ 062 — cómo crear archivos temporales con seguridad](https://mywiki.wooledge.org/BashFAQ/062)

## ✅ Checklist de Verificación

- [ ] `mktemp` crea un archivo `-rw-------` y `mktemp -d`, un directorio `drwx------`
- [ ] Reproduces la escritura a través de un enlace con un nombre predecible y explicas por qué `mktemp` lo evita
- [ ] `cd.sh` borra su directorio aunque salga con `exit 3`
- [ ] `echo rm -rf "${dir:?}/"` con `dir=""` aborta en lugar de imprimir `rm -rf /`
- [ ] `aw.sh` deja `salida.txt` sin ningún temporal al lado
- [ ] `noclobber` impide `>` sobre un archivo existente y `>|` lo permite

---

[← `trap`: señales y limpieza](03-trap-senales-y-limpieza.md) · [Registro y depuración →](05-registro-y-depuracion.md)
