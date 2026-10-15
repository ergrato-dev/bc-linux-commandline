# Crear archivos y directorios

> `touch` y `mkdir` parecen triviales hasta que necesitas crear una
> estructura de veinte carpetas de una sola vez, o entender por qué `touch`
> no "crea contenido" aunque cree el archivo.

## 🎯 Objetivos

- Crear archivos vacíos y actualizar sus fechas con `touch`
- Crear directorios, incluidos árboles completos, con `mkdir -p`
- Explicar qué significa realmente "crear un archivo" en Linux

## 1. Qué problema resuelve

Antes de copiar, mover o borrar nada, hace falta poder crear la estructura
de prueba sobre la que practicar sin miedo — y crear esa estructura a mano,
carpeta por carpeta, es lento y propenso a errores. `touch` y `mkdir -p`
son las dos herramientas mínimas para armar cualquier escenario de prueba en
segundos, antes de tocar algo real.

## 2. Cómo funciona

### 2.1 `touch`: crear un archivo vacío o actualizar su fecha

```bash
touch archivo.txt
ls -l archivo.txt
# -rw-r--r-- 1 root root 0 ene  1 10:00 archivo.txt
```

El tamaño es **0 bytes** — `touch` no escribe contenido, solo garantiza que
el archivo exista. Si el archivo **ya existe**, `touch` no lo vacía ni lo
toca en contenido: solo actualiza su fecha de modificación a "ahora".

```bash
echo "contenido real" > archivo.txt
touch archivo.txt
cat archivo.txt
# contenido real          (sigue intacto)

ls -l --time-style=long-iso archivo.txt
# la fecha cambio a la hora actual, el contenido no
```

Este es el uso más común de `touch` en la práctica real: "renovar" la fecha
de un archivo sin tocar su contenido — por ejemplo, para que una
herramienta de compilación lo considere "más nuevo" y lo vuelva a procesar.

### 2.2 `mkdir`: crear un directorio

```bash
mkdir proyecto
ls -ld proyecto
# drwxr-xr-x 2 root root 4096 ene  1 10:00 proyecto
```

Sin flags, `mkdir` falla si el directorio padre no existe:

```bash
mkdir proyecto/src/componentes
# mkdir: no se puede crear el directorio «proyecto/src/componentes»: No existe el archivo o directorio
```

### 2.3 `mkdir -p`: crear el árbol completo de una vez

```bash
mkdir -p proyecto/src/componentes
```

`-p` ("parents") crea cualquier directorio intermedio que falte, sin
quejarse. También es **idempotente**: si la carpeta ya existe, `mkdir -p` no
falla (a diferencia de `mkdir` sin `-p`, que sí tira error si ya existe).

```bash
mkdir proyecto          # falla si "proyecto" ya existe
mkdir -p proyecto        # no falla, exista o no
```

Esta diferencia importa mucho en scripts: un script que corre `mkdir -p`
puede ejecutarse varias veces sin romperse; uno con `mkdir` a secas falla en
la segunda corrida.

### 2.4 Combinando `mkdir -p` con expansión de llaves

Lo visto en la Semana 02 (expansión de llaves) y `mkdir -p` se combinan para
crear estructuras completas en un solo comando:

```bash
mkdir -p proyecto/{src,docs,tests,config}
ls proyecto
# config  docs  src  tests
```

### 2.5 Qué significa "crear un archivo", en términos del sistema

Crear un archivo (con `touch`, con un editor, con `cp`) implica dos cosas:
reservar un **inodo** (la estructura que guarda metadatos y apunta al
contenido, vista en la Semana 02) y agregar una **entrada de directorio**
que asocia un nombre con ese inodo. `touch` hace ambas cosas con contenido
vacío; un editor que guarda texto hace lo mismo pero además escribe datos.

### 2.6 Los permisos con los que nace un archivo nuevo

Cuando `touch` o `mkdir` crean algo nuevo, los permisos iniciales no son
arbitrarios: dependen de tu `umask` (una máscara que resta permisos al
máximo por defecto). No hace falta entenderla a fondo todavía — se explica
en detalle en la Semana 04 — pero conviene saber que existe, porque explica
por qué un archivo recién creado con `touch` nunca nace con permiso de
ejecución, aunque un directorio recién creado con `mkdir` sí nace navegable:

```bash
touch nuevo.txt && ls -l nuevo.txt
# -rw-r--r--   <- nunca trae x por defecto, sea cual sea tu umask

mkdir nuevo-dir && ls -ld nuevo-dir
# drwxr-xr-x   <- los directorios si nacen con x (necesario para poder "entrar")
```

### 2.7 `install -d`: crear directorios con permisos exactos en un paso

`mkdir -m` existe para fijar permisos al crear, pero `install -d` es la
herramienta pensada específicamente para esto (viene de empaquetado de
software, donde crear carpetas con permisos exactos es constante):

```bash
install -d -m 750 /tmp/carpeta-restringida
ls -ld /tmp/carpeta-restringida
# drwxr-x--- ...
```

La diferencia con `mkdir -m` es sutil (ambos funcionan para este caso
simple) pero `install` además puede crear la cadena de directorios padres
con el mismo permiso exacto en cada nivel, cosa que `mkdir -p -m` no
garantiza de forma consistente en todas las implementaciones.

## 3. Cómo se usa

```bash
# Crear varios archivos vacios de una
touch archivo1.txt archivo2.txt archivo3.txt

# Crear un arbol de proyecto completo
mkdir -p mi-proyecto/{src,docs,tests}
touch mi-proyecto/README.md mi-proyecto/src/main.sh

# Verificar la fecha exacta de creacion/modificacion mas reciente
stat archivo1.txt | grep Modify
```

```bash
# touch con fecha especifica, no "ahora"
touch -d "2026-01-01 10:00" archivo-viejo.txt
touch -t 202601011000 archivo-viejo-alt.txt    # formato alternativo
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `mkdir` sin `-p` en un script que puede correr más de una vez | La segunda corrida falla porque la carpeta ya existe, cortando el script si tiene `set -e` | Usar siempre `mkdir -p` en scripts, salvo que de verdad necesites que falle si ya existe |
| Pensar que `touch archivo-existente` "limpia" o "resetea" su contenido | Solo actualiza la fecha; el contenido queda intacto | Usar `> archivo` (redirección vacía) si de verdad quieres vaciarlo — con cuidado, es irreversible |
| Crear estructuras de carpetas a mano, una por una | Lento y propenso a errores de tipeo que generan carpetas con nombres parecidos pero distintos | Usar `mkdir -p` con expansión de llaves para crear el árbol completo de una |
| Asumir que `touch archivo-que-no-existe-en-ruta-sin-crear` crea también las carpetas intermedias | `touch` crea el archivo, no la ruta — falla si el directorio padre no existe | Asegurar la carpeta primero con `mkdir -p "$(dirname ruta)"`, recién después `touch` |

## 5. Trucos

- `mkdir -pv` (con `-v`, verbose) imprime cada carpeta que efectivamente
  creó — útil para confirmar qué partes del árbol ya existían.
- `touch -r otro-archivo nuevo-archivo` copia la fecha de modificación de
  `otro-archivo` a `nuevo-archivo`, sin tener que calcular ni escribir la
  fecha a mano.
- `mkdir -p "$(dirname ruta/completa/archivo.txt)"` es el patrón estándar en
  scripts para garantizar que la carpeta destino de un archivo exista antes
  de escribirlo ahí.
- `touch {a,b,c}.txt` combina expansión de llaves con `touch` para crear
  varios archivos relacionados en un solo comando, sin repetir el nombre
  base.

## Resumen

`touch` garantiza que un archivo exista (o renueva su fecha, nunca su
contenido); `mkdir -p` crea árboles completos de una vez y no falla si ya
existen. Ambos son los bloques mínimos para armar cualquier escenario de
prueba antes de practicar operaciones más riesgosas como copiar, mover o
borrar — que es exactamente lo que ven el resto de los archivos de esta
semana.

## 📚 Recursos Adicionales

- `man touch`, `man mkdir` — referencia completa de ambos comandos.
- [GNU Coreutils Manual — touch invocation](https://www.gnu.org/software/coreutils/manual/html_node/touch-invocation.html) — todos los formatos de fecha que acepta `-d`.
- [GNU Coreutils Manual — mkdir invocation](https://www.gnu.org/software/coreutils/manual/html_node/mkdir-invocation.html) — incluye `--mode` para fijar permisos en el mismo comando de creación.

## ✅ Checklist de Verificación

- [ ] Creaste un archivo con `touch` y confirmaste que pesa 0 bytes
- [ ] Confirmaste que `touch` sobre un archivo existente no borra su contenido
- [ ] Creaste un árbol de carpetas completo con `mkdir -p` y expansión de llaves en un solo comando
- [ ] Reprodujiste por qué `mkdir` sin `-p` falla en una segunda corrida y `mkdir -p` no
- [ ] Comparaste los permisos por defecto de un archivo nuevo contra los de un directorio nuevo y notaste la diferencia del bit `x`

---

[← Semana 03](../README.md) · [02 — Copiar archivos y directorios →](02-copiar-archivos-y-directorios.md)
