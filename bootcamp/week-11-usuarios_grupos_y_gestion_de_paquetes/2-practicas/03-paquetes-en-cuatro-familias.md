# Práctica 03: paquetes en cuatro familias

El mismo objetivo, "instalar, consultar y quitar `tree`", en los cuatro
contenedores del laboratorio. `ubuntu-lab` es el canónico; los otros tres
son de exploración y sirven para **ver** la divergencia, no para
calificarla.

Los comandos de `docker exec` se ejecutan desde **tu máquina**; cada uno
termina solo, no hace falta entrar a los contenedores.

## Paso 1: Refrescar el índice y buscar (ubuntu-lab)

**Por qué**: el índice local es una copia del catálogo del repositorio. Sin
refrescarlo, `apt` busca versiones que pueden ya no existir (archivo 05).

**Comando**:

```bash
docker exec ubuntu-lab apt-get update
docker exec ubuntu-lab apt search '^tree$'
docker exec ubuntu-lab apt-cache policy tree
```

**Verifica**:

```bash
docker exec ubuntu-lab apt-cache policy tree | sed -n 1,3p
# tree:
#   Installed: (none)
#   Candidate: 2.1.1-2ubuntu3.24.04.2
```

`Installed: (none)` y un `Candidate` dicen: existe en el repositorio, no
está en tu máquina.

## Paso 2: Instalar, consultar y quitar (ubuntu-lab)

**Por qué**: las tres preguntas del archivo 04 (¿está?, ¿de quién es este
archivo?, ¿qué trajo?) contestadas contra la base de `dpkg`.

**Comando**:

```bash
docker exec ubuntu-lab apt-get install -y tree
docker exec ubuntu-lab dpkg -l tree
docker exec ubuntu-lab dpkg -S /usr/bin/tree
docker exec ubuntu-lab dpkg -L tree
```

**Verifica**:

```bash
docker exec ubuntu-lab dpkg -S /usr/bin/tree
# tree: /usr/bin/tree

docker exec ubuntu-lab dpkg -l tree | tail -1 | cut -c1-30
# ii  tree           2.1.1-2ubun
```

Y la desinstalación, con comprobación de que el programa desapareció:

```bash
docker exec ubuntu-lab apt-get remove -y tree
docker exec ubuntu-lab bash -c 'command -v tree || echo "tree ya no esta"'
# tree ya no esta
```

## Paso 3: `remove` contra `purge` con un paquete que sí guarda configuración

**Por qué**: `tree` no tiene archivos de configuración, así que `remove` y
`purge` dan el mismo resultado. `cron` sí los tiene, y deja ver el estado
`rc`.

**Comando**:

```bash
docker exec ubuntu-lab apt-get install -y cron
docker exec ubuntu-lab apt-get remove -y cron
docker exec ubuntu-lab bash -c 'dpkg -l cron | tail -1 | cut -c1-30'
```

**Verifica**: el estado es `rc` (quitado, configuración conservada).

```bash
# rc  cron           3.0pl1-184u
docker exec ubuntu-lab apt-get purge -y cron
docker exec ubuntu-lab bash -c 'dpkg -l cron 2>&1 | tail -1 | cut -c1-40'
# un  cron           <none>       <none>
```

## Paso 4: Simular antes de limpiar dependencias

> ⚠️ **Advertencia**: `apt autoremove` puede quitar decenas de paquetes
> de una vez. Este paso **solo simula** (`-s`); no borra nada. Si luego
> decides ejecutarlo de verdad, hazlo sabiendo que en este laboratorio
> es seguro (se recrea con `./scripts/stop.sh && ./scripts/start.sh`),
> pero **nunca** a ciegas en una máquina que importa.

**Por qué**: instalar `cron` trajo decenas de dependencias. Tras quitarlo,
quedan sin dueño. `-s` muestra qué se llevaría `autoremove`.

**Comando**:

```bash
docker exec ubuntu-lab bash -c 'apt-get -s autoremove | grep -c "^Remv"'
docker exec ubuntu-lab bash -c 'apt-get -s autoremove | grep "^Remv" | head -3'
```

**Verifica**: un número de dos cifras y una lista de nombres reales
(los números exactos varían con el estado de la imagen). Y la prueba de que
la simulación **no desinstaló nada**: el conteo de paquetes instalados es el
mismo antes y después.

```bash
docker exec ubuntu-lab bash -c '
  antes=$(dpkg -l | grep -c "^ii")
  apt-get -s autoremove >/dev/null
  despues=$(dpkg -l | grep -c "^ii")
  [ "$antes" = "$despues" ] && echo "sin cambios: $antes paquetes"'
# sin cambios: 142 paquetes       <- tu numero puede variar, pero antes == despues
```

## Paso 5: El mismo ciclo en RHEL (rhel-lab, `dnf`)

**Por qué**: mismo modelo, otra sintaxis. Y una divergencia concreta: aquí
**no existe `purge`**.

**Comando**:

```bash
docker exec rhel-lab dnf search tree
docker exec rhel-lab dnf install -y tree
docker exec rhel-lab rpm -q tree
docker exec rhel-lab rpm -qf /usr/bin/tree
```

**Verifica**:

```bash
docker exec rhel-lab rpm -q tree
# tree-1.8.0-10.el9.x86_64

docker exec rhel-lab rpm -qf /usr/bin/tree
# tree-1.8.0-10.el9.x86_64
```

Quitar, y ver que `rpm` **imprime el error por stdout** (el motivo por el
que `pkgcheck` decide por el código de salida):

```bash
docker exec rhel-lab dnf remove -y tree
docker exec rhel-lab rpm -q tree; echo "codigo: $?"
# package tree is not installed
# codigo: 1
```

## Paso 6: El mismo ciclo en Arch (arch-lab, `pacman`)

**Por qué**: Arch es *rolling*: un `pacman -S` sin actualizar antes puede
producir una actualización parcial (archivo 05). Aquí se hace bien: `-Syu`.

**Comando**:

```bash
docker exec arch-lab pacman -Syu --noconfirm
docker exec arch-lab pacman -Ss '^tree$'
docker exec arch-lab pacman -S --noconfirm tree
docker exec arch-lab pacman -Q tree
docker exec arch-lab pacman -Qo /usr/bin/tree
```

**Verifica**:

```bash
docker exec arch-lab pacman -Q tree
# tree 2.3.2-1

docker exec arch-lab pacman -Qo /usr/bin/tree
# /usr/bin/tree is owned by tree 2.3.2-1
```

Quitar y comprobar:

```bash
docker exec arch-lab pacman -R --noconfirm tree
docker exec arch-lab pacman -Q tree; echo "codigo: $?"
# error: package 'tree' was not found
# codigo: 1
```

## Paso 7: Debian, el mismo `apt` con otra versión (debian-lab)

**Por qué**: Debian y Ubuntu comparten `apt`/`dpkg`, pero **no las
versiones**: el mismo paquete cambia de versión entre releases.

**Comando**:

```bash
docker exec debian-lab apt-get update
docker exec debian-lab apt-get install -y tree
docker exec debian-lab dpkg-query -W tree
```

**Verifica**:

```bash
docker exec debian-lab dpkg-query -W tree
# tree	2.1.0-1
```

Limpia: `docker exec debian-lab apt-get remove -y tree`.

## Paso 8: Verificar la firma y el hash a mano

**Por qué**: es la cadena de confianza del archivo 06 puesta en práctica,
con el mismo `sha256sum` de la Semana 09.

**Comando**:

```bash
docker exec ubuntu-lab bash -c '
  f=$(ls /var/lib/apt/lists/*noble_InRelease)
  gpgv --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg "$f" 2>&1 | grep "Good signature"
  cd /tmp && apt-get download tree >/dev/null 2>&1
  apt-cache show tree | grep -m1 "^SHA256"
  sha256sum tree_*.deb | cut -d" " -f1
  rm -f tree_*.deb'
```

**Verifica**: `Good signature from "Ubuntu Archive..."` y los dos hashes
**idénticos**.

## ✅ Resultado

- [ ] Instalaste, consultaste (`dpkg -S`, `dpkg -L`) y quitaste `tree` en `ubuntu-lab`
- [ ] Viste el estado `rc` tras `remove` y `un` tras `purge` con `cron`
- [ ] Simulaste `autoremove` con `-s` sin borrar nada
- [ ] Repetiste el ciclo con `dnf`/`rpm` en `rhel-lab` y `pacman` en `arch-lab`
- [ ] Verificaste una firma con `gpgv` y comparaste `SHA256` con `sha256sum`

```bash
./scripts/verificar-semana.sh 11
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `E: Unable to locate package tree` en Ubuntu/Debian | Índice vacío en un contenedor recién creado | `apt-get update` antes |
| `Could not resolve host` / errores de descarga | El contenedor no tiene salida a internet | Comprobar `docker exec ubuntu-lab apt-get update`; revisar la red de Docker del host |
| `warning: database file for 'core' does not exist` en Arch | Nunca se hizo `-Sy` | `pacman -Syu --noconfirm` |
| `pacman -Syu` tarda varios minutos | La imagen `archlinux:base` se actualiza entera | Es normal la primera vez; las siguientes ya van rápido |
| `dnf` pide confirmación y se queda esperando | Falta `-y` | Añadir `-y` (o `--assumeno` si solo querías simular) |
| `dpkg -S /bin/ls` no encuentra nada | `/bin` es un enlace a `/usr/bin` | `dpkg -S "$(readlink -f /bin/ls)"` |

---

[← Práctica 02](02-sudo-con-criterio.md) · [Práctica 04 →](04-acctaudit-y-pkgcheck-a-mano.md)
