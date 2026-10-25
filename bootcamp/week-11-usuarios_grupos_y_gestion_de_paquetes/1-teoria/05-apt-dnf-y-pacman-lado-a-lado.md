# apt, dnf y pacman lado a lado

> El modelo es idéntico en las tres familias: refrescar el índice,
> buscar, instalar, actualizar, quitar. Lo que cambia es la sintaxis, y
> dos trampas que **no existen** en las otras familias.

## 🎯 Objetivos

- Ejecutar el ciclo completo (buscar, instalar, quitar) con `apt`, `dnf` y `pacman`
- Explicar la diferencia entre `apt update` y `apt upgrade`, y por qué `pacman -Sy` solo es peligroso
- Distinguir `remove` de `purge` y saber qué restos deja cada gestor
- Simular una operación antes de ejecutarla, en las tres familias

## 1. Qué problema resuelve

El archivo 04 explicó *qué* es un paquete. Este explica cómo se
**opera**: ¿cómo sé qué existe?, ¿cómo lo instalo?, ¿cómo lo quito sin
dejar basura?, ¿cómo actualizo el sistema entero? Alguien que conoce un
solo gestor se siente perdido en otra distro; alguien que conoce el
modelo traduce la sintaxis en segundos. La tabla de equivalencias de este
archivo es esa traducción.

## 2. Cómo funciona

### 2.1 Índice local contra paquetes instalados

Hay **dos listas distintas** y confundirlas es el error más común:

- El **índice**: una copia local del catálogo del repositorio ("qué
  versiones existen"). Se refresca de la red.
- La **base de datos local** (archivo 04): "qué tengo instalado".

```bash
apt-get update          # refresca el INDICE; no instala ni actualiza nada
apt list --upgradable 2>/dev/null | tail -n +2 | head -2
# libaudit-common/noble-updates 1:3.1.2-2.1ubuntu0.1 all [upgradable from: 1:3.1.2-2.1build1.1]
# libaudit1/noble-updates 1:3.1.2-2.1ubuntu0.1 amd64 [upgradable from: 1:3.1.2-2.1build1.1]

apt-get upgrade -y      # ahora si: instala las versiones nuevas
```

`apt update` y `apt upgrade` **no son lo mismo**: el primero actualiza el
catálogo, el segundo actualiza los programas. Sin `update` previo,
`upgrade` trabaja con un catálogo viejo.

### 2.2 El ciclo, en las tres familias

| Acción | Ubuntu/Debian (`apt`) | RHEL/Fedora (`dnf`) | Arch (`pacman`) |
|---|---|---|---|
| Refrescar índice | `apt update` | `dnf makecache` (o `dnf check-update`) | `pacman -Sy` (ver 2.3) |
| Actualizar todo | `apt upgrade` | `dnf upgrade` | `pacman -Syu` |
| Buscar | `apt search texto` | `dnf search texto` | `pacman -Ss texto` |
| Ver ficha remota | `apt show PAQ` | `dnf info PAQ` | `pacman -Si PAQ` |
| Instalar | `apt install PAQ` | `dnf install PAQ` | `pacman -S PAQ` |
| Quitar | `apt remove PAQ` | `dnf remove PAQ` | `pacman -R PAQ` |
| Quitar + configuración | `apt purge PAQ` | *(no existe)* | `pacman -Rn PAQ` |
| Quitar dependencias huérfanas | `apt autoremove` | `dnf autoremove` | `pacman -Rs PAQ` / `pacman -Qdtq` lista huérfanos |
| Sin preguntar (scripts) | `-y` | `-y` | `--noconfirm` |
| Simular sin tocar nada | `-s` / `--simulate` | `--assumeno` | `-Sp PAQ` (solo imprime la URL) |
| Limpiar caché de descargas | `apt clean` | `dnf clean all` | `pacman -Sc` |
| Historial de operaciones | `/var/log/apt/history.log` | `dnf history` | `/var/log/pacman.log` |

> 🔀 **Divergencia de distro**: esta tabla es la columna vertebral del
> archivo; los tres ejemplos de **Cómo se usa** la ejecutan de verdad.
> En scripts, `apt-get` es la interfaz estable; `apt` es la interfaz
> interactiva y avisa de ello (sección 4).

### 2.3 Trampa de Arch: `pacman -Sy` a secas

Arch es *rolling release*: no hay versiones fijas, todo se actualiza a la
última. Por eso `pacman -Sy paquete` (refrescar índice e instalar **sin**
actualizar el resto) produce una **actualización parcial**: el paquete
nuevo se compila contra librerías más recientes que las que tienes
instaladas, y puede no arrancar. La regla de Arch es: **`-Sy` siempre
acompañado de `-u`** (`pacman -Syu`) antes de instalar nada.

```bash
# En arch-lab, la primera vez: sin -Sy el indice esta vacio.
pacman -Ss '^tree$'
# warning: database file for 'core' does not exist (use '-Sy' to download)
# warning: database file for 'extra' does not exist (use '-Sy' to download)

pacman -Syu --noconfirm     # el camino correcto: indice y todo el sistema juntos
```

Ni `apt` ni `dnf` tienen esta trampa: sus versiones son fijas dentro de
una release de la distro.

### 2.4 `remove` contra `purge`: qué se queda atrás

`remove` quita **los programas** pero conserva los archivos de
**configuración** (por si reinstalas). `purge` quita todo. Se ve en la
primera columna de `dpkg -l` (archivo 04):

```bash
apt-get install -y cron           # (instalar cron en la imagen minima trae 50 paquetes nuevos)
dpkg -l cron | tail -1 | cut -c1-30
# ii  cron           3.0pl1-184u

apt-get remove -y cron
dpkg -l cron | tail -1 | cut -c1-30
# rc  cron           3.0pl1-184u         <- "rc": quitado, configuracion conservada

apt-get purge -y cron
dpkg -l cron 2>&1 | tail -1 | cut -c1-40
# un  cron           <none>       <none>  <- "un": desconocido, no instalado
```

> 🔀 **Divergencia de distro**: en RHEL/Fedora no existe `purge`.
> `dnf remove` borra el paquete y, si modificaste un archivo de
> configuración, lo deja renombrado como `*.rpmsave`. En Arch,
> `pacman -R` deja `*.pacsave` para lo modificado y `-Rn` descarta las
> copias de configuración. El resultado práctico es el mismo; el nombre
> de la herramienta no.

### 2.5 Dependencias huérfanas y `autoremove`

Al instalar `cron`, `apt` trajo **50 paquetes nuevos** por dependencias.
Al quitar `cron`, 46 de ellos quedan marcados como *instalados
automáticamente* y sin nadie que los necesite:

```bash
apt-get -s autoremove | grep -c '^Remv'      # -s: SIMULA, no borra nada
# 46
apt-get -s autoremove | grep '^Remv' | sed -n 2,3p | cut -c1-50
# Remv networkd-dispatcher [2.2.4-1]
# Remv systemd-resolved [255.4-1ubuntu8.18]
```

> ⚠️ **Advertencia**: `apt autoremove -y` a ciegas puede quitar
> **decenas** de paquetes que no esperabas, entre ellos algo que tu
> sistema usa de verdad sin saberlo. **Simula siempre primero** con `-s`
> y lee la lista; solo entonces ejecuta sin `-s`. En una máquina real,
> respalda `dpkg --get-selections > /tmp/paquetes.txt` antes.

Para evitar que `autoremove` se lleve un paquete que quieres conservar,
márcalo como instalado a mano: `apt-mark manual PAQ`. `apt-mark showmanual`
lista lo que el sistema considera "elegido por una persona".

## 3. Cómo se usa

El mismo objetivo, "instalar `tree`", en las tres familias, con la
comprobación de cada una:

```bash
# ubuntu-lab / debian-lab
apt-get update && apt-get install -y tree
dpkg -l tree | tail -1 | cut -c1-20
# ii  tree           2

# rhel-lab
dnf install -y tree
rpm -q tree
# tree-1.8.0-10.el9.x86_64

# arch-lab
pacman -Syu --noconfirm && pacman -S --noconfirm tree
pacman -Q tree
# tree 2.3.2-1
```

Y la **vista previa** antes de aplicar, en las que la tienen:

```bash
apt-get -s install tmux | grep -E '^Inst' | cut -c1-30
# Inst libevent-core-2.1-7t64 (2
# Inst libutempter0 (1.2.1-3bui
# Inst tmux (3.4-1ubuntu0.2 Ubu

dnf install --assumeno tree 2>&1 | tail -3
# Total download size: 55 k
# Installed size: 113 k
# Operation aborted.
```

Regla del bootcamp: un comando destructivo necesita aviso y respaldo.
Instalar rara vez lo es; **quitar sí**. Antes
de `remove` o `autoremove` en un sistema que importa: simular y leer.

Para saber **qué se hizo en esta máquina**, el historial:

```bash
grep Commandline /var/log/apt/history.log | tail -2
# Commandline: apt-get install -y cron
# Commandline: apt-get remove -y cron
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `apt install` sin `apt update` antes | Intenta bajar versiones que ya no existen en el repositorio (`404 Not Found`) | `apt-get update && apt-get install` |
| `apt autoremove -y` sin simular | Puede quitar decenas de paquetes en un solo comando | `apt-get -s autoremove`, leer, luego ejecutar |
| `apt` (no `apt-get`) en un script | Imprime `WARNING: apt does not have a stable CLI interface` y su salida no es estable entre versiones | `apt-get` en scripts, `apt` en terminal |
| `pacman -Sy paquete` | Actualización parcial: puede romper el sistema | `pacman -Syu` siempre |
| `-y`/`--noconfirm` sin haber visto el plan | Aceptas lo que no has leído | Primera vez sin `-y`; en scripts, tras simular |
| `apt-get upgrade` a diario en un servidor sin mirar | Reinicia servicios, cambia versiones mayores | `apt list --upgradable` primero y una ventana de mantenimiento |
| `apt remove` creyendo que borra la configuración | Quedan los archivos de configuración (`rc`) | `apt purge` si de verdad no los quieres |

## 5. Trucos

- `apt-mark hold PAQ` **congela** la versión de un paquete: `apt upgrade`
  lo ignora. `apt-mark showhold` lista los congelados y `apt-mark unhold`
  lo libera. En RHEL, el equivalente es `dnf versionlock` (plugin).
- `apt-cache policy PAQ` muestra de **qué repositorio** vendría cada
  versión (`500` indica la prioridad) y cuál está instalada: la respuesta
  a "¿por qué me instala esta versión y no otra?".
- `dnf history undo N` revierte la transacción `N` de `dnf history`:
  deshacer una instalación o desinstalación completa con dependencias.
- `pacman -Qdtq` imprime solo los **nombres** de los paquetes huérfanos,
  listos para `pacman -Rs $(pacman -Qdtq)`; si no hay ninguno, no imprime
  nada y el comando falla de forma segura.

## 📚 Recursos Adicionales

- `man apt-get`, `man apt-mark`, `man dnf`, `man pacman`
- [Arch Wiki — pacman (partial upgrades)](https://wiki.archlinux.org/title/Pacman#Installing_packages)

## ✅ Checklist de Verificación

- [ ] `apt-get install -y cron` seguido de `apt-get remove -y cron` deja `rc` en `dpkg -l cron`
- [ ] `apt-get purge -y cron` lo pasa a `un`
- [ ] `apt-get -s autoremove | grep -c '^Remv'` imprime un número sin borrar nada
- [ ] En `rhel-lab`, `dnf install --assumeno tree` termina con `Operation aborted.`
- [ ] En `arch-lab`, `pacman -Syu --noconfirm` va **antes** de cualquier `pacman -S`

---

[← 04 — Qué es un gestor de paquetes](04-que-es-un-gestor-de-paquetes.md) · [Repositorios, firmas y confianza →](06-repositorios-firmas-y-confianza.md)
