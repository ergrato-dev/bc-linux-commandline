# xargs en paralelo y control de lote

> Comprimir mil logs, uno a la vez, significa esperar mil veces el
> tiempo de comprimir uno solo. `xargs -P` corre varios al mismo
> tiempo — la diferencia entre un lote que tarda minutos y uno que
> tarda segundos, en el mismo hardware.

## 🎯 Objetivos

- Ejecutar invocaciones de `xargs` en paralelo con `-P`
- Medir la diferencia real entre secuencial y paralelo
- Combinar `-P` con `-n` para controlar lote y paralelismo a la vez
- Reconocer cuándo el paralelismo ayuda y cuándo no vale la pena

## 1. Qué problema resuelve

Sin `-P`, `xargs` ejecuta una invocación, espera que termine, ejecuta
la siguiente — estrictamente secuencial. Si cada tarea tarda un tiempo
fijo y hay muchas, el tiempo total crece de forma lineal. En un sistema
con varios núcleos de CPU disponibles, la mayoría de ese tiempo es
espera ociosa — `-P` aprovecha esos núcleos corriendo varias tareas al
mismo tiempo.

## 2. Cómo funciona

### 2.1 La diferencia medida, no solo afirmada

```bash
time (seq 1 4 | xargs -I{} sleep 0.3)
```

```
real    0m1.206s
```

```bash
time (seq 1 4 | xargs -P4 -I{} sleep 0.3)
```

```
real    0m0.303s
```

Cuatro tareas de 0.3 segundos cada una: secuencial tarda `1.2s` (0.3 ×
4); con `-P4` (hasta 4 en simultáneo), tarda prácticamente lo mismo que
**una sola** tarea — porque las cuatro corrieron al mismo tiempo, no una
después de otra.

### 2.2 El orden de finalización no es el orden de inicio

```bash
(echo 1; echo 2; echo 3) | xargs -P3 -I{} sh -c '
  case {} in
    1) sleep 0.3 ;;
    2) sleep 0.1 ;;
    3) sleep 0.2 ;;
  esac
  echo "terminó {}"
'
```

```
terminó 2
terminó 3
terminó 1
```

La tarea `1` empezó primero pero tardó más — terminó **última**. Con
paralelismo, el orden de la salida refleja cuándo terminó cada tarea,
no el orden en que `xargs` las lanzó. Si el orden de la salida importa,
el paralelismo introduce una variable que no existía en modo
secuencial.

### 2.3 `-P0`: tantas tareas en paralelo como el sistema permita

```bash
nproc
# 8

xargs -P0 comando
```

`-P0` (o simplemente no limitar) deja que `xargs` lance tantas tareas
en paralelo como pueda, sin un límite fijo — `nproc` muestra cuántos
núcleos de CPU tiene el sistema, una referencia útil para elegir un
`-P N` concreto en vez de dejarlo sin límite.

### 2.4 Combinando `-P` con `-n`: lote y paralelismo juntos

```bash
seq 1 6 | xargs -P3 -n2 echo
```

```
1 2
3 4
5 6
```

`-n2` agrupa de a dos elementos por invocación; `-P3` permite hasta
tres de esas invocaciones corriendo en simultáneo — las dos banderas
controlan dimensiones distintas del mismo pipeline: cuánto hace cada
invocación (`-n`) y cuántas invocaciones corren a la vez (`-P`).

### 2.5 `-L`: agrupar por líneas de entrada, no por cantidad de argumentos

```bash
printf 'a b c\nd\ne f\n' | xargs -L1 echo "LINEA:"
```

```
LINEA: a b c
LINEA: d
LINEA: e f
```

```bash
printf 'a b c\nd\ne f\n' | xargs -n2 echo "N2:"
```

```
N2: a b
N2: c d
N2: e f
```

`-L1` respeta los **límites de línea originales** de la entrada —
cada invocación recibe exactamente lo que había en una línea, sin
importar cuántas palabras tenga. `-n2` ignora por completo dónde
estaban los saltos de línea originales y agrupa de a dos **palabras**,
mezclando contenido de líneas distintas si hace falta para completar el
grupo. Son herramientas para problemas distintos: `-L` cuando la
estructura de línea importa, `-n` cuando solo importa la cantidad de
argumentos por invocación.

## 3. Cómo se usa

```bash
# Comprimir logs viejos en paralelo, aprovechando varios nucleos
find /var/log -name "*.log" -mtime +30 -print0 | xargs -r0 -P4 -I{} gzip {}

# Calcular checksums de muchos archivos mas rapido
find . -type f -print0 | xargs -r0 -P"$(nproc)" -n1 sha256sum

# Descargar varios archivos en paralelo (ejemplo conceptual)
cat urls.txt | xargs -P5 -n1 curl -O
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `-P` alto sin medir si la tarea es intensiva en CPU o en I/O | Más paralelismo del que el sistema puede aprovechar de verdad puede saturar disco o red, volviendo todo **más lento**, no más rápido | Empezar con un `-P` moderado (como `nproc`) y medir con `time` antes de subirlo |
| Depender del orden de la salida en un pipeline con `-P` mayor a 1 | El orden de finalización no es el de inicio — un script que asume orden puede procesar resultados fuera de secuencia sin darse cuenta | Capturar y ordenar explícitamente después, si el orden final importa |
| Usar `-P` para tareas que modifican un recurso compartido sin protección | Dos invocaciones en paralelo escribiendo al mismo archivo, o incrementando un contador compartido, pueden perder datos por una condición de carrera | Evitar `-P` > 1 cuando las tareas no son independientes entre sí, o coordinar el acceso al recurso compartido |
| Asumir que `-P` siempre acelera sin medir primero | Para tareas muy cortas, el costo de lanzar procesos en paralelo puede superar la ganancia — no todo se beneficia igual | Medir con `time`, secuencial contra paralelo, antes de asumir la mejora |
| Confundir `-L` con `-n` cuando la estructura de línea de la entrada importa | `-n` puede mezclar contenido de líneas distintas en una sola invocación, rompiendo la asociación original | `-L` cuando cada línea representa una unidad lógica que no debe mezclarse con la siguiente |

## 5. Trucos

- `time (comando)` (con el comando entre paréntesis, en una subshell) es
  la forma más simple de medir cuánto tarda cualquier pipeline, sin
  modificar el comando en sí.
- `nproc` da el número de núcleos disponibles — un punto de partida
  razonable para `-P`, no necesariamente el óptimo para cada caso.
- Si no estás seguro de si el paralelismo ayuda, medí ambos: `time (...
  sin -P)` contra `time (... con -P N)`, con los mismos datos, antes de
  decidir cuál usar en un script real.

## Resumen

`-L` agrupa por líneas de entrada originales; `-n` agrupa por cantidad
de argumentos, sin respetar esos límites. `xargs -P N` ejecuta hasta `N` invocaciones en paralelo, en vez de una
por vez — una mejora medible cuando hay múltiples núcleos disponibles y
las tareas son independientes. El orden de finalización no respeta el
orden de inicio. `-P0` usa tantas como el sistema permita; combinado
con `-n`, controla tanto el tamaño de cada lote como cuántos lotes
corren a la vez. El paralelismo no es gratis: tareas dependientes entre
sí, o ya limitadas por disco/red en vez de CPU, pueden no mejorar — o
empeorar.

## 📚 Recursos Adicionales

- [GNU Findutils Manual — xargs](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Invoking-xargs) — `-P`, `-n` y el resto de banderas de control.
- `man xargs` — sección de `-P`/`--max-procs` y de `-L`/`--max-lines`.
- `man nproc` — detalle de cómo se calcula el número de núcleos disponibles.
- `man time` — si el sistema tiene el binario `/usr/bin/time` instalado, con más detalle que el `time` incorporado de bash.
- [GNU Coreutils Manual — nproc invocation](https://www.gnu.org/software/coreutils/manual/coreutils.html#nproc-invocation) — qué cuenta `nproc` exactamente como núcleo disponible.

## ✅ Checklist de Verificación

- [ ] Mediste con `time` la diferencia entre `xargs` secuencial y con `-P`
- [ ] Reprodujiste cómo el orden de finalización no respeta el orden de inicio con `-P` > 1
- [ ] Combinaste `-P` y `-n` en un mismo pipeline
- [ ] Explicaste con tus palabras un caso donde más paralelismo no mejora el resultado
- [ ] Reprodujiste la diferencia entre `-L1` (por línea) y `-n2` (por cantidad de argumentos) con entrada de largo irregular

---

[← 05 — xargs seguro: -print0, -I y nombres de archivo peligrosos](05-xargs-seguro-print0-y-nombres-peligrosos.md) · [07 — Construyendo finddupes: find + xargs + hashing →](07-construyendo-finddupes-find-xargs-hashing.md)
