# `logrotate`: que los registros no llenen el disco

> Un registro que nunca se rota acaba llenando `/var`. Uno que se rota mal pierde justo las líneas del fallo.
> `logrotate` renombra, comprime y borra los viejos: todo el truco está en **cómo** lo hace.

## 🎯 Objetivos

- Explicar qué hace una rotación y por qué los archivos acaban en `.1`, `.2.gz`…
- Escribir una configuración con `rotate`, `daily`/`size`, `compress`, `missingok` y `notifempty`
- Probarla sin riesgo con `-d`, forzarla con `-f` y ver el estado con `-v`
- Elegir entre `create` y `copytruncate` entendiendo qué pasa con el programa que escribe
- Entender cómo se lanza (`cron`/temporizador) y qué hay en `/etc/logrotate.d/`

## 1. Qué problema resuelve

Un servicio escribe a `app.log` día y noche. Sin intervención, el archivo crece
sin límite, y un día `/var` se llena y el servicio se cae. Rotar es: **renombrar**
el actual (`app.log` → `app.log.1`), empezar uno nuevo vacío, **comprimir** los
antiguos y **borrar** los que pasan de cierta edad. `logrotate` hace todo eso
según unas reglas por archivo, y se ejecuta periódicamente.

## 2. Cómo funciona

### 2.1 Una configuración

Un bloque es: la ruta (o varias, o comodines) y entre llaves las reglas. Un
ejemplo mínimo con los parámetros que más se usan:

```bash
mkdir -p /tmp/lr/logs && cd /tmp/lr
for i in 1 2 3; do echo "linea $i" >> logs/app.log; done
cat > app.conf <<'EOF'
/tmp/lr/logs/app.log {
    rotate 3
    daily
    missingok
    notifempty
    compress
    delaycompress
    create 0640 root root
}
EOF
```

| Regla | Hace |
|---|---|
| `rotate N` | conserva N archivos rotados; el más viejo se borra |
| `daily`, `weekly`, `monthly` | cada cuánto rota (se comprueba cuando corre `logrotate`) |
| `size 2k` | rota cuando el archivo pasa de ese tamaño, **en vez de** por fecha |
| `missingok` | no es un error que el archivo no exista |
| `notifempty` | no rota si está vacío |
| `compress`, `delaycompress` | comprime con `gzip`; la rotación **más reciente** se deja sin comprimir un ciclo |
| `create MODO USUARIO GRUPO` | crea el archivo nuevo con esos permisos |
| `dateext` | nombra con la fecha (`app.log-20261025`) en lugar de `.1`, `.2` |

`delaycompress` existe por el programa que escribe: puede seguir con el archivo
recién rotado abierto un rato, y comprimirlo mientras escribe lo corrompería.

### 2.2 Probar sin tocar nada: `-d`

`-d` (*debug*) **no hace nada**: explica qué haría. Es siempre el primer paso:

```bash
logrotate -d -s state app.conf 2>&1 | sed -n 9,17p
# rotating pattern: /tmp/lr/logs/app.log  after 1 days (3 rotations)
# empty log files are not rotated, old logs are removed
# considering log /tmp/lr/logs/app.log
# Creating new state
#   Now: 2026-10-25 06:06
#   Last rotated at 2026-10-25 06:00
#   log does not need rotating (log has already been rotated)
```

`-s state` indica **dónde guarda el estado** (en el sistema es
`/var/lib/logrotate/status`): la fecha de la última rotación de cada archivo. La
primera vez que ve un archivo lo anota con la hora actual y **no lo rota**: por
eso «no rota» en tu primera prueba. Para forzarlo, `-f`:

```bash
logrotate -s state app.conf; ls logs
# app.log
logrotate -f -s state app.conf; ls logs
# app.log  app.log.1
echo nuevo >> logs/app.log; logrotate -f -s state app.conf; ls logs
# app.log  app.log.1  app.log.2.gz
```

Fíjate: tras la segunda rotación, `.1` queda **sin comprimir** (`delaycompress`)
y el que era `.1` pasa a `.2.gz`. Con `-v` (*verbose*) ves cada decisión mientras
actúa de verdad.

### 2.3 Rotar de verdad: `create` frente a `copytruncate`

Aquí está el punto delicado. `create` **renombra** el archivo y crea uno nuevo;
pero un programa que ya tenía el archivo abierto **sigue escribiendo en el
renombrado**, porque lo abrió por inodo, no por nombre. Se ve con un
descriptor abierto:

```bash
exec 8>>logs/nc.log; echo antes >&8
printf '/tmp/lr/logs/nc.log {\n rotate 2\n create\n nocompress\n}\n' > nc.conf
logrotate -f -s state nc.conf; echo despues >&8
echo "nc.log:"; cat logs/nc.log
# nc.log:
echo "nc.log.1:"; cat logs/nc.log.1
# nc.log.1:
# antes
# despues
exec 8>&-
```

El `despues` cayó en `nc.log.1`: el archivo nuevo quedó **vacío** mientras el
programa escribe en el viejo. Dos soluciones: avisar al programa para que
reabra (`postrotate` con `systemctl reload servicio` o una señal `HUP`), o
**`copytruncate`**: copia el contenido a `.1` y **vacía** el original *sin
cambiar de inodo*, así el programa no se entera:

```bash
exec 9>>logs/ct.log; echo antes >&9
printf '/tmp/lr/logs/ct.log {\n rotate 2\n copytruncate\n nocompress\n}\n' > ct.conf
logrotate -f -s state ct.conf; echo despues >&9
echo "ct.log:"; cat logs/ct.log; echo "ct.log.1:"; cat logs/ct.log.1
# ct.log:
# despues
# ct.log.1:
# antes
exec 9>&-
```

El precio de `copytruncate`: entre la copia y el vaciado puede **perderse una línea**,
y un programa que no escribe en modo *append* deja huecos de ceros. Es el
último recurso para el que no sabe reabrir; el correcto es `create` y avisar.

### 2.4 Rotar por tamaño, nombrar por fecha y ejecutar un script

```bash
head -c 3000 /dev/zero | tr '\0' x > logs/sz.log
printf '/tmp/lr/logs/sz.log {\n size 2k\n rotate 2\n dateext\n nocompress\n}\n' > sz.conf
logrotate -s state sz.conf; ls logs | grep sz
# sz.log-20261025
printf '/tmp/lr/logs/pr.log {\n rotate 1\n postrotate\n  echo "post: $1" >> /tmp/lr/hook.txt\n endscript\n}\n' > pr.conf
echo y > logs/pr.log; logrotate -f -s state pr.conf; cat hook.txt
# post: /tmp/lr/logs/pr.log
```

`size 2k` rota **solo** si el archivo pasa de 2 KiB (uno de 6 bytes no se toca).
`postrotate ... endscript` ejecuta código tras rotar; recibe el nombre del
registro como `$1`. Con `sharedscripts` se ejecuta una vez para todos los
archivos del patrón, no uno por archivo.

## 3. Cómo se usa

### 3.1 El sistema: `/etc/logrotate.conf` y `/etc/logrotate.d/`

En una instalación normal no ejecutas `logrotate` tú: lo hace un **temporizador
de systemd** (`logrotate.timer`) o un script en `cron.daily`. Lee dos sitios:

```bash
grep -vE '^\s*(#|$)' /etc/logrotate.conf
# weekly
# su root adm
# rotate 4
# create
# include /etc/logrotate.d
ls /etc/logrotate.d
# alternatives  apt  btmp  dpkg  rsyslog  wtmp
```

`/etc/logrotate.conf` fija los valores generales (semanal, 4 rotaciones, `su root
adm` para el propietario) e **incluye** `/etc/logrotate.d/`, donde **cada
paquete deja su archivo** (`apt`, `dpkg`, `rsyslog`…). Para rotar un registro tuyo:
un archivo nuevo en `/etc/logrotate.d/`; no hace falta tocar el principal. Y se
prueba igual: `logrotate -d /etc/logrotate.d/miapp`.

### 3.2 El error de los permisos

Si el directorio del registro tiene permisos de escritura para un grupo, y no
indicas un propietario con `su`, `logrotate` se niega:

```
error: skipping "/tmp/lr/ins/i.log" because parent directory has insecure
permissions (It's world writable or writable by group which is not "root")
Set "su" directive in config file to tell logrotate which user/group should
be used for rotation.
```

Es una defensa: quien escribe en ese directorio podría poner un enlace y hacer
que `root` rote (o borre) otra cosa. Se arregla con `su usuario grupo` dentro
del bloque, o corrigiendo los permisos, **no** ignorando el error.

### 3.3 Un script propio

Un script de `cron` que escribe un registro (Semana 16) necesita una regla
`logrotate`. Ejemplo para el registro de `toolkit guard`:

```
/var/log/toolkit/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
```

`create` es correcto porque `guard` abre el registro en cada ejecución (no lo
mantiene abierto).

### 3.4 Divergencia de distro

`logrotate` es el mismo en las cuatro familias; lo que varía es **si viene
instalado** y **quién lo lanza**:

| | Ubuntu/Debian | RHEL/Rocky | Arch |
|---|---|---|---|
| Paquete | `logrotate` | `logrotate` | `logrotate` |
| Imagen mínima del laboratorio | **no** instalado | **no** instalado | **no** instalado |
| Configuración | `/etc/logrotate.conf`, `/etc/logrotate.d/` | igual | igual |

En `ubuntu-lab`: `apt-get install -y logrotate`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Probar con `logrotate -f` directamente | Rota de verdad un registro real | `-d` primero, y `-s` con un estado de prueba |
| `copytruncate` por defecto | Pierde líneas y duplica el uso de disco al copiar | `create` + `postrotate` que avise al servicio |
| `create` sin avisar al programa | Sigue escribiendo en el archivo renombrado | `postrotate` con un `reload`, o `copytruncate` |
| Sin `missingok` | Un registro ausente hace fallar la rotación de los demás | `missingok` |
| `rotate 0` o muy bajo en un registro de auditoría | Pierdes el historial que necesitas | Calcula la retención (archivo 03) |
| Comprimir el `.1` mientras el programa lo usa | Corrompe las últimas líneas | `delaycompress` |
| Editar `/etc/logrotate.conf` para un solo servicio | Se pierde en una actualización | Un archivo en `/etc/logrotate.d/` |
| Ignorar el error de permisos con `chmod 777` | Abres justo el agujero que avisa | `su usuario grupo` |

## 5. Trucos

- **`logrotate -d archivo.conf 2>&1 | grep -E 'rotating|considering|does not need'`**
  resume la decisión por archivo sin tocar nada.
- **`cat /var/lib/logrotate/status`** muestra, en una máquina donde `logrotate`
  ya ha corrido de verdad, cuándo rotó cada registro por última vez: ahí se ve
  por qué «hoy no ha rotado». (En el contenedor está vacío: nadie lo lanza.)
- **`zcat -f app.log app.log.1 app.log.*.gz | grep patron`** busca en toda la
  historia de un registro, esté comprimida o no.

## 📚 Recursos Adicionales

- `man logrotate` y `man logrotate.conf` (la lista completa de reglas)
- [`logrotate` en GitHub](https://github.com/logrotate/logrotate)

## ✅ Checklist de Verificación

- [ ] Escribes un bloque con `rotate`, `daily`, `compress`, `delaycompress` y `create`
- [ ] Pruebas con `-d` y fuerzas con `-f -s estado`, y ves `.1`, `.2.gz`
- [ ] Explicas por qué la primera ejecución de un archivo nuevo no rota
- [ ] Demuestras con un descriptor abierto la diferencia entre `create` y `copytruncate`
- [ ] Rotas por tamaño con `size` y nombras por fecha con `dateext`
- [ ] Ejecutas un `postrotate` y ves que recibe el nombre del registro
- [ ] Sabes dónde dejar la regla de un servicio nuevo y qué hace el error de permisos

---

[← `journalctl`: el diario de systemd](05-journalctl.md) · [Escribir en los registros →](07-escribir-en-los-registros.md)
