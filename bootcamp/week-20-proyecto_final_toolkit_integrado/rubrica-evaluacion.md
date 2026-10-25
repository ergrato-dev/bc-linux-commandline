# Rúbrica de Evaluación — Semana 20

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. `release build` crea su temporal en `${RL_OUT}` y no en `/tmp`, y publica con `mv`. ¿Qué garantiza eso y qué se perdería con `/tmp`?

<details>
<summary>Ver respuesta</summary>

`mv` dentro del **mismo sistema de archivos** es un renombrado: una operación
atómica. Otro proceso ve el `.deb` completo o no lo ve, nunca a medias, y un corte
de luz en mitad de `dpkg-deb --build` deja un temporal oculto, no un paquete roto
con un nombre válido. Si el temporal estuviera en `/tmp` y la salida en otro
disco, `mv` copiaría y borraría: deja de ser atómico y aparece de nuevo la ventana
en la que existe un archivo a medias. Por eso el temporal se crea **junto al destino**
y el `trap … EXIT` se encarga de borrarlo si algo falla.

</details>

2. `dpkg --verify toolkit` sale con 0 y no imprime nada, pero alguien ha hecho `chmod 777 /usr/bin/toolkit`. ¿Por qué no lo ve, y dónde sí puedes detectarlo?

<details>
<summary>Ver respuesta</summary>

`dpkg --verify` solo compara el **contenido** de cada archivo con la suma MD5 de
`md5sums` y avisa de los que **faltan**; no mira permisos ni propietario (en la
salida solo existe la posición `5` y la palabra `missing`). Un cambio de modo o
de dueño pasa limpio. Además sale con 0 aunque haya diferencias, así que un script
debe comprobar que su salida esté vacía, no su código. Los permisos incorrectos se
detectan **antes de instalar**, en el listado del paquete (`dpkg-deb -c`): es lo
que hace el chequeo `permisos` de `release verify`.

</details>

3. ¿Por qué `dpkg` considera `1.10.0` mayor que `1.9.0`, y qué hace el `~` en `1.0.0~rc1`?

<details>
<summary>Ver respuesta</summary>

`dpkg` no compara cadenas de texto sino **trozos alternos** de dígitos y letras, y
los dígitos como números enteros: `10 > 9`. Como texto, `1.10.0` sería menor
(`"1" < "9"`), y nadie recibiría la actualización. El `~` ordena **antes** que el
fin de cadena: `1.0.0~rc1 < 1.0.0`, de forma que una preliminar nunca desplaza a la
versión final. La prueba directa es `dpkg --compare-versions A lt B`.

</details>

4. `release verify` da `fallos: 0`, pero alguien ha sustituido el `.deb` **y** el `SHA256SUMS`. ¿Qué protege la suma y qué no?

<details>
<summary>Ver respuesta</summary>

Una suma protege la **integridad**: detecta corrupción, edición posterior o un
paquete que no es el que se anotó. No protege el **origen**: quien puede cambiar el
paquete y el archivo de sumas, que están en el mismo sitio, cambia las dos cosas y
todo cuadra. Para el origen hace falta una **firma** (GPG) con una clave cuya parte
pública el usuario ya tenga por otro canal, o publicar la suma por un canal distinto
del paquete. La suma protege del error; la firma, del adversario.

</details>

5. Explica cada pieza de `( "$@" ) >/dev/null 2>&1 || rc=$?` en `selftest_case` y qué pasaría si falta una.

<details>
<summary>Ver respuesta</summary>

Los paréntesis lanzan el comando en un **subproceso**: si ejecuta `exit 2`, solo
muere ese subproceso, y si cambia variables, no contamina al arnés. `>/dev/null
2>&1` oculta la salida de lo probado, que taparía el resumen y no es lo que se
prueba. `|| rc=$?` captura el código **sin que `set -e` aborte**: sin él, el primer
caso que devuelve distinto de 0 (justo lo que esperan los casos negativos) mataría
la autoprueba. Sin los paréntesis, un `exit` dentro de una función termina el
script entero.

</details>

6. Cuatro de los cinco casos de `selftest` esperan el código 2. ¿Por qué no basta con probar que las cosas salen bien?

<details>
<summary>Ver respuesta</summary>

Una herramienta que **siempre** devuelve 0 pasaría cualquier prueba de «sale
bien». Para saber que `audit` sirve hay que darle una carpeta con un archivo `0777`
y **exigir** que proteste: es una prueba de caso negativo y atrapa el error más
peligroso de una herramienta de auditoría, el falso negativo. El mismo principio
explica que una autoprueba **vacía** pase (`pruebas: 0, fallos: 0`): no ha
comprobado nada, y por eso hay que romper un caso a propósito y ver que `selftest`
lo delata con código 2.

</details>

7. `dpkg-deb --build` falla con `control directory has bad permissions 700`. ¿De dónde sale el 700 y cuándo preocuparte por `--root-owner-group`?

<details>
<summary>Ver respuesta</summary>

`mktemp -d` crea directorios con modo `0700` por seguridad, y `dpkg-deb` exige que
la raíz del paquete y `DEBIAN/` estén entre `0755` y `0775`. Se arregla con
`chmod 0755` antes de montar el árbol. `--root-owner-group` guarda todos los
archivos como `root:root` aunque los hayas creado tú: en el laboratorio ya eres
root y no se nota, pero en tu máquina el paquete llevaría **tu usuario**, que no
existe en el destino. Por eso se usa siempre. Atención: el fallo de permisos es
limpio (no crea paquete), a diferencia de un campo `Description` ausente, que solo
avisa y sale con 0 con un paquete mal formado.

</details>

8. El script dice `1.0.0`, pero `release build --version 1.2.3` crea `toolkit_1.2.3_all.deb`. ¿Qué dice el programa instalado y cómo se consigue?

<details>
<summary>Ver respuesta</summary>

Dice `toolkit 1.2.3`: durante `release_stage` se **estampa** la versión en la
**copia** que va al paquete con `sed -i
's/^TOOLKIT_VERSION=".*"$/TOOLKIT_VERSION="1.2.3"/'`, y el script de trabajo
sigue diciendo `1.0.0`. El patrón lleva `^` y `$` para tocar solo esa línea. Sin
estampar, el paquete diría una versión en el `control` y otra al ejecutarlo, y el
informe de un fallo no diría qué código corre. Es la idea de una **única fuente de
verdad** que se propaga al construir.

</details>

9. Tras instalar `toolkit` en `ubuntu-lab`, `dpkg -L` lista la página de manual pero `dpkg --verify` dice `missing`. ¿Qué ocurre y cómo la ves?

<details>
<summary>Ver respuesta</summary>

La imagen de Docker está «minimizada»: `/etc/dpkg/dpkg.cfg.d/excludes` contiene
`path-exclude=/usr/share/man/*`, y `dpkg` no instala lo que coincide, aunque el
paquete lo contenga. No es un error del paquete. Dos soluciones: instalar con
`dpkg -i --path-include='/usr/share/man/*'` o, sin instalar, extraer con
`dpkg-deb -x` y renderizar con `zcat … | groff -man -Tascii -P-c | col -b`. (Y
`man` en esa imagen es un sustituto que solo avisa del sistema minimizado.)

</details>

10. `groff -man -z -ww` sale con 0 sobre una página con una macro inexistente. ¿Cómo la comprobarías en un script, y qué otra herramienta del bootcamp se comporta igual?

<details>
<summary>Ver respuesta</summary>

Los avisos de `groff` van por `stderr` y no cambian el código de salida, así que
la comprobación fiable es que la **salida combinada esté vacía**:
`test -z "$(groff -man -z -ww p.1 2>&1)"`. Se comporta igual `dpkg --verify` (sale
con 0 con diferencias) y `systemd-analyze verify` con una clave desconocida (aviso,
código 0). Es un patrón general: antes de fiarte del código de salida de una
herramienta de **comprobación**, mira qué hace cuando encuentra un problema leve.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Un `.deb` por dentro | Monta el árbol, escribe el `control`, construye con `--root-owner-group`, lee con `-I`/`-f`/`-c`, abre control y datos por separado, extrae con `-x` y provoca el error de permisos y el aviso por campo ausente | 6 |
| 02 — Manual, versión y documentación | Usa `version` y `--short`, localiza la única fuente de versión, genera y renderiza la página, la comprueba leyendo la salida de `groff -z -ww`, comprime con `gzip -n` y contrasta los códigos de salida con el manual | 6 |
| 03 — Instalar, verificar y quitar | Construye dos versiones, instala, usa `-s`/`-L`/`-S`, explica el `missing` del manual, detecta una manipulación y su límite, actualiza, degrada, quita y usa `apt-get install ./` | 6 |
| 04 — Probar con un arnés | Fija un caso negativo, escribe `t NOMBRE ESPERADO CMD...`, comprueba el `trap`, rompe un caso, demuestra `\|\| rc=$?` y el subproceso, usa `shellcheck` y `PS4` | 6 |
| 05 — `release` a mano (1/2) | Rellena `release_parse`, `release_prepare`, `release_stage` y `release_build` con su verificación y la idempotencia de `SHA256SUMS` | 8 |
| 06 — `verify` y `selftest` a mano (2/2) | Rellena `release_verify`, `selftest_case`, `selftest_fixture` y `cmd_selftest`; rompe el paquete de cuatro maneras y la propia prueba; cierra con `shellcheck` y 18/18 | 8 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `shellcheck` limpio y regresión de las capas anteriores (6 checks) | 4 |
| `version` imprime `toolkit 1.0.0` y `--short` solo el número (1 check) | 1 |
| `release build` crea el `.deb` con `Package` y `Version` correctos y su línea en `SHA256SUMS` (1 check) | 2 |
| `release build` imprime `paquete:` y `sha256:` con la suma real (1 check) | 1 |
| El `.deb` lleva `toolkit` 755, el manual comprimido y nada escribible por grupo u otros (1 check) | 2 |
| El `toolkit` extraído del `.deb` declara la versión del paquete (1 check) | 2 |
| `release build` rechaza una versión inválida con `1` y no crea nada (1 check) | 1 |
| `release build --dry-run` anuncia el paquete y no escribe nada (1 check) | 1 |
| `release verify` da seis `ok` y `fallos: 0` (1 check) | 2 |
| `release verify` detecta un `.deb` manipulado con `2` y `falla suma` (1 check) | 2 |
| `release` sale con `1` sin `--out`, con opción desconocida y con paquete inexistente (1 check) | 1 |
| `selftest` pasa con cinco `ok` y `--quiet` solo imprime el resumen (1 check) | 2 |
| `selftest_case` marca `falla` con esperado y obtenido, y cuenta el fallo (1 check) | 1 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `release_line` es el único que imprime y cuenta un chequeo de `verify`; los patrones `=~` van en variables sin comillas; los errores de uso salen por `stderr` con el prefijo `toolkit release ACCION: ` | 2 |
| El `.deb` se escribe en un temporal **dentro de `--out`** y se publica con `mv`, con `trap … EXIT` y `trap - EXIT`; `SHA256SUMS` no duplica líneas y se calcula con el nombre sin ruta | 2 |
| `selftest_case` aísla en subproceso y captura con `\|\| rc=$?`; `selftest` lanza los casos con `"$TK_SELF"`, usa una maqueta `mktemp -d` borrada con `trap` y sus códigos son `0`/`1`/`2` | 2 |
| Cero `# shellcheck disable` sin justificar, versión estampada solo en la copia del paquete, sin `eval` ni `export` innecesarios, y los subcomandos anteriores intactos | 2 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `sudo su -`/`sudo bash` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| Secreto, clave privada o token con formato real comiteado (incluida una clave de firma del paquete) | Grave |
| Instalar el paquete en tu máquina principal en lugar de en `ubuntu-lab` | Grave |
| `rm -rf` sobre una ruta no comprobada, o fuera de `/tmp/wk20` | Grave |
| `release build` que escribe el `.deb` final directamente, dejando un archivo a medias si falla | Moderada |
| `shellcheck` con hallazgos o con `disable` sin justificar | Moderada |
| Dar por bueno `dpkg --verify` o `groff -z -ww` solo por su código de salida | Moderada |
| Mensajes de error escritos a `stdout` en lugar de `stderr` | Leve |

---

[← Proyecto: Capa 20 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
