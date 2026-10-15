# Guía de autoría — Bootcamp Linux Command Line

Este archivo es la **fuente única de verdad** de cómo se escribe el contenido
de este repositorio (no hay `.github/copilot-instructions.md`: este proyecto
no usa Copilot, todo el contrato vive aquí).

---

## 📋 Contexto del Bootcamp

`bc-linux-commandline` enseña **la línea de comandos de Linux de cero a
avanzado**, usando Ubuntu 24.04 LTS como entorno de referencia pero señalando
la divergencia real frente a las demás familias de distribuciones más usadas
(Debian, RHEL/Fedora, Arch). El alumno termina operando cualquier máquina
Linux por SSH sin GUI, procesando texto y logs con el pipeline de Unix,
automatizando tareas reales con bash, y entendiendo suficiente de procesos,
permisos, paquetes y red para ser un usuario de CLI confiable — sin
convertirse en curso de sysadmin/DevOps completo.

### 📊 Datos del bootcamp

| Dato | Valor |
|---|---|
| Duración | 20 semanas |
| Dedicación | 10 h/semana |
| Total | 200 horas |
| Modalidad | Autoestudio asincrónico |
| Nivel de entrada | Cero. No requiere terminal previa ni programación |
| Nivel de salida | Opera, automatiza y diagnostica sistemas Linux desde la CLI en cualquier distro mayor |
| Herramienta central | bash + coreutils (GNU) |
| Distro de referencia | Ubuntu 24.04 LTS |
| Entorno de prácticas | Laboratorio Docker multi-distro, versiones fijadas |
| Proyecto hilo conductor | `toolkit`, una caja de herramientas personal de sysadmin que crece las veinte semanas |
| Idioma de la prosa | Español |
| Idioma del código | Inglés |

---

## 🎯 Objetivos de Aprendizaje

Al terminar el bootcamp el alumno es capaz de:

- Moverse por cualquier sistema de archivos Linux sin GUI y explicar el FHS
- Leer y escribir permisos (rwx, octal, ACLs, bits especiales) sin adivinar
- Construir un pipeline de `grep`/`sed`/`awk`/`cut`/`sort`/`find`/`xargs` para
  resolver un problema real de texto o logs, no copiarlo de internet
- Gestionar procesos: listar, interpretar señales, controlar jobs, leer el
  estado de un servicio con `systemctl`/`journalctl`
- Instalar y gestionar paquetes en `apt`, `dnf` y `pacman`, y explicar en qué
  se parecen y en qué no
- Diagnosticar red desde la terminal (`ip`, `ss`, `curl`, `dig`, SSH) sin GUI
- Escribir un script bash que falla cuando debe fallar, con `set -euo
  pipefail`, `trap` y validación de entradas — limpio de `shellcheck`
- Programar tareas con `cron` y temporizadores de systemd
- Leer el estado de contenedores desde la CLI (`docker ps/logs/exec`) y
  conectarlo con lo ya aprendido de procesos y namespaces
- Reconocer cuándo un problema de "línea de comandos" en realidad pide un
  curso distinto (bash avanzado, sysadmin, vim) y saber adónde ir después

---

## 📚 Estructura del Bootcamp

### Distribución por fases

#### Fase 1 — Fundamentos (S01-04, 40 h)
Shell, terminal, navegación, sistema de archivos, permisos. Al terminar el
alumno se mueve por cualquier máquina Linux sin GUI.

#### Fase 2 — Manipulación de Datos (S05-08, 40 h)
`grep`, `sed`, `cut`, `sort`, `uniq`, `tr`, `awk`, pipes y redirección. Al
terminar el alumno construye pipelines de texto para resolver problemas
reales.

#### Fase 3 — Sistema y Procesos (S09-12, 40 h)
`find`/`xargs`, procesos y señales, usuarios y gestores de paquetes
comparados, red desde la CLI. Al terminar el alumno diagnostica una máquina
que no conoce.

#### Fase 4 — Automatización (S13-16, 40 h)
Bash scripting de cero a robusto, `cron` y temporizadores de systemd. Al
terminar el alumno automatiza tareas reales sin miedo a que fallen en
silencio.

#### Fase 5 — Avanzado (S17-19, 30 h)
Personalización del entorno, archivado y logs, inspección de systemd,
seguridad básica y contenedores desde la CLI. Al terminar el alumno opera con
soltura y sabe dónde está el límite de este bootcamp.

#### Fase 6 — Producción / Integración (S20, 10 h)
Integración final del `toolkit`, documentación, empaquetado. Al terminar el
alumno entrega una herramienta instalable y demostrable.

### Contenido semana a semana

| Semana | Slug | Tema |
|:--:|---|---|
| 01 | `week-01-terminal_shell_y_primeros_pasos` | Terminal, shell y primeros pasos |
| 02 | `week-02-navegacion_y_sistema_de_archivos` | Navegación y sistema de archivos |
| 03 | `week-03-manipulacion_de_archivos_y_directorios` | Manipulación de archivos y directorios |
| 04 | `week-04-permisos_y_propiedad` | Permisos y propiedad |
| 05 | `week-05-redireccion_pipes_y_flujo_de_datos` | Redirección, pipes y flujo de datos |
| 06 | `week-06-busqueda_de_texto_con_grep_y_regex` | Búsqueda de texto con grep y regex |
| 07 | `week-07-procesamiento_de_texto_sed_cut_sort_uniq` | Procesamiento de texto: sed, cut, sort, uniq, tr |
| 08 | `week-08-awk_y_pipelines_de_datos` | awk y pipelines de datos |
| 09 | `week-09-busqueda_de_archivos_find_y_xargs` | Búsqueda de archivos y ejecución en lote |
| 10 | `week-10-gestion_de_procesos_y_senales` | Gestión de procesos y señales |
| 11 | `week-11-usuarios_grupos_y_gestion_de_paquetes` | Usuarios, grupos y gestión de paquetes |
| 12 | `week-12-redes_desde_la_linea_de_comandos` | Redes desde la línea de comandos |
| 13 | `week-13-fundamentos_de_bash_scripting` | Fundamentos de bash scripting |
| 14 | `week-14-control_de_flujo_y_funciones_en_bash` | Control de flujo y funciones en bash |
| 15 | `week-15-scripts_robustos_manejo_de_errores` | Scripts robustos: manejo de errores |
| 16 | `week-16-automatizacion_y_tareas_programadas` | Automatización y tareas programadas |
| 17 | `week-17-personalizacion_del_entorno_y_productividad` | Personalización del entorno y productividad |
| 18 | `week-18-archivado_compresion_y_registros_del_sistema` | Archivado, compresión y registros del sistema |
| 19 | `week-19-systemd_seguridad_y_contenedores_desde_cli` | Inspección de systemd, seguridad básica y contenedores desde CLI |
| 20 | `week-20-proyecto_final_toolkit_integrado` | Proyecto final: toolkit integrado |

> **Esta tabla vive en dos archivos**: aquí y en `README.md`/`README_EN.md`.
> Si cambia una, cambian las tres.

---

## 🗂️ Estructura de Carpetas

```
bc-linux-commandline/
├── README.md                  # Contrato con el alumno
├── README_EN.md               # Único espejo en inglés
├── CLAUDE.md                  # Esta guía — fuente única de verdad
├── LICENSE
├── docker-compose.yml · .env.example   # El laboratorio multi-distro
├── assets/bootcamp-header.svg          # Solo recursos visuales globales
├── docs/                      # Documentación transversal a las veinte semanas
├── scripts/                   # start/stop del laboratorio y verificación
└── bootcamp/week-NN-tema/     # El contenido
```

Regla de reparto: si algo aplica a **todas** las semanas va en `docs/`; si
aplica a una, va dentro de su semana. Los SVG globales van en `assets/`; los
de una semana, en el `0-assets/` de esa semana. Nunca al revés.

---

## 🎓 Componentes de Cada Semana

```
week-XX-tema_principal/
├── README.md
├── rubrica-evaluacion.md
├── checks.json
├── 0-assets/
├── 1-teoria/
├── 2-practicas/
├── 3-proyecto/
│   ├── README.md
│   └── starter/            ← el único sitio donde vive código de partida
├── 4-recursos/{ebooks-free,videografia,webgrafia}/README.md
└── 5-glosario/README.md
```

### 1-teoria/

**El número de archivos es libre: los que pida el temario, no un cupo fijo.**
Seis u ocho es lo normal. **Nunca se sacrifica profundidad para que quepa.**

- **Extensión por archivo**: ~250 líneas, rango sano 200-300. Si un archivo se
  sale, casi siempre mezcla dos temas: divídelo, no recortes.
- **Un archivo, un concepto.**
- **Orden fijo**: qué problema resuelve → cómo funciona → cómo se usa →
  antipatrones → trucos.
- **Todo ejemplo se ejecuta contra `ubuntu-lab`**, el contenedor canónico. Si
  un ejemplo necesita otra familia de distro, dilo y usa el contenedor de
  exploración correspondiente (`debian-lab`, `rhel-lab`, `arch-lab`).
- **Marca la divergencia de distro** de todo comando que no sea universal
  (nombre de paquete distinto, flag distinto, ruta distinta). Ver
  [`docs/divergencia-distros.md`](docs/divergencia-distros.md).
- Diagramas en SVG, nunca arte ASCII.

Nomenclatura: `NN-tema-en-kebab-case.md`, numerados desde `01`.

### 2-practicas/

Archivos planos, **200-380 líneas** cada uno. Nada de carpeta por ejercicio:
`NN-titulo-en-kebab-case.md` y punto. El `starter/` vive en `3-proyecto/`, que
es donde el entregable es código.

Formato canónico de un paso:

````markdown
## Paso 3: Distinguir un proceso zombi de uno huérfano

**Por qué**: `kill -9` a un padre sin esperar a sus hijos (`wait`) deja
procesos zombi que un script de limpieza automatizado no puede matar — ya
están muertos, solo falta que el padre los reciba. Confundir esto con un
proceso colgado hace que el script intente matar algo que no se puede matar.

**Comando**:

```bash
# STAT Z = zombi: el proceso terminó, el padre no ha llamado wait() todavía.
# No se mata con -9: hay que arreglar o matar al padre.
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'
```

**Verifica**:

```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'
# PID   PPID  STAT  CMD
# 4821  4820  Z+    [sleep] <defunct>
```
````

Reglas:

- **Todo paso termina en una verificación ejecutable.** Sin excepción.
- **Toda salida esperada va comentada debajo del comando.**
- **Advertencia antes de lo destructivo**, con el comando de respaldo delante.
- Cierra con `## ✅ Resultado` (casillas + comando de `verificar-semana.sh`) y
  `## 🧯 Si algo sale mal` (tabla Síntoma | Causa | Solución).
- ❌ **No uses `# TODO:` en prácticas.** El `TODO` es formato de proyecto.

### 3-proyecto/README.md

La capa que esta semana añade a `toolkit`. Ocho secciones:

1. `## 🎯 Objetivo`
2. `## 📦 Qué añade esta capa` — cómo encaja con la semana anterior y qué
   desbloquea en la siguiente
3. `## ✅ Requisitos verificables` — **copia literal de las descripciones de
   `checks.json`**
4. `## 🎨 Criterios de calidad` — lo que el autograding no ve
5. `## 💡 Adaptación a tu dominio` — tabla con 3-4 variantes de uso personal
6. `## 🚦 Cómo entregarlo`
7. `## 🧯 Errores comunes`
8. `## 🔗 Navegación`

### 3-proyecto/starter/

El punto de partida, **nunca la solución**. Obligatorio en todos:

- `#!/usr/bin/env bash` y `set -euo pipefail`
- Bit de ejecución (`chmod +x`)
- Cabecera de comentario con el uso y los subcomandos
- **`# TODO:` en cada hueco**, numerados y con una frase de qué se espera
- `shellcheck` limpio sobre el esqueleto tal como se entrega

### 4-recursos/

Tres subcarpetas: `ebooks-free/`, `videografia/`, `webgrafia/`. Cada recurso
lleva una línea de por qué vale la pena, no solo el enlace, y la fecha de
comprobación.

### 5-glosario/

A-Z en español, con el término real en inglés entre paréntesis cuando lo haya.
Enlaza al glosario global.

### checks.json

Contrato completo en [`docs/autograding.md`](docs/autograding.md). Lo
esencial:

- Se escribe **antes** que el contenido.
- Entre 6 y 18 comprobaciones, creciendo con la complejidad de la semana.
- Cada `descripcion` se copia literal al proyecto; cada `pista` apunta a
  archivo + paso.
- Una comprobación, un hecho.
- Se ejecuta siempre contra `ubuntu-lab`. **Cero lógica bash por semana en
  `verificar-semana.sh`** — si una comprobación necesita código imperativo, el
  entregable no es verificable y va a rúbrica manual.

---

## 🎩 Sección de Trucos

**Obligatoria en el README de cada semana.** Lo que no viene en el manpage, o
viene enterrado en la línea 2.000 de `info`.

Criterio de admisión:

- ✅ Un flag poco conocido que ahorra tiempo de verdad
- ✅ Una forma de ver algo que la salida normal no enseña
- ❌ Repetir lo que ya dice la teoría de esa semana
- ❌ Trivialidades

Todo truco se replica en `docs/trucos-linux.md`, en la sección de su semana.

---

## 🔗 Navegación al pie de cada archivo

**Todo archivo de contenido de una semana termina con una línea de
navegación `← anterior` / `siguiente →`.** No solo el `README.md` de la
semana: también cada archivo de `1-teoria/`, `2-practicas/`,
`3-proyecto/README.md`, `rubrica-evaluacion.md`, cada `4-recursos/*/README.md`
y `5-glosario/README.md`.

El orden de lectura de una semana, para calcular ese `anterior`/`siguiente`,
es siempre:

```
README.md (de la semana)
  → 1-teoria/01 → 02 → ... → NN
  → 2-practicas/01 → 02 → ... → NN
  → 3-proyecto/README.md
  → rubrica-evaluacion.md
  → 4-recursos/ebooks-free/README.md
  → 4-recursos/videografia/README.md
  → 4-recursos/webgrafia/README.md
  → 5-glosario/README.md
  → README.md de la semana siguiente
```

Formato, al final del archivo, tras un separador `---`:

```markdown
---

[← Título del archivo anterior](ruta-relativa) · [Título del archivo siguiente →](ruta-relativa)
```

El primer archivo de teoría de la Semana 01 no tiene "anterior" real — enlaza
al `README.md` de su propia semana. El último archivo de la última semana no
tiene "siguiente" — enlaza al índice del bootcamp.

---

## 📝 Convenciones

### Comandos

✅ **BIEN** — el porqué, el comando, y qué esperar:

```bash
# -mtime +7: archivos modificados hace mas de 7 dias (dias completos, no horas).
# -exec ... {} + agrupa argumentos en lugar de invocar rm una vez por archivo.
find /var/log -name '*.log' -mtime +7 -exec rm {} +
```

❌ **MAL** — comando desnudo, sin motivo ni salida esperada:

```bash
find /var/log -name '*.log' -mtime +7 -exec rm {} +
```

### Scripts bash

✅ **BIEN**:

```bash
#!/usr/bin/env bash
set -euo pipefail

# trap garantiza limpieza del archivo temporal aunque el script falle a mitad.
tmpfile=$(mktemp)
trap 'rm -f "${tmpfile}"' EXIT
```

❌ **MAL** — sin `set -euo pipefail` un error a mitad de script se ignora y
sigue ejecutando con estado inconsistente; sin `trap` el temporal queda huérfano.

### Nomenclatura

| Elemento | Formato | Ejemplo |
|---|---|---|
| Carpeta de semana | `week-XX-tema_en_snake_case` | `week-13-fundamentos_de_bash_scripting` |
| Archivo de teoría | `NN-tema-en-kebab-case.md` | `03-permisos-especiales.md` |
| Archivo de práctica | `NN-titulo-en-kebab-case.md` | `02-encontrar-y-borrar-en-lote.md` |
| SVG | `NN-nombre-descriptivo.svg` | `01-anatomia-de-un-proceso.svg` |
| Script de starter | `nombre-en-kebab-case.sh` | `toolkit.sh` |
| Función bash | inglés, `snake_case` | `check_disk_usage` |
| Variable de entorno | `UPPER_SNAKE_CASE` | `TOOLKIT_HOME` |

**Inglés para código, identificadores, funciones, variables y mensajes de
commit. Español para documentación y comentarios educativos.**

Los slugs de carpeta y de archivo van **sin tildes y sin ñ**. Los títulos
dentro del markdown **sí llevan tildes**: es prosa en español.

### Placeholders

| Placeholder | Uso |
|---|---|
| `ubuntu-lab` | Contenedor canónico, graded, el único contra el que corre `verificar-semana.sh` |
| `debian-lab` / `rhel-lab` / `arch-lab` | Contenedores de exploración, no graded |
| `<tu-usuario>` | El usuario que el alumno crea en la Semana 11 |
| `~/bin` o `~/.local/bin` | Dónde vive `toolkit` |
| `<TOKEN>` / `$API_TOKEN` | Cualquier credencial en ejemplos de red/SSH |

### Placeholders prohibidos

Nunca una clave SSH, hash de contraseña o token con formato válido, ni real ni
inventado — usa `<TOKEN>` o genera uno descartable dentro del laboratorio.

---

## 🔐 Reglas de Seguridad del Contenido

Este bootcamp da acceso de `sudo` y manejo de credenciales SSH. El material
tiene que predicar con el ejemplo.

1. **Ningún comando destructivo sin aviso previo y sin el respaldo delante**:
   `rm -rf`, `dd`, `mkfs`, `> /dev/sdX`, `kill -9` sobre PID real del sistema.
2. **Ninguna clave privada ni contraseña real en el repositorio**, ni siquiera
   de ejemplo con formato plausible.
3. **`sudo` siempre con el comando mínimo necesario**, nunca `sudo su -` o
   `sudo bash` como solución por defecto — eso es antipatrón, va marcado como
   tal.
4. **SSH sin contraseña en texto plano**: todo ejemplo usa claves o explica
   por qué no.
5. **Todo ejemplo de automatización en `cron`/systemd lleva manejo de error**
   explícito — un script en cron que falla en silencio es el antipatrón que
   este bootcamp existe para evitar.
6. **Los contenedores del laboratorio nunca exponen puertos a la red pública**
   — solo `localhost`/red interna de Compose.

---

## 🎨 Recursos Visuales

- **SVG siempre. Arte ASCII prohibido.**
- Tema oscuro, sin degradados, tipografía sans-serif.
- Paleta (base GitHub dark, acento verde terminal):

  | Color | Hex | Uso |
  |---|---|---|
  | Lienzo | `#0d1117` | Fondo |
  | Superficie | `#161b22` | Cajas y paneles |
  | Borde | `#30363d` | Líneas y separadores |
  | Texto principal | `#f0f6fc` | Etiquetas |
  | Texto secundario | `#8b949e` | Anotaciones |
  | Verde terminal | `#3fb950` | Elemento principal, prompt/éxito |
  | Azul | `#58a6ff` / `#79c0ff` | Procesos, enlaces |
  | Amarillo | `#e3b341` | Aviso |
  | Rojo | `#f85149` | Error, señal destructiva |
  | Morado | `#d2a8ff` | Metadatos, variables de entorno |

- `viewBox` obligatorio, más `role="img"` y un `<title>` descriptivo.
- Nombrados en orden de lectura: `01-`, `02-`…
- **Todo SVG tiene que estar enlazado desde algún `.md`.**
  `verificar-enlaces.sh` falla si hay huérfanos.
- Se enlaza con `![Descripción](../0-assets/NN-nombre.svg)`.

---

## 📖 Documentación

### Las secciones del README de semana, en orden

1. `# Semana NN — Tema`
2. Blockquote de gancho, 2 líneas
3. `## 🎯 Objetivos de la Semana`
4. `## 📋 Prerrequisitos` — encadenados a semanas anteriores, concretos
5. `## 🗂️ Estructura de la Semana` — árbol comentado
6. `## 📝 Contenidos` — tabla de teoría y tabla de prácticas, párrafo de
   proyecto
7. `## ⏱️ Distribución del Tiempo (10 horas)` — **la tabla suma 10 h exactas**
8. `## 🎩 Trucos y atajos`
9. `## 📌 Entregables`
10. `## ✅ Verificación`
11. `## 🔗 Navegación`

Entre la 7 y la 8 cabe **una** sección temática propia de la semana si el
tema lo pide.

### Plantilla de archivo de teoría

````markdown
# Título del concepto

> Una línea que sitúa el concepto y por qué importa.

![Descripción del diagrama](../0-assets/NN-nombre.svg)

## 🎯 Objetivos

- Lo que sabrás hacer al terminar este archivo

## 1. Qué problema resuelve

## 2. Cómo funciona

### 2.1 Subtema

## 3. Cómo se usa

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|

## 5. Trucos

## 📚 Recursos Adicionales

## ✅ Checklist de Verificación

- [ ] Casillas ejecutables contra `ubuntu-lab`
````

---

## 📊 Evaluación

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Las prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Puntos verificables por autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

### Estructura de `rubrica-evaluacion.md`

1. `## 📊 Distribución de Evidencias`
2. `## 🧠 Conocimiento (30%)` — 10 preguntas conceptuales + `<details>` con
   respuestas argumentadas
3. `## 💪 Desempeño (40%)` — tabla Práctica | Criterio | Puntos
4. `## 📦 Producto (30%)` — dos tablas: autograding + calidad manual
5. `### Penalizaciones` — tabla Situación | Deducción (`sudo su -` sin
   justificar, secreto comiteado, comando destructivo sin aviso: graves)
6. Cierre con enlace de vuelta

---

## 🤖 Instrucciones para el agente

### Límites de respuesta

- **Una semana por tanda**, usando la última semana publicada como plantilla
  de calidad.
- Dentro de la semana: primero `checks.json`, luego README, luego teoría,
  luego prácticas, luego proyecto, luego rúbrica, luego recursos y glosario.
- **Commit + push al terminar cada semana** (y tras cualquier cambio de
  scaffolding raíz), con mensaje de commit en inglés.

### Reglas de generación

1. **Profundidad sobre cobertura.** Mejor explicar bien cinco flags de `find`
   que listar los cuarenta.
2. **Siempre el porqué.** Un comando sin motivo es una receta.
3. **Verificable.** Si un entregable no se puede comprobar, va a rúbrica
   manual.
4. **No inventar.** Si dudas de un flag o comportamiento, ejecútalo en
   `ubuntu-lab` o comprueba el manpage. Una opción plausible pero inexistente
   es el fallo más probable en este repositorio.
5. **Marca la divergencia de distro**, no la versión de una herramienta — el
   riesgo aquí no es una versión vieja, es un comando que no existe igual en
   `dnf`/`pacman`.
6. **Nunca ejecutar un comando destructivo real contra el host** al generar
   ejemplos — todo se valida dentro de un contenedor del laboratorio.

---

## 📚 Referencias Oficiales

- [GNU Coreutils Manual](https://www.gnu.org/software/coreutils/manual/coreutils.html)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [man7.org — Linux man-pages](https://man7.org/linux/man-pages/)
- [systemd documentation](https://www.freedesktop.org/software/systemd/man/)
- [ShellCheck](https://www.shellcheck.net/)
- [Ubuntu 24.04 LTS Release Notes](https://discourse.ubuntu.com/t/noble-numbat-release-notes/)

---

## ✅ Checklist para Nuevas Semanas

- [ ] `checks.json` escrito **primero**, 6-18 comprobaciones, contra `ubuntu-lab`
- [ ] Cada comprobación ejecutada a mano contra el laboratorio
- [ ] `README.md` con las secciones en orden
- [ ] La tabla de tiempos suma **10 h exactas**
- [ ] Archivos de teoría 200-300 líneas, un concepto por archivo
- [ ] Prácticas planas (200-380 líneas), cada paso con Por qué / Comando / Verifica
- [ ] Cada práctica cierra con `## ✅ Resultado` y `## 🧯 Si algo sale mal`
- [ ] `3-proyecto/README.md` con requisitos copiados literalmente del `checks.json`
- [ ] `starter/*.sh` con shebang, `set -euo pipefail`, bit de ejecución, `TODO`s, `shellcheck` limpio
- [ ] `rubrica-evaluacion.md` con 10 preguntas, respuestas argumentadas, penalizaciones
- [ ] Sección de trucos en el README, replicada en `docs/trucos-linux.md`
- [ ] Glosario A-Z
- [ ] Recursos con línea de justificación y fecha de comprobación
- [ ] SVG en `0-assets/`, todos enlazados, ninguno con arte ASCII
- [ ] Ningún comando destructivo sin aviso
- [ ] Ningún secreto en ningún ejemplo
- [ ] Prerrequisitos encadenados a semanas anteriores, concretos
- [ ] Navegación anterior/siguiente correcta en el `README.md` de la semana **y al pie de cada archivo de contenido**
- [ ] Las tablas maestras siguen coincidiendo (`CLAUDE.md`, `README.md`, `README_EN.md`)
- [ ] `bash scripts/verificar-enlaces.sh` en verde
- [ ] `bash scripts/verificar-semana.sh NN` en verde

---

## 💡 Notas Finales

- **Profundidad sobre cobertura.** Siempre.
- **Nunca comprimir para que quepa.** Si no cabe, se divide.
- **Lo que no se puede verificar no es obligatorio.**
- **Si dudas de un comando, ejecútalo en `ubuntu-lab`. No lo escribas "porque suena bien".**

_Última actualización: octubre de 2026 · Versión 1.0_
