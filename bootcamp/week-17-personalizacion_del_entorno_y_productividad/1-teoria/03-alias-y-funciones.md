# Alias y funciones

> Un alias es una abreviatura; una función es un mini-script que vive en tu shell.
> Elegir mal entre las dos es la causa de la mitad de los «mi alias no funciona».

## 🎯 Objetivos

- Definir, listar y borrar alias, y saber cuándo **no** se expanden
- Escribir una función con argumentos, `local` y `return`
- Elegir entre alias y función con un criterio
- Saltarte un alias (`\cmd`, `command cmd`) y ver qué es cada nombre (`type`)
- Saber dónde guardarlos (`~/.bashrc`, `~/.bash_aliases`) y exportar una función a los hijos

## 1. Qué problema resuelve

Escribes `ls -alF` cincuenta veces al día, y cada semana necesitas «crear un
directorio y entrar en él». Lo primero es un alias; lo segundo, una función. Los
dos se definen en la shell y son lo primero que se personaliza, pero tienen
reglas distintas que conviene conocer.

## 2. Cómo funciona

### 2.1 Alias: sustitución de texto

```bash
alias ll='ls -alF'
alias | grep ^alias.ll
# alias ll='ls -alF'
type ll
# ll is aliased to `ls -alF'
unalias ll
```

Un alias **sustituye el texto** de la **primera palabra** de una orden. Por eso
los argumentos van detrás, sin más:

```bash
shopt -s expand_aliases
alias saluda='echo hola'
saluda mundo cruel
# hola mundo cruel
```

(`expand_aliases` ya está activo en una shell interactiva; lo escribimos porque
aquí lo probamos en un script.) Un alias **no puede** colocar el argumento en el
medio ni usarlo dos veces; para eso hace falta una función.

### 2.2 Cuándo no se expanden

Tres sitios donde tu alias «desaparece»:

**1. En un script.** Los alias son para la shell interactiva:

```bash
printf 'alias ll="ls -l"\nll /tmp/p17a\n' > /tmp/al.sh
bash /tmp/al.sh
# /tmp/al.sh: line 2: ll: command not found
```

Se pueden activar con `shopt -s expand_aliases`, pero **no es buena idea**:
usa una función o el comando completo.

**2. En la misma línea donde se definen.** bash lee la línea **entera** antes de
ejecutarla, así que la expansión ya pasó cuando el alias existe:

```bash
printf 'shopt -s expand_aliases\nalias zz="echo zz"; zz\nzz\n' > /tmp/a3.sh
bash /tmp/a3.sh
# /tmp/a3.sh: line 2: zz: command not found
# zz
```

La primera `zz` (en la misma línea del `alias`) falla; la de la línea siguiente
funciona. Si defines y usas un alias en una sola línea, no funciona.

**3. Como segunda palabra.** Solo se expande la primera: en `sudo ll`, `ll` no es
un alias. El truco es que, **si el alias termina en espacio**, la palabra
siguiente también se expande:

```bash
alias ll="ls -d"
alias ve="env "      # con espacio final
ve ll /tmp
# /tmp
alias ve2="env"      # sin espacio
ve2 ll /tmp
# env: 'll': No such file or directory
```

Por eso se ve `alias sudo='sudo '`: para que `sudo ll` funcione.

### 2.3 Funciones: código de verdad

Una función tiene argumentos (`$1`, `$@`), variables `local`, `return` y todo lo
que aprendiste en las Semanas 13 y 14:

```bash
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
mkcd /tmp/mkcdx/y
pwd
# /tmp/mkcdx/y
```

Dos órdenes para inspeccionarlas:

```bash
type mkcd
# mkcd is a function
# mkcd () 
# { 
#     mkdir -p -- "$1" && cd -- "$1"
# }
declare -f mkcd      # solo el código, también sirve para copiarla
```

Con `local` y `return`:

```bash
doble() { local n=$1; echo $(( n * 2 )); return 3; }
doble 4
# 8
echo "rc=$?"
# rc=3
```

Y la regla que explica por qué **`cd` dentro de una función cambia tu shell**:
la función corre **en la shell actual**, no en un hijo. Es lo que un script no
podría hacer (un script `mkcd.sh` haría el `cd` en su propio proceso y se
perdería al terminar). Es el motivo principal para preferir una función.

### 2.4 Cuál elegir

| Necesitas | Usa |
|---|---|
| Abreviar una orden con sus opciones (`ls -alF`) | alias |
| Poner el argumento en medio, usarlo dos veces o ramificar | función |
| Cambiar de directorio o variables de **tu** shell | función |
| Algo que deba funcionar en un script | **ni una ni otra**: un script o `~/bin` |

### 2.5 Precedencia y cómo saltarte un alias

Para un mismo nombre, bash prueba: **alias → función → orden interna → archivo**
(2.3 del [archivo 02](02-variables-de-entorno-y-path.md)). Un alias gana a una
función del mismo nombre, hasta que lo borras:

```bash
f() { echo funcion; }
alias f="echo alias"
f
# alias
unalias f
f
# funcion
```

Para ejecutar el comando **real** aunque haya un alias:

```bash
alias date="echo ALIAS-date"
date +%Y
# ALIAS-date +%Y
\date +%Y >/dev/null && echo "con barra: ok"
# con barra: ok
command date +%Y >/dev/null && echo "con command: ok"
# con command: ok
```

La barra invertida (`\date`) y `command date` evitan el alias. `command` también
evita una función, y `command -v` es la forma de scripting de «¿existe?».
`type -a date` te los enseña todos, en orden: el alias primero, después
`/usr/bin/date` y `/bin/date`.

### 2.6 Dónde se guardan

En `~/.bashrc` (interactiva; ver [archivo 01](01-como-arranca-bash.md)). El de
Ubuntu ya incluye `ll`, `la` y `l`, y **carga un archivo aparte** si existe:

```bash
sed -n 104,106p /etc/skel/.bashrc
# if [ -f ~/.bash_aliases ]; then
#     . ~/.bash_aliases
# fi
```

`~/.bash_aliases` es una convención de Debian/Ubuntu para no tocar el `.bashrc`.
Hoy lo normal es versionar tu propio archivo (ver el
[archivo 08](08-dotfiles-y-construyendo-dotfiles.md)).

### 2.7 Exportar una función

Una función **no se hereda** de forma normal. `export -f` la mete en el entorno
para que otra `bash` hija la tenga:

```bash
saluda() { echo "hola $1"; }
bash -c 'saluda mundo'
# bash: line 1: saluda: command not found
export -f saluda
bash -c 'saluda mundo'
# hola mundo
```

Se usa con `xargs`, `find -exec bash -c` y `parallel`, que lanzan una `bash` nueva
por cada elemento. Solo funciona con bash (otros shells ignoran la función).

## 3. Cómo se usa

### 3.1 Un conjunto pequeño y útil

```bash
alias ll='ls -alF'
alias ..='cd ..'
alias grep='grep --color=auto'

mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# Una copia de seguridad con la fecha: la fecha va EN MEDIO del nombre.
backup() { cp -- "$1" "$1.$(date +%F).bak"; }
```

```bash
cd /tmp && echo x > f.txt && backup f.txt && ls f.txt*
# f.txt
# f.txt.2026-10-25.bak
```

### 3.2 Qué es cada nombre

`type -t` da una sola palabra, lo que necesita un script para decidir:

```bash
alias a1="echo"; f1() { :; }
type -t a1 f1 cd ls
# alias
# function
# builtin
# file
```

`compgen -a` lista tus alias y `compgen -A function` tus funciones.

### 3.3 Divergencia de distro

Los alias que traiga tu cuenta nueva **dependen de la distro**: el `.bashrc` de
Ubuntu define `ll`, `la` y `l`; el de `root` en RHEL define `rm -i`, `cp -i` y
`mv -i`. Eso no es una función de bash, sino de **su plantilla**: comprueba con
`alias` qué trae tu cuenta antes de asumir qué hace `rm`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `alias rm='rm -i'` como red de seguridad | Te acostumbras; en un servidor **sin** el alias, `rm` no pregunta | Hábito: `ls` antes de `rm` |
| Alias que cambia el comportamiento por defecto de un comando (`alias ls='ls -l'`) | Rompe tu intuición y los pegados de otros | Un nombre nuevo (`ll`) |
| Alias con argumento en medio (`alias f='cp $1 /tmp'`) | `$1` no existe en un alias | Una función |
| Alias dentro de un script | No se expanden | Llamar al comando completo |
| Función con `cd` dentro de un script esperando que cambie **tu** shell | El script corre en un hijo | La función en `.bashrc` |
| Nombre de función igual a un comando real (`ls`, `cd`) | Recursión infinita si la función llama al comando | `command ls` dentro de la función |
| `export -f` para código que otros usarán | Solo funciona en bash y no se ve en la configuración | Un script ejecutable en `~/bin` |
| Alias en el archivo equivocado (`.profile`) | No existen en las shells sin login | `~/.bashrc` |

## 5. Trucos

- **`alias -p`** imprime los alias en formato reutilizable (`alias nombre='...'`):
  lo que necesitas para copiarlos a otro archivo.
- **`declare -f`** (sin nombre) imprime **todas** las funciones, con su código.
- **`\comando`** y **`command comando`** para el real; **`type -a`** para ver
  quién más se llama igual.

## 📚 Recursos Adicionales

- `man bash`, secciones **ALIASES** y **FUNCTIONS**
- `help alias`, `help unalias`, `help declare`, `help command`

## ✅ Checklist de Verificación

- [ ] Defines un alias y lo ves con `type`; lo borras con `unalias`
- [ ] Reproduces que un alias no se expande en un script ni en la misma línea
- [ ] Usas el truco del espacio final con `ve ll /tmp`
- [ ] Escribes `mkcd` y compruebas que cambia **tu** directorio
- [ ] Muestras que un alias gana a una función del mismo nombre y saltas el alias con `\cmd`
- [ ] Exportas una función con `export -f` y la llamas desde `bash -c`

---

[← Variables de entorno y `PATH`](02-variables-de-entorno-y-path.md) · [El prompt (`PS1`) →](04-el-prompt-ps1.md)
