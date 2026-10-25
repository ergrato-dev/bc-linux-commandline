# Instalar, verificar y quitar

> Un paquete que se instala pero no se puede verificar ni quitar limpio es un `cp` con papeles.
> `dpkg` te da las tres cosas; solo hay que saber qué pregunta responde cada orden.

## 🎯 Objetivos

- Instalar, actualizar y degradar un paquete local con `dpkg -i` y `apt install ./`
- Saber a quién pertenece un archivo (`dpkg -S`) y qué instaló un paquete (`dpkg -L`)
- Detectar un archivo modificado con `dpkg --verify` y leer su salida
- Distinguir `-r` (quitar) de `-P` (purgar)
- Explicar por qué una imagen mínima puede no instalar la página de manual

> **Aquí se instala de verdad**, dentro de `ubuntu-lab`. Es un contenedor
> desechable: instalar y quitar `toolkit` no toca tu máquina. En tu equipo real,
> hazlo con cuidado y solo con paquetes cuyo contenido hayas revisado.

## 1. Qué problema resuelve

Tras copiar un archivo con `cp`, el sistema no sabe que existe. Con un paquete,
`dpkg` mantiene una base de datos (`/var/lib/dpkg/`) con **qué archivos pertenecen
a quién, con qué suma y en qué versión**. De ahí salen cuatro capacidades que
`cp` no tiene: actualizar sin dejar restos, comprobar que nadie ha tocado un
archivo, saber de dónde viene cualquier ruta, y desinstalar completo.

## 2. Cómo funciona

### 2.1 Instalar y actualizar

`dpkg -i` instala un `.deb` local. Si ya hay otra versión, la **actualiza**:

```bash
dpkg -i toolkit_1.0.0_all.deb
# Unpacking toolkit (1.0.0) ...
# Setting up toolkit (1.0.0) ...
dpkg -i toolkit_1.1.0_all.deb
# Preparing to unpack toolkit_1.1.0_all.deb ...
# Unpacking toolkit (1.1.0) over (1.0.0) ...
# Setting up toolkit (1.1.0) ...
toolkit version
# toolkit 1.1.0
```

Instalar una versión **menor** que la actual funciona, pero avisa:

```bash
dpkg -i toolkit_1.0.0_all.deb
# dpkg: warning: downgrading toolkit from 1.1.0 to 1.0.0
```

Ese aviso es el que merece una pausa. Nunca lo ignores en producción: casi
siempre significa que instalaste el paquete equivocado.

`dpkg -i` **no resuelve dependencias**: si el `Depends` pide algo que falta,
queda a medio instalar. `apt install ./archivo.deb` hace lo mismo y además
instala lo que falte desde los repositorios:

```bash
apt-get install -y ./toolkit_1.0.0_all.deb
# Unpacking toolkit (1.0.0) ...
# Setting up toolkit (1.0.0) ...
```

(La `./` es necesaria: sin ella `apt` busca un paquete con ese nombre en el
repositorio.)

### 2.2 Preguntar al sistema

| Orden | Responde |
|---|---|
| `dpkg -l toolkit` | ¿Está instalado? Estado `ii` = instalado |
| `dpkg -s toolkit` | La ficha completa: estado, versión, tamaño, descripción |
| `dpkg -L toolkit` | ¿Qué archivos instaló? |
| `dpkg -S /usr/bin/toolkit` | ¿A qué paquete pertenece este archivo? |

```bash
dpkg -L toolkit
# /.
# /usr
# /usr/bin
# /usr/bin/toolkit
# /usr/share
# /usr/share/man
# /usr/share/man/man1
# /usr/share/man/man1/toolkit.1.gz
dpkg -S /usr/bin/toolkit
# toolkit: /usr/bin/toolkit
dpkg -S /usr/bin/ls
# coreutils: /usr/bin/ls
```

`dpkg -S` es la respuesta a «¿de dónde ha salido esto?». Si un archivo del
sistema devuelve `no path found matching pattern`, **no lo instaló ningún paquete**:
alguien lo copió a mano.

(Usa la ruta real: en sistemas con `/bin` enlazado a `/usr/bin`, `dpkg -S /bin/ls`
no encuentra nada y `dpkg -S /usr/bin/ls` sí.)

### 2.3 Verificar: `dpkg --verify`

Compara los archivos instalados con las sumas MD5 que el paquete guardó en
`md5sums`. Una salida **vacía** significa «todo igual»:

```bash
dpkg --verify toolkit
# (sin salida: todo coincide)
echo "# x" >> /usr/bin/toolkit
dpkg --verify toolkit
# ??5??????   /usr/bin/toolkit
```

La cadena `??5??????` son nueve posiciones de comprobación; `dpkg` solo sabe
calcular la tercera, la **suma MD5**, y deja las demás en `?`. Un `5` ahí
significa «el contenido ha cambiado». Si el archivo no existe, en lugar de la
cadena verás la palabra `missing`. Nada más: **`dpkg --verify` no detecta
cambios de permisos ni de propietario**, solo de contenido y ausencias.

(En `ubuntu-lab` la primera salida **no** estará vacía: verás un `missing` de la
página de manual. Es el efecto que se explica en la sección 2.5.)

Dos cosas que sorprenden:

- `dpkg --verify` **sale con 0 aunque haya diferencias**. Hay que leer la salida,
  o comprobar que está vacía: `[ -z "$(dpkg --verify toolkit)" ]`.
- Es una comprobación de **integridad**, no de seguridad: MD5 detecta errores y
  cambios accidentales, no un atacante que reescriba también `md5sums`. Para eso
  existe la firma de los repositorios (Semana 11).

### 2.4 Quitar: `-r` frente a `-P`

```bash
dpkg -r toolkit      # remove: quita los archivos, conserva la configuración
dpkg -P toolkit      # purge: quita también la configuración
```

Para `toolkit`, que no instala ningún archivo de configuración, ambas hacen lo
mismo. La diferencia aparece con los archivos de `/etc` declarados como
*conffiles* en `DEBIAN/conffiles`: `-r` los deja (por si reinstalas), `-P` los
borra. Ya la viste en la Semana 11 con `apt remove` y `apt purge`.

```bash
dpkg -r toolkit
# Removing toolkit (1.0.0) ...
dpkg-query -W toolkit
# dpkg-query: no packages found matching toolkit
ls /usr/bin/toolkit
# ls: cannot access '/usr/bin/toolkit': No such file or directory
```

### 2.5 La página de manual que no aparece

Tras instalar en `ubuntu-lab`, `dpkg --verify` dice:

```
missing     /usr/share/man/man1/toolkit.1.gz
```

El paquete **sí** la contiene (`dpkg -c`), pero la imagen de Docker de Ubuntu está
«minimizada»: `/etc/dpkg/dpkg.cfg.d/excludes` tiene `path-exclude=/usr/share/man/*`
y `dpkg` **no instala** lo que coincide. Hay dos formas de verla:

```bash
# 1. Pedir a dpkg que la instale esta vez:
dpkg -i --path-include='/usr/share/man/*' toolkit_1.0.0_all.deb
# 2. Sin instalar: extraer y renderizarla con groff.
dpkg-deb -x toolkit_1.0.0_all.deb /tmp/x
zcat /tmp/x/usr/share/man/man1/toolkit.1.gz | groff -man -Tascii -P-c | col -b | head -5
# TOOLKIT(1)                  Comandos de usuario                   TOOLKIT(1)
```

(Además, la orden `man` de esa imagen es un sustituto que solo imprime un aviso
de «sistema minimizado»; por eso se usa `groff` directamente.)

## 3. Cómo se usa

### 3.1 Un ciclo de vida completo

1. `dpkg-deb -I` y `-c` — qué trae, **antes** de instalar.
2. `dpkg -i` (o `apt install ./`) — instalar.
3. `dpkg -L`, `dpkg -S` — comprobar qué dejó y dónde.
4. `dpkg --verify` — comprobar la integridad.
5. `dpkg -i` del siguiente — actualizar.
6. `dpkg -r` (o `-P`) — quitar.

### 3.2 Divergencia de distro

| Pregunta | Debian/Ubuntu | RHEL/Fedora | Arch |
|---|---|---|---|
| Instalar un archivo local | `dpkg -i` / `apt install ./x.deb` | `rpm -i` / `dnf install ./x.rpm` | `pacman -U x.pkg.tar.zst` |
| ¿A quién pertenece este archivo? | `dpkg -S /ruta` | `rpm -qf /ruta` | `pacman -Qo /ruta` |
| Archivos de un paquete | `dpkg -L` | `rpm -ql` | `pacman -Ql` |
| Verificar integridad | `dpkg --verify` | `rpm -V` | `pacman -Qkk` |

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `dpkg -i` de un `.deb` descargado sin mirarlo | Ejecuta código como root | `dpkg-deb -I`, `-c` y `-x` antes |
| Ignorar `warning: downgrading` | Instalaste una versión antigua | Parar y comprobar la versión del archivo |
| `dpkg -i` con dependencias sin resolver | Queda a medio instalar | `apt install ./archivo.deb` |
| Fiarte de que `--verify` sale con 1 | Sale con 0 aunque haya diferencias | Leer su salida |
| Editar `/usr/bin/toolkit` a mano | Se pierde en la siguiente actualización | Cambiar el fuente y reconstruir |
| Copiar con `cp` encima de un archivo de un paquete | `dpkg -S` mentirá y la actualización pisa tu cambio | Un *drop-in* o una versión nueva del paquete |
| Probar paquetes en tu máquina principal | Un fallo te afecta a ti | Un contenedor o una VM desechables |

## 5. Trucos

- **`dpkg-query -W -f='${Package} ${Version} ${Status}\n' toolkit`** da el estado
  en una línea, ideal para un `if` en un script.
- **`dpkg --verify` sin argumentos** comprueba **todos** los paquetes: lista los
  archivos del sistema modificados desde que se instalaron.
- **`dpkg -S` acepta patrones**: `dpkg -S '*/man1/ls.1.gz'` busca entre los
  archivos que conoce la base de datos de paquetes.

## 📚 Recursos Adicionales

- `man dpkg`, `man dpkg-query`
- `man apt-get` (sección `install`, rutas locales)

## ✅ Checklist de Verificación

- [ ] Instalas un `.deb` local y compruebas el estado `ii`
- [ ] Actualizas de 1.0.0 a 1.1.0 y ves `over (1.0.0)`
- [ ] Provocas y lees el aviso de degradación
- [ ] Localizas el paquete dueño de `/usr/bin/toolkit` y de `/usr/bin/ls`
- [ ] Modificas un archivo instalado y lo detectas con `dpkg --verify`
- [ ] Quitas el paquete y compruebas que el archivo desapareció
- [ ] Explicas por qué falta la página de manual en `ubuntu-lab`

---

[← Control, versión y numeración](02-control-version-y-numeracion.md) · [Documentar una herramienta →](04-documentar-una-herramienta.md)
