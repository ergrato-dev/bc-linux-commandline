# `cron` en el sistema y `at`

> Además de tu `crontab`, hay dos carpetas, un archivo y un truco de nombres
> por los que `cron` ejecuta cosas que tú no escribiste. Y para lo que solo
> hay que hacer **una vez**, no hace falta cron: existe `at`.

## 🎯 Objetivos

- Distinguir `crontab` de usuario, `/etc/crontab` y `/etc/cron.d`, y decir cuál lleva campo de usuario
- Saber qué nombres y permisos ignora `/etc/cron.d` **sin avisar**
- Explicar `cron.hourly`, `cron.daily`… y la regla de nombres de `run-parts`
- Entender qué problema resuelve `anacron` y quién lo trae en cada familia
- Programar una tarea de una sola vez con `at`

## 1. Qué problema resuelve

El `crontab` de un usuario sirve para tus tareas. Pero hay tareas que
pertenecen a **un paquete** (rotar logs de `nginx`), a **la máquina** (el
respaldo de la base de datos) o que no deben depender de que un usuario
concreto exista. Para eso `cron` lee más sitios, con reglas distintas, y
ninguna se explica sola. Casi todos los «mi tarea de `/etc/cron.d` no corre»
son una de las tres reglas silenciosas de la sección 2.2.

## 2. Cómo funciona

### 2.1 `/etc/crontab` y `/etc/cron.d/*`: el campo de usuario

Son los dos sitios del sistema. Se diferencian del `crontab` de usuario en una
columna: entre la expresión y el comando va el **usuario** con el que corre.

```bash
grep -E 'user-name|cron.hourly' /etc/crontab
# # *  *  *  *  * user-name command to be executed
# 17 *	* * *	root	cd / && run-parts --report /etc/cron.hourly
```

El formato cambia así:

| Tabla | Línea |
|---|---|
| `crontab` de usuario | `M H D M W  comando` |
| `/etc/crontab` y `/etc/cron.d/*` | `M H D M W  usuario  comando` |

| | `crontab -e` | `/etc/crontab` | `/etc/cron.d/archivo` |
|---|---|---|---|
| Campo de usuario | no | **sí** | **sí** |
| Cómo se instala | `crontab` (valida) | editas el archivo | copias el archivo |
| ¿Hace falta recargar? | no | no | no (`cron` ve el cambio en el siguiente minuto) |
| Quién lo usa | el usuario | el administrador | **paquetes** y administrador (una tarea = un archivo) |

Lo cómodo de `/etc/cron.d/` es que **cada tarea es un archivo**: se instala
con `cp`, se quita con `rm`, y un paquete puede traer el suyo sin tocar el de
nadie. Es la ubicación recomendada para tareas de sistema.

### 2.2 Tres reglas que ignoran el archivo sin decir nada

Lo comprobé en `ubuntu-lab` con cuatro archivos casi idénticos, cada uno con
una tarea cada minuto que escribe la hora en `/tmp/cd-NOMBRE.txt`. Solo uno
funcionó:

| Archivo en `/etc/cron.d/` | Diferencia | ¿Corrió? |
|---|---|:--:|
| `cronok` | ninguna (modo `644`, usuario `root`) | **sí** |
| `cron.dot` | tiene un **punto** en el nombre | no |
| `cronnouser` | falta el **campo de usuario** | no |
| `cronperm` | modo `666` (**escribible por todos**) | no |

```bash
printf '* * * * * root date +\%%T >> /tmp/cd-cronok.txt\n' > /etc/cron.d/cronok
# (los otros tres se crearon igual, cambiando solo lo indicado en la tabla)
ls -l /etc/cron.d
# -rw-r--r-- 1 root root  49 Oct 25 04:39 cron.dot
# -rw-r--r-- 1 root root  42 Oct 25 04:39 cronnouser
# -rw-r--r-- 1 root root  47 Oct 25 04:39 cronok
# -rw-rw-rw- 1 root root  49 Oct 25 04:39 cronperm
# espera dos minutos
ls /tmp/cd-*.txt
# /tmp/cd-cronok.txt
```

- **Nombre**: en Debian/Ubuntu solo valen letras, dígitos, guion y guion bajo.
  Un `backup.cron` o un `mi.tarea` **se ignora**. Existe para que los restos
  de paquetes (`.dpkg-old`, `.bak`, `~`) no se ejecuten.
- **Campo de usuario**: si lo olvidas, `cron` toma la primera palabra de tu
  comando como usuario, no lo encuentra, y descarta el archivo.
- **Permisos**: `cron` rechaza un archivo escribible por otros que no sea de
  `root`: si cualquiera pudiera editarlo, cualquiera ejecutaría órdenes como
  `root`.

**Ningún error aparece en pantalla.** En una máquina de verdad, la queja
queda en el registro (`journalctl -u cron` o `/var/log/syslog`); en el
laboratorio no hay registro, así que la única señal es que **no pasa nada**.
Por eso `toolkit.sh schedule gen` produce el `.cron` en formato de **usuario**
(se instala con `crontab archivo`) y la guía te explica cómo adaptarlo.

> `/etc/cron.d` en RHEL y Arch usa el mismo formato (con usuario). Los
> nombres admitidos varían un poco entre implementaciones: usa letras,
> dígitos, `-` y `_`, y valdrá en todas.

### 2.3 `cron.hourly` … `cron.monthly` y `run-parts`

Las carpetas `/etc/cron.hourly`, `cron.daily`, `cron.weekly` y `cron.monthly`
no contienen líneas de `crontab`: contienen **scripts ejecutables**. Los lanza
`run-parts`, invocado desde `/etc/crontab`:

```bash
grep run-parts /etc/crontab | head -2
# 17 *	* * *	root	cd / && run-parts --report /etc/cron.hourly
# 25 6	* * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
```

Para que un script de `cron.daily` se ejecute tiene que ser **ejecutable** y
tener un nombre sin punto. `run-parts --test` enseña qué ejecutaría sin
ejecutarlo:

```bash
touch /etc/cron.daily/con.punto.sh /etc/cron.daily/sin-punto
chmod +x /etc/cron.daily/con.punto.sh /etc/cron.daily/sin-punto
run-parts --test /etc/cron.daily
# /etc/cron.daily/apt-compat
# /etc/cron.daily/dpkg
# /etc/cron.daily/sin-punto
rm /etc/cron.daily/con.punto.sh /etc/cron.daily/sin-punto
```

`con.punto.sh` **no aparece**: otra vez la regla del punto. Y los scripts no
ejecutables también se saltan. La hora exacta de `cron.daily` (las 6:25 en
Debian/Ubuntu) **no la eliges tú**: si necesitas una hora concreta, no
uses estas carpetas; usa `/etc/cron.d/` o un `crontab`.

### 2.4 `anacron`: para máquinas que no están siempre encendidas

`cron` tiene un defecto de nacimiento: si la máquina está **apagada** a la
hora de la tarea, esa ejecución **se pierde**. `anacron` guarda cuándo se
ejecutó cada tarea por última vez y, al arrancar, ejecuta las vencidas. Sirve
para portátiles y sobremesas; no hace falta en un servidor siempre
encendido. Los temporizadores de systemd resuelven lo mismo con
`Persistent=true` ([archivo 06](06-temporizadores-de-systemd.md)).

Divergencia:

| | Debian / Ubuntu | RHEL / Fedora | Arch |
|---|---|---|---|
| Paquete de `anacron` | `anacron` (aparte) | `cronie-anacron` (se instala con `cronie`) | lo trae el propio `cronie` |
| Cómo se integra | `/etc/crontab` usa `anacron` si existe (`test -x /usr/sbin/anacron \|\| run-parts`) | `/etc/anacrontab` lanza `cron.daily`, `weekly` y `monthly`; `cron.hourly/0anacron` lo dispara cada hora | igual que RHEL: `cronie` trae `/etc/anacrontab` y `cron.hourly/0anacron` |

En `rhel-lab`, `/etc/anacrontab` (con `cronie-anacron` instalado) contiene,
entre otras, `1 5 cron.daily nice run-parts /etc/cron.daily`: «1 día de
periodo, 5 minutos de retraso, nombre del trabajo, comando».

### 2.5 `at`: una sola vez

`cron` es para lo **repetitivo**. Para «dentro de diez minutos», «mañana a las
9:00» o «tras este despliegue», `at`:

```bash
# En debian-lab (atd arrancado a mano con "atd"; en ubuntu-lab: apt-get install -y at)
echo 'date +%T > /tmp/at.txt' | at now + 1 minute
# warning: commands will be executed using /bin/sh
# job 1 at Sun Oct 25 04:34:00 2026
atq
# 1	Sun Oct 25 04:34:00 2026 a root
# espera un minuto
cat /tmp/at.txt
# 04:34:06
atq | wc -l
# 0
```

| Orden | Qué hace |
|---|---|
| `at HORA` | Lee los comandos de la entrada estándar (o de `-f archivo`) |
| `atq` | Lista los trabajos pendientes |
| `atrm N` | Cancela el trabajo `N` |
| `at -c N` | Enseña el script completo que guardó `at` |

La hora acepta `now + 10 minutes`, `17:30`, `tomorrow`, `noon`, `midnight`.
Una hora imposible se rechaza (`25:00` da `Garbled time`). Cuatro detalles:

- **`at` copia tu entorno**: `at -c N` enseña el `PATH` y el `umask` de tu
  sesión y un `cd` al directorio donde estabas. No es el entorno mínimo de
  `cron`, y por eso `at` «funciona» donde `cron` falla: **no son
  equivalentes** para depurar.
- Ejecuta con `/bin/sh` (el aviso `commands will be executed using /bin/sh`),
  así que los bashismos fallan igual que en `cron` en Debian/Ubuntu.
- Necesita el demonio `atd` en marcha. Como `cron`, en un contenedor lo
  arrancas tú.
- `at` **no** viene en las imágenes mínimas: `apt-get install at` (Debian y
  Ubuntu), `dnf install at` (RHEL), `pacman -S at` (Arch).

`systemd-run --on-active=10m comando` es la alternativa de systemd (crea un
temporizador transitorio). No se puede probar en el laboratorio: un
contenedor no tiene systemd como PID 1.

## 3. Cómo se usa

Dónde poner cada cosa:

| Tarea | Dónde |
|---|---|
| Mía, personal, depende de mi usuario | mi `crontab` (`crontab -e`) |
| De la máquina, la instala un paquete o el admin, una por archivo | `/etc/cron.d/NOMBRE` (con usuario, nombre sin punto, modo `644`) |
| Trabajo de mantenimiento cuya hora exacta da igual | script ejecutable en `cron.daily` (o `weekly`, `monthly`) |
| Una vez, en el futuro | `at` |
| Necesita ejecutarse aunque la máquina estuviera apagada | `anacron`, o un temporizador de systemd con `Persistent=true` |
| Necesita registro, dependencias o límites de recursos | un temporizador de systemd (archivos [06](06-temporizadores-de-systemd.md) y [07](07-unidades-service-para-tareas.md)) |

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `/etc/cron.d/backup.cron` | El punto lo hace invisible, sin aviso | `/etc/cron.d/backup` |
| Línea de `cron.d` sin el usuario | Se descarta el archivo entero | `M H D M W root comando` |
| Archivo de `cron.d` creado con `umask 000` o `chmod 666` | Se ignora por inseguro, y de verdad lo sería | `chmod 644`, propietario `root` |
| Un script en `cron.daily` con extensión (`limpia.sh`) | Se salta | `limpia`, ejecutable |
| `cron.daily` para «a las 3:00» | Se ejecuta a la hora que decida la distribución (6:25 en Debian/Ubuntu) | `cron.d` con la hora explícita |
| Un `crontab` de usuario para una tarea de sistema | Si borran el usuario o su `crontab -r`, desaparece | `/etc/cron.d/` bajo control de versiones |
| Programar con `cron` algo que hay que hacer una vez | Se ejecutará cada año o cada día, y no te acordarás de quitarlo | `at` |

## 5. Trucos

- **`run-parts --test DIR`** es la forma de saber qué ejecutaría
  `cron.daily` **antes** de esperar a las 6:25.
- **`ls -l /etc/cron.d`** y mirar el modo y el nombre de cada archivo es la
  primera comprobación cuando una tarea de sistema «no corre».
- **`at -c N | tail`** enseña el comando exacto que se ejecutará, con su
  entorno y su `cd`.
- **`atq` vacío tras la hora** significa «ya se ejecutó» (o se canceló). No
  distingue si funcionó: redirige la salida igual que en `cron`.

## 📚 Recursos Adicionales

- `man 8 cron` (Debian/Ubuntu) o `man 8 crond` (RHEL, Arch), `man 8 run-parts`, `man at`
- `man anacrontab` (RHEL y donde esté instalado `anacron`)

## ✅ Checklist de Verificación

- [ ] Dices cuál de `crontab -e`, `/etc/crontab` y `/etc/cron.d/*` lleva campo de usuario
- [ ] Reproduces los cuatro archivos de la sección 2.2 y ves que solo `cronok` corre
- [ ] `run-parts --test /etc/cron.daily` omite un script con punto en el nombre
- [ ] Explicas qué problema resuelve `anacron` y qué lo reemplaza en systemd
- [ ] Programas con `at` una tarea a un minuto vista y la ves ejecutarse
- [ ] Sabes por qué `at` y `cron` no se comportan igual ante el mismo `PATH`

---

[← El entorno mínimo de cron](03-el-entorno-minimo-de-cron.md) · [Tareas programadas que no fallan en silencio →](05-tareas-programadas-que-no-fallan-en-silencio.md)
