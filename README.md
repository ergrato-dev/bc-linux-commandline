<p align="center">
  <img src="assets/bootcamp-header.svg" alt="Bootcamp Linux Command Line: Zero to Advanced" width="900">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/semanas-20-yellow.svg" alt="20 Semanas">
  <img src="https://img.shields.io/badge/horas-200-orange.svg" alt="200 Horas">
  <img src="https://img.shields.io/badge/distro-Ubuntu%2024.04%20LTS-E95420.svg?logo=ubuntu&logoColor=white" alt="Ubuntu 24.04 LTS">
  <img src="https://img.shields.io/badge/laboratorio-Docker-2496ED.svg?logo=docker&logoColor=white" alt="Laboratorio Docker">
</p>

<p align="center">
  <a href="README_EN.md"><img src="https://img.shields.io/badge/lang-English-blue.svg" alt="English Version"></a>
</p>

---

## 📋 Descripción

Bootcamp intensivo de **20 semanas (200 horas)** para dominar la línea de
comandos de Linux desde cero hasta nivel avanzado. No es un tutorial de
comandos sueltos: es aprender a **operar, diagnosticar y automatizar** un
sistema Linux desde la terminal, en Ubuntu 24.04 LTS y con la divergencia de
las demás familias de distros (Debian, RHEL/Fedora, Arch) señalada donde
importa.

### 🎯 Objetivos

Al terminar serás capaz de:

- ✅ Moverte por cualquier sistema de archivos Linux sin GUI y explicar el FHS
- ✅ Leer y escribir permisos (rwx, octal, ACLs, bits especiales) sin adivinar
- ✅ Construir un pipeline de `grep`/`sed`/`awk`/`cut`/`sort`/`find`/`xargs`
  para resolver un problema real de texto o logs
- ✅ Gestionar procesos, señales, jobs, y leer el estado de un servicio con
  `systemctl`/`journalctl`
- ✅ Instalar y comparar paquetes en `apt`, `dnf` y `pacman`
- ✅ Diagnosticar red desde la terminal: `ip`, `ss`, `curl`, `dig`, SSH
- ✅ Escribir scripts bash robustos (`set -euo pipefail`, `trap`,
  `shellcheck` limpio)
- ✅ Programar tareas con `cron` y temporizadores de systemd
- ✅ Inspeccionar contenedores desde la CLI y conectarlo con procesos/namespaces
- ✅ Saber dónde termina este bootcamp y dónde empieza el siguiente

### 🚀 ¿Por qué un bootcamp entero sobre la línea de comandos?

Porque la mayoría aprende diez comandos sueltos y se detiene justo antes de lo
que importa: encadenarlos. Un `grep` sin un `awk` detrás es una búsqueda; un
`grep | awk | sort | uniq -c` es un reporte. Un script sin `set -euo pipefail`
"funciona" hasta que falla a mitad y nadie se entera. Este bootcamp existe para
cerrar esa distancia entre "conozco el comando" y "opero el sistema".

---

## 🗓️ Estructura del Bootcamp

| Fase | Semanas | Horas | Temas |
|---|:--:|:--:|---|
| **Fundamentos** | 01-04 | 40 h | Shell, navegación, sistema de archivos, permisos |
| **Manipulación de Datos** | 05-08 | 40 h | grep, sed, cut, sort, awk, pipes y redirección |
| **Sistema y Procesos** | 09-12 | 40 h | find/xargs, procesos, paquetes multi-distro, redes |
| **Automatización** | 13-16 | 40 h | Bash scripting de cero a robusto, cron, systemd timers |
| **Avanzado** | 17-19 | 30 h | Personalización, logs, systemd, seguridad, contenedores CLI |
| **Producción / Integración** | 20 | 10 h | Proyecto final, documentación, empaquetado |

---

## 📚 Contenido por Semana

Estado de publicación semana a semana en [`bootcamp/README.md`](bootcamp/README.md).

| # | Semana | Descripción |
|:--:|---|---|
| 01 | [Terminal, shell y primeros pasos](bootcamp/week-01-terminal_shell_y_primeros_pasos/) | Qué es una terminal/TTY/shell, prompt, `man`/`--help`, builtins vs externos |
| 02 | [Navegación y sistema de archivos](bootcamp/week-02-navegacion_y_sistema_de_archivos/) | `pwd/cd/ls`, rutas, FHS, tipos de archivo, globbing |
| 03 | [Manipulación de archivos y directorios](bootcamp/week-03-manipulacion_de_archivos_y_directorios/) | `cp/mv/rm/mkdir`, enlaces simbólicos/duros, `stat` |
| 04 | [Permisos y propiedad](bootcamp/week-04-permisos_y_propiedad/) | rwx, octal, `chmod/chown`, umask, SUID/SGID/sticky, ACLs, `sudo` |
| 05 | [Redirección, pipes y flujo de datos](bootcamp/week-05-redireccion_pipes_y_flujo_de_datos/) | stdin/stdout/stderr, pipes, `tee`, `$?`, `&&`/`||` |
| 06 | [Búsqueda de texto con grep y regex](bootcamp/week-06-busqueda_de_texto_con_grep_y_regex/) | `grep`, regex básica/extendida, casos reales en logs |
| 07 | [Procesamiento de texto: sed, cut, sort, uniq, tr](bootcamp/week-07-procesamiento_de_texto_sed_cut_sort_uniq/) | Edición de flujo, recorte, orden, deduplicación |
| 08 | [awk y pipelines de datos](bootcamp/week-08-awk_y_pipelines_de_datos/) | `awk` (campos/patrones/acciones), pipelines completos |
| 09 | [Búsqueda de archivos y ejecución en lote](bootcamp/week-09-busqueda_de_archivos_find_y_xargs/) | `find` predicados complejos, `xargs` |
| 10 | [Gestión de procesos y señales](bootcamp/week-10-gestion_de_procesos_y_senales/) | `ps/top`, jerarquía, señales, jobs, `nohup`/`disown` |
| 11 | [Usuarios, grupos y gestión de paquetes](bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) | Multiusuario, `apt` vs `dnf` vs `pacman` |
| 12 | [Redes desde la línea de comandos](bootcamp/week-12-redes_desde_la_linea_de_comandos/) | `ip`, `ss`, `curl`/`wget`, `dig`, SSH, `scp`/`rsync` |
| 13 | [Fundamentos de bash scripting](bootcamp/week-13-fundamentos_de_bash_scripting/) | Shebang, variables, quoting, condicionales, shellcheck |
| 14 | [Control de flujo y funciones en bash](bootcamp/week-14-control_de_flujo_y_funciones_en_bash/) | Bucles, funciones, scope, arrays básicos |
| 15 | [Scripts robustos: manejo de errores](bootcamp/week-15-scripts_robustos_manejo_de_errores/) | `set -euo pipefail`, `trap`, validación, logging |
| 16 | [Automatización y tareas programadas](bootcamp/week-16-automatizacion_y_tareas_programadas/) | `cron`, systemd timers, empaquetar herramientas |
| 17 | [Personalización del entorno y productividad](bootcamp/week-17-personalizacion_del_entorno_y_productividad/) | `.bashrc`, PATH, alias, tmux/screen |
| 18 | [Archivado, compresión y registros del sistema](bootcamp/week-18-archivado_compresion_y_registros_del_sistema/) | `tar/gzip`, respaldo, `journalctl`, `/var/log` |
| 19 | [Inspección de systemd, seguridad y contenedores CLI](bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) | `systemctl`, `ufw`/`firewalld`, hardening SSH, `docker` |
| 20 | [Proyecto final: toolkit integrado](bootcamp/week-20-proyecto_final_toolkit_integrado/) | Integración, documentación, empaquetado, demo |

### 🔑 Componentes de cada semana

```
week-XX-tema/
├── README.md                  # Objetivos, contenidos, trucos, entregables
├── rubrica-evaluacion.md      # 30% conocimiento / 40% desempeño / 30% producto
├── checks.json                # Las comprobaciones automáticas de la semana
├── 0-assets/                  # Diagramas SVG
├── 1-teoria/                  # Archivos de teoría, un concepto cada uno
├── 2-practicas/               # Prácticas sobre el laboratorio local
├── 3-proyecto/
│   ├── README.md              # La capa que esta semana añade a toolkit
│   └── starter/               # Esqueleto con TODOs. Nunca la solución
├── 4-recursos/
│   ├── ebooks-free/
│   ├── videografia/
│   └── webgrafia/
└── 5-glosario/
```

---

## 🛠️ Herramientas

| Herramienta | Versión | Uso |
|---|---|---|
| bash | 5.x | El intérprete del bootcamp |
| coreutils / findutils / grep / sed / gawk | GNU, las de Ubuntu 24.04 | El núcleo de todas las prácticas |
| shellcheck | cualquiera | Auditar los scripts del proyecto |
| Docker + Compose v2 | Compose **v2** | Levantar el laboratorio multi-distro |

### El laboratorio local

Cuatro contenedores en tu máquina, ~250 MB de RAM, el mismo ejercicio corrido
en varios para ver la divergencia real, no solo leerla:

| Servicio | Imagen | Para qué |
|---|---|---|
| `ubuntu-lab` | `ubuntu:24.04` | Entorno canónico — todas las prácticas y el autograding corren aquí |
| `debian-lab` | `debian:12` | Exploración: familia Debian sin `snap` |
| `rhel-lab` | `rockylinux:9` | Exploración: `dnf`/`rpm`, SELinux presente |
| `arch-lab` | `archlinux:latest` | Exploración: `pacman`, base mínima |

Solo `ubuntu-lab` es graded. Los otros tres son para comparar, no para
entregar.

---

## 🚀 Inicio Rápido

### Prerrequisitos

Terminal Linux, macOS o **WSL2** en Windows. No se requiere saber programar:
el bash se aprende durante el bootcamp.

### 1. Instalar las herramientas

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y shellcheck docker.io docker-compose-plugin
```

### 2. Clonar y levantar el laboratorio

```bash
git clone https://github.com/ergrato-dev/bc-linux-commandline.git
cd bc-linux-commandline
./scripts/start.sh
```

### 3. Comprobar que funciona

```bash
docker exec -it ubuntu-lab cat /etc/os-release | grep VERSION_ID
# VERSION_ID="24.04"
```

### 4. Empezar

El proyecto es uno solo y crece veinte semanas:
[`docs/proyecto-hilo-conductor.md`](docs/proyecto-hilo-conductor.md).

```bash
cd bootcamp/week-01-terminal_shell_y_primeros_pasos/
```

---

## ✅ Verificación Automática

```bash
./scripts/verificar-semana.sh --doctor   # tu entorno
./scripts/verificar-semana.sh 04         # la Semana 04
```

```
Semana 04 — Permisos y propiedad

  ✅ El directorio compartido tiene el bit SGID activo
  ✅ umask del usuario de practica es 027
  ❌ El script toolkit.sh no es ejecutable
     pista: 2-practicas/03-permisos-de-ejecucion.md, paso 2

  12/13 comprobaciones superadas.
```

Cada pista dice **en qué práctica y en qué paso** se arregla. Cómo funciona:
[`docs/autograding.md`](docs/autograding.md).

---

## 📊 Metodología

**Autoestudio asincrónico**, 10 h/semana. Cada semana: teoría (2-3 h),
prácticas sobre el laboratorio (4-5 h), y una capa nueva de `toolkit` (2-3 h).

### Evaluación

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales por semana |
| 💪 Desempeño | 40% | Las prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Puntos automáticos + rúbrica manual |

**Mínimo 70% en cada evidencia**, no en el promedio.

---

## ⚠️ Exención de Responsabilidad

Este material es educativo. Todo ejercicio destructivo se practica dentro de
los contenedores del laboratorio, nunca contra el host. Antes de ejecutar
cualquier comando de este bootcamp contra un sistema real, entiende qué hace.
Eso es precisamente lo que el bootcamp enseña.

---

## 📄 Licencia

[CC BY-NC-SA 4.0](LICENSE) — uso libre para fines educativos no comerciales.

---

## 📚 Documentación Adicional

- [Índice de la documentación](docs/README.md)
- [Preparar el entorno](docs/setup-entorno.md)
- [Divergencia entre distros](docs/divergencia-distros.md)
- [El proyecto hilo conductor](docs/proyecto-hilo-conductor.md)
- [Autograding](docs/autograding.md)
- [Trucos de Linux](docs/trucos-linux.md)
- [Glosario global](docs/glosario-global.md)
- [Índice de semanas y estado](bootcamp/README.md)
- [Guía de autoría](CLAUDE.md)

---

<p align="center">
  <strong>Tu terminal. Tu sistema. Sin GUI, sin miedo.</strong>
</p>

<p align="center">
  <a href="bootcamp/week-01-terminal_shell_y_primeros_pasos/">Empezar Semana 01</a> ·
  <a href="docs/setup-entorno.md">Preparar el entorno</a>
</p>
