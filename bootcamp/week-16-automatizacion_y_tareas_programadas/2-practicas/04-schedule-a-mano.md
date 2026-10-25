# Práctica 04 — `schedule` a mano

> Duración estimada: 90 min · Teoría de apoyo: archivos [02](../1-teoria/02-expresiones-de-cron-y-sus-trampas.md), [06](../1-teoria/06-temporizadores-de-systemd.md), [07](../1-teoria/07-unidades-service-para-tareas.md) y [08](../1-teoria/08-construyendo-schedule.md)

Aquí rellenas, **un `TODO` cada vez**, el `schedule` del
[`starter/toolkit.sh`](../3-proyecto/starter/toolkit.sh), y tras cada paso
compruebas lo añadido. Los `TODO` traen en su comentario **todos** los
mensajes y reglas; aquí van las piezas difíciles. Edita el `starter/` en tu
**host** y llévalo al laboratorio con esta función (desde la raíz del repo):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-16-automatizacion_y_tareas_programadas/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
docker exec ubuntu-lab apt-get install -y -qq systemd shellcheck >/dev/null
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh schedule check '30 2 * * 1-5'; echo "codigo: $?"
# TODO:  1
# codigo: 0
```

Es el punto de partida: ejecuta, pero `check` y `gen` son marcadores. (Desde
el host usa `/root/bin`, **no** `~/bin`: se expandiría en tu máquina.) Los
pasos 2, 3 y 5 se prueban con `source`, sin ejecutar `main`.

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae `cal_field`, `cron_dom_dow_restringidos`,
`schedule_safe`, las opciones de `gen` y `cmd_schedule`: no las reescribas.

**Comando**: abre `starter/toolkit.sh` en el bloque `# --- schedule (Semana 16)`
(hacia la línea 1050) y lee, sin tocar, `cal_field`, `schedule_safe` y `cmd_schedule`.

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-16-automatizacion_y_tareas_programadas/3-proyecto/starter/toolkit.sh
# 8
```

## Paso 2: TODO 1 — `cron_expand`

**Por qué**: es el corazón. Convierte **un campo** (`*/15`, `9-17`, `1,15`) en
la lista de números que cubre. Con listas, contar y traducir después es
trivial; con operadores, no.

**Comando**: sustituye el cuerpo de `cron_expand` (desde `CRON_VALUES=()` hasta
`: "${campo}" ...`) por las tres piezas, en este orden:

```bash
  local item rango paso inicio fin n
  local -a items
  local -A visto=()
  CRON_VALUES=()
  if [[ ! "$campo" =~ ^[^,]+(,[^,]+)*$ ]]; then
    CRON_ERROR="campo vacio o con coma sobrante: '${campo}'"; return 1
  fi
  IFS=, read -ra items <<< "$campo"
  for item in "${items[@]}"; do
    rango=$item; paso=1
    if [[ "$item" == */* ]]; then
      rango=${item%%/*}; paso=${item#*/}
      # 10# fuerza base 10: sin el, "08" es un octal invalido.
      if [[ ! "$paso" =~ ^[0-9]{1,4}$ ]] || (( 10#$paso < 1 )); then
        CRON_ERROR="paso invalido en '${item}'"; return 1
      fi
      paso=$(( 10#$paso ))
    fi
    # ... rango ('*', A-B o un numero) -> inicio y fin; errores de rango ...
    for (( n = inicio; n <= fin; n += paso )); do visto[$n]=1; done
  done
  for (( n = min; n <= max; n++ )); do
    if [[ -n "${visto[$n]:-}" ]]; then CRON_VALUES+=("$n"); fi
  done
```

El `...` lo escribes tú (comentario del `TODO 1`): `'*'` da `min` a `max`;
`A-B` se captura con `=~ ^([0-9]{1,4})-([0-9]{1,4})$` y `BASH_REMATCH`; un número
solo **sin** paso (`5/2` no existe); y los dos errores de rango.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
cron_expand "1,15,30-32/2" 0 59; echo "${CRON_VALUES[*]}"
cron_expand "*/15" 0 59; echo "${CRON_VALUES[*]}"
for e in 60 5-3 5/2; do cron_expand "$e" 0 59 || echo "$e -> error: $CRON_ERROR"; done
cron_expand 08 0 59; echo "${CRON_VALUES[*]}"'
# 1 15 30 32
# 0 15 30 45
# 60 -> error: fuera del rango 0-59: '60'
# 5-3 -> error: rango invertido: '5-3'
# 5/2 -> error: elemento no reconocido: '5/2'
# 8
```

## Paso 3: TODO 2 — `cron_parse`

**Por qué**: valida los **cinco** campos, unifica el domingo (`0` y `7`) y
deja los resultados en las globales.

**Comando**: tras vaciar los arrays y trocear con `read -ra campos <<< "$expr"`,
exige cinco campos y recorre `for i in 0 1 2 3 4`. La pieza clave es el día
de la semana:

```bash
    if [[ "$i" -eq 4 ]]; then
      # En el dia de la semana 0 y 7 son el mismo domingo: se unifican en 0.
      for v in "${CRON_VALUES[@]}"; do
        dias[$(( v % 7 ))]=1
      done
      CRON_VALUES=()
      for d in 0 1 2 3 4 5 6; do
        if [[ -n "${dias[$d]:-}" ]]; then
          CRON_VALUES+=("$d")
        fi
      done
    fi
    CRON_RAW[i]=${campos[$i]}
    CRON_COUNT[i]=${#CRON_VALUES[@]}
    CRON_LIST[i]=$(IFS=,; echo "${CRON_VALUES[*]}")
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
cron_parse "* * * *" || echo "error: $CRON_ERROR"
cron_parse "30 2 * * 1-5"; echo "count=${CRON_COUNT[*]}"; echo "dow=${CRON_LIST[4]}"
cron_parse "0 0 * * 0-7"; echo "count=${CRON_COUNT[*]}"; echo "dow=${CRON_LIST[4]}"'
# error: se esperaban 5 campos y hay 4
# count=1 1 31 12 5
# dow=1,2,3,4,5
# count=1 1 31 12 7
# dow=0,1,2,3,4,5,6
```

## Paso 4: TODO 3 — `schedule_check`

**Por qué**: con las listas, el informe es imprimir. El código separa «lo
llamaste mal» (`1`) de «la expresión es inválida» (`2`).

**Comando**: con `$# -ne 1` a `stderr` y `exit 1`; si `cron_parse` falla,
`toolkit schedule check: expresion invalida: ${CRON_ERROR}` y `exit 2`; si no,
las siete líneas del comentario (la última, `ejecuciones por dia`, es
`$(( CRON_COUNT[0] * CRON_COUNT[1] ))`) y el aviso si
`cron_dom_dow_restringidos`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c "/root/bin/toolkit.sh schedule check '*/15 9-17 * * 1-5'; echo rc=\$?"
# expresion: */15 9-17 * * 1-5
# minutos: 4
# horas: 9
# dias del mes: 31
# meses: 12
# dias de la semana: 5
# ejecuciones por dia: 36
# rc=0
docker exec ubuntu-lab /root/bin/toolkit.sh schedule check '60 * * * *'; echo "codigo: $?"
# toolkit schedule check: expresion invalida: fuera del rango 0-59: '60'
# codigo: 2
docker exec ubuntu-lab /root/bin/toolkit.sh schedule check '0 0 13 * 5' | tail -1
# aviso: dia del mes y dia de la semana restringidos: cron los une con OR, systemd con AND
```

## Paso 5: TODO 4 — `schedule_calendar`

**Por qué**: de las listas a `OnCalendar`: **unes valores con comas**; solo
los días de la semana pasan de número a nombre.

**Comando**:

```bash
  local dow="" v
  local -a ds
  local -a nombres=(Sun Mon Tue Wed Thu Fri Sat)
  if [[ "${CRON_COUNT[4]}" -ne 7 ]]; then
    IFS=, read -ra ds <<< "${CRON_LIST[4]}"
    for v in "${ds[@]}"; do
      dow+="${nombres[$v]},"
    done
    dow="${dow%,} "
  fi
  echo "${dow}*-$(cal_field 3 12)-$(cal_field 2 31) $(cal_field 1 24):$(cal_field 0 60):00"
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
for e in "30 2 * * 1-5" "0 3 * * 0,6" "* * * * *"; do cron_parse "$e"; printf "%s  ->  " "$e"; schedule_calendar; done
cron_parse "30 2 * * 1-5"; systemd-analyze calendar "$(schedule_calendar)" | sed -n "s/^Normalized form: //p"'
# 30 2 * * 1-5  ->  Mon,Tue,Wed,Thu,Fri *-*-* 2:30:00
# 0 3 * * 0,6  ->  Sun,Sat *-*-* 3:0:00
# * * * * *  ->  *-*-* *:*:00
# Mon..Fri *-*-* 02:30:00
```

La última línea es **systemd** confirmando tu traducción.

## Paso 6: TODO 5 — validar antes de escribir

**Por qué**: nada se escribe hasta que **todo** es válido (tabla de la teoría 08).

**Comando**: sustituye el `TODO 5` y la línea `local lock=...` + `: "${cron}"...`
por las comprobaciones (a)-(h) del comentario. Las dos de seguridad:

```bash
  # (a) el nombre forma la ruta de salida: sin "/" ni "..".
  if [[ ! "$nombre" =~ ^[a-z][a-z0-9-]{0,39}$ ]]; then ... exit 1; fi
  # (e) type -P: la ruta ABSOLUTA del ejecutable, sin alias ni funciones.
  if ! cmd0=$(type -P -- "$1"); then ... exit 1; fi
  shift
  # (f) lista blanca: sin comillas, ";", "$" ni espacios no hace falta entrecomillar.
  for arg in "$self" "$log" "$cmd0" "$@"; do
    if ! schedule_safe "$arg"; then ... exit 1; fi
  done
```

(Declara `local lock=... self cmd0 arg base ext`; `self=$(readlink -f "${BASH_SOURCE[0]}")`;
y el bucle de (h) sobre `cron service timer`, solo si `force` vale `0`.)

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c "cd /tmp && mkdir -p p16d && cd p16d
T=/root/bin/toolkit.sh
\$T schedule gen ../x --cron '0 3 * * *' -- /usr/bin/true; echo rc=\$?
\$T schedule gen tarea --cron '0 3 * * *' --timeout abc -- /usr/bin/true; echo rc=\$?
\$T schedule gen tarea --cron '0 3 * * *' -- /usr/bin/echo 'a b'; echo rc=\$?
\$T schedule gen tarea --cron '0 3 13 * 5' -- /usr/bin/true; echo rc=\$?"
# toolkit schedule gen: nombre invalido: '../x' (minusculas, digitos y guiones; empieza por letra)
# rc=1
# toolkit schedule gen: --timeout debe ser un entero: 'abc'
# rc=1
# toolkit schedule gen: valor no soportado (solo A-Za-z0-9_@%+=:,./-): 'a b'
# rc=1
# toolkit schedule gen: dia del mes y dia de la semana a la vez: cron usa OR, systemd AND; usa uno solo
# rc=2
```

## Paso 7: TODO 6 — el archivo `.cron`

**Por qué**: es el archivo que `cron` leerá, con las tres defensas de la
teoría 03: variables fijadas, `%` escapado y salida **siempre** a un registro.

**Comando**: calcula `guardia="${self} guard -k ${lock} -t ${segundos} -- ${cmd0}"`
(más `" $*"` si hay argumentos) y escribe `${base}.cron` con un *here-document*
sin comillas (`<< UNIDAD`, para que se expandan las variables). El contenido
exacto está en la [teoría 08, apartado 2.6](../1-teoria/08-construyendo-schedule.md);
la línea que importa es la última:

```bash
${cron} ${guardia//\%/\\%} >> ${log} 2>&1
```

Sin esa barra, `date +%F` dejaría de funcionar en silencio (práctica 01, paso 5).

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c "cd /tmp/p16d && rm -f * && /root/bin/toolkit.sh schedule gen tarea --cron '*/15 9-17 * * 1-5' -- /usr/bin/date +%F; tail -1 tarea.cron"
# TODO: schedule gen
# */15 9-17 * * 1-5 /root/bin/toolkit.sh guard -k /var/tmp/toolkit-tarea.lock -t 300 -- /usr/bin/date +\%F >> /var/tmp/toolkit-tarea.log 2>&1
docker exec ubuntu-lab /root/bin/toolkit.sh schedule gen tarea --cron '0 3 * * *' --salida /tmp/p16d -- /usr/bin/true; echo "codigo: $?"
# toolkit schedule gen: ya existe /tmp/p16d/tarea.cron (usa --force para reemplazarlo)
# codigo: 1
```

## Paso 8: TODO 7 — `.service` y `.timer`

**Por qué**: la otra mitad. Aquí el `%` se duplica (`%%`) en lugar de
escaparse con barra, y la fecha del `OnCalendar` sale de `schedule_calendar`.

**Comando**: calcula `calendario=$(schedule_calendar)` y escribe `${base}.service`
y `${base}.timer` con dos *here-documents* más, copiando de la teoría 08 (2.6).
Las dos líneas que cambian respecto al `.cron`:

```bash
ExecStart=${guardia//\%/%%}        # en el .service
OnCalendar=${calendario}            # en el .timer
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c "cd /tmp/p16d && rm -f * && /root/bin/toolkit.sh schedule gen tarea --cron '*/15 9-17 * * 1-5' -- /usr/bin/date +%F; ls | tr '\n' ' '; echo; grep ExecStart tarea.service; systemd-analyze verify ./tarea.service ./tarea.timer; echo verify=\$?"
# TODO: schedule gen
# tarea.cron tarea.service tarea.timer
# ExecStart=/root/bin/toolkit.sh guard -k /var/tmp/toolkit-tarea.lock -t 300 -- /usr/bin/date +%%F
# verify=0
./scripts/verificar-semana.sh 16 | tail -1
#   18/18 comprobaciones superadas.
```

Con siete `TODO` ya pasan **las 18 comprobaciones**; el último pule la salida.

## Paso 9: TODO 8, `shellcheck` y una prueba con `cron` de verdad

**Por qué**: `gen` debe **decir** qué hizo, y la única prueba definitiva de un
`.cron` es dejar que `cron` lo ejecute.

**Comando**: sustituye el marcador final por los tres mensajes:

```bash
  for ext in cron service timer; do
    echo "generado: ${base}.${ext}"
  done
  echo "calendario: ${calendario}"
  echo "archivos creados: 3"
```

Luego la prueba con una expresión de **cada minuto** (hazle antes
`crontab -l > respaldo`):

```bash
entregar
docker exec ubuntu-lab bash -c 'crontab -l > /tmp/p16d/crontab.orig 2>/dev/null || true
pgrep -x cron >/dev/null || cron
cd /tmp/p16d && /root/bin/toolkit.sh schedule gen minuto --cron "* * * * *" --salida /tmp/p16d -- /usr/bin/date +%T
crontab /tmp/p16d/minuto.cron; crontab -l | tail -1'
# generado: /tmp/p16d/minuto.cron   (y .service, .timer, calendario: *-*-* *:*:00, archivos creados: 3)
# * * * * * /root/bin/toolkit.sh guard -k /var/tmp/toolkit-minuto.lock -t 300 -- /usr/bin/date +\%T >> /var/tmp/toolkit-minuto.log 2>&1
docker exec ubuntu-lab timeout 130 bash -c 'until [ -s /var/tmp/toolkit-minuto.log ]; do sleep 2; done'
docker exec ubuntu-lab cat /var/tmp/toolkit-minuto.log
# 2026-10-25T05:05:07 INFO intento 1/1: /usr/bin/date +%T
# 05:05:07
# 2026-10-25T05:05:07 INFO ok
# 2026-10-25T05:05:07 INFO fin: codigo de salida 0
```

Se ejecutó `date +%T` (con el `%` intacto), bajo `guard`. **Quita la tarea**:

```bash
docker exec ubuntu-lab bash -c 'crontab -r; if [ -s /tmp/p16d/crontab.orig ]; then crontab /tmp/p16d/crontab.orig; fi; rm -rf /tmp/p16d /var/tmp/toolkit-minuto.*'
```

**Verifica**:

```bash
docker exec ubuntu-lab shellcheck /root/bin/toolkit.sh; echo "shellcheck: $?"
# shellcheck: 0
./scripts/verificar-semana.sh 16 | tail -1
#   18/18 comprobaciones superadas.
```

## ✅ Resultado

- [ ] `cron_expand` y `cron_parse` expanden listas, rangos y pasos, y rechazan lo inválido
- [ ] `schedule check` informa de las ejecuciones por día y sale con `2` (inválida) o `1` (mal usado)
- [ ] `schedule gen` genera `.cron`, `.service` y `.timer` y rechaza nombre, comando, valor o expresión peligrosos
- [ ] El `%` sale como `\%` en el `.cron` y `%%` en el `.service`
- [ ] `systemd-analyze verify` acepta la pareja y `cron` ejecutó de verdad el `.cron` generado
- [ ] `shellcheck` limpio y `verificar-semana.sh 16` en `18/18`

```bash
./scripts/verificar-semana.sh 16
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `shellcheck` avisa `CRON_ERROR appears unused` a mitad de camino | Aún falta la función que lo lee | Normal hasta el paso 4 |
| `value too great for base` | Falta el `10#` en una conversión | `$(( 10#$paso ))` y `$(( 10#${BASH_REMATCH[1]} ))` |
| El `.cron` lleva `+%F` sin barra | Olvidaste `${guardia//\%/\\%}` | Paso 7 |

---

[← Práctica 03: temporizadores de systemd sin systemd](03-temporizadores-de-systemd-sin-systemd.md) · [Proyecto: capa 16 de `toolkit` →](../3-proyecto/README.md)
