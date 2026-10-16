# trap: capturar señales en scripts

> La Semana 03 prometió esta pregunta para más adelante: "¿qué pasa con
> tus archivos temporales si el script se corta a la mitad?" `trap` es
> la respuesta — el mecanismo de bash para ejecutar código propio
> cuando llega una señal, en vez de dejar que el comportamiento por
> defecto decida.

## 🎯 Objetivos

- Ejecutar código de limpieza garantizado con `trap ... EXIT`
- Confirmar que el trap `EXIT` corre incluso si el script falla a mitad bajo `set -e`
- Capturar señales específicas (`TERM`, `INT`) con tu propio código
- Restaurar el comportamiento por defecto de una señal con `trap - SEÑAL`

## 1. Qué problema resuelve

Un script que crea un archivo temporal, abre una conexión, o bloquea
un recurso necesita liberar eso **sin importar cómo termine** — ya sea
que llegue al final normalmente, falle con un error, o lo interrumpan
con `Ctrl+C`. Sin `trap`, cualquiera de esos caminos distintos al "todo
salió bien" puede dejar el recurso sin liberar.

## 2. Cómo funciona

### 2.1 `trap ... EXIT`: limpieza garantizada

```bash
tmp=$(mktemp)
trap "rm -f $tmp; echo limpie: $tmp" EXIT
echo "trabajando con $tmp"
```

```
trabajando con /tmp/tmp.aJ5QXdxmOE
limpie: /tmp/tmp.aJ5QXdxmOE
```

El trap `EXIT` corre **siempre** que el script termina — ya sea que
llegue al final de forma normal, o que termine por cualquier otro
motivo. Es la forma correcta de responder a la pregunta de la Semana
03: nunca hace falta duplicar el código de limpieza en cada punto de
salida posible, un solo `trap EXIT` al principio del script cubre
todos.

### 2.2 El trap EXIT corre incluso si el script falla bajo `set -e`

```bash
set -e
trap 'echo LIMPIEZA SIEMPRE' EXIT
echo antes
false
echo nunca-se-ve
```

```
antes
LIMPIEZA SIEMPRE
```

`false` hace que `set -e` corte el script inmediatamente — pero el
trap `EXIT` corre de todas formas, **antes** de que el proceso termine
de verdad. Esto es precisamente lo que hace seguro usar `trap EXIT`
para limpiar recursos en cualquier script con `set -euo pipefail`
(el estándar de este bootcamp desde la Semana 13): un error a mitad de
camino no se "salta" la limpieza.

### 2.3 Capturar una señal específica, no solo EXIT

```bash
trap 'echo atrape una senal' TERM
( sleep 0.3; kill -TERM $$ ) &
sleep 2
echo "esto se imprime igual, porque el trap no termino el script"
```

```
atrape una senal
esto se imprime igual, porque el trap no termino el script
```

`$$` es el PID del script actual — enviarle `TERM` a sí mismo (desde un
proceso en segundo plano, simulando una señal externa) dispara el
trap. A diferencia del comportamiento por defecto de `SIGTERM`
(terminar el proceso), el trap **reemplaza** esa acción — el script
sigue corriendo después, salvo que el propio código del trap incluya
un `exit` explícito.

### 2.4 `trap - SEÑAL`: restaurar el comportamiento por defecto

```bash
trap 'echo custom' TERM
trap - TERM
kill -TERM $$
```

```
(el script termina, sin imprimir "custom")
```

`trap - SEÑAL` (con un guion en vez de un comando) quita cualquier
trap personalizado y restaura la acción por defecto de esa señal —
útil cuando un trap temporal ya cumplió su propósito y no debe seguir
activo para el resto del script.

### 2.5 Varias señales en el mismo trap

```bash
trap 'echo "interrumpido, limpiando..."; rm -f "$tmp"; exit 1' INT TERM
```

Un mismo trap puede responder a varias señales a la vez, listándolas
todas al final — útil cuando el mismo código de limpieza debe correr
sin importar si la interrupción fue `Ctrl+C` (`INT`) o un `kill`
externo (`TERM`).

### 2.6 `RETURN` y `ERR`: pseudo-señales propias de bash

```bash
f() { trap 'echo trap de la funcion' RETURN; echo dentro; }
f
echo despues
```

```
dentro
trap de la funcion
despues
```

`EXIT` no es la única pseudo-señal que `trap` entiende — `RETURN`
dispara al salir de una función (útil para limpieza local a esa
función, no a todo el script); `ERR` dispara cada vez que un comando
falla bajo `set -e`, antes de que el script corte:

```bash
set -e
trap 'echo "ERR disparado en: $BASH_COMMAND"' ERR
false
```

```
ERR disparado en: false
```

`$BASH_COMMAND` dentro del trap de `ERR` identifica exactamente qué
comando falló — útil para loguear el punto de fallo real, sin tener
que envolver cada línea del script en un chequeo manual.

## 3. Cómo se usa

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

procesar_datos > "$tmpfile"
mv "$tmpfile" resultado-final.txt

# El trap EXIT corre aca, pero rm -f sobre un archivo ya movido no falla
```

```bash
# Script que debe terminar limpio ante Ctrl+C, liberando un lock
trap 'rm -f /var/lock/mi-script.lock; exit 1' INT TERM
touch /var/lock/mi-script.lock
# ... trabajo largo ...
rm -f /var/lock/mi-script.lock
trap - INT TERM
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Duplicar el código de limpieza en cada posible punto de salida del script | Fácil olvidar actualizar todos los lugares si la lógica de limpieza cambia — y fácil que un error inesperado salte todos ellos | Un solo `trap ... EXIT` al principio del script, que cubre cualquier forma en que el script termine |
| Asumir que `set -e` salta la limpieza de un trap `EXIT` | El trap `EXIT` corre igual, incluso cuando `set -e` corta el script por un error | Confiar en `trap EXIT` para limpieza, también en scripts con `set -euo pipefail` |
| Dejar un trap de señal activo más tiempo del necesario | Un trap pensado para una sección puntual del script puede interferir con el comportamiento esperado después de esa sección | `trap - SEÑAL` apenas termine la sección que necesitaba ese comportamiento especial |
| Poner lógica compleja directamente en la cadena de `trap` | Un trap de una sola línea larga es difícil de leer y de depurar | Llamar a una función desde el trap (`trap limpiar EXIT`) cuando la lógica de limpieza tiene más de una instrucción |

## 5. Trucos

- `trap limpiar EXIT` (llamando a una función en vez de poner el
  código inline) hace que el trap sea tan legible como cualquier otra
  parte del script.
- `trap -p` lista todos los traps activos en la sesión actual, con el
  comando exacto configurado para cada señal — útil para confirmar qué
  está capturado antes de agregar uno nuevo.
- Definir el `trap EXIT` como la primera línea ejecutable del script
  (justo después de `set -euo pipefail`) asegura que cubra absolutamente
  todo lo que viene después, sin ninguna ventana sin protección.

## Resumen

`trap comando SEÑAL` ejecuta `comando` cuando el script recibe esa
señal, reemplazando (no sumando) la acción por defecto. `trap ...
EXIT` corre siempre al terminar el script, incluso bajo `set -e` y
ante un error — la forma correcta de garantizar limpieza sin
duplicarla en cada punto de salida. `trap - SEÑAL` restaura el
comportamiento por defecto. Varias señales pueden compartir el mismo
trap.

## 📚 Recursos Adicionales

- [GNU Bash Manual — Bourne Shell Builtins (trap)](https://www.gnu.org/software/bash/manual/bash.html#index-trap) — referencia completa del builtin.
- [man7.org — signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html) — comportamiento por defecto de cada señal, lo que `trap` reemplaza.

## ✅ Checklist de Verificación

- [ ] Usaste `trap ... EXIT` para limpiar un archivo temporal, garantizado sin importar cómo termine el script
- [ ] Confirmaste que el trap `EXIT` corre incluso bajo `set -e` cuando el script falla a mitad
- [ ] Capturaste `TERM`/`INT` con tu propio código, confirmando que el script no termina solo por eso
- [ ] Restauraste el comportamiento por defecto de una señal con `trap - SEÑAL`
- [ ] Escribiste un trap que responde a más de una señal a la vez
- [ ] Usaste `trap ... ERR` con `$BASH_COMMAND` para identificar qué comando falló

---

[← 04 — Señales fundamentales](04-senales-fundamentales.md) · [06 — Señales comunes y kill con criterio →](06-senales-comunes-y-kill-con-criterio.md)
