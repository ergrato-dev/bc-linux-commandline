# Capa 15 de `toolkit`: el subcomando `guard`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `guard`: una envoltura que ejecuta
**cualquier comando** con las defensas de la semana. No se solapa consigo
mismo (`flock`), no se cuelga (`timeout`), reintenta con tope, deja un
registro de lo que pasó, **limpia su archivo temporal aunque algo falle o lo
maten** (`trap`) y sale con un código que dice qué ocurrió. Es el primer
subcomando que no hace un trabajo propio: protege el de otros.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck`,
`netcheck`, `snapshot` y `healthcheck` siguen intactos y **vienen completos**
en el starter. El esqueleto de `guard` trae ya hechas `guard_log` (el
registro) y `guard_interrupt` (el manejador de `INT`/`TERM`): léelas, porque
son el modelo de lo que escribes tú. Tu trabajo nuevo son los ocho `TODO`:
`guard_cleanup`, `guard_run`, `getopts`, la validación, el temporal con sus
traps, el bloqueo, el bucle de intentos y el cierre.

Qué desbloquea: la Semana 16 programará `healthcheck` y `snapshot` con `cron`
y con un temporizador de systemd, y `guard` será la envoltura de esas tareas:
`toolkit.sh guard -k ... -t ... -l ... -- toolkit.sh healthcheck`.

Reutiliza, de forma explícita, patrones ya vistos:

- **Códigos de salida con significado**: `0`, `1` (uso), `2` (fallo), ahora con
  `3` (bloqueado) y `4` (timeout) y `128 + N` para las señales.
- **Validación antes de usar** (`is_uint`): la lección de la Semana 12, ahora
  aplicada a un bucle sobre los **nombres** de las variables.
- **`local` y funciones pequeñas** de la Semana 14, más variables globales solo
  donde un `trap` las necesita.
- **`|| rc=$?`** para quedarse con el código sin que `set -e` aborte.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. Los subcomandos snapshot y healthcheck siguen funcionando (regresion de las Semanas 13 y 14)
7. guard ejecuta el comando y muestra su salida
8. guard sale con codigo 2 cuando el comando falla
9. guard sale con codigo 1 si no se le da ningun comando
10. guard sale con codigo 1 ante una opcion que no conoce
11. guard sale con codigo 1 si el limite de tiempo no es un entero
12. guard sale con codigo 4 cuando el comando agota el limite de tiempo
13. guard sale con codigo 3 si otra ejecucion tiene el bloqueo
14. guard registra cada intento en el archivo de registro
15. guard registra el codigo de salida final aunque el comando falle
16. guard reintenta el comando las veces pedidas
17. guard no deja su archivo temporal aunque el comando falle
18. guard sale con codigo 143 al recibir TERM mientras el comando corre

## 🎨 Criterios de calidad

- Los manejadores de `trap` leen **variables globales** (`GUARD_TMP`,
  `GUARD_PID`, `GUARD_LOG`); el resto de variables de las funciones lleva
  `local`, separado de la asignación cuando el valor viene de `$( )`
- `guard_cleanup` guarda `$?` en `rc` en su **primera línea**
- El temporal se crea con `mktemp` y los traps se instalan **después** de
  validar: un error de uso no deja temporal ni línea de `fin` en el registro
- El comando corre en **segundo plano** con `wait`, para que `TERM` actúe al
  instante, y el manejador de señal mata **y recoge** al hijo
- `guard_run ... || rc=$?`: el fallo del comando no aborta el script ni se pierde
- Cada opción y cada número se validan **antes** de actuar; los errores de uso
  van a `stderr` y salen con `1`
- La espera va **entre** intentos, nunca tras el último
- Ningún `eval`, ningún `bash -c "$dato"`; el comando se ejecuta como `"$@"`
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas `snapshot`, `healthcheck` ni los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir a tu propio `guard` (no evaluado esta semana) |
|---|---|
| Lo lanzas desde `cron` (Semana 16) | Una opción `-q` que silencie `stdout` y deje solo el registro |
| Tus tareas fallan a veces por la red | Espera creciente entre intentos (`espera=$(( espera * 2 ))`) en lugar de fija |
| Quieres enterarte de los fallos | Un `-n COMANDO` que se ejecute solo si el código final no es `0` (aviso por correo, `curl` a un webhook con `$API_TOKEN`) |
| Varios scripts comparten un recurso | Un `-W SEG` que use `flock -w` para **esperar** el bloqueo en lugar de salir con `3` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-15-scripts_robustos_manejo_de_errores/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de guard en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 15
```

La [práctica 04](../2-practicas/04-guard-a-mano.md) te guía por los ocho
`TODO` uno a uno, con una comprobación tras cada paso.

## 🧯 Errores comunes

- Instalar los traps **antes** de validar: un `guard` mal invocado deja un
  temporal y una línea `fin: codigo de salida 1` en el registro.
- Leer `$?` en `guard_cleanup` después de otro comando: ya no es el código de
  salida. `local rc=$?` va primero.
- Declarar `GUARD_TMP` como `local` en `cmd_guard`: el trap, que corre fuera de
  la función, no lo ve y el temporal queda sin borrar.
- Ejecutar el comando en primer plano: un `TERM` espera a que termine y el
  `143` llega tarde, o nunca si el comando es largo.
- Llamar a `guard_run` sin `|| rc=$?`: `set -e` aborta con el primer fallo y no
  hay reintentos ni código `2`.
- Matar al hijo en `guard_interrupt` sin `wait`: queda un proceso zombi.
- Dormir también tras el último intento: el fallo se retrasa sin motivo.
- Olvidar `local OPTIND=1`: la segunda llamada a `cmd_guard` no procesa
  ninguna opción.
- Pasar `${!nombre}` sin inicializar `local nombre=""`: con `set -u`, aborta.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-guard-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
