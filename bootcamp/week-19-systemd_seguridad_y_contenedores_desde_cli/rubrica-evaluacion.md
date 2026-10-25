# Rúbrica de Evaluación — Semana 19

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. En `ubuntu-lab`, `systemctl status cron` falla con «System has not been booted with systemd». ¿Por qué, y qué herramientas de systemd sí puedes usar allí?

<details>
<summary>Ver respuesta</summary>

`systemctl` habla con el proceso que es el **PID 1**, y solo es systemd si el
sistema arrancó con él. En el laboratorio el PID 1 es `sleep infinity`: no hay
nadie con quien hablar. Las herramientas que solo **leen archivos** sí funcionan:
`systemd-analyze verify`, `security --offline=true`, `calendar`, `timespan` y
`cat-config`, y `systemctl --root=DIR enable|disable|is-enabled`, que crea o
quita enlaces simbólicos en un directorio de prueba. Lo que necesita estado vivo
(`status`, `is-active`, `list-units`, `journalctl -u` con una unidad real) se
practica en una máquina con systemd.

</details>

2. `systemctl is-failed cron` imprime `active` y devuelve 1; `systemctl is-active cron ssh docker` devuelve 0 aunque `ssh` esté parado. Explica los dos códigos.

<details>
<summary>Ver respuesta</summary>

`is-failed` es una **pregunta**: «¿está fallada?». Devuelve 0 cuando la respuesta
es sí; una unidad sana responde 1 (no). Es lo contrario de lo que sugiere el
nombre si piensas en «0 = todo bien». Con varias unidades, `is-active` devuelve 0
si **alguna** está activa (imprime una línea por unidad). Para exigir que todas lo
estén hay que comprobarlas una a una, con `--quiet` y un `if`. Moraleja: lee la
pregunta que hace cada verbo antes de interpretar su código.

</details>

3. `systemd-analyze verify` devuelve 0 con una unidad que tiene `Restar=on-failure`. ¿Qué significa ese 0, y qué otra comprobación harías?

<details>
<summary>Ver respuesta</summary>

Una clave desconocida es un **aviso**: systemd la ignora (`Unknown key name ...,
ignoring`) y sigue, así que el código es 0. Un error real, como un `ExecStart=`
con una ruta que no existe, devuelve 1. Un script que solo mire el código dejaría
pasar la errata y la unidad correría sin `Restart`. Hay que **leer también la
salida** (o guardarla y exigir que esté vacía), y luego medir con
`systemd-analyze security --offline=true` para ver que las directivas que crees
haber puesto cuentan.

</details>

4. El arranque tarda 10 s y `blame` pone `apt-daily.service` con 12 s. ¿Es el culpable? ¿Qué mirarías?

<details>
<summary>Ver respuesta</summary>

No necesariamente. `blame` ordena por cuánto tardó **cada unidad en activarse**,
pero muchas corren en paralelo sin que nada espere por ellas: 12 s en
`apt-daily` con un arranque total de 10 s demuestra que no estaba en el camino.
`critical-chain` muestra la ruta de dependencias que **determinó** el tiempo
total (`@` es el instante de activación, `+` lo que tardó). Se optimiza lo que
sale ahí; acelerar una unidad ajena a la cadena crítica no cambia el arranque.

</details>

5. ¿Por qué `ana ALL=(root) NOPASSWD: /usr/bin/systemctl status *` es mejor que `NOPASSWD: ALL`, y por qué un `*` detrás de `vi` o `less` sería un error?

<details>
<summary>Ver respuesta</summary>

La primera regla concede **un comando concreto** con ruta absoluta: si la cuenta
de `ana` se compromete, el atacante puede mirar el estado de servicios, no leer
`/etc/shadow` ni abrir una shell de root. `NOPASSWD: ALL` es root sin contraseña.
Con `vi` o `less`, permitir cualquier argumento incluye `!sh` dentro del programa,
que abre una shell con los permisos concedidos: el comando permitido se convierte
en una puerta. Y antes de instalar la regla se comprueba con `visudo -cf`, porque
un error de sintaxis en `sudoers` puede dejar sin `sudo` a todo el sistema.

</details>

6. ¿Qué hace el bit setuid, por qué la lista de binarios setuid de un sistema sano es corta, y para qué sirve el bit *sticky* de `/tmp`?

<details>
<summary>Ver respuesta</summary>

Un binario setuid se ejecuta con los permisos de su **propietario**, no de quien
lo lanza: así `passwd` (de root) puede escribir en `/etc/shadow` aunque lo lance
un usuario normal. Es una escalada de privilegios controlada, y por eso cada
binario setuid es una superficie de ataque: la lista debe ser corta, conocida y
auditable (`find /usr/bin -perm -4000`). El bit *sticky* (`1777`) se aplica a
directorios escribibles por todos: solo el propietario de un archivo (o root)
puede borrarlo o renombrarlo, de modo que un usuario no pueda quitar los archivos
temporales de otro.

</details>

7. Una unidad pasa de 9,4 UNSAFE a 2,0 OK con un drop-in. ¿Qué te dice y qué **no** te dice esa nota?

<details>
<summary>Ver respuesta</summary>

Dice que el archivo declara muchas restricciones: `NoNewPrivileges`,
`ProtectSystem=strict`, `PrivateTmp`, `RestrictAddressFamilies`, un filtro de
llamadas al sistema, etc. **No** dice que el servicio siga funcionando: una
restricción excesiva (`ProtectSystem=strict` sin `ReadWritePaths=`, o
`AF_UNIX` en algo que necesita red) rompe la tarea. Tampoco es un análisis del
programa. Hay que añadir las directivas de una en una, reiniciar, y leer
`journalctl -u` antes de dar por buena la unidad.

</details>

8. En `sshd_config.d/` tienes `50-cloud.conf` con `PasswordAuthentication yes` y creas `10-hard.conf` con `no`. ¿Cuál gana, por qué, y cómo lo compruebas sin fiarte del archivo?

<details>
<summary>Ver respuesta</summary>

Gana `10-hard.conf`. En `sshd_config` **la primera aparición** de una directiva
es la que vale (al revés que en una unidad de systemd), y `Include
/etc/ssh/sshd_config.d/*.conf` mete los archivos en orden alfabético en el punto
donde está, que en Ubuntu es al principio. Por eso el ajuste de endurecimiento
lleva un número bajo. Se comprueba con `sshd -T`, que imprime la configuración
**efectiva** ya resuelta (`passwordauthentication no`); `sshd -t` solo valida la
sintaxis. Lo que haya tras un bloque `Match` no es global.

</details>

9. ¿En qué se diferencian los *namespaces* de los *cgroups*, y por qué un PID 1 como `sleep infinity` llena el contenedor de zombis?

<details>
<summary>Ver respuesta</summary>

Los *namespaces* limitan lo que el proceso **ve** (PIDs, red, montajes, usuarios,
hostname); los *cgroups* limitan lo que **usa** (CPU, memoria, número de procesos).
Un contenedor es un proceso del anfitrión con ambos. En su espacio de PIDs, el
primer proceso es el PID 1, que debe recoger (`wait`) a los hijos huérfanos. Un
`sleep` no lo hace, así que los procesos terminados quedan como zombis y el
contador `PIDs` de `docker stats` crece. Se evita con `docker run --init`, que
pone un PID 1 (`docker-init`/`tini`) que sí recoge.

</details>

10. `toolkit harden` sale con 1 en unos casos y con 2 en otros. ¿Por qué distinguirlos, y por qué un `ok` no significa «seguro»?

<details>
<summary>Ver respuesta</summary>

El `1` significa «no pude mirar» (uso incorrecto, archivo inexistente) y el `2`
«miré y hay hallazgos». Un script de vigilancia debe tratarlos distinto: un `1`
es un fallo de la propia vigilancia y requiere arreglarla; un `2` es información
sobre el sistema. Un `ok` solo dice que **esa comprobación concreta** pasó: la
herramienta mira cuatro cosas de cada objeto y no ve, por ejemplo, los montajes de
un contenedor, las capacidades añadidas, los drop-ins de una unidad ni la
configuración efectiva de `sshd`. Es una auditoría acotada, no un escáner.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Inspeccionar systemd | Confirma el PID 1, localiza archivo y drop-ins, lee `status`, interpreta los códigos de `is-*`, extrae con `show -p`, distingue `blame` de `critical-chain` y lee el diario por unidad y arranque | 6 |
| 02 — Unidades y endurecimiento | Escribe una unidad `oneshot`, distingue error (`rc=1`) de aviso (`rc=0`), valida `OnCalendar`, mide la exposición antes y después del drop-in, usa `cat-config` y `--root enable` | 6 |
| 03 — Seguridad básica y SSH | Concede un comando con `sudo` tras `visudo -cf`, comprueba lo que queda cerrado, inventaría setuid/setgid, arregla un directorio sin sticky, demuestra `umask` y la primera aparición con `sshd -T` | 6 |
| 04 — Contenedores desde el anfitrión | Lista, inspecciona con `--format`, lee `logs`, usa `exec -u`, observa los *namespaces*, lanza un contenedor endurecido en `127.0.0.1` y lo audita | 6 |
| 05 — `harden` a mano (1/2) | Rellena `harden_parse`, `harden_prepare`, `harden_value` (última/primera/`Match`) y `harden_check` con su verificación | 8 |
| 06 — `harden` a mano (2/2) | Rellena `harden_unit`, `harden_ssh`, `harden_perms` y `harden_container`; cierra con `shellcheck` y datos reales | 8 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (6 checks) | 4 |
| `harden unit` sobre una unidad sin aislamiento da 5 riesgos y sale con `2` (1 check) | 2 |
| `harden unit` sobre una unidad con aislamiento da `hallazgos: 0` (1 check) | 2 |
| `harden unit` toma el último valor cuando una directiva se repite (1 check) | 1 |
| `harden ssh` usa la primera aparición (1 check) | 2 |
| `harden ssh` marca la ausencia de `PasswordAuthentication` (1 check) | 1 |
| `harden ssh` ignora lo posterior a `Match` (1 check) | 1 |
| `harden perms` clasifica y ordena, y no marca un directorio con sticky (1 check) | 2 |
| `harden perms --depth 1` y un directorio limpio (1 check) | 1 |
| `harden container` privilegiado, root y con puerto abierto da 5 riesgos (1 check) | 2 |
| `harden container` acepta un contenedor endurecido (1 check) | 1 |
| `harden` sale con `1` ante archivo inexistente u opción desconocida (1 check) | 2 |
| `harden --quiet` no imprime los `ok` (1 check) | 1 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `harden_line` es el único que imprime y cuenta; `harden_value` deja `nocasematch` desactivado y sus patrones `=~` van en variables sin comillas | 2 |
| `harden_perms` usa sustitución de procesos (no tubería), `find -xdev`, `-printf '\0'` y `LC_ALL=C sort -z` | 2 |
| El valor por defecto cuenta (ausencia = riesgo) y los códigos son `0`/`1`/`2` con errores de uso a `stderr` | 2 |
| Cero `# shellcheck disable` sin justificar, asignación y `local` separados donde se captura una salida, sin `eval` ni `export` innecesarios, y `harden` no modifica nada | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` o `NOPASSWD: ALL` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave privada o token con formato real comiteado (también dentro de una configuración de ejemplo) | Grave |
| Lanzar un contenedor con `--privileged`, `--network host` o un puerto publicado fuera de `127.0.0.1` | Grave |
| Inspeccionar o parar contenedores que no son del laboratorio | Grave |
| Cambiar `sshd_config` o `sudoers` reales sin `sshd -t`/`visudo -c` ni sesión de respaldo | Grave |
| `harden` que modifica los archivos o permisos que audita | Grave |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Dar por bueno un `verify` solo por su código de salida | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 19 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
