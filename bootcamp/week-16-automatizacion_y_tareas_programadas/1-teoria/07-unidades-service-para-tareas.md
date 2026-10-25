# Unidades `service` para tareas

> El `.timer` solo dice cuándo. Lo que importa de verdad está en el
> `.service`: con qué usuario, con qué entorno, durante cuánto tiempo y qué
> pasa con su salida. Y no es un shell: no hay pipes ni `$HOME`.

## 🎯 Objetivos

- Escribir un `.service` de tipo `oneshot` con `ExecStart=` correcto
- Explicar por qué `ExecStart=` **no** es una línea de shell (sin pipes, redirecciones ni expansión)
- Fijar usuario, directorio, variables y límite de tiempo en la unidad
- Decir adónde va la salida de un servicio (`journald`) y cómo mandarla a un archivo
- Usar `systemd-analyze verify` y conocer **lo que no detecta**
- Distinguir unidades de sistema y de usuario

## 1. Qué problema resuelve

En `cron` el entorno era mínimo y accidental: dependía de cómo se compiló
el demonio. En un `.service` el entorno es **el que escribes**: usuario,
directorio, variables, tiempos máximos y destino de la salida están en un
archivo legible y revisable.

## 2. Cómo funciona

### 2.1 La unidad mínima, y la completa

Un servicio de tarea necesita tres líneas; el resto es opcional:

```ini
[Service]
Type=oneshot
ExecStart=/usr/bin/true
```

Una unidad con todo lo que suele hacer falta en la práctica:

```ini
[Unit]
Description=Tarea de ejemplo
After=network-online.target

[Service]
Type=oneshot
User=nobody
WorkingDirectory=/tmp
Environment=MODO=prueba
EnvironmentFile=-/etc/default/tarea
ExecStart=/usr/bin/true
TimeoutStartSec=30
Nice=10
NoNewPrivileges=true
ProtectSystem=strict
StandardOutput=append:/var/tmp/tarea.log
StandardError=inherit
```

| Directiva | Qué hace |
|---|---|
| `Type=oneshot` | systemd **espera** a que el proceso termine antes de dar la unidad por activada. Es el tipo de las tareas que acaban |
| `ExecStart=` | El comando, con **ruta absoluta**. Con `oneshot` puede haber varias líneas, que se ejecutan en orden |
| `User=`, `Group=` | Con quién corre. Sin ellas, `root` en una unidad de sistema |
| `WorkingDirectory=` | El `cd` previo. Sin ella, `/` |
| `Environment=` | Una variable. `EnvironmentFile=` lee varias de un archivo; el `-` delante dice «si no existe, no pasa nada» |
| `After=network-online.target` | Espera a que haya red antes de lanzar la tarea (para `curl`, `rsync`) |
| `TimeoutStartSec=` | Si la tarea tarda más, systemd la mata. Es el `guard -t` de systemd |
| `Nice=` | Prioridad (Semana 10): una tarea de mantenimiento no debe quitar CPU al servicio |
| `NoNewPrivileges=`, `ProtectSystem=strict` | Endurecimiento: la tarea no puede ganar privilegios ni escribir fuera de las rutas que permitas |
| `StandardOutput=append:RUTA` | La salida va a un archivo, añadiendo (por defecto va al registro, `journald`) |

`systemd-analyze verify ./ok.service` da el visto bueno (sale con `0`) con
un solo aviso, el de `User=nobody`:

```bash
systemd-analyze verify ./ok.service
# /tmp/u3/ok.service:7: Special user nobody configured, this is not safe!
echo "codigo: $?"
# codigo: 0
```

(`nobody` es un usuario «especial» que systemd desaconseja para servicios:
mejor un usuario propio. Un aviso no es un error.)

### 2.2 `ExecStart=` no es un shell

Es lo que más sorprende viniendo de `cron`. systemd **no** lanza un shell:
ejecuta el programa directamente y trocea la línea en palabras. No hay:

| En `cron` (vía `sh`) | En `ExecStart=` |
|---|---|
| `a \| b` (pipe) | `\|` es un **argumento** literal para `a` |
| `a > fichero` | `>` y `fichero` son **argumentos** |
| `$HOME`, `$(date)`, `~` | No se expanden como en un shell: `$VAR` se sustituye solo si está en `Environment=`; `$(...)` y `~` no existen |
| `a && b` | `&&` es un argumento |
| `scripts/mi-script` (relativa, con barra) | **Error**: `Neither a valid executable name nor an absolute path`. Un nombre sin barra (`mi-script`) solo se busca en los directorios fijos de systemd, **no** en tu `PATH`: `Command mi-script is not executable: No such file or directory` |

Lo que haría un `ExecStart=` con un pipe, emulado (esto es lo que recibe el
programa):

```bash
/usr/bin/echo hola '|' /usr/bin/tr a-z A-Z
# hola | /usr/bin/tr a-z A-Z
```

`echo` imprimió la barra y el resto en vez de conectar los dos comandos. Y
`systemd-analyze verify` **no avisa**: la línea es válida, solo que no hace
lo que crees (más en 2.4). Si necesitas un shell, pídelo explícitamente:

```ini
ExecStart=/usr/bin/bash -c 'echo hola | tr a-z A-Z >> /var/tmp/salida.txt'
```

Y dos caracteres con significado propio en systemd:

| Para escribir… | Escribe en `ExecStart=` |
|---|---|
| un `%` literal (`date +%F`) | `%%F` (el `%` inicia un **especificador**, como `%n` o `%h`) |
| un `$` literal | `$$` |

Es la contrapartida exacta de lo que viste en `cron` (`\%`). Lo que
`toolkit.sh schedule gen` hace en el `.service` es `%` → `%%`, y en el
`.cron`, `%` → `\%`:

```bash
~/bin/toolkit.sh schedule gen demo --cron '0 3 * * *' --salida /tmp -- /usr/bin/date +%F | tail -1
# archivos creados: 3
grep -h 'date' /tmp/demo.cron /tmp/demo.service | cut -c1-200
# 0 3 * * * /root/bin/toolkit.sh guard -k /var/tmp/toolkit-demo.lock -t 300 -- /usr/bin/date +\%F >> /var/tmp/toolkit-demo.log 2>&1
# ExecStart=/root/bin/toolkit.sh guard -k /var/tmp/toolkit-demo.lock -t 300 -- /usr/bin/date +%%F
```

### 2.3 Dónde va la salida

Un servicio de systemd tiene la salida estándar y los errores conectados a
**`journald`**, el registro del sistema. No rediriges nada y, aun así, no se
pierde:

```bash
# SOLO EN UN HOST con systemd:
journalctl -u tarea.service                 # todo lo que imprimio
journalctl -u tarea.service --since today
systemctl status tarea.service              # estado y ultimas lineas
```

Esa es la mayor ventaja práctica frente a `cron`: el registro viene **de
serie**, con marcas de hora, rotación y filtros. Si quieres un archivo,
`StandardOutput=append:RUTA`. La unidad que genera `schedule gen` **no**
redirige (usa el `journald`), mientras que el `.cron` sí tiene que hacerlo.

### 2.4 `verify`: qué detecta y qué no

`systemd-analyze verify` solo mira la unidad **sin ejecutarla**. Probé seis
unidades en `ubuntu-lab`:

| Unidad | Código | `verify` dice |
|---|:--:|---|
| La completa de 2.1 | `0` | Un aviso por `User=nobody` |
| `[Service]` solo con `Type=oneshot` | **1** | `Service has no ExecStart=, ExecStop=, or SuccessAction=. Refusing.` |
| `ExecStart=/no/existe --x` | **1** | `Command /no/existe is not executable: No such file or directory` |
| `ExecStart=/usr/bin/echo hola \| /usr/bin/tr a-z A-Z` | `0` | **Nada** |
| `Restart=maybe` | `0` | `Failed to parse service restart specifier, ignoring: maybe` |
| `User=noexiste_usuario` | `0` | **Nada** |

Dos lecciones. **Lee las líneas de aviso**, no solo el código de salida: un
`0` con un «ignoring» significa que systemd tiró tu directiva. Y **`verify` no
detecta**: un pipe que no es un pipe, ni un usuario que no existe. La
verificación real es ejecutar la unidad en un host (`systemctl start
tarea.service`; `journalctl -u tarea.service`) y comprobar el resultado.

### 2.5 Unidades de sistema y de usuario

| | Sistema | Usuario |
|---|---|---|
| Dónde viven | `/etc/systemd/system/` | `~/.config/systemd/user/` |
| Cómo se gestionan | `sudo systemctl ...` | `systemctl --user ...` |
| Con qué usuario corren | `root` o `User=` | tú |
| ¿Corren si no has iniciado sesión? | sí | solo con `loginctl enable-linger TU-USUARIO` |

Para tareas **personales** (tu respaldo, tu sincronización), las unidades de
usuario evitan `sudo` entero. Todo esto es **solo en un host**.

## 3. Cómo se usa

El flujo de trabajo completo, desde cero, con lo que comprobarías en cada
paso:

1. Escribe `NOMBRE.service` (y pruébalo **solo**, sin temporizador).
2. `systemd-analyze verify ./NOMBRE.service` y lee los avisos.
3. En un host: `sudo cp`, `sudo systemctl daemon-reload`, `sudo systemctl start NOMBRE.service`.
4. `journalctl -u NOMBRE.service`: ¿hace lo que querías, con el usuario correcto?
5. Solo entonces escribe `NOMBRE.timer`, `verify`, `enable --now NOMBRE.timer`.
6. `systemctl list-timers` para ver `NEXT`; espera una ejecución y mira `journalctl`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `ExecStart=scripts/mi-script` o `ExecStart=mi-script` | La primera es un error de sintaxis; la segunda no se busca en tu `PATH` | Ruta absoluta |
| `ExecStart=a \| b > f` | Pipe y redirección son argumentos; pasa `verify` | `ExecStart=/usr/bin/bash -c '...'` o un script |
| `date +%F` sin duplicar el `%` | systemd lo toma por un especificador | `%%F` |
| `User=nobody` por costumbre | systemd lo desaconseja | Un usuario de servicio propio |
| Redirigir a mano `> /var/log/x.log` en un servicio | Pierdes `journald` y su filtrado | Dejar el registro por defecto, o `StandardOutput=append:` |
| Confiar en `verify` como prueba | No ejecuta nada | `systemctl start` + `journalctl` en un host |
| `Type=simple` (o sin `Type=`) en una tarea que termina | La unidad queda «activa» mientras corre y no hay forma limpia de esperar | `Type=oneshot` |

## 5. Trucos

- **`systemctl cat tarea.service`** (**solo en un host**) muestra la unidad
  tal como la ve systemd, con los *drop-ins* (`.d/`) aplicados.
- **`systemctl edit tarea.service`** crea un fragmento que se **añade** a la
  unidad sin tocar el archivo original: la forma correcta de personalizar una
  unidad de un paquete.
- **`systemd-run --on-active=30s /usr/bin/true`** crea un temporizador y un
  servicio **transitorios** sin escribir ningún archivo (solo en un host).

## 📚 Recursos Adicionales

- `man systemd.service`, `man systemd.exec` (entorno, usuario, endurecimiento) y `man systemd.unit`
- [systemd.exec — documentación oficial](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)

## ✅ Checklist de Verificación

- [ ] Escribes un `.service` `oneshot` con `ExecStart=` absoluto y lo pasas por `verify`
- [ ] Explicas por qué `ExecStart=a | b` no hace un pipe
- [ ] Sabes cómo escribir un `%` literal en `cron` (`\%`) y en systemd (`%%`)
- [ ] Citas una cosa que `verify` **no** detecta
- [ ] Dices dónde acaba la salida de un servicio y cómo verla
- [ ] Distingues unidad de sistema y de usuario, y qué hace falta para que una de usuario corra sin sesión

---

[← Temporizadores de systemd](06-temporizadores-de-systemd.md) · [Construyendo `schedule` →](08-construyendo-schedule.md)
