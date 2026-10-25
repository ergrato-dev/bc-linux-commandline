# El entorno mínimo de `cron`

> «En mi terminal funciona» es la frase más repetida de la automatización.
> `cron` no lanza tu shell, no lee tu `.bashrc` y no tiene terminal:
> arranca tu comando en un entorno casi vacío. Conócelo antes de depurar a
> ciegas.

## 🎯 Objetivos

- Listar las variables que `cron` fija y las que **no** fija
- Explicar por qué un comando que funciona en tu terminal puede fallar en `cron` con `not found`
- Fijar `SHELL`, `PATH` y `MAILTO` en el propio `crontab`, y saber que ahí no se expande `$VAR`
- Emular el entorno de `cron` desde tu terminal con `env -i`
- Decir adónde va la salida de una tarea cuando no la rediriges

## 1. Qué problema resuelve

Casi todo script programado falla la **primera vez** por una de cuatro razones:

1. El comando no está en el `PATH` de `cron`.
2. El script usa algo de `bash` y `cron` lo ejecutó con `sh`.
3. Depende del directorio actual o de una variable de tu sesión.
4. Falló y **su error se perdió**, así que ni te enteraste.

Las cuatro desaparecen si sabes con qué se encuentra tu comando al arrancar.

## 2. Cómo funciona

### 2.1 Lo que `cron` te da

Programa en `ubuntu-lab` una tarea que vuelque su entorno y espera un minuto:

```bash
echo '* * * * * env | sort > /tmp/env-cron.txt; pwd >> /tmp/env-cron.txt; tty >> /tmp/env-cron.txt 2>&1' | crontab -
# espera un minuto
cat /tmp/env-cron.txt
# HOME=/root
# LANG=C.UTF-8
# LOGNAME=root
# PATH=/usr/bin:/bin
# PWD=/root
# SHELL=/bin/sh
# /root
# not a tty
crontab -r
```

| Variable / dato | Valor | Qué implica |
|---|---|---|
| `PATH` | `/usr/bin:/bin` | **No** están `/usr/local/bin`, `/sbin` ni `/usr/sbin`, ni nada de tu `~/.bashrc` |
| `SHELL` | `/bin/sh` | Tu comando lo interpreta `sh`, **no** `bash` |
| `HOME`, `LOGNAME` | los del usuario | Lo único «tuyo» |
| directorio actual | el `HOME` del usuario | Las rutas relativas parten de ahí, no de donde tú estás |
| terminal | ninguna (`not a tty`) | `read`, `less`, `sudo` sin `-n`, `ssh` pidiendo contraseña… se cuelgan o fallan |
| `USER` | **ausente** en Ubuntu | Usa `LOGNAME` o `id -un` |
| `.bashrc`, alias, funciones | **no existen** | `ll`, `alias`, tu `PATH` personalizado: nada |

(`LANG` y similares dependen de cómo se arrancó el demonio y pueden variar;
en RHEL, `cron` sí añade `USER`.)

### 2.2 Las dos que más muerden: `PATH` y `SHELL`

**`PATH`**. Un programa de `/usr/local/bin` existe en tu terminal y no existe
para `cron`. Emúlalo sin esperar un minuto con `env -i`, que arranca un
proceso con el entorno **vacío** salvo lo que le pases:

```bash
printf '#!/bin/sh\necho hola desde usr-local\n' > /usr/local/bin/hola-cron
chmod +x /usr/local/bin/hola-cron
command -v hola-cron
# /usr/local/bin/hola-cron
env -i HOME=/root PATH=/usr/bin:/bin SHELL=/bin/sh /bin/sh -c 'hola-cron'
# /bin/sh: 1: hola-cron: not found
```

El error real, en `cron`, no aparece en pantalla (véase 2.4): sencillamente
la tarea no hace nada. La cura es **ruta absoluta** (`/usr/local/bin/hola-cron`)
o fijar `PATH` en el `crontab` (2.3).

**`SHELL`**. En Debian y Ubuntu, `/bin/sh` es `dash`, que no conoce los
«bashismos» (`[[ ]]`, arrays, `${var,,}`, `<(...)`):

```bash
ls -l /bin/sh
# lrwxrwxrwx 1 root root 4 Mar 31  2024 /bin/sh -> dash
env -i PATH=/usr/bin:/bin /bin/sh -c '[[ 1 -eq 1 ]] && echo ok'
# /bin/sh: 1: [[: not found
```

En **RHEL y Arch**, `/bin/sh` es `bash`, así que el mismo `[[ ]]` **funciona**
dentro de `cron` (lo comprobé en `rhel-lab` y `arch-lab`) y falla en
Debian/Ubuntu. Es la divergencia más traicionera: el script pasa en tu
máquina RHEL, y en el servidor Ubuntu la tarea no hace nada. Tus scripts ya
empiezan con `#!/usr/bin/env bash`, y eso es lo correcto: **el shebang manda
cuando ejecutas el archivo** (`/ruta/script.sh`). El problema aparece solo
si pones el código en la propia línea del `crontab`, o ejecutas `bash`-ismos
con `sh script.sh`.

### 2.3 Fijar variables en el `crontab`

Antes de las tareas, un `crontab` admite líneas `VARIABLE=valor`. Valen para
todas las tareas que siguen:

```bash
cat > /tmp/v.cron <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""
X=hola
Y=$X-mundo
* * * * * { echo "shell=$0"; hola-cron; [[ 1 -eq 1 ]] && echo bash_ok; echo "Y=$Y"; echo "cwd=$PWD"; } > /tmp/v1.txt 2>&1
EOF
crontab /tmp/v.cron
# espera un minuto
cat /tmp/v1.txt
# shell=/bin/bash
# hola desde usr-local
# bash_ok
# Y=$X-mundo
# cwd=/root
crontab -r
```

- Con `SHELL=/bin/bash` el `[[ ]]` funciona y `$0` lo confirma.
- Con `PATH=/usr/local/bin:...`, `hola-cron` se encuentra.
- **No hay expansión de variables en esas líneas**: `Y=$X-mundo` guarda el
  texto literal `$X-mundo`. Por eso `PATH=$PATH:/opt/bin` **no** funciona:
  escribe la lista completa.
- El directorio sigue siendo el `HOME` (`cwd=/root`). Si tu script necesita
  otro, `cd` explícito: `cd /ruta && ./script.sh`, y mejor aún, que el propio
  script haga `cd "$(dirname "$0")"` o use rutas absolutas.

`toolkit.sh schedule gen` escribe estas cuatro líneas en cada archivo `.cron`
que genera (`SHELL=/bin/bash`, `PATH`, `MAILTO=""`): así el horario no depende
de lo que cada distribución ponga por defecto.

### 2.4 ¿Adónde va la salida?

`cron` conecta la salida y los errores de tu comando a un **pipe** y, cuando
el comando termina, si hubo algo, se lo **envía por correo** al usuario (o a
`MAILTO`) con el programa de correo del sistema. Eso explica los avisos
fantasma de `You have mail in /var/mail/root`. Hay tres casos:

| Situación | Qué pasa con la salida |
|---|---|
| Hay un servidor de correo (MTA) configurado | Se envía por correo a `MAILTO` (por defecto, el usuario) |
| `MAILTO=""` | Se descarta, sin avisar |
| No hay MTA (el caso de **`ubuntu-lab`** y de la mayoría de los contenedores y servidores modernos) | Se pierde: Debian/Ubuntu lo anota en el registro del sistema, que en el laboratorio tampoco existe |

La conclusión es una regla de este bootcamp: **toda tarea programada redirige
su salida a un archivo**.

```bash
# Sin esto, el error de "ls" desaparece. Con esto, queda en el log.
* * * * * /usr/local/bin/mi-tarea >> /var/tmp/mi-tarea.log 2>&1
```

`>>` añade (con `>` cada ejecución borraría la anterior) y `2>&1` manda
también `stderr` al mismo sitio: **en este orden**, `>> archivo 2>&1` (el
mismo orden de la Semana 05). Es lo que escribe `toolkit.sh schedule gen` al
final de cada línea.

### 2.5 La hora

`cron` usa la **zona horaria del sistema**. Dos consecuencias:

- Una tarea «a las 3:00» corre a las 3:00 **del servidor**, no de tu portátil.
  Comprueba con `date` y `timedatectl` (en un host real).
- Las tareas programadas dentro de la hora que **se salta o se repite** en el
  cambio de horario de verano pueden no ejecutarse o ejecutarse dos veces,
  según la implementación. En servidores, lo habitual y lo más sencillo es
  tener el reloj en **UTC**.

## 3. Cómo se usa

Un método para depurar una tarea que «no hace nada», de menos a más esfuerzo:

```bash
# 1. Emula el entorno de cron en TU terminal (rapido, sin esperar un minuto).
env -i HOME="$HOME" LOGNAME="$LOGNAME" PATH=/usr/bin:/bin SHELL=/bin/sh \
  /bin/sh -c 'cd "$HOME" && /ruta/a/tu/comando'
# 2. Si falla ahi, ya tienes el error. Si funciona, programala cada minuto con
#    la salida redirigida y mira el archivo:
#    * * * * * /ruta/a/tu/comando >> /var/tmp/depura.log 2>&1
# 3. Quita la linea cuando termines.
```

El paso 1 resuelve el 80 % de los casos: `not found`, `[[: not found`, un
archivo relativo que no existe.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Confiar en el `PATH` de tu terminal | `cron` tiene `/usr/bin:/bin` | Ruta absoluta o `PATH=` en el `crontab` |
| Llamar a un alias o función de tu `.bashrc` | No existen en `cron` | La ruta del programa; `type -P` te la da |
| Rutas relativas (`./script.sh`, `datos.csv`) | El directorio es `HOME`, no el tuyo | Rutas absolutas |
| Línea de `crontab` con `[[ ]]` y `SHELL` por defecto | Falla en Debian/Ubuntu (`dash`) y funciona en RHEL | `SHELL=/bin/bash`, o meter el código en un script con shebang |
| `PATH=$PATH:/opt/bin` en el `crontab` | No se expande: `PATH` queda con el texto literal | Escribir la lista completa |
| Dejar la salida sin redirigir | Se pierde: ni error visible ni registro | `>> archivo 2>&1` |
| `MAILTO=""` sin redirigir | Silencia **también** los errores | Redirige primero; `MAILTO=""` solo evita el correo duplicado |
| Programar a la hora que se repite con el cambio de horario | Dos ejecuciones o ninguna | Servidor en UTC |

## 5. Trucos

- **`env -i ... /bin/sh -c '...'`** es el simulador de `cron` más barato que
  existe. Guárdalo como alias o función.
- **`* * * * * env | sort > /tmp/env-cron.txt`**, una sola vez, te dice
  exactamente el entorno de **tu** `cron` (cambia entre distribuciones y
  versiones).
- **`type -P comando`** (sin alias ni funciones) imprime la ruta absoluta de
  un ejecutable: es lo que usa `toolkit.sh schedule gen` para que el
  horario no dependa del `PATH`.

## 📚 Recursos Adicionales

- `man 5 crontab`, sección de variables de entorno
- [Ubuntu — CronHowto](https://help.ubuntu.com/community/CronHowto)

## ✅ Checklist de Verificación

- [ ] Volcaste el entorno de `cron` y viste `PATH=/usr/bin:/bin` y `SHELL=/bin/sh`
- [ ] `env -i ... /bin/sh -c 'hola-cron'` da `not found` y con ruta absoluta funciona
- [ ] Demuestras que `[[ ]]` falla con `/bin/sh` en Ubuntu y explicas por qué en RHEL no
- [ ] `Y=$X-mundo` en un `crontab` deja el texto literal
- [ ] Una tarea sin redirección no deja rastro; con `>> archivo 2>&1` sí
- [ ] Explicas por qué `USER` puede no existir en `cron` y qué usar en su lugar

---

[← Expresiones de cron y sus trampas](02-expresiones-de-cron-y-sus-trampas.md) · [`cron` en el sistema y `at` →](04-cron-en-el-sistema-y-at.md)
