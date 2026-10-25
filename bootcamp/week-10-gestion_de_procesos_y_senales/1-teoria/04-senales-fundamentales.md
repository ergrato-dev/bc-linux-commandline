# Señales fundamentales

> Una señal no es un mensaje de texto ni una orden que el proceso
> "ejecuta" — es una interrupción que el kernel entrega, y el proceso
> decide (dentro de lo que la señal permite) qué hacer con ella: morir,
> ignorarla, o reaccionar con su propio código. Esa libertad de
> reacción es exactamente la diferencia entre `SIGTERM` y `SIGKILL`.

## 🎯 Objetivos

- Distinguir las señales más comunes: `SIGTERM`, `SIGKILL`, `SIGINT`, `SIGHUP`
- Explicar por qué algunas señales se pueden ignorar y otras no
- Leer el código de salida `128+N` que indica qué señal terminó un proceso
- Enviar señales por nombre o por número con `kill`

## 1. Qué problema resuelve

Terminar un proceso de forma distinta según la urgencia: pedirle que se
cierre ordenadamente (guardando su estado, cerrando archivos), o
forzar su terminación inmediata sin darle oportunidad de nada —
ninguna de las dos es "mejor" en abstracto, son herramientas para
situaciones distintas. Las señales son ese vocabulario.

## 2. Cómo funciona

### 2.1 Las señales más comunes

| Señal | Número | Significa | ¿Se puede ignorar? |
|---|:--:|---|:--:|
| `SIGINT` | 2 | Interrupción (`Ctrl+C` en una terminal) | Sí |
| `SIGTERM` | 15 | Pedido de terminación ordenada (el default de `kill`) | Sí |
| `SIGKILL` | 9 | Terminación inmediata, sin excepciones | **No** |
| `SIGHUP` | 1 | La terminal que lo controlaba se cerró | Sí |

`kill -l` (visto en el archivo 03 de esta semana) lista las 64+
señales disponibles — estas cuatro son, en la práctica diaria, las que
más se usan.

### 2.2 `SIGTERM` se puede ignorar; `SIGKILL` nunca

```bash
bash -c 'trap "" TERM; sleep 10' &
p=$!
kill -TERM "$p"
kill -0 "$p"   # sigue vivo
```

```bash
kill -KILL "$p"
kill -0 "$p"   # ya no existe
```

`trap "" TERM` le dice al proceso que **ignore** `SIGTERM`
explícitamente (archivo 05 de esta semana profundiza en `trap`) — y el
proceso efectivamente sobrevive. `SIGKILL` no pasa por ningún
mecanismo que el proceso pueda interceptar: el kernel lo termina
directamente, sin darle oportunidad de reaccionar. Por diseño, no
existe forma de ignorar, bloquear o atrapar `SIGKILL`.

### 2.3 Por qué `SIGTERM` es el default de `kill`, no `SIGKILL`

```bash
kill 1234        # equivalente a: kill -TERM 1234
kill -9 1234     # equivalente a: kill -KILL 1234
```

`kill` sin ninguna bandera de señal envía `SIGTERM` — un pedido, no una
orden incondicional. Esto le da al proceso la oportunidad de terminar
ordenadamente (cerrar archivos, guardar estado, limpiar temporales) si
tiene lógica para eso. `SIGKILL` es el último recurso, para cuando
`SIGTERM` no fue suficiente (el proceso lo ignora, o no responde).

### 2.4 El código de salida 128+N: qué señal terminó un proceso

```bash
sleep 10 & p=$!
kill -TERM "$p"
wait "$p"
echo $?
```

```
143
```

Ya visto en la Semana 05: cuando una señal termina un proceso, el
código de salida es `128 + número_de_señal` — `143 = 128 + 15`
(`SIGTERM`). Este cálculo identifica exactamente qué señal lo mató, sin
tener que haber estado mirando en el momento exacto en que pasó.

### 2.5 `SIGHUP`: la terminal se fue

```bash
# al cerrar una sesion de terminal, bash envia SIGHUP a sus procesos en segundo plano
```

Históricamente, `SIGHUP` ("hang up") se enviaba cuando una línea
telefónica de módem se cortaba — hoy, el mismo mecanismo se dispara al
cerrar una sesión de terminal. Es la razón por la que `nohup` (archivo
03 de esta semana) existe específicamente para esta señal, y por la
que muchos demonios usan `SIGHUP` con un significado reinterpretado:
"recarga tu configuración", no "termina" (archivo 06 de esta semana).

### 2.6 `SIGUSR1`/`SIGUSR2`: señales sin significado fijo

```bash
bash -c 'trap "echo recibi USR1, recargando config" USR1; sleep 5 & wait' &
p=$!
kill -USR1 "$p"
```

```
recibi USR1, recargando config
```

A diferencia de `SIGTERM`/`SIGINT`/`SIGHUP`, que tienen una convención
de uso extendida, `SIGUSR1` y `SIGUSR2` no significan nada por
defecto — el kernel las entrega, pero qué hace el proceso con ellas es
pura decisión de quien escribió ese proceso. Muchos programas las usan
para disparar una acción personalizada puntual (recargar un archivo,
rotar un log, imprimir estadísticas) sin necesitar reiniciar nada.

### 2.7 Otras señales con comportamiento especial

| Señal | Comportamiento por defecto |
|---|---|
| `SIGQUIT` | Termina **y** genera un volcado de memoria (*core dump*), a diferencia de `SIGINT` |
| `SIGSEGV` | El kernel la envía automáticamente ante una violación de acceso a memoria |
| `SIGCHLD` | Se envía al padre cuando un hijo termina o cambia de estado — la señal detrás de por qué `wait()` puede reaccionar sin tener que consultar activamente |

`ulimit -c` muestra si el sistema actual tiene habilitados los volcados
de memoria (`core dumps`) — si está en `0`, `SIGQUIT` termina el
proceso igual, pero sin generar ningún archivo de volcado.

## 3. Cómo se usa

```bash
# Pedir terminacion ordenada primero, forzar despues si no responde
kill -TERM 1234
sleep 5
kill -0 1234 2>/dev/null && kill -KILL 1234

# Identificar que senal mato un proceso a partir de su codigo de salida
echo $(( codigo_de_salida - 128 ))

# Enviar SIGINT programaticamente, como si fuera Ctrl+C
kill -INT 1234
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `kill -9` como primera opción, siempre | El proceso no tiene oportunidad de cerrar archivos o limpiar estado — puede dejar datos a medio escribir | `SIGTERM` primero, `SIGKILL` solo si no responde después de un tiempo razonable |
| Asumir que cualquier señal se puede ignorar | `SIGKILL` (y `SIGSTOP`) nunca se pueden ignorar, bloquear ni atrapar — por diseño del kernel | Confirmar cuál señal corresponde según si la terminación debe ser garantizada o negociable |
| Interpretar un código de salida alto (`130`, `143`) como un error del programa | Esos códigos significan "una señal lo terminó", no "el programa falló por su propia lógica" | Restar 128 para identificar la señal real, antes de diagnosticar el código como un bug del programa |
| Confundir el número de señal entre sistemas sin confirmar | La mayoría de los números son consistentes en Linux, pero depender del número en vez del nombre es menos legible y más propenso a error | Usar el nombre (`-TERM`, `-KILL`) en vez del número cuando sea posible — más claro de leer, y portable |

## 5. Trucos

- `kill -l 143` (con un código de salida en vez de un nombre de señal)
  traduce directo a qué señal corresponde, sin hacer la resta a mano.
- `timeout 5 comando` corre un comando con un límite de tiempo,
  enviándole `SIGTERM` automáticamente si no termina solo — útil para
  no tener que escribir el patrón de "esperar y forzar" a mano.
- Enviar `SIGTERM` y esperar un momento antes de recurrir a `SIGKILL`
  le da a la mayoría de los programas bien escritos la chance de salir
  limpio — vale la pena por defecto, no solo en casos especiales.

## Resumen

`SIGUSR1`/`SIGUSR2` no tienen significado fijo — quedan a criterio de
cada programa. `SIGTERM` (15) pide terminación ordenada y se puede ignorar; `SIGKILL`
(9) termina sin excepción, nunca se puede ignorar ni atrapar; `SIGINT`
(2) es el equivalente de `Ctrl+C`; `SIGHUP` (1) se dispara al cerrar
una terminal, y muchos demonios lo reinterpretan como "recarga
configuración". El código de salida `128+N` identifica qué señal
terminó un proceso. `kill` sin bandera envía `SIGTERM`, no `SIGKILL` —
un pedido antes que una orden incondicional.

El archivo 05 de esta semana retoma `trap` para construir, con
cualquiera de estas señales, una reacción personalizada propia dentro
de un script.

## 📚 Recursos Adicionales

- [man7.org — signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html) — lista completa de señales y su comportamiento por defecto.
- [man7.org — kill(1)](https://man7.org/linux/man-pages/man1/kill.1.html) — sintaxis completa del comando `kill`.
- `man timeout` — referencia del comando mencionado en los trucos.
- `man 7 signal-safety` — qué funciones son seguras de llamar desde dentro de un manejador de señal, para quien escriba su propio programa.

## ✅ Checklist de Verificación

- [ ] Enviaste `SIGTERM` y `SIGKILL` al mismo tipo de proceso y confirmaste la diferencia cuando el proceso ignora `SIGTERM`
- [ ] Calculaste qué señal terminó un proceso a partir de su código de salida (`128+N`)
- [ ] Explicaste por qué `SIGKILL` nunca se puede atrapar ni ignorar
- [ ] Usaste el patrón "SIGTERM primero, SIGKILL si no responde" en un proceso real
- [ ] Confirmaste que `kill` sin bandera envía `SIGTERM`, no `SIGKILL`
- [ ] Enviaste `SIGUSR1` a un proceso con un trap propio, y confirmaste que no tiene ningún significado por defecto

---

[← 03 — Trabajos y control de shell](03-trabajos-y-control-de-shell.md) · [05 — trap: capturar señales en scripts →](05-trap-capturar-senales-en-scripts.md)
