# Capa 16 de `toolkit`: el subcomando `schedule`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `schedule`, con dos acciones:

- `schedule check 'M H DOM MES DOW'` **lee** una expresión de cron, la valida
  campo a campo y dice cuántas veces al día se ejecutaría.
- `schedule gen NOMBRE --cron '...' -- COMANDO` **escribe** tres archivos
  (`.cron`, `.service`, `.timer`) que programan el comando de las dos formas,
  envuelto en `guard`, con el `%` escapado y la salida siempre a un registro.

Es el primer subcomando que **genera configuración** en lugar de ejecutar un
trabajo: todo lo que entra en un archivo que otro programa leerá después se
valida antes, con lista blanca.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck`,
`netcheck`, `snapshot`, `healthcheck` y `guard` siguen intactos y **vienen
completos** en el starter. También vienen hechas `cal_field`,
`cron_dom_dow_restringidos`, `schedule_safe` y `cmd_schedule` (el despachador
de `check`/`gen`). Tu trabajo nuevo son los ocho `TODO`: `cron_expand`,
`cron_parse`, `schedule_check`, `schedule_calendar`, las validaciones de
`gen`, el archivo `.cron`, el `.service`/`.timer` y el mensaje final.

Cómo encaja: la Semana 15 te dio `guard`; esta semana lo **programas**. Lo que
desbloquea: la Semana 17 personaliza el entorno (alias, `~/.bashrc`,
autocompletado) y puede registrar `toolkit schedule` como un subcomando más
con su ayuda.

Reutiliza patrones ya vistos:

- **Validación antes de usar** (Semanas 12 y 15), ahora con una lista blanca.
- **Códigos de salida con significado**: `0`, `1` (uso) y `2` (entrada inválida).
- **Arrays asociativos** (`local -A`) de la Semana 14, para deduplicar valores.
- **`10#`** para evitar que `08` se lea como octal en la aritmética de bash.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. Los subcomandos snapshot, healthcheck y guard siguen funcionando (regresion de las Semanas 13 a 15)
7. schedule check cuenta 36 ejecuciones por dia para '*/15 9-17 * * 1-5'
8. schedule check trata 0 y 7 como el mismo domingo (0-7 son 7 dias, no 8)
9. schedule check sale con codigo 2 si un valor esta fuera de rango
10. schedule check sale con codigo 2 si la expresion no tiene 5 campos
11. schedule gen crea los archivos .cron, .service y .timer
12. La linea de cron envuelve el comando en guard con bloqueo y redirige stdout y stderr al registro
13. En el archivo de cron el % del comando se escribe \%
14. El .timer lleva OnCalendar con los dias laborables y Persistent=true
15. systemd-analyze verify acepta el .service y el .timer generados
16. schedule gen sale con codigo 1 si los archivos ya existen y no se pide --force
17. schedule gen rechaza con codigo 1 un nombre que intenta salir del directorio
18. schedule gen sale con codigo 2 si restringes dia del mes y dia de la semana a la vez

## 🎨 Criterios de calidad

- `cron_expand` devuelve **valores**, no operadores: lista ordenada y sin
  duplicados, con un `local -A` para deduplicar
- Cada número se convierte con `10#`; ninguna conversión revienta con `08` o `09`
- `0` y `7` se unifican en `0` **solo** en el día de la semana
- Los errores de uso salen por `stderr` con `1`; las expresiones inválidas, con `2`
- **Nada se escribe hasta que todo es válido**: un `gen` fallido no deja
  archivos a medias
- El nombre se valida con una regex anclada **antes** de construir ninguna ruta
- El comando se resuelve con `type -P` (ruta absoluta, sin alias ni funciones)
  y todo valor que entra en un archivo pasa por la lista blanca `schedule_safe`
- El `%` se escapa de forma distinta en cada formato (`\%` en cron, `%%` en
  systemd) y por **sustitución**, no a mano
- Ningún `eval`, ningún `bash -c "$dato"`
- No se sobrescribe sin `--force`, ni siquiera parcialmente
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir a tu propio `schedule` (no evaluado esta semana) |
|---|---|
| Quieres usar `/etc/cron.d` | Una opción `--usuario` que añada el campo de usuario que ese formato exige y que `crontab` no lleva |
| Tus tareas dependen de otra | `After=` y `Requires=` en el `.service` generado, opcionales |
| Quieres saber cuándo será la próxima ejecución | Que `check` llame a `systemd-analyze calendar` y muestre `Next elapse` |
| Programas tareas de tu propio usuario | Un `schedule install` que copie el `.service`/`.timer` a `~/.config/systemd/user/` y haga `systemctl --user enable` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-16-automatizacion_y_tareas_programadas/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de schedule en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y cron systemd shellcheck   # si aun no los instalaste
./scripts/verificar-semana.sh 16
```

Necesitas `systemd` solo por `systemd-analyze` (el contenedor no arranca con
systemd como PID 1; no hace falta). La [práctica 04](../2-practicas/04-schedule-a-mano.md)
te guía por los ocho `TODO` uno a uno, con una comprobación tras cada paso.

## 🧯 Errores comunes

- Dejar `0-7` sin unificar: el domingo cuenta dos veces y `check` da `8` días.
- Olvidar `10#`: `08` en aritmética es un octal inválido y el script aborta.
- Escapar el `%` con barra también en el `.service`: systemd no lo entiende;
  allí es `%%`.
- No escapar el `%` en el `.cron`: `date +%F` deja de funcionar **en silencio**
  y el registro nunca se crea.
- Construir la ruta con el nombre **antes** de validarlo: `../x` escribe fuera
  del directorio.
- Dejar que `gen` cree `.cron` y falle al crear `.timer`: quedan archivos a
  medias. Valida todo primero.
- Aceptar días del mes **y** de la semana a la vez sin avisar: cron los une con
  OR y systemd con AND, así que los dos mundos hacen cosas distintas.
- Usar `which` o aceptar un alias como comando: el archivo generado necesita
  una ruta absoluta (`type -P`).
- Olvidar que el `.cron` de `crontab` **no** lleva campo de usuario, pero el de
  `/etc/cron.d` sí.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-schedule-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
