# ACLs y el modelo de confianza de `sudo`

> El modelo de `rwx` × tres ámbitos alcanza para el 95% de los casos. Este
> archivo cierra la semana con las dos herramientas que cubren el otro 5%:
> dar permisos a una persona puntual (ACLs) y delegar privilegios de forma
> medible (`sudo`).

## 🎯 Objetivos

- Dar permiso a un usuario o grupo específico sin tocar dueño/grupo/otros
- Leer y escribir ACLs con `getfacl`/`setfacl`
- Explicar el modelo de confianza de `sudo` y configurar una regla mínima

## 1. Qué problema resuelve

El modelo clásico de permisos tiene un límite real: solo puede nombrar
**un** usuario (el dueño) y **un** grupo. "Quiero que Ana pueda escribir
este archivo, pero nadie más del grupo" no se puede expresar con `rwx`
clásico — necesitarías crear un grupo nuevo solo para Ana, lo cual no
escala. Las ACLs (listas de control de acceso) resuelven exactamente esto:
agregan permisos para usuarios o grupos puntuales, más allá de los tres
ámbitos clásicos.

Por otro lado, `sudo` resuelve un problema distinto: cómo delegar
privilegios de `root` sin repartir la contraseña de `root`, y sin dar
acceso total cuando alcanza con un comando puntual.

## 2. Cómo funciona

### 2.1 Instalar las herramientas

Ninguna de las dos viene preinstalada en la imagen base de Ubuntu que usa
este laboratorio:

```bash
apt-get update -qq
apt-get install -y acl sudo
```

### 2.2 ACLs: permiso para una persona puntual

```bash
touch /tmp/informe.txt
chmod 600 /tmp/informe.txt    # solo el dueño, nadie mas

getfacl /tmp/informe.txt
# user::rw-
# group::r--
# other::r--
```

```bash
setfacl -m u:ana:rw /tmp/informe.txt
getfacl /tmp/informe.txt
# user::rw-
# user:ana:rw-      <- la entrada nueva, especifica para ana
# group::r--
# mask::rw-
# other::r--
```

`ls -l` marca con un `+` al final de los permisos que un archivo tiene ACLs
adicionales, sin mostrar el detalle completo — por eso `getfacl` es
necesario para ver qué hay realmente configurado:

```bash
ls -l /tmp/informe.txt
# -rw-rw----+ 1 root root ...
```

### 2.3 El campo `mask`: el techo real de las ACLs

El `mask` que aparece en `getfacl` es el límite máximo efectivo para
cualquier entrada de ACL de usuario o grupo (no para el dueño ni para
"otros"). Si el `mask` es `r--`, una entrada `user:ana:rw-` queda limitada
a solo lectura en la práctica, aunque diga `rw-`:

```bash
setfacl -m mask::r /tmp/informe.txt
getfacl /tmp/informe.txt
# user:ana:rw-          #effective:r--    <- el mask recorta el permiso real
```

`setfacl` recalcula el `mask` automáticamente cada vez que agregas una
entrada, salvo que lo fijes tú mismo explícitamente — es un detalle que
sorprende la primera vez que un permiso "parece estar ahí" pero no se
aplica.

### 2.4 ACLs por defecto en un directorio: herencia

```bash
mkdir /tmp/carpeta-compartida
setfacl -d -m u:ana:rwx /tmp/carpeta-compartida

touch /tmp/carpeta-compartida/nuevo.txt
getfacl /tmp/carpeta-compartida/nuevo.txt
# el archivo nuevo ya trae la ACL de ana, heredada del directorio
```

`-d` ("default") define una ACL que **no** aplica al directorio mismo, sino
que se copia automáticamente a todo lo que se cree dentro — el equivalente
en ACLs a lo que SGID hace para el grupo (visto en el archivo anterior).

### 2.5 Quitar ACLs

```bash
setfacl -x u:ana /tmp/informe.txt     # quita solo la entrada de ana
setfacl -b /tmp/informe.txt            # quita TODAS las ACLs, vuelve al modelo clasico
```

### 2.6 El modelo de confianza de `sudo`

`sudo` no es "convertirse en root": es ejecutar **un comando puntual** con
privilegios elevados, registrado y auditable. La configuración vive en
`/etc/sudoers`, que **nunca** se edita directamente — se usa `visudo`,
que valida la sintaxis antes de guardar (un error de sintaxis en
`/etc/sudoers` puede dejar el sistema sin forma de usar `sudo` para
arreglarlo):

```bash
visudo
```

### 2.7 Una regla mínima, con el principio de menor privilegio

```bash
# archivo nuevo en /etc/sudoers.d/, mas seguro que editar el principal
echo 'ana ALL=(ALL) /usr/bin/apt update' > /etc/sudoers.d/ana
visudo -c -f /etc/sudoers.d/ana    # valida sintaxis antes de confiar en el archivo
chmod 440 /etc/sudoers.d/ana        # los archivos de sudoers deben ser 440
```

Esta regla permite a `ana` correr **exactamente** `sudo apt update`, nada
más — ni siquiera `sudo apt upgrade`. Es el principio de menor privilegio
aplicado de forma literal: dar acceso al comando puntual que hace falta,
no acceso total "para no tener que pedir de nuevo".

```bash
su ana -c 'sudo apt update'      # funciona
su ana -c 'sudo whoami'           # pide contraseña / falla: no esta en la regla
```

### 2.8 `sudo -l`: ver qué puede hacer un usuario

```bash
sudo -l -U ana
# User ana may run the following commands on este-host:
#     (ALL) /usr/bin/apt update
```

Es la forma de auditar, sin adivinar, exactamente qué privilegios tiene
delegados cualquier usuario del sistema.

## 3. Cómo se usa

```bash
# Dar acceso puntual a un archivo sin crear un grupo nuevo
setfacl -m u:colega:rw informe-compartido.txt

# Configurar herencia en una carpeta de equipo
setfacl -d -m g:desarrollo:rwx /srv/equipo

# Auditar una regla de sudo antes de confiar en ella
visudo -c -f /etc/sudoers.d/nombre-del-archivo
sudo -l -U usuario
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Editar `/etc/sudoers` directamente con un editor cualquiera | Un error de sintaxis puede dejar el sistema sin `sudo` funcional para nadie | Usar siempre `visudo`, que valida antes de guardar |
| Dar `ALL=(ALL) NOPASSWD: ALL` por comodidad | Es equivalente a entregar la contraseña de `root`, sin ningún límite ni registro específico | Delegar comandos puntuales, el mínimo necesario para la tarea real |
| Configurar una ACL sin revisar el `mask` resultante | El permiso "parece" estar ahí en `getfacl` pero el `mask` lo recorta en la práctica | Revisar siempre la línea `#effective:` que `getfacl` muestra cuando el mask limita algo |
| Olvidar `-d` al querer que una carpeta compartida propague ACLs a lo nuevo | La ACL solo aplica al directorio mismo, no se hereda a los archivos creados después | Usar `setfacl -d` para ACLs por defecto en directorios compartidos |

## 5. Trucos

- `getfacl archivo1 | setfacl --set-file=- archivo2` copia la ACL completa
  de un archivo a otro, sin tener que reescribir cada entrada a mano.
- `sudo -l` (sin `-U`) muestra qué puedes hacer **tú mismo** con `sudo`, sin
  necesitar privilegios para consultar tu propia configuración.
- Un archivo en `/etc/sudoers.d/` nombrado igual que el usuario (`ana`, no
  `ana.conf` ni similar) es la convención más común para encontrar
  rápidamente qué regla corresponde a quién.

## Resumen

Las ACLs extienden el modelo clásico de `rwx` para nombrar usuarios o
grupos puntuales, con un `mask` que limita el efecto real y una variante
`-d` para herencia en directorios. `sudo` delega comandos puntuales de
`root`, auditable con `sudo -l`, configurado siempre vía `visudo` para
evitar dejar el sistema sin acceso administrativo por un error de sintaxis.
Ninguna de las dos reemplaza el modelo clásico — lo complementan para los
casos que `rwx` solo no puede expresar.

## 📚 Recursos Adicionales

- [RHEL Docs — ACLs](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_file_systems/managing-access-control-lists_managing-file-systems) — guía práctica de ACLs con más ejemplos que la página de `man`.
- `man setfacl`, `man getfacl`, `man 5 sudoers` — referencias completas de cada herramienta.
- `man visudo` — por qué existe y cómo configurar qué editor usa.

## ✅ Checklist de Verificación

- [ ] Agregaste una ACL de usuario puntual y confirmaste el `+` en `ls -l`
- [ ] Reprodujiste cómo el `mask` recorta un permiso que "parece" estar en la ACL
- [ ] Configuraste una ACL por defecto (`-d`) en un directorio y confirmaste la herencia
- [ ] Creaste una regla de `sudo` con un comando puntual, validada con `visudo -c`
- [ ] Usaste `sudo -l` para auditar qué privilegios tiene delegado un usuario

---

[← 05 — Bits especiales](05-bits-especiales-suid-sgid-sticky.md) · [Práctica 01 →](../2-practicas/01-modelo-de-permisos-y-chmod.md)
