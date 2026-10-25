# Shebang y ejecución de un script

> Un script es un archivo de texto que el kernel sabe a quién entregar. Entender
> **quién** lo ejecuta (y en qué proceso) explica la mitad de los fallos de un
> principiante: `Permission denied`, `command not found` y variables que "no se quedan".

## 🎯 Objetivos

- Escribir un script con `#!/usr/bin/env bash` y ejecutarlo de tres formas distintas
- Explicar qué hace el kernel con la primera línea y por qué `/bin/sh` no es `bash`
- Distinguir ejecutar (`./script`), interpretar (`bash script`) y cargar (`source script`)
- Diagnosticar `Permission denied`, `required file not found` y los finales de línea de Windows
- Leer el código de salida de un script y saber de dónde sale

## 1. Qué problema resuelve

Hasta la Semana 12 escribiste comandos sueltos y `toolkit.sh` ya lo usabas
como una caja negra. Un script es **la misma línea de comandos guardada en un
archivo**, para repetirla sin teclearla y sin equivocarte. Para que eso
funcione hacen falta dos cosas que la terminal te daba gratis: saber **qué
intérprete** debe leer el archivo, y que el sistema te **deje ejecutarlo**.

## 2. Cómo funciona

### 2.1 La primera línea: el shebang

```bash
#!/usr/bin/env bash
echo "hola desde $0 con $# argumentos"
```

Los dos primeros bytes `#!` (en inglés *shebang*, de *hash-bang*) son un
número mágico: cuando pides al kernel ejecutar un archivo y empieza por esos
dos bytes, **el kernel** (no la shell) lee el resto de la línea, arranca ese
programa y le pasa la ruta del script como argumento. Por eso debe ser la
**línea 1, columna 1**: un espacio o una línea en blanco antes y deja de ser un
shebang (para bash será un comentario más).

```bash
mkdir -p ~/bin && cd ~/bin
printf '#!/usr/bin/env bash\necho "hola desde $0 con $# argumentos"\n' > hola.sh
head -c 2 hola.sh; echo
# #!
```

### 2.2 `env bash` frente a `/bin/bash`

| Shebang | Qué hace | Cuándo |
|---|---|---|
| `#!/bin/bash` | Ruta fija al intérprete | Si estás seguro de dónde vive `bash` |
| `#!/usr/bin/env bash` | `env` busca `bash` en el `PATH` | **Por defecto en este bootcamp**: no asume la ruta |
| `#!/bin/sh` | El intérprete POSIX del sistema | Solo si el script es POSIX de verdad |

`/usr/bin/env` existe en las cuatro distribuciones del laboratorio, así que la
segunda forma funciona en todas.

> ⚠️ **Divergencia real**: `/bin/sh` **no es lo mismo** en todas partes. En
> Ubuntu 24.04 y Debian 12 es `dash`, una shell mínima que no sabe `[[ ]]`;
> en Rocky (RHEL) y Arch es `bash`. Comprobado en los cuatro contenedores:
> `sh -c '[[ 1 -eq 1 ]]'` falla con `[[: not found` en `ubuntu-lab` y
> `debian-lab` y funciona en `rhel-lab` y `arch-lab`. Un script con
> `#!/bin/sh` que usa `[[` "funciona en mi Fedora" y se rompe en Ubuntu.
> **Si usas características de bash, el shebang dice `bash`.**

### 2.3 El bit de ejecución

Sin el bit `x` el kernel se niega a ejecutar el archivo, aunque el contenido
sea perfecto (permisos, Semana 04):

```bash
ls -l hola.sh | cut -c1-10
# -rw-r--r--
./hola.sh; echo "codigo: $?"
# bash: ./hola.sh: Permission denied
# codigo: 126
chmod +x hola.sh
./hola.sh a b; echo "codigo: $?"
# hola desde ./hola.sh con 2 argumentos
# codigo: 0
```

`126` significa "encontré el archivo pero no puedo ejecutarlo".

### 2.4 Tres maneras de lanzar el mismo archivo

| Orden | Quién lee el archivo | ¿Necesita `x`? | ¿Usa el shebang? | ¿Proceso propio? |
|---|---|:--:|:--:|:--:|
| `./hola.sh` | el programa del shebang | sí | sí | sí |
| `bash hola.sh` | `bash`, lo pidas tú | no | no (es un comentario) | sí |
| `source hola.sh` (o `. hola.sh`) | **tu shell actual** | no | no | **no** |

La última es la que sorprende. Un script ejecutado es un **proceso hijo**: sus
variables y su `cd` mueren con él (el `fork` de la Semana 10). Un script
cargado con `source` corre **dentro** de tu shell:

```bash
printf 'mivar=desde-script\ncd /tmp\n' > efecto.sh
cd ~/bin
bash efecto.sh; echo "[${mivar:-vacia}] $PWD"
# [vacia] /root/bin
. ./efecto.sh;  echo "[${mivar:-vacia}] $PWD"
# [desde-script] /tmp
```

`source` es lo que usa tu `~/.bashrc` y lo que usarás en la Semana 17 para
cargar configuración. Un script "normal" **nunca** debe esperar cambiar el
directorio ni las variables de quien lo llama.

### 2.5 Dónde busca la shell: `./` y el `PATH`

```bash
hola.sh
# bash: hola.sh: command not found
```

Sin `/` en el nombre, bash busca solo en los directorios de `$PATH`, y el
directorio actual **no** está (a propósito: así un `ls` falso en una carpeta
ajena no se cuela en lugar del real). Dos salidas: escribir la ruta
(`./hola.sh`, `~/bin/hola.sh`) o poner el directorio en el `PATH`.

```bash
PATH="$PATH:$HOME/bin" hola.sh x
# hola desde /root/bin/hola.sh con 1 argumentos
```

Esa es la razón de que el proyecto viva en `~/bin`: queda en tu `PATH`
(Semana 17 lo fija para siempre en `~/.bashrc`).

### 2.6 El código de salida de un script

Un script sale con el código **del último comando que ejecutó** (o con el que
le pongas a `exit`). Dos scripts casi idénticos:

```bash
printf '#!/usr/bin/env bash\nfalse\necho fin\n' > a.sh
printf '#!/usr/bin/env bash\necho fin\nfalse\n' > b.sh
chmod +x a.sh b.sh
./a.sh; echo "codigo: $?"
# fin
# codigo: 0
./b.sh; echo "codigo: $?"
# fin
# codigo: 1
```

`a.sh` ejecutó un `false` y **siguió**; acabó con el `echo`, que salió bien.
Por eso hace falta `set -e` (archivo 04) y `exit` explícito: un script
`cron` que "terminó con 0" no demuestra que todo fuera bien.

## 3. Cómo se usa

Receta mínima de un script nuevo:

```bash
cd ~/bin
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' '' 'echo "hola"' > nuevo.sh
chmod +x nuevo.sh
./nuevo.sh
# hola
```

Dos opciones de `bash` para **probar sin ejecutar** o **ver qué hace**:

```bash
printf 'if true; then\necho x\n' > roto.sh
bash -n roto.sh; echo "codigo: $?"
# roto.sh: line 3: syntax error: unexpected end of file
# codigo: 2
printf 'x=5\necho $((x+1))\n' > dbg.sh
bash -x dbg.sh
# 6
# + x=5
# + echo 6
```

- `bash -n archivo` **solo comprueba la sintaxis** (no ejecuta nada): seguro
  incluso con un script peligroso.
- `bash -x archivo` imprime cada comando **ya expandido**, con `+` delante: el
  depurador de bash. La salida de `+ ...` va a `stderr`, por eso puede
  aparecer mezclada con la normal.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `#!/bin/sh` con `[[ ]]`, arrays o `local` | En Debian/Ubuntu `sh` es `dash` y falla con `[[: not found` | `#!/usr/bin/env bash` si usas bash |
| Un `chmod 777` para "que deje ejecutar" | Cualquiera puede modificar un script que luego se ejecuta con tus permisos | `chmod 755` (o `700` si es solo tuyo) |
| Guardar el script con finales de línea de Windows (CRLF) | El shebang pasa a ser `bash\r` y falla (ver 5) | `sed -i 's/\r$//' script.sh` y configurar el editor a LF |
| Esperar que un script cambie tu `cd` o tus variables | Corre en un proceso hijo | `source`, o que **imprima** el dato y lo captures con `$( )` |
| `sudo ./script.sh` por costumbre | Das `root` a todo lo que haga, incluido un bug | Pedir `sudo` solo en el comando que lo necesita, dentro del script |
| Confiar en que el script "termina con 0" | El código es el del último comando, no el de todo | `set -e` y `exit` con significado |

## 5. Trucos

- **Final de línea de Windows**: un script editado en Windows trae `\r\n`. El
  kernel busca un intérprete llamado `bash\r`, y falla con un mensaje
  engañoso:

  ```bash
  printf '#!/usr/bin/env bash\r\necho hola\r\n' > crlf.sh && chmod +x crlf.sh
  ./crlf.sh; echo "codigo: $?"
  # /usr/bin/env: 'bash\r': No such file or directory
  # /usr/bin/env: use -[v]S to pass options in shebang lines
  # codigo: 127
  sed -i 's/\r$//' crlf.sh && ./crlf.sh
  # hola
  ```

- **`required file not found`**: el mismo síntoma con un shebang directo a un
  intérprete que no existe (`#!/usr/bin/noexiste`). El `bash: ./bad.sh: cannot
  execute: required file not found` apunta al **intérprete**, no al script.
- **`env -S`**: `#!/usr/bin/env -S bash -eu` pasa **varios** argumentos al
  intérprete (un shebang normal solo admite uno). Comprobado en `ubuntu-lab`.
  Útil, pero `set -euo pipefail` dentro del archivo es más portable y se lee
  mejor.
- **`$0` y `dirname`**: `$0` es la ruta con la que **te llamaron**
  (`./p.sh`, no la ruta absoluta). `${BASH_SOURCE[0]}` es el archivo actual
  incluso con `source`; `"$(dirname "$0")"` da su carpeta, para localizar
  archivos que viajan junto al script.

## 📚 Recursos Adicionales

- `man bash`, sección *INVOCATION* y *COMMAND EXECUTION ENVIRONMENT*
- `man execve`: sección *Interpreter scripts*, donde el kernel documenta el `#!`

## ✅ Checklist de Verificación

- [ ] `head -c 2 ~/bin/hola.sh` imprime `#!`
- [ ] Sin `chmod +x`, `./hola.sh` sale con `126`; con `bash hola.sh` funciona
- [ ] `docker exec ubuntu-lab sh -c '[[ 1 -eq 1 ]]'` falla y el mismo en `rhel-lab` no
- [ ] Con `source` una variable sobrevive; con `bash script` no
- [ ] Sabes explicar por qué `./a.sh` salió con `0` habiendo ejecutado `false`

---

[← Índice de la semana](../README.md) · [Variables y expansión de parámetros →](02-variables-y-expansion-de-parametros.md)
