# Rúbrica de Evaluación — Semana 12

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. ¿Por qué un fallo de red se diagnostica de abajo hacia arriba y no al revés?

<details>
<summary>Ver respuesta</summary>

Porque cada capa depende de la de abajo: sin interfaz no hay ruta, sin
ruta no llega la consulta DNS, sin IP no se puede probar un puerto. Un
fallo en una capa **explica** los de las de arriba, así que se arregla
primero la más baja que falle. Empezar por arriba (reiniciar el servicio,
cambiar el DNS) es cambiar cosas sin saber cuál es el problema.

</details>

2. ¿Cuándo sale un paquete por la puerta de enlace y cuándo se entrega directamente?

<details>
<summary>Ver respuesta</summary>

El kernel elige la ruta de **prefijo más largo** que encaje con el
destino. Si el destino está en la red de la interfaz (`172.27.0.0/16` y
destino `172.27.0.4`), gana esa ruta: entrega directa, sin `via`. Si no
encaja ninguna ruta específica, se usa `default via GATEWAY`. Lo muestra
`ip route get DESTINO`: con `via` sale por la puerta de enlace; sin `via`,
directo.

</details>

3. ¿Por qué `getent hosts nombre` puede resolver un nombre que `dig nombre` no ve?

<details>
<summary>Ver respuesta</summary>

`getent` pasa por NSS, que según `/etc/nsswitch.conf` (`hosts: files dns`)
consulta **primero** `/etc/hosts` y después el DNS: hace lo mismo que
`ping`, `curl` o `ssh`. `dig` se salta NSS y pregunta directo al servidor
DNS. Una entrada solo en `/etc/hosts` la ve `getent` y no `dig`. Para saber
qué verá tu programa se usa `getent`; para saber qué dice el DNS, `dig`.

</details>

4. ¿Qué diferencia hay entre `Connection refused` y `Connection timed out`, y qué sugiere cada una?

<details>
<summary>Ver respuesta</summary>

*Refused* es una respuesta **inmediata** de la máquina destino: llegaste,
pero en ese puerto no escucha nadie (servicio apagado, puerto equivocado, o
escucha en otra dirección). *Timed out* es **ausencia de respuesta**: el
paquete se perdió o alguien lo descartó (máquina caída, ruta mala,
cortafuegos). El primero dice que la red funciona; el segundo, que no sabes
dónde se perdió el paquete.

</details>

5. Un servidor funciona con `curl localhost:8080` pero falla desde otra máquina. ¿Qué miras primero y por qué?

<details>
<summary>Ver respuesta</summary>

La **dirección de escucha**: `ss -tlnp`. Si el servidor escucha en
`127.0.0.1:8080`, solo la propia máquina puede conectarse (desde fuera da
*refused*); si escucha en `0.0.0.0:8080`, también la red. Es el error más
frecuente de "mi servicio no responde". Escuchar en `0.0.0.0` expone el
servicio a toda la red: se hace deliberadamente, no "para que funcione".

</details>

6. ¿Por qué `curl` sin `-f` sale con `0` ante un `404`, y qué códigos de salida distinguen DNS, TCP y timeout?

<details>
<summary>Ver respuesta</summary>

Para `curl`, la petición **funcionó**: recibió una respuesta HTTP, aunque
fuera un error. `-f` convierte los `4xx`/`5xx` en el código `22`. Los demás
códigos identifican la capa: `6` = no resolvió el nombre (DNS), `7` =
conexión rechazada (TCP), `28` = tiempo agotado (ruta o cortafuegos). Un
script robusto usa `-sSf` y `--max-time`.

</details>

7. ¿Qué archivo de un par de claves SSH se comparte, cuál nunca, y qué ocurre si la privada tiene modo `644`?

<details>
<summary>Ver respuesta</summary>

Se comparte la **pública** (`id_ed25519.pub`, se instala en el
`authorized_keys` del servidor); la **privada** (`id_ed25519`, modo `600`)
nunca sale de la máquina del usuario: es su identidad. Con modo `644`,
`ssh` se niega a usarla (`UNPROTECTED PRIVATE KEY FILE!`), porque otros
usuarios podrían leerla. En un entorno real, la privada lleva además una
passphrase.

</details>

8. ¿Qué significa `REMOTE HOST IDENTIFICATION HAS CHANGED` y qué NO se debe hacer al verlo?

<details>
<summary>Ver respuesta</summary>

La huella del servidor ya no coincide con la guardada en `known_hosts`.
Las causas honestas son frecuentes (servidor reinstalado, contenedor
recreado, IP reasignada); la grave es que alguien se interponga en la
conexión. Hay que **averiguar cuál es** antes de actuar. Lo que no se hace
es borrar todo `known_hosts` ni poner `StrictHostKeyChecking=no`: se pierde
la protección de todos los servidores. Si la causa es honesta, se quita solo
la entrada afectada con `ssh-keygen -R host`.

</details>

9. ¿Por qué `[[ "$puerto" -ge 1 ]]` es peligroso con una entrada del usuario y cómo se evita?

<details>
<summary>Ver respuesta</summary>

`-ge` dentro de `[[ ]]` **evalúa el contenido como una expresión
aritmética**, y bash ejecuta una sustitución de comando dentro de un índice:
un "puerto" como `a[$(comando)]` ejecuta el comando. Se evita con una
**regex previa** que exija solo dígitos (`[[ $p =~ ^[0-9]+$ && $p -ge 1 ]]`):
`&&` corta antes de llegar a la comparación aritmética.

</details>

10. ¿Por qué `((fallos++))` rompe un script con `set -e` y qué se escribe en su lugar?

<details>
<summary>Ver respuesta</summary>

`((expresión))` sale con código `1` cuando la expresión vale `0`, y `f++`
devuelve el valor **anterior**: la primera vez `0`. Con `set -e`, ese `1`
aborta el script en el primer fallo, justo cuando se quería seguir
contando. `fallos=$(( fallos + 1 ))` es una asignación: siempre sale con
`0`.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — interfaces, rutas y puertos | Lee interfaz, IP y gateway (con `ip` y con `/proc/net/route`) y demuestra `127.0.0.1` frente a `0.0.0.0` desde otro contenedor | 10 |
| 02 — DNS y curl | Reproduce la diferencia `getent`/`dig`, restaura `/etc/hosts` y provoca los códigos `0`, `22`, `7`, `6` y `28` | 10 |
| 03 — SSH entre contenedores | Entra con clave, resuelve un aviso de huella cambiada con `ssh-keygen -R`, y abre y cierra un túnel | 10 |
| 04 — netcheck a mano | Valida el puerto con regex, construye las cuatro capas y las junta con código de salida `0`/`2` | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable y regresión de las capas anteriores (4 checks) | 4 |
| `netcheck`: validación de entrada, host y puerto (2 checks) | 3 |
| `netcheck`: interfaz y ruta por defecto (2 checks) | 4 |
| `netcheck`: DNS que resuelve, DNS que falla e IP literal (3 checks) | 5 |
| `netcheck`: TCP abierto, cerrado y omitido sin DNS (3 checks) | 4 |
| `netcheck`: código de salida `0` con todo bien y `2` con un fallo (2 checks) | 2 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `shellcheck` limpio sobre el starter completo | 3 |
| Cada capa usa una fuente sin dependencias (`/sys`, `/proc`, `getent`, `/dev/tcp`) y lo documenta | 2 |
| Valida el puerto con regex **antes** de comparar con `-ge`/`-le` | 2 |
| Cuenta fallos con `fallos=$(( fallos + 1 ))`, no `((fallos++))` | 1 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Clave privada SSH (aunque sea de laboratorio) o token con formato real comiteado | Grave |
| `StrictHostKeyChecking=no` permanente, o borrar todo `known_hosts` para silenciar un aviso, sin explicarlo | Grave |
| `sudo su -`/`sudo bash` o `curl \| sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Exponer un servicio en `0.0.0.0` o publicar un puerto del laboratorio al host sin justificarlo | Grave |
| `userdel -r` u otro comando destructivo sin aviso ni respaldo previo | Grave |
| `shellcheck` con hallazgos sin justificar | Moderada |

---

[← Proyecto: Capa 12 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
