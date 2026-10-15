# Historial y edición de línea

> Reescribir un comando largo de cero cada vez que te equivocas en un
> carácter es la forma más lenta posible de usar una terminal. Bash trae un
> editor de línea completo; casi nadie usa más de dos de sus atajos.

## 🎯 Objetivos

- Navegar y reutilizar el historial de comandos sin volver a escribirlos
- Usar los atajos de edición de línea de readline para moverte y corregir rápido
- Configurar un historial persistente y más grande que el valor por defecto

## 1. Qué problema resuelve

Bash recuerda cada comando que escribes y te da herramientas para buscarlos,
repetirlos y editarlos sin volver a teclear nada. La mayoría de la gente solo
usa la flecha arriba, y se pierde el resto: búsqueda incremental, repetición
del último argumento, edición de línea con atajos de teclado tipo Emacs. El
efecto acumulado de no saber esto es minutos perdidos por hora, todos los
días, para siempre.

## 2. Cómo funciona

### 2.1 Dos historiales: el de la sesión y el del archivo

Bash mantiene el historial **en memoria** durante la sesión actual, y lo
vuelca a un archivo (`~/.bash_history`) recién cuando la sesión termina
normalmente (no con un corte abrupto, como matar el proceso). Esto explica
por qué, si tienes dos terminales abiertas al mismo tiempo, los comandos de
una no aparecen en el historial de la otra hasta que cierras alguna — cada
sesión escribe su propio historial al archivo solo al final.

```bash
# Cuantos comandos recuerda esta sesion ahora mismo, en memoria
history | wc -l
```

### 2.2 Las variables que controlan el historial

| Variable | Qué controla | Valor típico en Ubuntu |
|---|---|---|
| `HISTSIZE` | Cuántos comandos recuerda la sesión en memoria | 1000 |
| `HISTFILESIZE` | Cuántas líneas guarda `~/.bash_history` en disco | 2000 |
| `HISTCONTROL` | Si ignora duplicados o líneas que empiezan con espacio | sin configurar por defecto |
| `HISTTIMEFORMAT` | Si el historial muestra fecha/hora de cada comando | sin configurar por defecto |

El valor por defecto de Ubuntu (1000/2000) es bajo para una sesión de trabajo
intensa: una tarde productiva fácilmente supera los mil comandos, y los más
viejos se descartan sin aviso. Subirlo es una de las primeras cosas que vale
la pena cambiar en `~/.bashrc`.

```bash
# En ~/.bashrc:
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:ignorespace
HISTTIMEFORMAT='%F %T  '
```

`HISTCONTROL=ignorespace` es particularmente útil: cualquier comando que
escribas con **un espacio al principio** no queda guardado en el historial —
el lugar correcto para escribir algo con una contraseña de prueba sin
dejarlo grabado en texto plano para siempre.

### 2.3 Readline: el editor de línea debajo de bash

Todo lo que escribes en el prompt pasa por **readline**, una biblioteca que
le da a bash edición de línea, no solo "escribir y borrar con backspace".
Trae, por defecto, atajos estilo Emacs: moverte por palabras, cortar y pegar,
buscar en el historial sin usar las flechas.

| Atajo | Acción |
|---|---|
| `Ctrl+A` | Ir al inicio de la línea |
| `Ctrl+E` | Ir al final de la línea |
| `Ctrl+U` | Borrar desde el cursor hasta el inicio |
| `Ctrl+K` | Borrar desde el cursor hasta el final |
| `Ctrl+W` | Borrar la palabra anterior al cursor |
| `Alt+F` / `Alt+B` | Saltar una palabra adelante/atrás |
| `Ctrl+R` | Búsqueda incremental hacia atrás en el historial |
| `Ctrl+L` | Limpiar la pantalla (igual que `clear`) |
| `Ctrl+_` | Deshacer el último cambio en la línea actual |

`Ctrl+A`/`Ctrl+E` reemplazan por completo la necesidad de mantener apretada
la tecla Home/End o de usar las flechas quince veces para llegar al principio
de un comando largo.

### 2.4 Cuándo se escribe el historial a disco

Por defecto, bash agrega las líneas de la sesión actual al archivo
`~/.bash_history` recién al cerrar esa sesión — no línea por línea en vivo.
Esto significa que, si un contenedor o una sesión SSH se corta abruptamente
(no con `exit`, sino con un corte de red o un `kill`), los comandos de esa
sesión nunca llegan a escribirse en el archivo.

```bash
# Forzar que la sesion actual escriba su historial en memoria al archivo, ya
history -a
```

`history -a` es la pieza que hace que `PROMPT_COMMAND='history -a'` (una
configuración común en `.bashrc` más avanzados) escriba cada comando al
archivo apenas se ejecuta, en vez de esperar al cierre de la sesión — relevante
si trabajas en entornos donde las sesiones se cortan seguido, como contenedores
efímeros.

### 2.5 Compartir historial en vivo entre varias terminales abiertas

Combinando `history -a` (escribir lo nuevo de esta sesión al archivo) con
`history -c; history -r` (olvidar lo que esta sesión tiene en memoria y
releer el archivo completo) se puede lograr que varias terminales abiertas al
mismo tiempo vean, casi en vivo, los comandos que vas escribiendo en las
otras:

```bash
# En ~/.bashrc:
PROMPT_COMMAND='history -a; history -c; history -r'
```

Esto tiene un costo: cada prompt nuevo relee el archivo completo de
historial, lo cual se nota si ese archivo creció mucho (otra razón para no
dejar `HISTFILESIZE` en un valor exagerado sin necesidad real). Para la
mayoría de los casos, `shopt -s histappend` del paso anterior alcanza sin
este costo adicional — esta configuración más agresiva vale la pena
específicamente cuando trabajas con varias terminales a la vez y te importa
verlas sincronizadas en tiempo real, no solo al cerrar sesión.

## 3. Cómo se usa

```bash
# Busqueda incremental: Ctrl+R, despues escribir parte de un comando pasado
# (Ctrl+R) (bck-i-search)`apt`: sudo apt install shellcheck
```

Apretar `Ctrl+R` de nuevo avanza a la coincidencia anterior; `Enter` ejecuta
la línea encontrada; una flecha o `Ctrl+G` cancela la búsqueda sin ejecutar
nada.

```bash
# Repetir el ultimo comando, tal cual
!!

# Repetir el ultimo comando, con sudo adelante (el caso de uso mas comun)
sudo !!
```

```bash
# Reutilizar el ultimo argumento del comando anterior
mkdir /tmp/carpeta_larga
cd !$
# equivale a: cd /tmp/carpeta_larga
```

```bash
# Ver el historial completo numerado, y ejecutar uno puntual por numero
history | tail -5
#   501  cat /etc/os-release
#   502  ls -la /etc
#   503  sudo apt update
!502
# vuelve a ejecutar exactamente "ls -la /etc"
```

```bash
# Buscar y ejecutar el ultimo comando que empezo con cierta palabra
!apt
# ejecuta el ultimo comando del historial que arranca con "apt"
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `!comando` sin revisar qué se va a ejecutar | Ejecuta de inmediato el último comando que coincide — si no es el que pensabas, puede ser destructivo | Usar `!comando:p` para *imprimir* el comando sin ejecutarlo, revisarlo, y recién ahí correrlo con flecha arriba |
| Dejar `HISTSIZE` en el valor por defecto en una máquina donde trabajas a diario | Se pierden comandos útiles de hace unas horas sin aviso | Subir `HISTSIZE`/`HISTFILESIZE` en `~/.bashrc` desde el primer día |
| Escribir contraseñas de prueba directo en la línea de comandos sin espacio inicial | Quedan guardadas en texto plano en `~/.bash_history`, potencialmente para siempre | Configurar `HISTCONTROL=ignorespace` y anteponer un espacio a cualquier línea sensible |
| Presionar backspace repetidamente para borrar una línea larga | Es lento comparado con los atajos de readline | `Ctrl+U` borra toda la línea antes del cursor de un solo golpe |

## 5. Trucos

- `history -d N` borra una entrada puntual del historial por su número — útil
  si tipeaste algo sensible sin el espacio inicial y quieres sacarlo ya.
- `Ctrl+X Ctrl+E` abre el comando que estás escribiendo en tu editor
  (`$EDITOR`) para comandos muy largos o con múltiples líneas — más cómodo
  que editar carácter por carácter en el prompt.
- `shopt -s histappend` (en `~/.bashrc`) hace que terminales múltiples
  *agreguen* al archivo de historial en vez de sobrescribirlo — sin esto, la
  última terminal que cierras "gana" y borra lo que las otras habían guardado.

## Resumen

El historial de bash vive en memoria durante la sesión y se escribe a
`~/.bash_history` al cerrarla, salvo que se fuerce antes con `history -a`.
Readline es el editor de línea que hace posible moverse, cortar y buscar sin
depender de backspace y flechas; `Ctrl+R`, `!!` y `!$` cubren la mayoría de
los casos reales de reutilizar algo que ya escribiste antes.

## 📚 Recursos Adicionales

- [GNU Readline manual](https://www.gnu.org/software/bash/manual/html_node/Readline-Interaction.html) — la referencia completa de atajos de edición de línea.
- `man bash`, sección `HISTORY EXPANSION` — toda la sintaxis de `!!`, `!$`, `!N`, documentada con precisión.

## ✅ Checklist de Verificación

- [ ] Configuraste `HISTSIZE`, `HISTFILESIZE` y `HISTCONTROL` en `~/.bashrc` y recargaste con `source`
- [ ] Usaste `Ctrl+R` para encontrar y ejecutar un comando anterior sin escribirlo de nuevo
- [ ] Usaste `!!` y `!$` al menos una vez cada uno en un caso real

---

[← 05 — Obtener ayuda: man, --help, info](05-obtener-ayuda-man-help-info.md) · [Práctica 01 →](../2-practicas/01-primer-contacto-con-ubuntu-lab.md)
