# Variables de entorno y `PATH`

> Una variable de shell vive en tu shell. Una variable de **entorno** viaja a cada proceso que lances.
> Y el `PATH` es la variable de entorno que decide qué programa se ejecuta cuando escribes un nombre.

## 🎯 Objetivos

- Distinguir una variable de shell de una de entorno y explicar qué hace `export`
- Fijar una variable solo para un comando (`VAR=valor comando`) y quitarla (`env -u`, `unset`)
- Leer el `PATH` y predecir **cuál** de dos programas con el mismo nombre se ejecuta
- Explicar la caché de `hash` y cuándo vaciarla
- Añadir un directorio al `PATH` **sin duplicarlo**, y saber en qué archivo
- Decir qué es `/etc/environment` y por qué no es un script

## 1. Qué problema resuelve

Dos síntomas del mismo desconocimiento:

- Defines `EDITOR=nano` y `git commit` sigue abriendo `vim`. La variable existe
  en tu shell, pero **nadie más la ve**.
- Instalas una herramienta en `~/bin`, la lanzas y el sistema ejecuta **otra**
  con el mismo nombre. O dice `command not found` aunque esté ahí.

Ambos se resuelven entendiendo qué heredan los procesos hijos y cómo busca bash
un ejecutable.

## 2. Cómo funciona

### 2.1 Variable de shell frente a variable de entorno

Una variable normal solo existe en la shell que la creó. Un proceso hijo
(otra `bash`, un script, `git`) arranca con **una copia** del entorno, y el
entorno solo contiene las variables **exportadas**:

```bash
MIVAR=hola
bash -c 'echo "hijo: [${MIVAR:-vacio}]"'
# hijo: [vacio]
export MIVAR
bash -c 'echo "hijo: [${MIVAR:-vacio}]"'
# hijo: [hola]
```

Es una **copia**, no un enlace: lo que el hijo cambie no vuelve al padre.

```bash
bash -c 'MIVAR=cambiado; echo "hijo: $MIVAR"'
# hijo: cambiado
echo "padre: $MIVAR"
# padre: hola
```

Cuatro formas de ver qué hay, según lo que preguntes:

```bash
printenv MIVAR          # solo el valor, y solo si está exportada
# hola
env | grep '^MIVAR='    # el entorno que heredaría un hijo
# MIVAR=hola
export -p | grep MIVAR  # las exportadas, con el formato de declare
# declare -x MIVAR="hola"
declare -p MIVAR        # la variable, con todos sus atributos
# declare -x MIVAR="hola"
```

El `-x` de `declare -x` es «exportada». Para deshacer:

```bash
export -n MIVAR         # deja de exportarla, pero conserva el valor
bash -c 'echo "hijo: [${MIVAR:-vacio}]"'
# hijo: [vacio]
echo "padre: $MIVAR"
# padre: hola
unset MIVAR             # la borra del todo
echo "[${MIVAR:-vacio}]"
# [vacio]
```

### 2.2 Solo para un comando

Poner la asignación **delante** de un comando la exporta únicamente a ese
comando:

```bash
EDITOR=nano bash -c 'echo "dentro: $EDITOR"'
# dentro: nano
echo "fuera: [${EDITOR:-vacio}]"
# fuera: [vacio]
```

Para quitarla de un solo comando, `env -u`:

```bash
env -u HOME bash -c 'echo "[${HOME:-sin-HOME}]"'
# [sin-HOME]
```

### 2.3 Cómo busca bash un comando

Cuando escribes `hola`, bash lo busca en este orden: alias, función, orden
interna, y después **cada directorio de `$PATH`, de izquierda a derecha**. Gana
el primero que lo tenga:

```bash
echo "$PATH" | tr ':' '\n'
# /usr/local/sbin
# /usr/local/bin
# /usr/sbin
# /usr/bin
# /sbin
# /bin
```

Dos directorios con un `hola` distinto. El **orden** decide:

```bash
mkdir -p /tmp/p17a /tmp/p17b
printf '#!/bin/sh\necho desde-a\n' > /tmp/p17a/hola
printf '#!/bin/sh\necho desde-b\n' > /tmp/p17b/hola
chmod +x /tmp/p17a/hola /tmp/p17b/hola
PATH=/tmp/p17a:/tmp/p17b:$PATH hola
# desde-a
PATH=/tmp/p17b:/tmp/p17a:$PATH hola
# desde-b
```

`type -a` los enseña **todos**, en el orden en que se probarían:

```bash
PATH=/tmp/p17a:/tmp/p17b:$PATH bash -c 'type -a hola'
# hola is /tmp/p17a/hola
# hola is /tmp/p17b/hola
```

Por eso `~/bin` se pone **delante**: para que tu versión gane a la del sistema.
Y por eso es un riesgo poner un directorio escribible por otros delante:
cualquiera podría colocar ahí un `ls` falso.

**Una entrada vacía en el `PATH` significa «el directorio actual»**. Un `PATH`
que empieza por `:`, termina en `:` o contiene `::` (o un `.`) ejecuta lo que
haya en la carpeta donde estés:

```bash
cd /tmp/p17a && PATH=":$PATH" hola
# desde-a
cd /
```

Es la forma clásica de que alguien te haga ejecutar un `ls` suyo con solo dejar
un archivo en una carpeta. **Nunca** lo dejes así.

### 2.4 La caché de `hash`

Buscar en cada directorio de `$PATH` cada vez es lento, así que bash **recuerda**
dónde encontró cada comando. Si luego instalas uno mejor delante, bash sigue
usando el viejo hasta que lo olvide:

```bash
mkdir -p /tmp/q1 /tmp/q2
printf '#!/bin/sh\necho viejo\n' > /tmp/q2/hola && chmod +x /tmp/q2/hola
cat > /tmp/h.sh <<'EOF'
PATH=/tmp/q1:/tmp/q2:$PATH
hola
printf '#!/bin/sh\necho nuevo\n' > /tmp/q1/hola; chmod +x /tmp/q1/hola
hola
hash -r
hola
EOF
bash /tmp/h.sh
# viejo
# viejo
# nuevo
```

La segunda llamada sigue dando `viejo`: bash tenía guardada la ruta de
`/tmp/q2/hola`. `hash -r` vacía la caché y la tercera ya ve el nuevo. La caché
también se vacía sola cuando **reasignas `PATH`**.

El síntoma típico: «acabo de instalar la versión nueva y sigue saliendo la vieja».
La respuesta es `hash -r` (o abrir otra shell).

### 2.5 Añadir al `PATH` sin duplicar

`PATH="$HOME/bin:$PATH"` en un archivo que se lee varias veces (recargas con
`source`, shells anidadas) acumula copias: el `PATH` crece y `type -a` repite
líneas. La guarda correcta comprueba antes:

```bash
anadir() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
PATH=/usr/bin:/bin; anadir /opt/x; anadir /opt/x; anadir /opt/y
echo "$PATH"
# /opt/y:/opt/x:/usr/bin:/bin
```

Rodear con `:` por los dos lados permite que la primera y la última entrada
también casen. Es el patrón estándar de POSIX: no necesita `bash`.

### 2.6 Dónde se fija el `PATH`

En `~/.profile` (**login**; ver [archivo 01](01-como-arranca-bash.md)). El de
Ubuntu ya trae dos bloques que añaden `~/bin` y `~/.local/bin` **si existen en
el momento de entrar**:

```bash
rm -rf /tmp/h17b && mkdir /tmp/h17b && cp /etc/skel/.profile /tmp/h17b/.profile
env -i HOME=/tmp/h17b PATH=/usr/bin:/bin bash -lc 'echo $PATH'
# /usr/bin:/bin
mkdir -p /tmp/h17b/bin /tmp/h17b/.local/bin
env -i HOME=/tmp/h17b PATH=/usr/bin:/bin bash -lc 'echo $PATH'
# /tmp/h17b/.local/bin:/tmp/h17b/bin:/usr/bin:/bin
```

La trampa: creas `~/bin` **después** de entrar y no aparece en tu `PATH` hasta el
siguiente login. La solución inmediata, `source ~/.profile` (o una shell de login
nueva), y no hace falta tocar nada más.

### 2.7 `/etc/environment`: no es un script

`/etc/environment` es una lista de `CLAVE=valor` que lee **PAM** (`pam_env`) al
abrir sesión, no bash:

```bash
cat /etc/environment
# PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
```

Por eso no admite `export`, ni `$VAR`, ni `$(comandos)`: lo que escribas se toma
**literal**. Sirve para variables de todo el sistema que también necesite algo que
no es una shell; para tu usuario, `~/.profile`.

## 3. Cómo se usa

### 3.1 Qué variables conviene fijar

| Variable | Para qué | Dónde |
|---|---|---|
| `PATH` | Dónde buscar programas | `~/.profile` |
| `EDITOR`, `VISUAL` | El editor que usan `git`, `crontab -e`, `sudoedit` | `~/.profile` |
| `PAGER` | Cómo se paginan `man` y `git log` (`less`) | `~/.profile` |
| `LANG`, `LC_*` | Idioma y ordenación de `sort` y `ls` | `~/.profile` o el sistema |
| `XDG_CONFIG_HOME` | Dónde buscan configuración las herramientas modernas (por defecto `~/.config`) | normalmente sin tocar |

### 3.2 Probar un cambio sin arriesgarte

Antes de editar `~/.profile`, comprueba en un entorno **vacío** que arranca
bien: `env -i HOME=$HOME bash -lc 'echo $PATH'`. Si falla, sigues dentro de tu
sesión y puedes corregirlo.

### 3.3 Divergencia de distro

El mecanismo es idéntico; cambia **quién añade `~/.local/bin`** por ti:

| | Ubuntu/Debian | RHEL/Fedora | Arch |
|---|---|---|---|
| `~/bin` y `~/.local/bin` en el `PATH` | los añade `~/.profile` (**login**), si el directorio existe | los añade `~/.bashrc` del esqueleto, con una guarda para no duplicar | **nadie**: lo añades tú |
| `PATH` global | `/etc/environment` (PAM) | `/etc/profile`, con una función que no duplica | `/etc/profile`, con una función que no duplica |

Fíjate en que RHEL y Arch resuelven la duplicación **igual que 2.5**: con una
función que comprueba `case ":$PATH:"` antes de añadir. Es el idioma estándar.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `export PATH=$PATH:~/bin` en `.bashrc` | Cada `source` o shell anidada duplica la entrada | La guarda de 2.5, en `~/.profile` |
| `PATH=` con `.` o con `:` vacío | Ejecutas lo que haya en el directorio actual | Rutas explícitas, nunca el directorio actual |
| Poner `~/bin` **detrás** y esperar que gane | Gana el del sistema | Delante |
| `sudo` esperando tu `PATH` personal | En una configuración por defecto `sudo` fija su propio `PATH` (`secure_path`) y no ve `~/bin` | Ruta absoluta con `sudo` |
| Meter `export` o `$VAR` en `/etc/environment` | No lo interpreta nadie: se toma literal | Un script en `/etc/profile.d/` |
| Guardar un secreto en una variable del `.bashrc` | Todo hijo lo hereda y `ps eww` lo puede enseñar | Un archivo `600` que el script lea |

## 5. Trucos

- **`env -i`** (entorno vacío) y **`env -u VAR`** reproducen un fallo que solo
  ocurre en otro entorno.
- **`command -v`** da solo el primer resultado y es lo que usan los scripts;
  `type -a` enseña todos.
- **`hash -t nombre`** dice qué ruta tiene bash en la cabeza: útil cuando
  «sigue saliendo la versión vieja».

## 📚 Recursos Adicionales

- `man bash`, secciones **ENVIRONMENT** y **Shell Variables**
- `help export`, `help hash`, `help unset` (internas: `help`, no `man`)

## ✅ Checklist de Verificación

- [ ] Muestras que una variable sin `export` no llega a un hijo y con `export` sí
- [ ] Demuestras que el hijo cambia su copia y el padre no se entera
- [ ] Usas `VAR=valor comando` y `env -u` para una variable solo en un comando
- [ ] Predices cuál de dos `hola` se ejecuta y lo compruebas con `type -a`
- [ ] Provocas la caché de `hash` y la limpias con `hash -r`
- [ ] Añades un directorio al `PATH` dos veces y solo aparece una
- [ ] Explicas por qué `/etc/environment` no admite `export`

---

[← Cómo arranca bash](01-como-arranca-bash.md) · [Alias y funciones →](03-alias-y-funciones.md)
