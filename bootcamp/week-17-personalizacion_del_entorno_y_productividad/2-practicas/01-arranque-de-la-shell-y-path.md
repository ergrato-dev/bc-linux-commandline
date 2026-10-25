# Práctica 01 — El arranque de la shell y el `PATH`

> Duración estimada: 60 min · Teoría de apoyo: archivos [01](../1-teoria/01-como-arranca-bash.md) y [02](../1-teoria/02-variables-de-entorno-y-path.md)

Trabajas **dentro de `ubuntu-lab`**. Casi todo se prueba con un `HOME` de
juguete en `/tmp/p17`, así que **no tocas** tu `~/.bashrc` ni tu `~/.profile`
reales.

```bash
docker exec -it ubuntu-lab bash
mkdir -p /tmp/p17 && cd /tmp/p17
```

## Paso 1: Instalar lo que usará la semana

**Por qué**: las prácticas de esta semana usan `tmux` (para probar un prompt y
un autocompletado sin teclado), `bash-completion` y `git`. La imagen mínima no
los trae.

**Comando**:

```bash
# -qq: casi sin salida. Los tres paquetes se llaman igual en apt, dnf y pacman.
apt-get update -qq
apt-get install -y -qq tmux bash-completion git
```

**Verifica**:

```bash
tmux -V
# tmux 3.4
ls /usr/share/bash-completion/bash_completion
# /usr/share/bash-completion/bash_completion
```

## Paso 2: ¿Qué clase de shell soy?

**Por qué**: todo lo demás depende de dos respuestas: ¿login? ¿interactiva? Si
no sabes contestarlas, no sabes qué archivo editar.

**Comando**:

```bash
# La shell en la que escribes (docker exec -it la lanza interactiva y sin login):
shopt login_shell
# `echo $-` contiene "i" si es interactiva. En un -c no la tiene:
bash -c 'echo $-'
# Pidiendo login a mano (-l) o no:
bash -lc 'shopt login_shell'
bash -c 'shopt login_shell'
```

**Verifica**:

```bash
bash -c 'echo $-' | grep -c i
# 0
bash -lc 'shopt login_shell' | grep -c on
# 1
```

El primero sale `0` porque `bash -c` **no** es interactiva (su `$-` es `hBc`, sin
`i`); el segundo `1` porque `-l` la hace de login.

## Paso 3: Tres arranques, tres archivos distintos

**Por qué**: comprobar por ti mismo que cada forma de arrancar lee **otros**
archivos. Cada archivo del `HOME` de juguete solo anuncia su nombre.

**Comando**:

```bash
rm -rf /tmp/p17/h1 && mkdir /tmp/p17/h1
for f in .bash_profile .bash_login .profile .bashrc .bash_logout; do
  printf 'echo "  [leido %s]"\n' "$f" > "/tmp/p17/h1/$f"
done
# Login, sin interactiva:
HOME=/tmp/p17/h1 bash -lc 'echo cmd'
#   [leido .bash_profile]
# cmd
# Interactiva, sin login (2>/dev/null calla un aviso por no tener terminal):
HOME=/tmp/p17/h1 bash -ic 'echo cmd' 2>/dev/null
#   [leido .bashrc]
# cmd
# Ni lo uno ni lo otro, como un script:
HOME=/tmp/p17/h1 bash -c 'echo cmd'
# cmd
# Las dos a la vez, lo que obtienes entrando por SSH a un terminal:
HOME=/tmp/p17/h1 bash -lic 'echo cmd' 2>/dev/null
#   [leido .bash_profile]
# cmd
```

**Verifica**:

```bash
HOME=/tmp/p17/h1 bash -lic 'true' 2>/dev/null | grep -c leido
# 1
HOME=/tmp/p17/h1 bash -ic 'true' 2>/dev/null | grep -c bashrc
# 1
HOME=/tmp/p17/h1 bash -c 'true' | wc -l
# 0
```

## Paso 4: Solo el primero que exista, y `.bash_logout`

**Por qué**: un login lee **un** archivo de tres. Crear un `.bash_profile` «para
el `PATH`» tapa al `.profile` sin avisar: lo verás desaparecer.

**Comando**:

```bash
rm /tmp/p17/h1/.bash_profile
HOME=/tmp/p17/h1 bash -lc 'echo cmd'
#   [leido .bash_login]
# cmd
rm /tmp/p17/h1/.bash_login
HOME=/tmp/p17/h1 bash -lc 'echo cmd'
#   [leido .profile]
# cmd
# Un login lee ademas .bash_logout AL SALIR:
HOME=/tmp/p17/h1 bash -lc 'exit'
#   [leido .profile]
#   [leido .bash_logout]
```

**Verifica**:

```bash
HOME=/tmp/p17/h1 bash -lc 'true' | grep -c 'profile\|login'
# 1
```

## Paso 5: Por qué `.profile` carga `.bashrc` (y la trampa del `.bash_profile`)

**Por qué**: el `.profile` de Ubuntu lleva una línea que carga `.bashrc`, por
eso tus alias funcionan por SSH. Si creas un `.bash_profile`, esa línea **deja
de ejecutarse** y los alias desaparecen.

**Comando**:

```bash
rm -rf /tmp/p17/h2 && mkdir /tmp/p17/h2
cp /etc/skel/.profile /etc/skel/.bashrc /tmp/p17/h2/
# Con los archivos de Ubuntu, "ll" existe en un login interactivo:
env -i HOME=/tmp/p17/h2 PATH=/usr/bin:/bin bash -lic 'type -t ll' 2>/dev/null
# alias
# Creas un .bash_profile "para el PATH": ahora .profile NO se lee.
printf 'echo "  [mi .bash_profile]"\n' > /tmp/p17/h2/.bash_profile
env -i HOME=/tmp/p17/h2 PATH=/usr/bin:/bin bash -lic 'type -t ll || echo "ll: sin alias"' 2>/dev/null
#   [mi .bash_profile]
# ll: sin alias
# Arreglo: que .bash_profile cargue .profile
printf '. ~/.profile\n' >> /tmp/p17/h2/.bash_profile
env -i HOME=/tmp/p17/h2 PATH=/usr/bin:/bin bash -lic 'type -t ll || echo "ll: sin alias"' 2>/dev/null
#   [mi .bash_profile]
# alias
```

**Verifica**:

```bash
env -i HOME=/tmp/p17/h2 PATH=/usr/bin:/bin bash -lic 'type -t ll' 2>/dev/null | tail -1
# alias
```

## Paso 6: `export` y la herencia

**Por qué**: una variable sin `export` se queda en tu shell. Comprueba qué ve el
proceso hijo, y que lo que el hijo cambia **no vuelve**.

**Comando**:

```bash
MIVAR=hola
bash -c 'echo "hijo: [${MIVAR:-vacio}]"'
# hijo: [vacio]
export MIVAR
bash -c 'echo "hijo: [${MIVAR:-vacio}]"'
# hijo: [hola]
bash -c 'MIVAR=cambiado'
echo "padre: $MIVAR"
# padre: hola
unset MIVAR
# Una variable solo para UN comando, sin dejar rastro:
EDITOR=nano bash -c 'echo "dentro: $EDITOR"'
# dentro: nano
echo "fuera: [${EDITOR:-vacio}]"
# fuera: [vacio]
```

**Verifica**:

```bash
X17=1 bash -c 'echo $X17'; echo "[${X17:-vacio}]"
# 1
# [vacio]
```

## Paso 7: El orden del `PATH` decide quién gana

**Por qué**: dos programas con el mismo nombre: gana el del **primer** directorio.
Es el motivo por el que `~/bin` va delante. Y una entrada vacía en el `PATH`
ejecuta lo que haya en el directorio actual.

**Comando**:

```bash
mkdir -p /tmp/p17/a /tmp/p17/b
printf '#!/bin/sh\necho desde-a\n' > /tmp/p17/a/hola
printf '#!/bin/sh\necho desde-b\n' > /tmp/p17/b/hola
chmod +x /tmp/p17/a/hola /tmp/p17/b/hola
PATH=/tmp/p17/a:/tmp/p17/b:$PATH hola
# desde-a
PATH=/tmp/p17/b:/tmp/p17/a:$PATH hola
# desde-b
PATH=/tmp/p17/a:/tmp/p17/b:$PATH bash -c 'type -a hola'
# hola is /tmp/p17/a/hola
# hola is /tmp/p17/b/hola
# Entrada vacia (un ":" al principio) = el directorio donde estas:
cd /tmp/p17/a && PATH=":$PATH" hola; cd /tmp/p17
# desde-a
```

**Verifica**:

```bash
PATH=/tmp/p17/b:/tmp/p17/a:$PATH hola
# desde-b
```

## Paso 8: La caché de `hash`

**Por qué**: bash recuerda dónde encontró cada comando. Si instalas uno mejor
**delante**, sigue usando el viejo hasta que lo olvide: el origen de «instalé la
versión nueva y sigue saliendo la vieja».

**Comando**:

```bash
rm -rf /tmp/p17/q1 /tmp/p17/q2 && mkdir /tmp/p17/q1 /tmp/p17/q2
printf '#!/bin/sh\necho viejo\n' > /tmp/p17/q2/hola && chmod +x /tmp/p17/q2/hola
cat > /tmp/p17/h.sh << 'EOF'
rm -f /tmp/p17/q1/hola
PATH=/tmp/p17/q1:/tmp/p17/q2:$PATH
hola
printf '#!/bin/sh\necho nuevo\n' > /tmp/p17/q1/hola; chmod +x /tmp/p17/q1/hola
hola
hash -t hola
hash -r
hola
EOF
bash /tmp/p17/h.sh
# viejo
# viejo
# /tmp/p17/q2/hola
# nuevo
```

**Verifica**:

```bash
bash /tmp/p17/h.sh | sed -n '2p;4p'
# viejo
# nuevo
```

(La segunda línea es el segundo `hola`, aún `viejo`; la cuarta, el tercero tras
`hash -r`. El script empieza borrando `q1/hola`, así que se puede repetir.)

## Paso 9: `~/bin` solo aparece **al entrar**

**Por qué**: el `.profile` de Ubuntu añade `~/bin` al `PATH` **si existe en el
momento del login**. Creas el directorio, instalas tu script, y no lo encuentra:
no es un error, es que no has vuelto a entrar. Y un script (`bash -c`) jamás lo
ve.

**Comando**:

```bash
rm -rf /tmp/p17/h3 && mkdir /tmp/p17/h3 && cp /etc/skel/.profile /tmp/p17/h3/
env -i HOME=/tmp/p17/h3 PATH=/usr/bin:/bin bash -lc 'echo $PATH'
# /usr/bin:/bin
mkdir -p /tmp/p17/h3/bin
printf '#!/bin/sh\necho mi-herramienta\n' > /tmp/p17/h3/bin/mi-herramienta
chmod +x /tmp/p17/h3/bin/mi-herramienta
env -i HOME=/tmp/p17/h3 PATH=/usr/bin:/bin bash -lc 'echo $PATH'
# /tmp/p17/h3/bin:/usr/bin:/bin
env -i HOME=/tmp/p17/h3 PATH=/usr/bin:/bin bash -lc 'mi-herramienta'
# mi-herramienta
env -i HOME=/tmp/p17/h3 PATH=/usr/bin:/bin bash -c 'mi-herramienta' 2>&1
# bash: line 1: mi-herramienta: command not found
```

**Verifica**:

```bash
env -i HOME=/tmp/p17/h3 PATH=/usr/bin:/bin bash -lc 'command -v mi-herramienta'
# /tmp/p17/h3/bin/mi-herramienta
```

## Paso 10: Añadir al `PATH` sin duplicar

**Por qué**: `PATH="$HOME/bin:$PATH"` en un archivo que se lee varias veces
acumula copias. El patrón con `case` es el que usan RHEL y Arch en su
`/etc/profile`.

**Comando**:

```bash
anadir() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
PATH=/usr/bin:/bin; anadir /opt/x; anadir /opt/x; anadir /opt/y
echo "$PATH"
# /opt/y:/opt/x:/usr/bin:/bin
# Sin la guarda, dos veces la misma linea duplican la entrada:
PATH=/usr/bin:/bin; PATH="/opt/x:$PATH"; PATH="/opt/x:$PATH"
echo "$PATH"
# /opt/x:/opt/x:/usr/bin:/bin
```

**Verifica**:

```bash
PATH=/usr/bin:/bin; anadir /opt/x; anadir /opt/x
echo "$PATH" | tr ':' '\n' | sort | uniq -d | wc -l
# 0
```

## ✅ Resultado

- [ ] Sabes decir si tu shell es de login y si es interactiva, y compruebas ambas cosas
- [ ] Reproduciste los tres arranques y qué archivo lee cada uno
- [ ] Demostraste que un login lee **solo uno** de los tres y que `.bash_logout` se lee al salir
- [ ] Viste desaparecer los alias al crear un `.bash_profile`, y lo arreglaste
- [ ] Probaste `export` frente a una variable local y `VAR=valor comando`
- [ ] Predijiste cuál de dos `hola` se ejecuta y limpiaste la caché de `hash`
- [ ] Comprobaste que `~/bin` solo entra en el `PATH` al hacer login
- [ ] Añades al `PATH` sin duplicar

Cuando termines, ve a la [práctica 02](02-alias-prompt-e-historial.md). No hay
nada que verificar con `verificar-semana.sh` hasta la práctica 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `bash: cannot set terminal process group` | Una `bash -i` sin terminal; es solo un aviso | `2>/dev/null` |
| `bash -lic` no muestra `[leido .bashrc]` | Un login lee `.bash_profile` o `.profile`, no `.bashrc` | Es lo esperado (paso 3) |
| `ll` no existe en tu shell | La imagen mínima no tiene alias | Define el alias tú: no es un fallo |
| `tmux: command not found` | Falta el paquete | Repite el paso 1 |
| `hash -t hola` no imprime nada | `hola` aún no se ha ejecutado en esa shell | Ejecuta `hola` antes |
| Tu `PATH` real se ve alterado | Usaste `PATH=...` sin el prefijo del comando y sin `env -i` | Cierra la shell y abre otra: nada se guarda |

---

[← Dotfiles y `toolkit dotfiles`](../1-teoria/08-dotfiles-y-construyendo-dotfiles.md) · [Práctica 02: alias, prompt e historial →](02-alias-prompt-e-historial.md)
