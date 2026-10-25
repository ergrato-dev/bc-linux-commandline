# Semana 18 — Archivado, compresión y registros del sistema

> Una copia que no sabes restaurar y un registro que nadie rota tienen el mismo final: descubres el problema cuando ya es tarde.
> Esta semana archivas y comprimes con criterio, compruebas que la copia sirve, lees lo que el sistema cuenta de sí mismo y haces que `toolkit` te respalde.

## 🎯 Objetivos de la Semana

- Crear, listar y extraer archivos con `tar`, controlando rutas con `-C` y filtrando con `--exclude` y `-T`
- Elegir entre `gzip`, `bzip2`, `xz` y `zstd` con números de tus propios datos, y reconocer cada formato por sus bytes
- Comprobar la integridad con `sha256sum`, distinguir un archivo cambiado de uno ausente o truncado, y restaurar sin pisar nada
- Detectar un archivo con rutas `..` o absolutas antes de extraerlo
- Saber qué escribe cada archivo de `/var/log`, cuáles son binarios y quién puede leerlos
- Filtrar el diario con `journalctl` por unidad, etiqueta, prioridad, texto y tiempo
- Rotar registros con `logrotate`, probarlo sin riesgo y elegir entre `create` y `copytruncate`
- Escribir en el registro del sistema desde tus scripts con `logger` y `systemd-cat`
- Construir `backup`: crea, verifica, lista, restaura y poda copias con suma y sin escrituras a medias

## 📋 Prerrequisitos

Semana 17 completada: `toolkit.sh` con `dotfiles` funcionando y `shellcheck`
instalado en `ubuntu-lab`. Semana 17 (respaldar antes de reemplazar y `--dry-run`),
Semana 16 (`schedule` y `guard`, con los que programarás la copia), Semana 15
(`mktemp`, `trap` y los códigos de salida), Semana 14 (funciones, `case` y
`shift`), Semana 05 (redirecciones y pipes) y Semana 04 (permisos: las copias
deben ser `600`).

## 🗂️ Estructura de la Semana

```
week-18-archivado_compresion_y_registros_del_sistema/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 8 archivos: tar, compresión, integridad, /var/log, journalctl, logrotate, logger y backup
├── 2-practicas/           # 4 prácticas dentro de ubuntu-lab
├── 3-proyecto/            # Capa 18 de toolkit: subcomando backup
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, cada uno para algo que la prosa cuenta mal: **qué hay dentro de
un `.tar.gz`** (la compresión envuelve el archivado, no al revés) y **de dónde
salen los registros** (qué escribe cada demonio y por dónde llega a texto o al
diario). El resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-tar-archivar-sin-comprimir.md) | `tar`: archivar sin comprimir | 25 min |
| [02](1-teoria/02-compresion-gzip-bzip2-xz-zstd.md) | Compresión: `gzip`, `bzip2`, `xz` y `zstd` | 20 min |
| [03](1-teoria/03-integridad-y-restauracion.md) | Integridad y restauración | 25 min |
| [04](1-teoria/04-var-log-y-registros-clasicos.md) | `/var/log` y los registros clásicos | 25 min |
| [05](1-teoria/05-journalctl.md) | `journalctl`: el diario de systemd | 25 min |
| [06](1-teoria/06-logrotate.md) | `logrotate`: que los registros no llenen el disco | 25 min |
| [07](1-teoria/07-escribir-en-los-registros.md) | Escribir en los registros desde tus scripts | 20 min |
| [08](1-teoria/08-construyendo-backup.md) | Construyendo `backup` | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-tar-y-compresion.md) | Crear, listar y extraer; `-C`, `--exclude`, `-T`, `-d`, `-k`; medir los cuatro compresores y reconocerlos por sus bytes | 60 min |
| [02](2-practicas/02-integridad-y-restauracion.md) | Sumas con `sha256sum`, archivos cambiados, ausentes y truncados, `diff -r` y archivos con rutas peligrosas | 60 min |
| [03](2-practicas/03-registros-journald-y-logrotate.md) | Arrancar `rsyslogd` y `journald` a mano, `logger`, `journalctl` con filtros y `logrotate` con `create` y `copytruncate` | 90 min |
| [04](2-practicas/04-backup-a-mano.md) | Rellenar los ocho `TODO` de `backup` paso a paso, con `shellcheck` al final | 120 min |

Y la decimoctava capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `backup`: `create` hace una copia con suma y `--exclude`,
`verify` la comprueba, `list` las cuenta, `restore` extrae solo en un directorio
vacío tras revisar las rutas y `prune` conserva las K últimas de una serie; sale
con `0`, `1` (uso) o `2` (copia no fiable).

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 3 h |
| Prácticas (4 archivos) | 5 h 30 min |
| Proyecto: Capa 18 de `toolkit` | 40 min |
| Rúbrica de conocimiento (10 preguntas) | 40 min |
| Repaso, glosario y recursos | 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `tar -cf - -C origen . | tar -xf - -C destino` copia un árbol **conservando
  permisos y enlaces**, sin archivo intermedio: la tubería hace de `.tar`. Un
  `600` sigue siendo `600` al otro lado.
- `sha256sum --quiet -c archivo.sha256` no imprime nada cuando todo va bien y
  solo nombra lo que falla: ideal para un `cron`, donde el silencio significa
  «correcto». (El código de salida es `1` si algo falla.)
- `tar -xzf archivo.tgz --one-top-level=salida` mete **todo** dentro de
  `salida/`, aunque el archivo traiga los ficheros sueltos en la raíz y
  ensucie tu directorio actual (lo que se conoce como *tarbomb*).

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `backup` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck`, `netcheck`, `snapshot`, `healthcheck`, `guard`, `schedule` y
   `dotfiles` de semanas anteriores siguen funcionando sin regresiones, y
   `shellcheck ~/bin/toolkit.sh` sale limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 18
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 17](../week-17-personalizacion_del_entorno_y_productividad/README.md) | Semana 18 | [Semana 19 →](../week-19-systemd_seguridad_y_contenedores_desde_cli/README.md) |

[← Volver al índice del bootcamp](../README.md)
