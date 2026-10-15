# `umask`

> Todo archivo nuevo "nace" con permisos, sin que nadie corra `chmod` a
> propósito. Esta sección explica de dónde salen esos permisos iniciales —
> adelantada, sin profundidad, en la Semana 03.

## 🎯 Objetivos

- Calcular qué permisos recibe un archivo nuevo a partir del `umask` activo
- Cambiar el `umask` de la sesión, y hacerlo persistente
- Explicar por qué archivos y directorios nacen con permisos distintos bajo el mismo `umask`

## 1. Qué problema resuelve

Cuando un editor guarda un archivo nuevo, o un script hace `touch`, el
sistema tiene que decidir qué permisos ponerle — y no los inventa al azar.
Los calcula restando una máscara (`umask`) de un máximo por defecto. Sin
entender esa resta, "por qué mis archivos nuevos siempre nacen sin
ejecución" o "por qué en esta otra máquina los archivos nuevos son más
permisivos" quedan sin respuesta.

## 2. Cómo funciona

### 2.1 Ver el `umask` actual

```bash
umask
# 0022

umask -S
# u=rwx,g=rx,o=rx
```

`umask` sin argumentos muestra el valor en octal; `-S` ("symbolic") lo
traduce a lo que **queda permitido** después de aplicar la máscara — no a
lo que la máscara resta, que es una confusión común.

### 2.2 El cálculo: máximo por defecto, menos la máscara

El sistema parte de un máximo teórico distinto para archivos y
directorios:

| | Máximo por defecto | Con `umask 022` |
|---|---|---|
| Directorios | `777` (rwxrwxrwx) | `777 - 022 = 755` |
| Archivos | `666` (rw-rw-rw-) | `666 - 022 = 644` |

La resta es **bit a bit**, no aritmética decimal: cada `1` en la máscara
apaga el bit correspondiente del máximo. `umask 022` apaga el bit de
escritura (`w`) para grupo y otros, en ambos casos.

```bash
umask
# 0022
touch archivo-nuevo.txt
mkdir carpeta-nueva

ls -l archivo-nuevo.txt
# -rw-r--r--    <- 644, el maximo de archivos (666) menos 022

ls -ld carpeta-nueva
# drwxr-xr-x    <- 755, el maximo de directorios (777) menos 022
```

### 2.3 Por qué los archivos nunca nacen con `x`, aunque la máscara no lo prohíba

Esta es la pregunta que queda pendiente de la Semana 03: incluso con
`umask 000` (sin restar nada), un archivo nuevo creado con `touch` o un
editor **nunca** nace con `x`:

```bash
umask 000
touch archivo-sin-mascara.txt
ls -l archivo-sin-mascara.txt
# -rw-rw-rw-    <- 666, sin ningun x, a pesar de umask 000
```

La razón: el máximo teórico de un **archivo** nunca incluye `x` (`666`, no
`777`) — ponerle ejecución a un archivo es una decisión explícita que toma
quien lo crea (un compilador, un script de instalación), no algo que el
sistema de archivos asuma por defecto. Los **directorios** sí parten de
`777`, porque necesitan `x` (tránsito, visto en el primer archivo de esta
semana) para ser usables en absoluto.

### 2.4 Cambiar el `umask` de la sesión actual

```bash
umask 027    # mas restrictivo: sin ningun permiso para "otros"
touch probando.txt
ls -l probando.txt
# -rw-r-----
```

Este cambio solo dura la sesión actual — para que persista, hace falta
agregarlo a `~/.bashrc` (el mismo archivo donde configuraste `PATH` e
historial en semanas anteriores):

```bash
echo 'umask 027' >> ~/.bashrc
```

### 2.5 Notación simbólica de `umask`

```bash
umask u=rwx,g=rx,o=
```

Igual que con `chmod`, `umask` acepta notación simbólica — pero acá
describe **lo que queda permitido**, no lo que se resta. Es menos intuitivo
que el octal para la mayoría, por eso el octal (`umask 022`) sigue siendo
la forma más común en la práctica.

## 3. Cómo se usa

```bash
# Diagnostico rapido: que umask tiene esta sesion
umask

# Umask mas restrictivo para una sesion que va a crear archivos sensibles
umask 077
touch credenciales.txt
ls -l credenciales.txt
# -rw-------    <- solo el dueño, nada para nadie mas

# Volver al umask por defecto
umask 022
```

```bash
# Confirmar el umask persistente despues de reiniciar la sesion
docker exec -it ubuntu-lab bash -c 'umask'
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Confundir `umask -S` con "lo que se resta" | Muestra lo que **queda permitido**, no la máscara que se aplica — leerlo al revés lleva a conclusiones opuestas a la realidad | Usar el octal (`umask` sin flags) para pensar en términos de la resta; `-S` solo para confirmar el resultado final |
| Esperar que `umask 000` le dé `x` a un archivo nuevo | El máximo teórico de un archivo nunca incluye `x`, sin importar la máscara | Agregar `x` explícitamente con `chmod` si el archivo realmente necesita ejecución |
| Cambiar el `umask` en la sesión actual y esperar que persista | El cambio solo dura la sesión, se pierde al abrir una terminal nueva | Agregarlo a `~/.bashrc` si necesita ser permanente |
| Usar un `umask` muy permisivo (`000`) por comodidad, sin pensarlo | Cualquier archivo nuevo nace editable por cualquier usuario del sistema | Usar `umask 022` (estándar) o `umask 077` (restrictivo) según el caso, nunca `000` sin una razón puntual |
| Fijar un `umask` distinto en cada script esperando que afecte a procesos ya corriendo | `umask` solo afecta al proceso que lo corre y a los que arranque después, nunca retroactivamente a procesos ya en ejecución | Fijar el `umask` al principio de un script, antes de crear cualquier archivo que dependa de ese valor |

## 5. Trucos

- `umask 077` es el valor recomendado para sesiones donde vas a manejar
  archivos sensibles (claves, credenciales, respaldos privados) — nada para
  grupo ni otros, por defecto.
- Si un script necesita garantizar permisos exactos sin depender del
  `umask` del usuario que lo ejecute, lo correcto es fijar el permiso
  explícito con `chmod` después de crear el archivo, no confiar en que el
  `umask` del entorno sea el esperado.
- `(umask 077; touch archivo-temporal)` en un subshell cambia el `umask`
  solo para ese comando puntual, sin afectar el resto de la sesión.

### 2.6 El `umask` por defecto del sistema, antes de tu `.bashrc`

Antes de que tu propio `~/.bashrc` fije nada, el sistema ya aplicó un
`umask` por defecto, definido en `/etc/profile` o `/etc/login.defs` (el
valor exacto varía por distro — en Ubuntu suele ser `022` para usuarios
normales, `027` para `root`). Tu configuración personal en `~/.bashrc`
sobrescribe ese valor para tu propia sesión, pero no cambia el
comportamiento de otros usuarios ni de procesos del sistema que arrancan
por su cuenta.

```bash
grep -r umask /etc/profile /etc/login.defs 2>/dev/null
```

### 2.7 Por qué `toolkit.sh audit` reporta el `umask` actual

La capa de esta semana del proyecto (`3-proyecto/README.md`) incluye el
`umask` activo en su reporte, precisamente porque es información de
contexto necesaria para interpretar el resto: un archivo "escribible por
otros" detectado por `audit` puede ser el resultado de un `umask`
demasiado permisivo en el momento de crearlo, no necesariamente un `chmod`
explícito posterior. Saber el `umask` de la sesión es el primer dato para
diagnosticar *por qué* algo nació con los permisos que tiene.

## Resumen

Todo archivo nuevo nace de un máximo teórico (`666` para archivos, `777`
para directorios) menos el `umask` activo, bit a bit. Un archivo nunca nace
con `x` sin importar el `umask`, porque su máximo teórico no lo incluye. El
cambio de `umask` es solo de sesión salvo que se agregue a `~/.bashrc`, y
`077` es el valor a usar cuando lo que se crea es sensible.

## 📚 Recursos Adicionales

- [Bash Reference Manual — umask](https://www.gnu.org/software/bash/manual/bash.html#index-umask) — `umask` es builtin, documentado junto al resto de comandos del shell.
- `help umask` — ayuda offline, al ser builtin.
- `man 2 umask` — la syscall real detrás del builtin, para quien quiera el detalle de kernel.

## ✅ Checklist de Verificación

- [ ] Calculaste a mano los permisos de un archivo y un directorio nuevos bajo `umask 022`
- [ ] Reprodujiste por qué un archivo nunca nace con `x`, incluso con `umask 000`
- [ ] Cambiaste el `umask` de forma persistente en `~/.bashrc`
- [ ] Usaste un subshell para cambiar el `umask` de un solo comando, sin afectar el resto de la sesión
- [ ] Corriste `toolkit.sh audit` y leíste el `umask` que reporta, antes de interpretar el resto de su salida

---

[← 03 — chown y chgrp](03-chown-y-chgrp.md) · [05 — Bits especiales: SUID, SGID, sticky →](05-bits-especiales-suid-sgid-sticky.md)
