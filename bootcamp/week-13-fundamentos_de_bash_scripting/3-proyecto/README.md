# Capa 13 de `toolkit`: el subcomando `snapshot`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `snapshot`, una foto de la máquina (sistema,
usuario, memoria, procesos, disco) que se puede mostrar o guardar en un
archivo, que avisa cuando el disco llega a un umbral y que sale con un código
que un script o `cron` puede usar. Es el primer subcomando que **no** reutiliza
a otro: lo escribes con las herramientas de la semana (variables, comillas,
argumentos, condicionales, sustitución de comandos, here-docs y `shellcheck`).

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck` y
`netcheck` siguen intactos y **vienen completos** en el starter de esta
semana: `netcheck` lo terminaste en la Semana 12. Esta capa abre la Fase 4
(automatización): hasta aquí `toolkit` miraba el sistema; desde aquí empieza a
**escribir** informes con fecha (`--salida`) y a decidir con códigos de salida
que alguien más pueda leer.

Qué desbloquea: la Semana 14 partirá `cmd_snapshot` en funciones pequeñas con
`local`; la Semana 15 le añadirá `trap` y registro de errores, y la 16 lo
programará con `cron` y con un temporizador de systemd (`--salida` con la fecha
en el nombre es justo lo que ese informe diario necesita).

Reutiliza, de forma explícita, patrones ya vistos:

- **Tres códigos de salida con significado** (`0` bien, `1` uso inválido, `2`
  hallazgo): el contrato de toda la Fase 3.
- **Validación con regex antes de comparar** (`[[ "$umbral" =~ ^[0-9]+$ &&
  "$umbral" -le 100 ]]`): la lección de la Semana 12 sobre `-le` y la
  aritmética.
- **`while` + `case` + `shift`** para las opciones: el mismo procesador de la
  [teoría 04](../1-teoria/04-argumentos-y-codigos-de-salida.md).
- **Leer del kernel en vez de depender de un paquete** (`/proc`,
  `/etc/os-release`), como `procwatch` y `netcheck`.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. snapshot sale con codigo 0 e imprime su cabecera cuando el disco esta bajo el umbral
7. snapshot imprime el nombre de la maquina que da uname -n
8. snapshot imprime el usuario aunque la variable USER no exista
9. snapshot lee el nombre del sistema de /etc/os-release
10. snapshot imprime la fecha en formato AAAA-MM-DD
11. snapshot convierte la memoria total de kB a MiB con aritmetica de bash
12. snapshot cuenta al menos un proceso en /proc
13. snapshot imprime el porcentaje de uso del disco raiz
14. snapshot sale con codigo 1 si el umbral no es un entero de 0 a 100
15. snapshot sale con codigo 1 ante una opcion que no conoce
16. snapshot sale con codigo 2 cuando el disco llega al umbral
17. snapshot explica la alerta con el porcentaje y el umbral
18. snapshot guarda el informe en una ruta con espacios (comillas bien puestas)

## 🎨 Criterios de calidad

- El shebang es `#!/usr/bin/env bash` y el script empieza con `set -euo pipefail`
- Toda expansión de variable y de `$( )` va **entre comillas dobles**; la única
  excepción deliberada es el cuerpo del here-doc
- `local` y la asignación van **separados** cuando el valor viene de `$( )` (SC2155)
- El umbral se valida con regex **antes** de compararlo con `-le`/`-ge`
- La comparación del disco con el umbral es **numérica** (`-ge`), no de texto (`>`)
- `usuario` usa un valor por defecto (`${USER:-$(id -un)}`), porque `$USER` no
  existe bajo `docker exec`
- La lectura de `/etc/os-release` ocurre en un **subshell**, y la directiva
  de `shellcheck` que la justifica lleva su porqué
- El informe se construye con un **here-doc**, no con once `echo`
- Los errores van a `stderr` y los resultados a `stdout`
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `snapshot` (no evaluado esta semana) |
|---|---|
| Administras un servidor con varios discos | Aceptar `--ruta /var` y mostrar el uso de ese sistema de archivos, no solo el de `/` |
| Quieres comparar días | Imprimir la carga media (`/proc/loadavg`) y guardar un informe por día con la fecha en el nombre |
| Lo vas a lanzar desde `cron` (Semana 16) | Una opción `--silencioso` que solo imprima algo cuando hay alerta |
| Trabajas con contenedores | Añadir la línea `contenedor: sí/no` mirando si existe `/.dockerenv` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-13-fundamentos_de_bash_scripting/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO de cmd_snapshot en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 13
```

## 🧯 Errores comunes

- Comparar el disco con el umbral usando `>` en lugar de `-ge`: `9 > 80` es
  **verdadero** como texto y la alerta salta sin motivo.
- Olvidar las comillas en `"$salida"`: una ruta con espacios se parte en dos
  argumentos y `mkdir` o la redirección fallan.
- Escribir `local sistema=$( . /etc/os-release && echo "$PRETTY_NAME" )` en una
  sola línea: el código de salida del subshell se pierde (SC2155).
- Cargar `os-release` sin subshell: `NAME`, `ID` y `VERSION` quedan
  definidas y pisan las del script.
- Usar `hostname` en lugar de `uname -n`: no está en la imagen mínima de Arch.
- Poner el salto de línea **fuera** de `${alerta:+...}`: aparece una línea en
  blanco cuando no hay alerta.
- Olvidar `exit 2`: el script acaba con el código del último comando y la
  alerta nunca llega a quien lo lanzó.
- Silenciar `shellcheck` con `# shellcheck disable=...` sin leer el aviso.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-snapshot-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
