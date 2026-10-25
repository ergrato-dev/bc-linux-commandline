# El prompt (`PS1`)

> El prompt es lo único que ves **después de cada comando**.
> Bien hecho, te dice dónde estás, quién eres y si lo último falló, sin que preguntes.

## 🎯 Objetivos

- Leer y escribir un `PS1` con las secuencias de escape de bash
- Añadir color sin romper el recorte de línea (`\[ \]`)
- Mostrar el código de salida del último comando y la rama de git
- Usar `PROMPT_COMMAND` para lo que no cabe en una cadena
- Distinguir `PS1`, `PS2`, `PS3` y `PS4`
- Probar un prompt sin abrir una terminal nueva (`${PS1@P}`)

## 1. Qué problema resuelve

Entras por SSH en tres servidores con el mismo prompt y ejecutas un `rm` en el
equivocado. O pasas diez minutos preguntándote si el último comando acabó bien.
El prompt es el sitio más barato donde poner esa información: el nombre de la
máquina, el directorio, el estado del último comando.

## 2. Cómo funciona

### 2.1 Cuatro prompts, no uno

| Variable | Cuándo se muestra |
|---|---|
| `PS1` | Esperando un comando (**el prompt**) |
| `PS2` | Una orden continúa en la línea siguiente (comillas sin cerrar, `\` al final) |
| `PS3` | El menú de `select` en un script |
| `PS4` | Delante de cada línea con `set -x` (Semana 15) |

`PS2` se ve fácilmente:

```bash
PS2='... '
echo "uno \
dos"
# ... dos"        <- «... » es el PS2 que bash pinta antes de tu segunda línea
# uno dos
```

### 2.2 Las secuencias de escape

`PS1` es una cadena con secuencias `\x` que bash sustituye **antes de mostrarla**.
No necesitas abrir otra terminal para probarlas: `${PS1@P}` expande una cadena
como si fuera un prompt (bash 4.4 o posterior).

```bash
cd /tmp; PS1='\u@\h:\w\$ '; echo "[${PS1@P}]"
# [root@ubuntu-lab:/tmp$ ]
```

Las que más se usan, con lo que muestran aquí (`ubuntu-lab`, usuario `root`):

| Secuencia | Significa | Resultado |
|---|---|---|
| `\u` | usuario | `root` |
| `\h` | máquina, hasta el primer punto | `ubuntu-lab` |
| `\H` | nombre completo de la máquina | `ubuntu-lab` |
| `\w` | directorio actual, con `~` | `/tmp` (o `~/proyectos`) |
| `\W` | **solo** el último componente | `share` (de `/usr/share`) |
| `\$` | `#` si eres root, `$` si no | `#` |
| `\t` `\T` `\@` `\A` | hora (24 h, 12 h, am/pm, hh:mm) | `05:39:39` `05:39 AM` |
| `\d` | fecha | `Sun Oct 25` |
| `\j` | trabajos en segundo plano | `0` |
| `\!` / `\#` | número en el historial / de la orden | `1` |
| `\n` | salto de línea | |
| `\s` `\v` | nombre y versión de la shell | `bash` `5.2` |

```bash
cd /usr/share; PS1='\W \$ '; echo "[${PS1@P}]"
# [share # ]
```

> `\$` para un usuario normal sería `$`; aquí sale `#` porque somos `root`. Es
> la forma más barata de **avisar de que estás con privilegios**.

### 2.3 Color y la trampa de `\[ \]`

Los colores son secuencias ANSI: `ESC [ código m`. `\e` es el carácter ESC. Las
más usadas:

| Código | Efecto | Código | Efecto |
|---|---|---|---|
| `0` | reiniciar | `1` | negrita |
| `31` | rojo | `32` | verde |
| `33` | amarillo | `34` | azul |
| `36` | cian | `37` | blanco |

Verde para el usuario y reinicio después:

```bash
PS1='\[\e[32m\]\u\[\e[0m\]\$ '
printf '%q\n' "${PS1@P}"
# $'\E[32mroot\E[0m# '
```

Las secuencias de color **no ocupan columnas** al pintar, pero bash no lo sabe.
`\[` y `\]` le dicen a `readline`: «lo de en medio es invisible, no lo cuentes».
Sin ellos, el prompt «mide» más de lo que se ve y la edición de la línea se
rompe: el cursor salta a mitad de la pantalla al llegar al borde, o una
orden larga se sobrescribe a sí misma. Cada secuencia de color va **entre `\[`
y `\]`**.

### 2.4 Que el prompt se evalúe cada vez

Si `PS1` está entre **comillas simples**, `$?` y `$(...)` se evalúan **cada vez
que se muestra** (la opción `promptvars` está activa por defecto). Con comillas
dobles se expanden **una sola vez**, al definirla. Un prompt con el código de
salida y la rama de git:

```bash
__rama() { git branch --show-current 2>/dev/null; }
PS1='[$?] \u@\h \W $(__rama)\$ '
```

Así se ve cuando lo usas (estados reales de un `true`, un `false` y un `cd` a un
repositorio):

```
[0] root@ubuntu-lab ~ #
[1] root@ubuntu-lab ~ #
[0] root@ubuntu-lab repo17 principal#
```

El `[1]` aparece después de un `false`. Es el primer síntoma de «mi prompt
miente»: si lo pones entre comillas dobles, el `$?` queda fijo para siempre.

### 2.5 `PROMPT_COMMAND`: lo que no cabe en una cadena

`PROMPT_COMMAND` es una orden (o, desde bash 5.1, un **array** de órdenes) que
bash ejecuta **antes de cada prompt**. Sirve para lo que cambia estado y no solo
dibuja: guardar el código de salida, escribir el historial, actualizar el
título de la ventana.

```bash
PROMPT_COMMAND='rc=$?'
false
echo $rc
# 1
```

Y como array, en bash 5.1 o posterior:

```bash
PROMPT_COMMAND=("echo uno" "echo dos")
declare -p PROMPT_COMMAND
# declare -a PROMPT_COMMAND=([0]="echo uno" [1]="echo dos")
```

Si defines `PROMPT_COMMAND` como cadena, **no machaques** el valor de otras
personas ni de `/etc/bash.bashrc`; añade con `;`:
`PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }nuevo"`.

### 2.6 Directorios largos: `PROMPT_DIRTRIM`

Con `PROMPT_DIRTRIM=2`, bash recorta `\w` a los dos últimos componentes y pone
`...` al principio:

```bash
PROMPT_DIRTRIM=2
cd /tmp/t17/a/b/c/d/e
PS1='\w \$ '
# ~/.../d/e $
```

(En esa prueba `/tmp/t17` era el `HOME`, por eso sale `~`).

### 2.7 El coste

`$(...)` en `PS1` **corre un proceso por cada prompt**. Un `git status`
entero ahí hace tu terminal lenta en repositorios grandes. La rama sola
(`git branch --show-current`) es barata; el estado «sucio» (`git status
--porcelain`) no.

## 3. Cómo se usa

### 3.1 Un prompt pensado

La regla: **lo que te protege, siempre visible**; lo demás, lo mínimo.

- Máquina y usuario (`\u@\h`): imprescindible en SSH.
- `\$`: avisa de root.
- Directorio con `\w`, recortado con `PROMPT_DIRTRIM`.
- Código de salida si es distinto de cero: más silencioso que siempre.
- Color distinto en producción: lo que más evita desastres.

### 3.2 Color solo si hay terminal

Un prompt con colores no importa en un script, pero sí en `ssh -T` o cuando se
vuelca la salida. `PS1` solo se usa en shells interactivas; el `.bashrc` de
Ubuntu ya incluye la guarda (ver [archivo 01](01-como-arranca-bash.md)), así que
no tienes que preocuparte.

### 3.3 Divergencia de distro

El prompt por defecto cambia: **Ubuntu y Debian** usan `usuario@máquina:ruta$`
(con color si el terminal lo soporta); **RHEL** y **Arch** usan `[\u@\h \W]\$` (`[usuario@máquina directorio]$`). Es solo la plantilla del `.bashrc` o de `/etc/bashrc`, y se cambia igual.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Color sin `\[ \]` | La línea de edición se rompe al borde de la pantalla | Siempre `\[\e[..m\]` |
| `PS1="...$(cmd)..."` con comillas dobles | `$(cmd)` se evalúa **una vez** y queda fijo | Comillas simples |
| `git status` entero en `PS1` | Lento en repositorios grandes: cada Enter espera | Solo la rama, o una función con caché |
| Prompt de tres líneas | Menos historial visible | Una línea, y una segunda solo si hace falta |
| `PROMPT_COMMAND='cmd'` pisando el valor existente | Rompes lo que otro ya configuró | Añadir con `${PROMPT_COMMAND:+…; }` |
| Mismo prompt en producción y en desarrollo | Ejecutas un `rm` en el servidor equivocado | Un color o un `\h` visible distinto en producción |
| Mostrar el usuario y la máquina en un script | `PS1` no se usa fuera de la shell interactiva | Nada: `PS1` es solo para el prompt |

## 5. Trucos

- **`${PS1@P}`** prueba un prompt sin abrir una terminal. Con `printf '%q\n'`
  ves además los códigos de escape que genera.
- **`PS0`** (bash 4.4+) se muestra **después** de pulsar Enter y **antes** de que
  la orden empiece: útil para marcar la hora de inicio.
- **El título de la ventana** se fija con la secuencia `\e]0;texto\a` dentro
  de `\[ \]` en `PS1`: `PS1='\[\e]0;\u@\h: \w\a\]\$ '`. Así la pestaña del
  terminal muestra dónde estás.

## 📚 Recursos Adicionales

- `man bash`, sección **PROMPTING**: la lista completa de secuencias
- [Bash Prompt HOWTO (TLDP)](https://tldp.org/HOWTO/Bash-Prompt-HOWTO/): clásico, con ejemplos de color

## ✅ Checklist de Verificación

- [ ] Pruebas un `PS1` con `echo "[${PS1@P}]"` sin abrir otra terminal
- [ ] Añades color con `\[ \]` y ves con `printf '%q'` qué códigos genera
- [ ] Explicas la diferencia entre comillas simples y dobles en `PS1`
- [ ] Muestras el código de salida del último comando en el prompt
- [ ] Usas `PROMPT_COMMAND` y sabes que, desde bash 5.1, puede ser un array
- [ ] Recortas el directorio con `PROMPT_DIRTRIM`

---

[← Alias y funciones](03-alias-y-funciones.md) · [Historial y `readline` →](05-historial-y-readline.md)
