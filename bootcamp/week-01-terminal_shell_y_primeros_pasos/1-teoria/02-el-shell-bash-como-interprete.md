# El shell: bash como intérprete

> El shell no es "la pantalla negra". Es un programa como cualquier otro,
> con su propio ciclo de vida, que puedes inspeccionar y hasta reemplazar.

## 🎯 Objetivos

- Explicar qué hace un shell entre que tecleas Enter y ves el resultado
- Distinguir shell de login, interactivo no-login, y no interactivo
- Identificar qué shell estás usando y por qué bash es el de referencia acá

## 1. Qué problema resuelve

Mucha gente aprende comandos sueltos sin preguntarse quién los ejecuta. Eso
funciona hasta que algo se comporta "raro": un script que andaba en la
terminal falla al correrlo con cron, un alias que "siempre funcionó" no
existe en una sesión nueva, un `source` que no hace nada. Casi todos esos
casos tienen la misma causa: distintos **tipos de shell** cargan distintos
archivos de configuración, y el comportamiento depende de cuál eres en ese
momento.

Sin este modelo, cada uno de esos casos parece un bug distinto. Con él, todos
son la misma pregunta: "¿qué tipo de shell es este, y qué archivo debería
haber cargado?".

## 2. Cómo funciona

### 2.1 Qué es, en concreto, un shell

Un shell es un programa que corre en un bucle: lee una línea de texto,
la interpreta según una gramática (la del lenguaje bash, en este caso), y
ejecuta lo que esa línea significa — ya sea un comando interno (builtin), un
programa externo, o una estructura de control (`if`, `for`). Eso es todo.
No hay magia: `bash` es un binario en `/usr/bin/bash` como cualquier otro.

```bash
which bash
# /usr/bin/bash

file /usr/bin/bash
# /usr/bin/bash: ELF 64-bit LSB pie executable...
```

Es un ejecutable normal. Lo que lo hace especial es que, cuando corre en
modo interactivo, se queda en un bucle leyendo tu teclado en vez de terminar.

### 2.2 Shells disponibles en Ubuntu 24.04

| Shell | Dónde vive | Rol típico |
|---|---|---|
| `bash` | `/usr/bin/bash` | Shell interactivo por defecto del usuario |
| `sh` | `/usr/bin/sh` → symlink a `dash` en Ubuntu | Shell de scripts del sistema, POSIX estricto |
| `dash` | `/usr/bin/dash` | Más rápido, menos features que bash — usado por `#!/bin/sh` |
| `zsh` | si se instala | Alternativa interactiva, no es la de este bootcamp |

Este bootcamp enseña **bash** porque es el shell interactivo por defecto en
Ubuntu y la inmensa mayoría de distros, y porque los scripts que vas a
escribir (Semana 13 en adelante) usan `#!/usr/bin/env bash`, no `sh`. Es
importante saber que `sh` existe y que *no* es un alias de bash: muchos
`features` de bash (arrays, `[[ ]]`, `function`) simplemente no existen en
`sh`/`dash`, y un script con shebang `#!/bin/sh` que usa sintaxis de bash
falla con errores crípticos.

```bash
# Verificar que sh NO es bash en Ubuntu
ls -la /usr/bin/sh
# lrwxrwxrwx 1 root root 4 ene  1 10:00 /usr/bin/sh -> dash
```

### 2.3 Los tres modos de un shell

| Modo | Cuándo ocurre | Archivos que carga |
|---|---|---|
| Login | Inicias sesión (consola física, `ssh usuario@host`, `login`) | `/etc/profile`, luego el primero que exista entre `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| Interactivo no-login | Abres una terminal nueva en un sistema ya logueado | `~/.bashrc` |
| No interactivo | Corre un script (`bash script.sh`), o cron, o systemd | Ninguno por defecto — a menos que el script haga `source` explícito |

Esta tabla es la causa número uno de "funciona en mi terminal pero no en
cron": un cron job no es ni login ni interactivo, así que no carga `.bashrc`.
Si tu script depende de un alias o una variable definida solo ahí, falla en
cron y funciona perfecto cuando lo pruebas a mano.

```bash
# Ver en que modo estas ahora mismo
echo "login=$0 interactivo=$-"
# login=-bash interactivo=himBHs
```

Un `$0` que empieza con `-` (`-bash`) indica shell de login. La `i` dentro de
`$-` indica modo interactivo (entre otras letras que no son relevantes acá).

### 2.4 Shell de login vs usuario por defecto del sistema

No confundir "shell de login" (el *modo* en que arrancó) con "shell por
defecto del usuario" (qué programa arranca cuando haces login, configurado en
`/etc/passwd`):

```bash
getent passwd "$USER" | cut -d: -f7
# /bin/bash
```

Cambiar esto (`chsh -s /usr/bin/zsh`, por ejemplo) es lo que decide qué
intérprete arranca la próxima vez que inicies sesión — no afecta qué pasa si,
una vez dentro de bash, corres `zsh` manualmente.

### 2.5 Shells anidados y `$SHLVL`

Cada vez que lanzas un shell dentro de otro (corriendo `bash` a mano, o
entrando a un contenedor con `docker exec -it ubuntu-lab bash`), se crea un
**proceso nuevo**, hijo del anterior. Bash lleva la cuenta en `$SHLVL`
("shell level"):

```bash
echo "$SHLVL"
# 1
bash
echo "$SHLVL"
# 2
exit
echo "$SHLVL"
# 1 (volviste al shell padre)
```

Un `$SHLVL` sospechosamente alto (5, 10) suele significar que un script o un
alias está lanzando `bash` dentro de sí mismo por error — por ejemplo, un
`.bashrc` que llama `bash` en vez de solo configurar el shell actual. Es una
de las primeras cosas a mirar cuando una terminal "se siente rara" o un
prompt se repite más de lo esperado.

### 2.6 `exec`: reemplazar en vez de anidar

`exec` le dice al shell "conviértete en este otro programa", sin crear un
proceso nuevo:

```bash
echo "PID antes: $$"
exec bash
echo "esta linea nunca se ejecuta"
```

El segundo `echo` no corre porque `exec bash` no devuelve el control: el
proceso actual *se convierte* en el nuevo `bash`, con el mismo PID. Esto
importa porque ciertas herramientas (incluido el patrón `exec` al final de
scripts de arranque) lo usan específicamente para no dejar un proceso
intermedio colgado — se retoma con más detalle en la Semana 10.

## 3. Cómo se usa

```bash
# El shell actual, de la forma mas confiable (no $SHELL, que solo refleja
# el shell de login configurado, no el que estas usando ahora)
ps -p $$ -o comm=
# bash
```

`$SHELL` es una variable de entorno que se **hereda**, no que se actualiza:
si entras a `bash` y después corres `dash` manualmente, `$SHELL` sigue
diciendo `bash` aunque estés parado en `dash`. `ps -p $$` consulta al kernel
qué proceso eres *ahora mismo* y es la forma correcta de preguntarlo.

```bash
# Lanzar un subshell y comprobar que es un proceso nuevo
bash -c 'echo "PID del subshell: $$"'
echo "PID de este shell: $$"
```

```bash
# Ejecutar un script con un shell explicito, sin depender del shebang
bash mi_script.sh
sh mi_script.sh      # puede fallar si el script usa sintaxis de bash
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir `#!/bin/sh` pero usar sintaxis de bash (`[[ ]]`, arrays) | En Ubuntu `sh` es `dash`: el script falla con "syntax error" lejos de donde realmente está el problema | Usar `#!/usr/bin/env bash` si necesitas features de bash — y usarlas con esa certeza |
| Asumir que un cron job ve los mismos alias/variables que tu terminal | Cron corre no interactivo: no carga `.bashrc` | Definir lo necesario dentro del script mismo, o cargarlo explícito con `source` |
| Confiar en `$SHELL` para saber qué shell estás corriendo ahora | Es una variable heredada, no el estado actual | Usar `ps -p $$ -o comm=` |
| Pensar que cambiar de shell con `chsh` cambia el shell de la sesión actual | `chsh` solo define qué arranca en el *próximo* login | Cerrar sesión y volver a entrar, o lanzar el shell nuevo manualmente para probarlo ya |
| Ver `$SHLVL` en 6 y no investigarlo | Casi siempre indica un script o alias que lanza `bash` dentro de sí mismo en lugar de configurar el shell actual | Revisar `.bashrc`/`.bash_profile` buscando una llamada a `bash` sin `exec` |

## 5. Trucos

- `bash --version` te dice la versión exacta — relevante porque algunas
  features (arrays asociativos, `${var,,}`) requieren bash 4+.
- `chsh -l` (o `cat /etc/shells`) lista los shells que el sistema reconoce
  como válidos para iniciar sesión.
- Para probar algo rápido en otro shell sin cambiar nada permanente, basta con
  escribir su nombre (`dash`, `zsh`) y salir con `exit` cuando termines.
- `bash -l` fuerza un shell de login sin tener que cerrar sesión — útil para
  probar si un problema de configuración viene de `.bash_profile` o de
  `.bashrc`.
- `echo $SHLVL` es un chequeo de salud de dos segundos cuando algo en tu
  sesión se siente "acumulado": si subió sin que lo hayas abierto a mano, hay
  un `bash` de más en la cadena.

## Resumen

`bash` es un binario normal que lee tus comandos en un bucle. Qué archivos
carga depende de si el shell es de login, interactivo no-login, o no
interactivo — y esa distinción es la explicación real detrás de "funciona en
mi terminal pero no en cron". `$SHLVL` y `exec` son las herramientas para
razonar sobre cuántos shells hay apilados y por qué.

## 📚 Recursos Adicionales

- [Bash Reference Manual — Invocation](https://www.gnu.org/software/bash/manual/bash.html#Invocation) — la tabla oficial de qué archivos carga bash según el modo.
- `man bash`, sección `INVOCATION` — la misma tabla, offline.

## ✅ Checklist de Verificación

- [ ] Corriste `ps -p $$ -o comm=` y confirmaste que estás en `bash`
- [ ] Verificaste que `/usr/bin/sh` apunta a `dash`, no a `bash`
- [ ] Explicaste con tus palabras por qué un cron job no ve tus alias de `.bashrc`

---

[← 01 — Terminal, consola y TTY](01-terminal-consola-y-tty.md) · [03 — Anatomía del prompt →](03-anatomia-del-prompt.md)
