# El proyecto hilo conductor: `toolkit`

Un solo proyecto crece las veinte semanas: tu propia caja de herramientas de
sysadmin personal, instalada en `~/bin` o `~/.local/bin`, que vas extendiendo
capa a capa. No hay veinte proyectos sueltos — hay uno que al final de la
Semana 20 es una herramienta real, instalable, demostrable en una entrevista.

## Por qué un proyecto y no ejercicios sueltos

Un ejercicio suelto se olvida apenas se entrega. Una herramienta que sigues
usando cada semana para resolver el ejercicio de esa semana se vuelve parte de
cómo trabajas. Cada capa nueva también obliga a no romper las anteriores —
eso es exactamente lo que un sysadmin de verdad tiene que manejar.

## Cómo crece

| Semanas | Qué añade |
|---|---|
| 02-04 | Script de exploración/organización de archivos (navegación + permisos) |
| 05-09 | `log-report.sh`: pipeline de reporte sobre logs (grep/sed/awk/find/xargs) |
| 10-12 | `sys-snapshot.sh`: reporte de procesos/usuarios/paquetes/red de la máquina |
| 13-16 | Refactor a un único entrypoint `toolkit <subcomando>`, manejo de errores, programado por cron/systemd timer |
| 17-19 | Subcomandos de dotfiles, backup/archivado, auditoría de seguridad básica, inspección de contenedores |
| 20 | Pulido, documentado, empaquetado — el entregable final |

## Reglas

- **Se extiende, no se reescribe.** Cada semana parte de lo que ya existe.
- **Vive fuera del repositorio del bootcamp**, en tu propio repositorio
  personal (o al menos en una carpeta separada) — es tuyo, no un ejercicio de
  clase.
- **Todo lo que falla, falla ruidoso.** `set -euo pipefail` desde la primera
  línea que escribes, no solo desde la Semana 15.
- Cada semana, la sección `3-proyecto/README.md` dice exactamente qué capa
  tienes que añadir y con qué `checks.json` se verifica.

## Adaptación

`toolkit` opera sobre **tu propia máquina** — no hay "elegir un dominio" como
en otros bootcamps del canal, porque el dominio acá siempre es el mismo: el
sistema que tienes al frente. Lo que sí varía persona a persona son los
subcomandos opcionales que cada quien decide priorizar en la Semana 17-19
(backup vs. auditoría de seguridad vs. monitoreo de contenedores).

---

[← Volver al índice de documentación](README.md)
