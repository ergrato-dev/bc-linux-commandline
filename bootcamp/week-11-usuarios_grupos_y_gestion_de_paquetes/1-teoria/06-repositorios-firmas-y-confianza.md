# Repositorios, firmas y confianza

> Instalar un paquete es ejecutar código ajeno **como `root`**. El gestor de
> paquetes es seguro solo mientras sepas de dónde viene lo que instala y
> quién garantiza que no lo cambiaron por el camino.

## 🎯 Objetivos

- Leer la lista de repositorios de cada familia y saber qué clave los firma
- Verificar a mano una firma de repositorio y el hash de un paquete
- Explicar por qué un `.deb` suelto no se verifica solo y un `.rpm` sí
- Reconocer los atajos de instalación que saltan toda esa cadena de confianza

## 1. Qué problema resuelve

Cuando ejecutas `apt install tree`, `apt` descarga un archivo de un
servidor (un *mirror*) que **no controlas**, y `dpkg` lo instala con
permisos de `root`: sus scripts de instalación se ejecutan antes de que
puedas mirar nada. Si alguien intercepta la descarga, o un mirror se
compromete, ese código llega a tu máquina con todos los privilegios.

La defensa es criptográfica: el repositorio publica un índice **firmado**
con una clave que ya tienes instalada; el índice lista el hash de cada
paquete; el gestor comprueba firma y hash antes de instalar. Si algo no
cuadra, **se niega a instalar**. Este archivo explica cada eslabón.

## 2. Cómo funciona

### 2.1 Dónde se declaran los repositorios

| Familia | Dónde | Qué clave los firma |
|---|---|---|
| Ubuntu/Debian | `/etc/apt/sources.list.d/*.sources` (formato *deb822*) y `/etc/apt/sources.list` | Campo `Signed-By:` de cada entrada |
| RHEL/Fedora | `/etc/yum.repos.d/*.repo` | `gpgcheck=1` y `gpgkey=` en cada repo |
| Arch | `/etc/pacman.conf` + `/etc/pacman.d/mirrorlist` | `SigLevel` + llavero de `pacman-key` |

En Ubuntu 24.04 el archivo es `ubuntu.sources`, con un bloque por
repositorio:

```bash
grep -v '^#' /etc/apt/sources.list.d/ubuntu.sources | head -6
# Types: deb
# URIs: http://archive.ubuntu.com/ubuntu/
# Suites: noble noble-updates noble-backports
# Components: main universe restricted multiverse
# Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

| Campo | Significa |
|---|---|
| `URIs` | El servidor del que se descarga |
| `Suites` | La release (`noble`) y sus canales: `-updates` (correcciones), `-backports` (versiones nuevas portadas), `-security` (seguridad) |
| `Components` | Secciones: `main` (soportado por Canonical), `universe` (comunidad), `restricted` y `multiverse` (licencias no libres) |
| `Signed-By` | **La única clave que puede firmar este repositorio** |

`Signed-By` es la mejora importante sobre el método antiguo: antes, una
clave añadida con `apt-key` valía para **todos** los repositorios; ahora
cada repositorio tiene la suya. `apt-key` está obsoleto por eso.

> 🔀 **Divergencia de distro**: en RHEL, la misma idea es `gpgkey=` por
> repo (`file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9`) con `gpgcheck=1`;
> la lista se ve con `dnf repolist`. En Arch, `SigLevel = Required
> DatabaseOptional` en `pacman.conf` exige firma válida en cada paquete y
> la firma de las bases es opcional.

### 2.2 La cadena de confianza de `apt`, paso a paso

El índice firmado se llama `InRelease` y `apt update` lo descarga. Puedes
**repetir a mano** la comprobación que `apt` hace sin que lo veas:

```bash
f=$(ls /var/lib/apt/lists/*noble_InRelease)
gpgv --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg "$f" 2>&1 | head -3
# gpgv: Signature made Thu Apr 25 15:11:21 2024 UTC
# gpgv:                using RSA key F6ECB3762474EDA9D21B7022871920D1991BC93C
# gpgv: Good signature from "Ubuntu Archive Automatic Signing Key (2018) <ftpmaster@ubuntu.com>"
```

`Good signature` es el primer eslabón: el índice lo firmó la clave de
`Signed-By`. El índice contiene el hash SHA-256 de cada paquete: ese es
el segundo eslabón, el mismo `sha256sum` que usaste en la Semana 09:

```bash
cd /tmp
apt-get download tree >/dev/null 2>&1

apt-cache show tree | grep -m1 '^SHA256'
# SHA256: 56edc302c11b1d35975ded0a38d52e98e82280b12a7a1c7a1b03e4772061731e

sha256sum tree_*.deb | cut -d' ' -f1
# 56edc302c11b1d35975ded0a38d52e98e82280b12a7a1c7a1b03e4772061731e
```

Los dos hashes coinciden: el paquete es **exactamente** el que el
repositorio firmó. Cambiar un solo byte cambia el hash entero:

```bash
cp tree_*.deb mal.deb && printf 'x' >> mal.deb
sha256sum mal.deb | cut -c1-20
# 1fb30322bc1c48e363c4       <- ya no es 56edc302...
```

El resumen de la cadena: **clave en `Signed-By` → firma del índice →
hash del paquete → paquete**. `apt` la recorre entera en cada instalación
desde un repositorio.

### 2.3 Un `.deb` suelto no se verifica; un `.rpm` sí

Aquí está una de las diferencias de fondo entre familias. El `mal.deb`
de arriba, con un byte de más, **`dpkg` lo abre sin quejarse**:

```bash
dpkg-deb -I mal.deb | tail -1 | cut -c1-60
#  Original-Maintainer: Florian Ernst <florian@debian.org>
```

Un `.deb` no lleva firma propia: la confianza viene **del índice
firmado del repositorio**, no del archivo. Descargado fuera de `apt`
(una web, un `curl`), no hay nadie que lo garantice.

Un `.rpm`, en cambio, va **firmado individualmente**, y `rpm -K` lo
comprueba:

```bash
# En rhel-lab: dnf install --downloadonly --destdir=/tmp/rpms tree
rpm -K /tmp/rpms/tree-1.8.0-10.el9.x86_64.rpm
# /tmp/rpms/tree-1.8.0-10.el9.x86_64.rpm: digests signatures OK

cp /tmp/rpms/tree*.rpm /tmp/rpms/mal.rpm && printf 'x' >> /tmp/rpms/mal.rpm
rpm -K /tmp/rpms/mal.rpm
# /tmp/rpms/mal.rpm: DIGESTS signatures NOT OK
```

> 🔀 **Divergencia de distro**: en RHEL/Fedora la firma viaja **con cada
> paquete** y `rpm -K` la valida en cualquier archivo, también uno
> sacado de una memoria USB. En Debian/Ubuntu la firma vive en el
> **índice**, no en el `.deb`: instalar un `.deb` descargado "de internet"
> significa confiar solo en quien te lo dio.

Las claves públicas ya aceptadas se ven así en cada familia:

```bash
# rhel-lab: las claves de confianza son paquetes "gpg-pubkey".
rpm -qa 'gpg-pubkey*'
# gpg-pubkey-350d275d-6279464b

# arch-lab: el llavero de pacman.
pacman-key --list-keys | head -3
```

### 2.4 Repositorios de terceros: PPA, EPEL, AUR

Los repositorios oficiales no lo tienen todo. Cada familia tiene su
vía de terceros, y cada una **añade una persona más en la cadena**:

| Familia | Vía | Qué te estás jugando |
|---|---|---|
| Ubuntu | PPA (`add-apt-repository ppa:usuario/nombre`) | Una cuenta personal de Launchpad puede publicar código que se ejecuta como `root` en tu máquina en cada `apt upgrade` |
| RHEL | EPEL y repos de terceros en `/etc/yum.repos.d` | EPEL lo mantiene una comunidad de confianza; un `.repo` cualquiera, no |
| Arch | AUR (`yay`, `paru`) | No son paquetes: son **recetas** (`PKGBUILD`) que se ejecutan en tu máquina; nadie las revisa por ti |

`add-apt-repository` ni siquiera viene en la imagen mínima de `ubuntu-lab`
(`command -v add-apt-repository` no imprime nada): se instala con el
paquete `software-properties-common`.

## 3. Cómo se usa

Una receta mínima de "añadir un repositorio de terceros con criterio":

1. **¿Hace falta?** Busca primero en los repositorios oficiales
   (`apt search`, `dnf search`, `pacman -Ss`).
2. **Descarga la clave a un archivo**, léela y comprueba su huella
   contra la web oficial del proyecto, por un canal distinto al de la
   descarga.
3. **Un `Signed-By` por repositorio** (apt), o `gpgcheck=1` + `gpgkey=`
   (dnf): nunca desactives la comprobación "para que funcione".
4. **Simula** antes de instalar (`apt-get -s install`) y lee de qué
   repositorio viene cada paquete (`apt-cache policy`).

```bash
# Que repositorio proporciona la version candidata de un paquete (500 = prioridad normal):
apt-cache policy tree | sed -n 1,5p
# tree:
#   Installed: (none)
#   Candidate: 2.1.1-2ubuntu3.24.04.2
#   Version table:
#      2.1.1-2ubuntu3.24.04.2 500
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `curl https://sitio/instalar.sh \| sudo bash` | Ejecutas **como `root` y sin leer** código que puede cambiar entre dos descargas | Descargar a un archivo, leerlo, comprobar hash, ejecutar con el mínimo necesario |
| `apt-get install --allow-unauthenticated` | Desactiva la comprobación de firma: cualquier intermediario manda | Arreglar la clave (`Signed-By`), nunca saltarse la firma |
| `[trusted=yes]` en un repositorio apt | Declara de confianza **todo** lo que sirva ese servidor | Una clave concreta en `Signed-By` |
| `gpgcheck=0` en un `.repo` | Igual: el `.rpm` ya no se valida | `gpgcheck=1` con `gpgkey=` explícita |
| `dpkg -i` de un `.deb` bajado de un foro | Sin firma ni índice detrás | El mismo paquete desde el repositorio, o compilar desde fuente verificada |
| Añadir un PPA por un tutorial sin mirar quién es | Confías para siempre en una cuenta desconocida | Revisar al autor y valorar si el paquete oficial basta |

## 5. Trucos

- `apt-cache policy` sin argumentos lista **todos los repositorios
  activos** con su prioridad: el modo más rápido de ver "de dónde me
  llegan paquetes" en una máquina que no conoces.
- `gpgv --keyring CLAVE.gpg ARCHIVO` valida una firma **sin tocar tu
  llavero personal**: ideal en scripts y en este laboratorio, donde
  `gnupg` completo no está instalado.
- `dnf repolist --all` incluye también los repos **desactivados**, que
  `dnf repolist` oculta: útil cuando "el paquete existe pero no aparece".
- `rpm -qi gpg-pubkey-350d275d-6279464b | grep Summary` dice **a quién
  pertenece** una clave instalada, algo que su nombre no revela.

## 📚 Recursos Adicionales

- `man sources.list`, `man apt-secure`, `man rpm` (sección `-K`), `man pacman-key`
- [Debian Wiki — SecureApt](https://wiki.debian.org/SecureApt)

## ✅ Checklist de Verificación

- [ ] `gpgv` sobre el `InRelease` de `noble` responde `Good signature from "Ubuntu Archive..."`
- [ ] El `SHA256` de `apt-cache show tree` coincide con `sha256sum` del `.deb` descargado
- [ ] `printf x >> mal.deb` cambia el `sha256sum` del archivo
- [ ] En `rhel-lab`, `rpm -K` da `NOT OK` sobre un `.rpm` modificado
- [ ] Puedes nombrar el campo que firma cada familia: `Signed-By`, `gpgkey=`, `SigLevel`

---

[← 05 — apt, dnf y pacman lado a lado](05-apt-dnf-y-pacman-lado-a-lado.md) · [Construyendo acctaudit y pkgcheck →](07-construyendo-acctaudit-y-pkgcheck.md)
