# Pipes: encadenar comandos

> Un pipe no es "pegar comandos con un símbolo". Es conectar el stdout de
> un proceso directamente al stdin de otro, sin pasar por ningún archivo
> intermedio — y esa distinción cambia cómo piensas los pipelines.

## 🎯 Objetivos

- Construir pipelines de varios comandos, entendiendo qué fluye entre cada uno
- Explicar por qué un pipe no usa archivos temporales por debajo
- Diagnosticar un pipeline que "no hace nada" paso por paso
- Usar `pipefail` y `PIPESTATUS` para no perder de vista un fallo intermedio

## 1. Qué problema resuelve

Sin pipes, conectar la salida de un comando con la entrada de otro
requeriría guardar un archivo intermedio, pasárselo al siguiente comando,
y borrar el archivo temporal — repetido por cada paso de una cadena de
procesamiento. El pipe (`|`) elimina ese paso intermedio: conecta
directamente un proceso con el siguiente, sin tocar el disco.

## 2. Cómo funciona

### 2.1 El mecanismo: stdout de uno, stdin del siguiente

(Recordá: stdout y stdin son los descriptores 1 y 0 vistos en el primer
archivo de esta semana — un pipe no inventa nada nuevo, reutiliza el mismo
mecanismo de redirección, apuntando un descriptor directo a otro proceso
en vez de a un archivo.)

```bash
comando1 | comando2
```

Bash crea un **pipe** (una estructura del kernel, no un archivo) y conecta
el descriptor `1` (stdout) de `comando1` al descriptor `0` (stdin) de
`comando2`. Ambos procesos corren **al mismo tiempo**, no uno después del
otro — `comando2` puede empezar a procesar datos que `comando1` todavía
está generando.

```bash
ls -la /etc | wc -l
```

`ls -la /etc` nunca escribe a un archivo ni a la pantalla en este caso: su
salida va directo al pipe, que `wc -l` lee y cuenta.

### 2.2 Pipelines de más de dos comandos

```bash
cat /var/log/syslog | grep "error" | sort | uniq -c | sort -rn
```

Cada `|` agrega una conexión más en la cadena. Pensá cada pipeline como una
línea de ensamblaje: cada comando recibe lo que el anterior produjo, hace
**una** transformación puntual, y pasa el resultado al siguiente. El valor
real de los pipes está en que cada comando individual hace una sola cosa
bien (filtrar, ordenar, contar, deduplicar) — la complejidad sale de
combinarlos, no de que cada uno sea complicado.

### 2.3 `$?` después de un pipe: el código del último comando

```bash
false | true
echo $?
# 0
```

Por defecto, `$?` después de un pipeline refleja el código de salida del
**último** comando de la cadena — aunque uno anterior haya fallado. Esto
es una fuente real de bugs: un pipeline puede "parecer exitoso" aunque el
primer comando haya fallado silenciosamente.

```bash
set -o pipefail
false | true
echo $?
# 1
```

`pipefail` (que vas a usar en todo script a partir de la Semana 13) cambia
este comportamiento: el código de salida del pipeline pasa a ser el del
**primer** comando que falló, no necesariamente el último.

### 2.4 Un pipe no es un archivo: no hay "buscar hacia atrás"

```bash
comando1 | wc -l
```

Como no hay archivo de por medio, `wc -l` no puede "retroceder" a leer algo
que ya pasó — procesa el flujo una vez, en orden, a medida que llega. Esto
contrasta con herramientas que sí trabajan sobre archivos reales (como
`sort`, que necesita ver todo el contenido antes de poder ordenar — por
eso `sort` dentro de un pipe igual junta todo lo que recibe antes de emitir
su resultado, aunque el pipe en sí no sea un archivo).

### 2.5 Buffering: por qué un pipe a veces "no muestra nada" hasta el final

```bash
comando-que-tarda | grep "patron"
```

Cuando la salida de un comando no va directo a una terminal (va a un pipe),
muchas herramientas cambian su estrategia de escritura de "línea por
línea" a "en bloques grandes" (buffering), por eficiencia. El resultado:
`grep` puede no mostrar nada durante un buen rato, y después mostrar todo
de golpe, aunque el comando de origen ya esté produciendo datos
constantemente.

```bash
stdbuf -oL comando-que-tarda | grep "patron"
```

`stdbuf -oL` fuerza buffering por línea en el comando de origen, para ver
los resultados a medida que se generan, no todos juntos al final.

### 2.6 `PIPESTATUS`: el código de salida de cada comando, no solo el último

Más detallado todavía que `pipefail`: bash guarda el código de salida de
**cada** comando de la última pipeline ejecutada en el array `PIPESTATUS`:

```bash
false | true | false
echo "${PIPESTATUS[@]}"
# 1 0 1
```

Esto permite distinguir exactamente cuál de los comandos de una cadena
larga falló, en vez de solo saber que "algo falló en algún punto" (que es
todo lo que da `pipefail`). Útil en scripts donde importa no solo *si*
falló, sino *dónde*.

## 3. Cómo se usa

```bash
# Contar cuantos procesos corren bajo cada usuario
ps -eo user | sort | uniq -c | sort -rn

# Ver las 5 lineas mas largas de un archivo
awk '{ print length, $0 }' archivo.txt | sort -rn | head -5

# Pipeline que falla en el medio, y pipefail lo detecta
set -o pipefail
comando-que-no-existe | wc -l
echo $?
# distinto de 0, gracias a pipefail
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Confiar en `$?` después de un pipe sin `pipefail` activo | Solo refleja el último comando — un fallo temprano en la cadena pasa desapercibido | Activar `set -o pipefail` en cualquier script que encadene comandos con pipes |
| Construir un pipeline de diez comandos de una sola vez, sin probar paso a paso | Si algo falla, no sabes en qué eslabón de la cadena está el problema | Construir el pipeline agregando un comando a la vez, verificando la salida intermedia con cada adición |
| Esperar salida en tiempo real de un pipe sin considerar el buffering | La herramienta de origen puede estar acumulando datos antes de emitirlos, dando la falsa impresión de que "no hace nada" | Usar `stdbuf -oL` (o la opción de buffering propia del comando, si la tiene) cuando el tiempo real importa |
| Usar un pipe para mover datos entre comandos que necesitan ver el archivo completo dos veces | Un pipe se consume una sola vez, en orden — no se puede "releer" | Usar un archivo intermedio real cuando un comando necesita releer o buscar hacia atrás |
| Revisar solo `$?` e ignorar que existe `PIPESTATUS` | Se pierde la posibilidad de saber cuál comando específico de la cadena falló | Consultar `${PIPESTATUS[@]}` cuando el diagnóstico exacto importa, no solo "algo falló" |

## 5. Trucos

- Construí un pipeline largo probándolo comando por comando: corré
  `comando1`, confirmá la salida, agregá `| comando2`, confirmá de nuevo, y
  así siguiendo — mucho más rápido que depurar los diez comandos juntos
  después de que algo falla.
- `comando | less` es la forma más rápida de "paginar" cualquier salida
  larga sin guardarla en ningún archivo.
- `mkfifo` crea un pipe con nombre, persistente en el sistema de archivos
  (a diferencia de un pipe anónimo de `|`, que desaparece cuando el
  pipeline termina) — una herramienta avanzada, vale la pena saber que
  existe.
- `set -o pipefail` combinado con `set -euo` (visto desde la Semana 13) es
  la combinación estándar al principio de cualquier script serio que use
  pipes.

## Resumen

Un pipe conecta el stdout de un proceso directo al stdin del siguiente, a
nivel de kernel, sin archivo intermedio — ambos corren en simultáneo. `$?`
solo refleja el último comando de la cadena salvo que actives `pipefail`;
`PIPESTATUS` da el detalle completo, comando por comando. El buffering por
bloques (en vez de por línea) cuando la salida va a un pipe explica por
qué un pipeline a veces "no muestra nada" hasta acumular suficiente.

## 📚 Recursos Adicionales

- [Bash Reference Manual — Pipelines](https://www.gnu.org/software/bash/manual/bash.html#Pipelines) — la referencia oficial, incluido `pipefail`.
- [Bash Reference Manual — The Set Builtin](https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin) — documentación completa de `set -o`, incluido `pipefail` junto al resto de opciones.
- `man 7 pipe` — la página de manual que documenta el mecanismo de pipes a nivel de kernel.
- `man stdbuf` — referencia completa de las opciones de buffering por herramienta.
- `help pipefail` (o `man bash`, sección `SHOPT`) — documentación del builtin `set -o pipefail`.

## ✅ Checklist de Verificación

- [ ] Construiste un pipeline de al menos cuatro comandos, probándolo paso a paso
- [ ] Reprodujiste por qué `$?` sin `pipefail` no detecta un fallo temprano en la cadena
- [ ] Activaste `pipefail` y confirmaste el cambio de comportamiento
- [ ] Explicaste con tus palabras por qué un pipe no es un archivo temporal
- [ ] Usaste `PIPESTATUS` para identificar exactamente cuál comando de una cadena falló

---

[← 02 — Redirecciones de entrada y salida](02-redirecciones-de-entrada-y-salida.md) · [04 — tee: ver y guardar al mismo tiempo →](04-tee-ver-y-guardar-al-mismo-tiempo.md)
