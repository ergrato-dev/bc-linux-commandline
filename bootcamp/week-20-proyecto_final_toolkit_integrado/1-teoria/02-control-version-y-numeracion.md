# Control, versión y numeración

> El archivo `control` es la ficha del paquete; el número de versión es la promesa sobre qué cambió.
> Si ambos mienten, el gestor de paquetes decide mal cuándo actualizar.

## 🎯 Objetivos

- Leer y escribir los campos obligatorios de un `control`
- Aplicar el versionado `MAYOR.MENOR.PARCHE` y saber cuándo sube cada número
- Comparar versiones como lo hace `dpkg`, incluido `~` para preliminares
- Estampar la versión en el artefacto **construido** sin tocar el código fuente
- Validar una versión antes de construir con una expresión regular anclada

## 1. Qué problema resuelve

`dpkg` decide si una instalación es una **actualización**, una **reinstalación** o
una **degradación** comparando dos cadenas de versión. Si pones `1.9` y luego `1.10`
y el gestor cree que `1.9` es mayor, nadie recibirá la corrección. Y si el binario
instalado dice una versión y el paquete otra, cuando alguien te reporte un fallo no
sabrás qué código está ejecutando.

Dos reglas lo resuelven: una **numeración con significado** y **una sola fuente de
verdad** para la versión, que se estampa al construir.

## 2. Cómo funciona

### 2.1 Los campos de `control`

Es un archivo de texto con pares `Campo: valor`. Los que usa `release build`:

| Campo | Ejemplo | Para qué |
|---|---|---|
| `Package` | `toolkit` | El nombre. Minúsculas, dígitos, `+`, `-` y `.` |
| `Version` | `1.2.3` | Lo que `dpkg` compara |
| `Architecture` | `all` | `all` = no depende del procesador (un script); `amd64` si hubiera binarios |
| `Maintainer` | `Toolkit <toolkit@example.invalid>` | Quién responde del paquete |
| `Depends` | `bash (>= 5.0)` | Paquetes que deben estar instalados antes |
| `Section` / `Priority` | `utils` / `optional` | Clasificación para los repositorios |
| `Installed-Size` | `100` | KiB que ocupa instalado (`du -sk`) |
| `Description` | `caja de herramientas…` | Primera línea: resumen. Las siguientes **empiezan por un espacio** |

La descripción extendida es la parte que más se rompe: una línea que no empieza
por espacio se lee como un campo nuevo.

```
Description: caja de herramientas personal de sysadmin
 Subcomandos para inspeccionar, auditar y automatizar una maquina Linux
 desde la linea de comandos.
```

(Un párrafo en blanco dentro de la descripción se escribe ` .`, un espacio y un punto.)

`Depends: bash (>= 5.0)` es una **promesa verificable**: `toolkit.sh` usa
`${var,,}` (pasar a minúsculas), que exige bash 4 o superior, y se ha probado con
bash 5.2. Si pones un requisito más estricto de lo que
usas, el paquete no se instala donde sí funcionaría; si más laxo, se instala donde
fallará.

### 2.2 Versionado con significado

El esquema `MAYOR.MENOR.PARCHE` (en inglés *semantic versioning*) dice qué cambió:

| Sube… | Cuando… | Ejemplo en `toolkit` |
|---|---|---|
| **MAYOR** | Rompes algo que funcionaba | Cambiar los códigos de salida de `audit` |
| **MENOR** | Añades algo compatible | Un subcomando nuevo (`harden`) |
| **PARCHE** | Corriges un fallo sin cambiar el contrato | Que `logscan` ignore un directorio vacío |

Al subir un número, los de la derecha vuelven a cero: `1.4.7` → `1.5.0`.

Con la numeración como contrato, **un mensaje de error es parte del contrato**
si otros scripts lo leen. Es la razón de que las semanas anteriores fijaran los
mensajes exactos y los códigos `0/1/2`.

### 2.3 Cómo compara versiones `dpkg`

`dpkg` no compara números sino **trozos**: alterna texto y dígitos y compara
los dígitos como enteros. `dpkg --compare-versions A OP B` devuelve 0 si se cumple:

```bash
dpkg --compare-versions 1.10.0 gt 1.9.0  && echo si
# si                    (10 > 9: es numérico, no alfabético)
dpkg --compare-versions 1.0.0~rc1 lt 1.0.0 && echo si
# si                    (el ~ ordena ANTES que la versión final)
dpkg --compare-versions 1.0.0 lt 1.0.0-1  && echo si
# si                    (-1 es la revisión del empaquetado)
```

El `~` es el recurso para preliminares: `1.0.0~rc1` precede a `1.0.0`. Y la
**revisión** (`-1`, `-2`) cambia cuando arreglas el *empaquetado* sin cambiar el
programa; para una herramienta propia, que es su propio origen, se omite.

### 2.4 Una sola fuente de verdad

La versión se declara **una vez** en el script:

```bash
TOOLKIT_VERSION="1.0.0"
```

y de ahí salen el comando `toolkit version`, el nombre del archivo
(`toolkit_1.0.0_all.deb`), el campo `Version:` y la cabecera de la página de manual.
Pero `release build --version 1.2.3` permite construir una versión **distinta** de
la que hay en el fuente. Para que el binario instalado no se contradiga, se
**estampa** en la copia que va al paquete:

```bash
# Solo la linea TOOLKIT_VERSION="...", en la copia de staging; el original no cambia.
sed -i "s/^TOOLKIT_VERSION=\".*\"\$/TOOLKIT_VERSION=\"${RL_VERSION}\"/" "$dir/usr/bin/toolkit"
```

El patrón empieza por `^` y acaba por `$` para tocar **solo** esa línea; un `sed`
sin anclas podría cambiar una cadena parecida dentro del código. Resultado:

```bash
toolkit release build --out /tmp/o --version 1.2.3 >/dev/null
dpkg-deb -x /tmp/o/toolkit_1.2.3_all.deb /tmp/x
/tmp/x/usr/bin/toolkit version
# toolkit 1.2.3
toolkit version
# toolkit 1.0.0
```

El paquete declara `1.2.3`; tu script de trabajo sigue declarando `1.0.0`.

### 2.5 Validar antes de construir

Una versión inválida debe fallar **antes** de crear nada:

```bash
re='^[0-9]+\.[0-9]+\.[0-9]+$'
[[ "1.0" =~ $re ]] || echo "toolkit release build: version invalida: 1.0 (usa MAYOR.MENOR.PARCHE)"
```

Con la regex en una variable y **sin comillas** (entre comillas bash compara
como texto literal). Lo que se valida es el **formato**; que `1.2.3` sea mayor
que la anterior lo decide `dpkg` al instalar.

## 3. Cómo se usa

### 3.1 Un registro de cambios

Un `CHANGELOG.md` junto al código responde «¿qué trae esta versión?» sin leer el
historial de `git`. Un formato mínimo, versión por versión, lo más reciente arriba
(los cambios de este ejemplo son ilustrativos):

```markdown
## 1.1.0 - 2026-10-25
### Añadido
- `harden`: auditorías de unidades, SSH, permisos y contenedores.
### Cambiado
- `healthcheck` sale con 2 si falla cualquier comprobación (antes, solo si fallaban dos).

## 1.0.0 - 2026-10-18
- Primera versión: 19 subcomandos.
```

La regla práctica: **toda versión que sale lleva su entrada**, y el número del
`CHANGELOG` coincide con `TOOLKIT_VERSION`.

### 3.2 Divergencia de distro

El concepto es idéntico, la sintaxis cambia: en RHEL la versión y la revisión van en
campos separados del `.spec` (`Version:` y `Release:`) y en Arch en variables
del `PKGBUILD` (`pkgver` y `pkgrel`). Además, `rpm` y `pacman` comparan versiones con
reglas **ligeramente distintas** de las de `dpkg` (no tratan `~` igual); por eso no
mezcles esquemas de preliminares entre familias.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Versión en tres sitios a mano | Se desincronizan | Una constante y estampar al construir |
| `1.9` y luego `1.10` leído como texto | Orden alfabético: `1.10` < `1.9` | Comparar con `dpkg --compare-versions` |
| Subir PARCHE al añadir una función | Quien confía en el contrato no se entera | MENOR para lo compatible nuevo |
| Reutilizar un número de versión | Dos paquetes distintos con el mismo nombre | Una versión nueva por cada artefacto publicado |
| `sed` sin anclas para estampar | Cambia más de una línea | `^…$` y comprobar con `grep -c` |
| Descripción extendida sin espacio inicial | Se lee como campo nuevo | Cada línea de continuación empieza por un espacio |
| `Depends` demasiado estricto | No se instala donde sí funcionaría | Solo lo que de verdad usas |

## 5. Trucos

- **`dpkg --compare-versions A gt B`** en un `if` es la prueba de «¿esta versión es
  más nueva?» que necesitan los scripts de actualización.
- **`dpkg-query -W -f='${Version}\n' toolkit`** devuelve solo la versión instalada,
  sin cabeceras: pásalo a un script.
- **`dpkg-parsechangelog`** (del paquete `dpkg-dev`) lee un `debian/changelog`, pero
  tu `CHANGELOG.md` simple te basta mientras no publiques en un repositorio.

## 📚 Recursos Adicionales

- `man deb-control`, `man deb-version`
- [Versionado semántico 2.0.0](https://semver.org/lang/es/)

## ✅ Checklist de Verificación

- [ ] Sabes qué campos de `control` son obligatorios y cómo se continúa la descripción
- [ ] Decides si un cambio sube MAYOR, MENOR o PARCHE
- [ ] Compruebas con `dpkg --compare-versions` que `1.10.0` es mayor que `1.9.0`
- [ ] Demuestras que `1.0.0~rc1` precede a `1.0.0`
- [ ] Estampas una versión distinta en el paquete sin cambiar tu script
- [ ] Rechazas `1.0` con una expresión regular anclada

---

[← Empaquetar una herramienta](01-empaquetar-una-herramienta.md) · [Instalar, verificar y quitar →](03-instalar-verificar-y-quitar.md)
