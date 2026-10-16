# Señales comunes y kill con criterio

> `pkill -f patron` puede matar al proceso que lo está ejecutando —
> incluido él mismo. No es un caso exótico: basta con que el patrón de
> búsqueda aparezca, por coincidencia, en los propios argumentos del
> script que lo está corriendo.

## 🎯 Objetivos

- Enviar señales por PID (`kill`) o por nombre/patrón (`pkill`)
- Elegir la señal explícitamente con `-s`/`--signal` o por nombre directo
- Reproducir cómo `pkill -f` puede automatarse por coincidir con su propia invocación
- Aplicar el patrón "SIGTERM primero, SIGKILL si no responde" con criterio

## 1. Qué problema resuelve

Terminar "todos los procesos de nginx" o "todo lo que coincida con
este patrón", sin tener que buscar cada PID a mano con `ps`/`pgrep`
primero — `pkill` combina la búsqueda y el envío de la señal en un solo
comando. Pero esa misma comodidad es, exactamente, lo que lo vuelve
peligroso si el patrón de búsqueda no es tan específico como parece.

## 2. Cómo funciona

### 2.1 `kill`: por PID, con la señal que corresponda

```bash
kill -s TERM 1234
kill -TERM 1234      # forma equivalente, mas corta
kill -9 1234          # por numero, SIGKILL
```

`kill` necesita un PID específico — la forma más precisa, pero requiere
saber de antemano cuál es.

### 2.2 `pkill`: busca y mata en un solo paso

```bash
pkill sleep
```

```
(sin salida, pero termina cualquier proceso cuyo "comm" sea "sleep")
```

`pkill nombre` es, en esencia, `pgrep nombre` seguido de `kill` sobre
cada resultado — mismas reglas de comparación que `pgrep` (archivo 01
de esta semana): por defecto, contra `comm` (máximo 15 caracteres), no
contra la línea de comando completa.

### 2.3 El gotcha real: `pkill -f` puede automatarse

```bash
#!/usr/bin/env bash
echo "pid propio: $$ cmd: $0 $*"
sleep 100 &
pkill -f "modo-mantenimiento"
echo "si ves esto, el script sobrevivio"
```

```bash
./script.sh modo-mantenimiento
```

```
pid propio: 4113 cmd: /root/script.sh modo-mantenimiento
```

**El script termina ahí** — la línea final nunca se imprime. `pkill -f`
compara contra la línea de comando **completa**, y el propio script se
invocó con el argumento `modo-mantenimiento`, que coincide exactamente
con el patrón que el script le pasó a `pkill`. El script se mató a sí
mismo, sin ninguna advertencia.

```bash
./script.sh otra-cosa
```

```
pid propio: 4120 cmd: /root/script.sh otra-cosa
si ves esto, el script sobrevivio
```

Con un argumento distinto, el patrón ya no coincide con la propia
invocación, y el script sobrevive — la diferencia entre ambos casos es
pura coincidencia textual, no algo que `pkill` pueda saber que
importa.

### 2.4 Por qué pasa, y cómo evitarlo

`pkill -f` no distingue "el proceso que busco" de "el proceso que me
está ejecutando a mí mismo ahora" — ambos son, para el sistema,
procesos como cualquier otro, y si el patrón coincide con ambos, actúa
sobre ambos. Mitigaciones reales:

```bash
# Excluir el propio PID explicitamente
pkill -f "patron" 2> /dev/null
# (pkill SI excluye su propio proceso de pkill, pero NO excluye a su invocador)

# Mas especifico: anclar el patron para que no matchee argumentos sueltos
pkill -f "^/usr/bin/mi-servicio --config"
```

Un patrón más específico (anclado, con más contexto) reduce el riesgo
de coincidir con algo no intencional — pero la forma más segura es
confirmar primero con `pgrep -fa "patron"` (sin matar nada todavía) y
revisar la lista de PIDs y comandos que va a afectar, antes de agregar
la acción.

### 2.5 El patrón completo: confirmar, pedir, forzar

```bash
# 1. Confirmar que PIDs van a verse afectados
pgrep -fa "patron"

# 2. Pedir terminacion ordenada
pkill -f "patron"

# 3. Si no responden despues de un tiempo, forzar
sleep 5
pkill -9 -f "patron"
```

El mismo patrón "SIGTERM primero, SIGKILL si no responde" del archivo
04 de esta semana, ahora aplicado a un **grupo** de procesos por
patrón en vez de uno por PID.

### 2.6 `pkill -c`: cuenta, pero **también** envía la señal

```bash
pkill -c sleep
```

```
3
```

`-c` imprime cuántos procesos coincidieron — pero por defecto, **igual
les envía `SIGTERM`** mientras cuenta. No es un modo de solo-lectura;
es un cambio de qué se imprime, no de qué se hace. Para contar sin
matar nada, hay que combinarlo con la señal `0` (que no hace nada,
solo verifica que el proceso existe):

```bash
pkill -c -0 sleep
```

```
3
```

Con `-0`, el conteo es real y **nadie murió** — la combinación
correcta para "decime cuántos coinciden" sin ninguna consecuencia.

## 3. Cómo se usa

```bash
# Confirmar antes de actuar, siempre
pgrep -fa "proceso-viejo"

# Terminar ordenadamente todos los procesos de un usuario
pkill -u www-data

# Forzar terminacion si un proceso especifico no responde a TERM
kill -TERM 1234; sleep 5; kill -0 1234 2>/dev/null && kill -9 1234
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `pkill -f` con un patrón corto o genérico dentro de un script | El patrón puede coincidir con los propios argumentos del script, matándolo a sí mismo | Confirmar con `pgrep -fa` primero, y usar patrones específicos (rutas completas, flags únicos) |
| Saltar directo a `pkill -9` sin confirmar qué va a afectar | Un patrón mal pensado puede matar procesos que no eran el objetivo, sin ninguna posibilidad de deshacerlo | `pgrep -fa "patron"` primero, confirmar la lista, recién después `pkill` |
| Usar `pkill` sin `-f` esperando que compare contra la línea de comando completa | Por defecto compara contra `comm` (15 caracteres) — un patrón más largo o más específico no va a coincidir con nada | `-f` cuando el patrón necesita compararse contra la línea completa, con la precaución de la sección 2.3 |
| Asumir que `pkill`/`kill` siempre tienen éxito solo porque no dieron error | Un proceso puede ignorar `SIGTERM` (archivo 04) — "no dio error" no significa "terminó" | Confirmar con `pgrep`/`kill -0` después de la señal, no solo confiar en el código de salida de `pkill` |
| Usar `pkill -c "patron"` esperando que sea un modo de solo contar | Sin la señal `0` explícita, `-c` cuenta **y** envía `SIGTERM` de todas formas | `pkill -c -0 "patron"` cuando la intención es contar sin matar nada |

## 5. Trucos

- `pgrep -fa "patron"` (sin `pkill`) es la forma más segura de "ensayar"
  qué va a afectar un `pkill -f "patron"`, sin ningún riesgo.
- Anclar el patrón de `pkill -f` con `^` cuando se conoce cómo empieza
  el comando real reduce drásticamente el riesgo de coincidir con algo
  no intencional.
- `pkill -u usuario` mata todos los procesos de un usuario específico
  de una sola vez — útil para limpiar una sesión completa sin buscar
  cada proceso por separado.

## Resumen

`kill` necesita un PID específico; `pkill` busca por nombre/patrón y
mata todo lo que coincide, igual que `pgrep` busca. `pkill -f`
compara contra la línea de comando completa — y puede coincidir con
los propios argumentos del script que lo ejecuta, matándose a sí
mismo sin aviso. Confirmar primero con `pgrep -fa`, usar patrones
específicos, y aplicar "SIGTERM primero, SIGKILL si no responde"
también para grupos de procesos, no solo para uno.

## 📚 Recursos Adicionales

- [man7.org — pkill(1)](https://man7.org/linux/man-pages/man1/pgrep.1.html) — `pkill` se documenta junto a `pgrep` en la misma página.
- [man7.org — kill(1)](https://man7.org/linux/man-pages/man1/kill.1.html) — sintaxis completa de `kill`.

## ✅ Checklist de Verificación

- [ ] Enviaste una señal por PID con `kill` y por patrón con `pkill`
- [ ] Reprodujiste cómo `pkill -f` puede coincidir con la propia invocación de un script y matarlo
- [ ] Confirmaste con `pgrep -fa` antes de ejecutar un `pkill` real
- [ ] Aplicaste el patrón "confirmar, pedir, forzar" sobre un grupo de procesos por patrón
- [ ] Usaste `pkill -c -0` para contar coincidencias sin matar nada, y confirmaste que `-c` solo (sin `-0`) sí mata

---

[← 05 — trap: capturar señales en scripts](05-trap-capturar-senales-en-scripts.md) · [07 — Construyendo procwatch →](07-construyendo-procwatch-deteccion-y-senales.md)
