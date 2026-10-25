# Concurrencia, bloqueos y reintentos

> Un script que funciona una vez no es un script robusto: hay que preguntarse
> **qué pasa si se lanza dos veces a la vez, si se cuelga, si falla a la
> primera pero funcionaría a la segunda**. Las respuestas: `flock`, `timeout`
> y los reintentos.

## 🎯 Objetivos

- Evitar ejecuciones simultáneas con `flock` (con comando, con descriptor, `-n` y `-w`)
- Explicar por qué un bloqueo por `flock` no se queda "huérfano" y uno por archivo PID sí
- Limitar el tiempo de un comando con `timeout` y distinguir `124`, `137` y el resto
- Escribir una función de reintento con espera creciente
- Reconocer qué comandos son **idempotentes** y por qué importa

## 1. Qué problema resuelve

En la Semana 16 programarás tus scripts con `cron` o un temporizador de
systemd. Entonces ocurren tres cosas que en tu terminal nunca ves:

1. **Solapamiento**: el script de las 3:00 aún corre cuando llega el de las
   3:05, y los dos escriben en el mismo archivo.
2. **Cuelgue**: un `curl` a un servidor que no responde se queda esperando
   para siempre, y los lanzamientos siguientes se acumulan.
3. **Fallo pasajero**: la red falla un segundo y el script entero se da por
   perdido, cuando un segundo intento habría funcionado.

## 2. Cómo funciona

### 2.1 `flock`: un bloqueo que entiende el kernel

`flock` pide al kernel un **bloqueo sobre un archivo**. Mientras alguien lo
tiene, los demás esperan o fallan según la opción.

```bash
flock -n /tmp/l.lock sleep 2 &
sleep 0.3
flock -n /tmp/l.lock echo "entre"; echo "codigo: $?"
# codigo: 1
wait
flock -n /tmp/l.lock echo "entre"; echo "codigo: $?"
# entre
# codigo: 0
```

- `flock -n ARCHIVO COMANDO` (`--nonblock`): **no espera**; si está ocupado,
  sale con `1` sin ejecutar el comando.
- `flock -w SEG ARCHIVO COMANDO`: espera **hasta** `SEG` segundos y luego se
  rinde con `1`. Sin `-n` ni `-w`, espera **indefinidamente**.
- `flock ARCHIVO -c 'comando con espacios'`: la forma con `-c` acepta una
  cadena.

El archivo de bloqueo es solo un **punto de encuentro**: se crea si no
existe y su contenido no importa.

### 2.2 La forma con descriptor: el bloqueo vive lo que vive el script

Para proteger **todo el script** (no un comando), se abre el archivo en un
descriptor y se bloquea ese descriptor:

```bash
cat > lk.sh <<'EOS'
exec {lock_fd}>/tmp/lk.lock          # abre el archivo en un fd libre (bash elige el numero)
if ! flock -n "$lock_fd"; then
  echo "otra ejecucion en curso" >&2
  exit 3
fi
echo "trabajando"
sleep 2
EOS
bash lk.sh & sleep 0.3; bash lk.sh; echo "codigo: $?"; wait
# trabajando
# otra ejecucion en curso
# codigo: 3
```

`exec {lock_fd}>archivo` pide a bash un descriptor libre y lo guarda en
`$lock_fd` (no hay que escoger el 9 a mano). El bloqueo se mantiene **mientras
el descriptor esté abierto**, es decir, hasta que el script termina: no hace
falta soltarlo. Es la forma que usa `guard` con `-k`.

### 2.3 Por qué `flock` no se queda huérfano

El bloqueo pertenece a un **descriptor abierto**, y el kernel lo libera cuando
el proceso muere, **incluso con `kill -9`**:

```bash
bash -c 'exec 9>/tmp/l2.lock; flock 9; read -r x' < <(sleep 30) & h=$!
sleep 0.4
flock -n /tmp/l2.lock true; echo "ocupado: $?"
# ocupado: 1
kill -9 $h; sleep 0.2
flock -n /tmp/l2.lock true; echo "tras kill -9: $?"
# tras kill -9: 0
```

Compáralo con la alternativa casera, un **archivo con el PID**: si el script
muere sin borrarlo, el archivo queda diciendo "hay alguien corriendo" para
siempre, y para saber si es verdad hay que comprobar si ese PID existe (y los
PID se reutilizan):

```bash
echo 99999 > /tmp/pidf
kill -0 "$(cat /tmp/pidf)" 2>/dev/null && echo "vivo" || echo "pid muerto (bloqueo huerfano)"
# pid muerto (bloqueo huerfano)
```

La otra alternativa casera, `mkdir`, sí es **atómica** (falla si existe), pero
tampoco se libera sola:

```bash
mkdir /tmp/lk.d && echo "adquirido"; mkdir /tmp/lk.d 2>/dev/null || echo "ocupado"; rmdir /tmp/lk.d
# adquirido
# ocupado
```

Regla: **`flock` siempre que esté disponible** (en las cuatro distribuciones
del laboratorio viene con `util-linux`).

### 2.4 `timeout`: no esperar para siempre

```bash
timeout 1 sleep 5; echo "codigo: $?"
# codigo: 124
timeout 5 true; echo "codigo: $?"
# codigo: 0
timeout -s KILL 1 sleep 3; echo "codigo: $?"
# codigo: 137
```

| Código de `timeout` | Significa |
|:--:|---|
| `124` | El comando **agotó** el tiempo y `timeout` le envió `TERM` |
| `137` | Se tuvo que matar con `KILL` (`128 + 9`) |
| otro | El código del propio comando |
| `0` con duración `0` | `timeout 0` significa **sin límite** |

Un comando que **ignora `TERM`** no muere con el aviso normal. `-k` añade un
`KILL` de respaldo pasado un tiempo:

```bash
timeout -k 1 1 bash -c 'trap "" TERM; sleep 5'; echo "codigo: $?"
# codigo: 137
```

(A 1 s envía `TERM`, el comando lo ignora, a 1 s más envía `KILL`: `137`.)
`timeout` ejecuta **programas externos**: no funciona con funciones ni con
builtins de tu script (sí con `bash -c '...'`). `guard` lo aplica con `-t`.

### 2.5 Reintentos con espera creciente

```bash
retry() {
  local intentos=$1 espera=1 i
  shift
  for ((i = 1; i <= intentos; i++)); do
    "$@" && return 0
    echo "intento ${i} fallo, espero ${espera}s" >&2
    sleep "$espera"
    espera=$(( espera * 2 ))
  done
  return 1
}
retry 3 false
# intento 1 fallo, espero 1s
# intento 2 fallo, espero 2s
# intento 3 fallo, espero 4s
```

La espera **se duplica** cada vez (*backoff exponencial*): el segundo
intento llega pronto por si fue algo pasajero, y los siguientes dan tiempo a
que el servicio se recupere sin martillearlo. Tres reglas:

- **Un tope de intentos**: sin él, un fallo permanente es un bucle infinito.
- **Reintenta solo lo que merece la pena**: un error de sintaxis no se
  arregla esperando; un `timeout` o una red caída, sí.
- **El comando debe ser seguro de repetir** (siguiente apartado).

### 2.6 Idempotencia: repetir sin miedo

Un comando es **idempotente** si ejecutarlo dos veces deja el sistema igual
que ejecutarlo una:

```bash
mkdir -p dir; mkdir -p dir; echo "codigo: $?"
# codigo: 0
rm -f noexiste; echo "codigo: $?"
# codigo: 0
ln -sfn /tmp enlace; ln -sfn /tmp enlace; echo "codigo: $?"
# codigo: 0
```

| Idempotente | No idempotente |
|---|---|
| `mkdir -p`, `rm -f`, `ln -sfn`, `touch` | `mkdir` (falla la 2.ª vez), `rm` sin `-f` |
| `cp` a un destino fijo, `mv` con `-f` | `>>` a un informe (duplica líneas), `echo >> ~/.bashrc` |
| `sed -i 's/a/b/'` (si no queda más `a`) | `useradd` sin comprobar antes |

Un script programado se **repite** (por reintentos, por solapamientos, por
re-ejecutarlo a mano tras un fallo). Si cada paso es idempotente, repetirlo
es seguro.

## 3. Cómo se usa

Las tres defensas juntas, que es justo lo que ofrece `guard`:

```bash
# En cron (Semana 16): no solapar, no colgarse, reintentar una vez.
~/bin/toolkit.sh guard -k /tmp/informe.lock -t 60 -r 1 -- ~/bin/toolkit.sh snapshot --salida /tmp/informe.txt
```

Si otra ejecución tiene el bloqueo, `guard` sale con `3`; si el comando
tarda más de 60 s, con `4`; si falla, lo repite una vez (con la espera `-w`
entre ambos intentos).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Archivo PID como bloqueo | Queda huérfano si el script muere; los PID se reutilizan | `flock` |
| `[ -f lock ] \|\| touch lock` | **Carrera**: dos scripts pasan la comprobación a la vez | `flock -n` o `mkdir` |
| `flock` sin `-n` ni `-w` en una tarea programada | Los lanzamientos se acumulan esperando | `-n` (saltar) o `-w SEG` |
| Comando de red sin `timeout` | Un cuelgue bloquea el script para siempre | `timeout 30 curl ...` |
| Reintentar sin tope | Bucle infinito ante un fallo permanente | `for` con máximo de intentos |
| Reintentar sin espera | Martillea el servicio y no deja que se recupere | `sleep` con espera creciente |
| Pasos no idempotentes en una tarea repetible | La 2.ª ejecución duplica o falla | `mkdir -p`, `rm -f`, comprobar antes |
| `timeout` sobre una función de bash | `timeout` solo ejecuta programas externos | `timeout 5 bash -c '...'` o dividir el trabajo |

## 5. Trucos

- **`flock -n 9 || exit 0`** al principio de un script silencioso: si ya hay
  otra copia, sale **sin ruido** (con `0`, para que `cron` no avise).
- **`timeout --preserve-status`** devuelve el código con el que murió el
  comando (`143` si fue por `TERM`) en vez de `124`.
- **`flock -x` / `-s`**: bloqueo **exclusivo** (por defecto) o **compartido**
  (varios lectores a la vez, ningún escritor).

## 📚 Recursos Adicionales

- `man flock`, `man timeout`
- [BashFAQ 045 — cómo evitar que un script se ejecute dos veces a la vez](https://mywiki.wooledge.org/BashFAQ/045)

## ✅ Checklist de Verificación

- [ ] `flock -n archivo sleep 2 &` y otro `flock -n archivo ...` sale con `1`
- [ ] `lk.sh` lanzado dos veces seguidas sale con `3` la segunda
- [ ] Tras `kill -9` del proceso que tenía el bloqueo, `flock -n` vuelve a funcionar
- [ ] `timeout 1 sleep 5` da `124`, y con `-s KILL`, `137`
- [ ] `retry 3 false` espera `1`, `2` y `4` segundos
- [ ] Explicas por qué `mkdir -p` es idempotente y `mkdir` no

---

[← Registro y depuración](05-registro-y-depuracion.md) · [`getopts` y validación de entradas →](07-getopts-y-validacion-de-entradas.md)
