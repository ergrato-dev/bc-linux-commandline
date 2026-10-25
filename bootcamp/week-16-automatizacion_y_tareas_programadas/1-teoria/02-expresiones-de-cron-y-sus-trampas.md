# Expresiones de `cron` y sus trampas

> Los cinco campos se aprenden en diez minutos. Lo que cuesta años es saber
> que `*/7` no es «cada 7 minutos», que `%` rompe tu comando y que dos
> campos se unen con **O** en lugar de **Y**.

## 🎯 Objetivos

- Escribir listas (`,`), rangos (`-`) y pasos (`/`) en cualquiera de los cinco campos
- Contar a mano, o con `toolkit.sh schedule check`, cuántas veces al día corre una expresión
- Explicar por qué `*/7` en los minutos no reparte las ejecuciones por igual
- Reconocer la regla del **O** entre día del mes y día de la semana
- Escapar `%` en una línea de `crontab`
- Usar los atajos `@daily`, `@hourly`, etc., y saber qué no se puede comprobar con ellos

## 1. Qué problema resuelve

«Cada quince minutos, de nueve a cinco, de lunes a viernes» es una frase
que todo el mundo entiende y que `cron` solo entiende como
`*/15 9-17 * * 1-5`. Esa traducción es donde se cometen casi todos los
errores de programación de tareas: la expresión es **válida**, `crontab` la
acepta y no hace lo que querías.

## 2. Cómo funciona

### 2.1 Cuatro formas de decir qué valores

Cada campo admite estas formas, y se pueden **separar con comas**:

| Forma | Ejemplo | Valores en los minutos |
|---|---|---|
| Un valor | `30` | 30 |
| Lista | `0,15,45` | 0, 15, 45 |
| Rango | `10-14` | 10, 11, 12, 13, 14 |
| Paso | `*/15` | 0, 15, 30, 45 |
| Rango con paso | `10-40/10` | 10, 20, 30, 40 |
| Combinadas | `0-10/5,30` | 0, 5, 10, 30 |

Cuenta tú mismo las ejecuciones por día. `'*/15 9-17 * * 1-5'` son 4 minutos
(`0, 15, 30, 45`) por 9 horas (`9` a `17`, **ambas incluidas**) = **36 al día**,
y solo de lunes a viernes. Compruébalo:

```bash
# schedule check lo escribes tu esta semana. Con la solucion terminada:
~/bin/toolkit.sh schedule check '*/15 9-17 * * 1-5'
# expresion: */15 9-17 * * 1-5
# minutos: 4
# horas: 9
# dias del mes: 31
# meses: 12
# dias de la semana: 5
# ejecuciones por dia: 36
```

El rango incluye los dos extremos: `9-17` incluye las 17:00, y la última
ejecución es a las **17:45**, no a las 17:00.

### 2.2 El paso parte del principio del rango, no del anterior

`*/7` en los minutos no significa «cada 7 minutos»: significa «los minutos
0, 7, 14, 21, 28, 35, 42, 49 y 56, contados desde el 0 de cada hora». Y al
llegar la hora siguiente **vuelve a empezar en 0**:

```bash
# Los minutos que cubre */7:
for m in $(seq 0 7 59); do printf '%s ' "$m"; done; echo
# 0 7 14 21 28 35 42 49 56
~/bin/toolkit.sh schedule check '*/7 * * * *' | tail -2
# dias de la semana: 7
# ejecuciones por dia: 216
```

De las 12:56 a las 13:00 pasan **4** minutos, no 7. Si necesitas intervalos
exactos que no dividen a 60 (cada 7 minutos, cada 90 minutos, cada 5 horas),
`cron` no puede: es el trabajo de los temporizadores **monotónicos** de
systemd (`OnUnitActiveSec=`, [archivo 06](06-temporizadores-de-systemd.md)).
Para los pasos que sí dividen a 60 (`*/5`, `*/10`, `*/15`, `*/30`) no hay
sorpresa.

### 2.3 Domingo es 0 **y** 7

```bash
~/bin/toolkit.sh schedule check '0 0 * * 0-7' | grep semana
# dias de la semana: 7
```

El día de la semana va de 0 a 7 porque el domingo se admite con los dos
números. Por eso `0-7` son **siete** días y no ocho. `cron`
también acepta nombres (`jan`, `mon`), y Ubuntu aceptó incluso `mon-fri`:

```bash
printf '0 3 * * mon-fri /usr/bin/true\n' | crontab - && echo "aceptado"
# aceptado
```

Aun así, usa **números**: funcionan en todas las implementaciones y son lo
único que entiende `toolkit.sh schedule`.

### 2.4 La trampa del O: día del mes **o** día de la semana

Los cinco campos se combinan con **Y**… salvo dos. Si el día del mes **y** el
día de la semana están restringidos (ninguno empieza por `*`), `cron` ejecuta
cuando **cualquiera** de los dos coincide.

```bash
# "Los viernes 13" ... ¿eso quisiste decir?
~/bin/toolkit.sh schedule check '0 0 13 * 5' | tail -1
# aviso: dia del mes y dia de la semana restringidos: cron los une con OR, systemd con AND
```

`0 0 13 * 5` corre **todos los días 13 y también todos los viernes**: unas
sesenta veces al año, no una o dos. Lo comprobé en `ubuntu-lab` el
domingo 25 de octubre con tres tareas, cada una escribía una letra a un
archivo:

| Línea | Día del mes | Día de la semana | Disparó |
|---|---|---|:--:|
| `* * 13 * 0` | 13 (no) | domingo (sí, era domingo) | **sí** |
| `* * 13 * 1` | 13 (no) | lunes (no) | no |
| `* * 25 * 1` | 25 (sí) | lunes (no) | **sí** |

Para repetirlo hoy, sea el día que sea:

```bash
# dom = un dia del mes que NO es hoy; dow = el dia de la semana de hoy.
dom=$(( 10#$(date +%d) % 28 + 1 ))
dow=$(date +%w)
echo "* * ${dom} * ${dow} date +\%T >> /tmp/or.log" | crontab -
# Espera un minuto:
cat /tmp/or.log
# 04:30:01     <- se ejecuto aunque hoy no es el dia $dom
crontab -r
```

Si de verdad quieres «el viernes 13», `cron` no sabe: o programas **todos
los viernes** y el propio script comprueba la fecha (`[[ $(date +%d) == 13 ]]
|| exit 0`), o usas un temporizador de systemd, que sí une las dos con **Y**
(`OnCalendar=Fri *-*-13`). Esa diferencia es una de las razones por las que
`toolkit.sh schedule gen` se niega a traducir una expresión así.

### 2.5 `%` es un salto de línea

En una línea de `crontab`, un `%` sin escapar **parte el comando**: lo que
va antes es el comando y lo que va detrás, separado por cada `%`, es lo que
recibe por **entrada estándar**.

```bash
cat > /tmp/t.cron <<'EOF'
* * * * * date +%T >> /tmp/pct1.log
* * * * * date +\%T >> /tmp/pct2.log
* * * * * cat > /tmp/pct3.txt % uno % dos
EOF
crontab /tmp/t.cron
# espera un minuto
ls /tmp/pct1.log
# ls: cannot access '/tmp/pct1.log': No such file or directory
cat /tmp/pct2.log
# 04:36:04
cat -A /tmp/pct3.txt
#  uno $
#  dos$
```

La primera línea **no escribió nada**: `cron` ejecutó `date +` y el
`>> /tmp/pct1.log` se fue a la entrada estándar como texto. Y no hay ningún
error visible. La tercera demuestra el mecanismo: el archivo recibió ` uno `
y ` dos` como dos líneas. **Siempre `\%`** en `date +\%F`, en `printf` con
formato y en cualquier comando con `%`. (Los `%` dentro de un script
llamado desde `cron` no tienen este problema: solo cuenta lo que está **en
la línea de `crontab`**. Por eso es buena idea que la línea sea corta y
llame a un script.)

### 2.6 Atajos: `@daily` y compañía

Los atajos reemplazan los cinco campos por una palabra:

| Atajo | Equivale a | Cuándo corre |
|---|---|---|
| `@hourly` | `0 * * * *` | cada hora en punto |
| `@daily` (o `@midnight`) | `0 0 * * *` | cada día a las 00:00 |
| `@weekly` | `0 0 * * 0` | el domingo a las 00:00 |
| `@monthly` | `0 0 1 * *` | el día 1 a las 00:00 |
| `@yearly` (o `@annually`) | `0 0 1 1 *` | el 1 de enero a las 00:00 |
| `@reboot` | — | una vez, al arrancar el demonio `cron` |

`crontab` los acepta (`printf '@daily true\n' | crontab -` sale con `0`).
`@reboot` **no se puede comprobar en el laboratorio**: un contenedor no se
«reinicia» como una máquina, y en `ubuntu-lab` reiniciar a mano el demonio
no lo disparó. En un host real, `@reboot` es la forma de lanzar algo al
arrancar sin escribir una unidad de systemd.

Un detalle de diseño: la hora «00:00» a la que corren `@daily`, `@weekly` y
compañía es la **de más carga** del servidor, porque todo el mundo las elige.
Si programas varias tareas pesadas, escalona los minutos (`7 3 * * *`,
`23 3 * * *`).

## 3. Cómo se usa

Un procedimiento para no equivocarte:

1. Escribe la frase en español («cada quince minutos, de 9 a 17, de lunes a viernes»).
2. Tradúcela campo a campo.
3. Cuéntala con `toolkit.sh schedule check` y comprueba que
   `ejecuciones por dia` coincide con tu cuenta mental.
4. Si dice `aviso: dia del mes y dia de la semana restringidos`, reescríbela.
5. Solo entonces instálala.

```bash
~/bin/toolkit.sh schedule check '30 2 * * 1-5' | tail -1
# ejecuciones por dia: 1
~/bin/toolkit.sh schedule check '60 * * * *'
# toolkit schedule check: expresion invalida: fuera del rango 0-59: '60'
echo "codigo: $?"
# codigo: 2
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `date +%F` en un `crontab` | El `%` parte el comando y falla sin error visible | `date +\%F`, o llamar a un script |
| `*/7` esperando «cada 7 minutos» | Reinicia en 0 cada hora: intervalos de 7 y 4 minutos | Un paso que divida a 60, o `OnUnitActiveSec=` |
| Día del mes **y** día de la semana a la vez | `cron` los une con O: corre mucho más de lo que crees | Uno solo, y el script comprueba el otro |
| `0 0 * * *` para todo | Todas las tareas de la máquina arrancan a la vez | Minutos distintos |
| `0 24 * * *` | La hora llega hasta 23: `crontab` lo rechaza | `0 0 * * *` |
| Instalar la expresión sin contarla | Es válida pero no es la tuya | `schedule check` primero |
| Fiarse de una web «generadora de cron» sin entenderla | No te avisa de la regla del O ni del `%` | Entender los cinco campos |

## 5. Trucos

- **`seq 0 7 59`** muestra los valores que cubre un paso en un campo de
  minutos. Es la comprobación más rápida de un `*/N`.
- **`systemd-analyze calendar`** (instalado con `systemd`) enseña **cuándo será
  la próxima ejecución** de una expresión; con `--iterations=3`, las tres
  siguientes. Para comprobar un `cron` con una herramienta independiente,
  traduce a `OnCalendar` ([archivo 06](06-temporizadores-de-systemd.md)).
- **Escalonar con `sleep` aleatorio**: `sleep $((RANDOM % 60))` al principio
  del script reparte la carga entre muchos servidores que usan la misma línea.

## 📚 Recursos Adicionales

- `man 5 crontab`
- [crontab.guru](https://crontab.guru) — traduce una expresión a frase. Útil
  para contrastar, no para aprender: no avisa del `%`

## ✅ Checklist de Verificación

- [ ] Cuentas a mano las ejecuciones por día de `*/15 9-17 * * 1-5` (36)
- [ ] Explicas por qué `*/7` deja un hueco de 4 minutos cada hora
- [ ] Sabes que `0-7` en el día de la semana son 7 valores, no 8
- [ ] Repites el experimento del O y ves que `cron` ejecuta fuera del día del mes
- [ ] Comprobaste que `date +%T` sin escapar no escribe nada y `date +\%T` sí
- [ ] Nombras los seis atajos y dices por qué no se puede probar `@reboot` en un contenedor

---

[← `cron` y `crontab`](01-cron-y-crontab.md) · [El entorno mínimo de cron →](03-el-entorno-minimo-de-cron.md)
