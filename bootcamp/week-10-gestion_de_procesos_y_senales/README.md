# Semana 10 — Gestión de procesos y señales

> Todo lo que corre en Linux es un proceso, y todo proceso puede
> recibir una señal que no pidió. Esta semana aprendes a leerlos, a
> distinguir uno que ya murió de uno que solo está dormido, y a
> terminarlos con el criterio correcto — nunca a ciegas.

## 🎯 Objetivos de la Semana

- Leer PID, PPID, STAT y la jerarquía de procesos con `ps`
- Distinguir un proceso zombie de uno huérfano, y entender por qué ninguno responde igual a una señal
- Manejar trabajos en segundo plano con `jobs`, `fg`, `bg` y `disown`
- Capturar señales en scripts con `trap`, garantizando limpieza incluso ante un fallo
- Enviar señales con criterio usando `kill`/`pkill`, evitando el riesgo de automatcheo de `-f`

## 📋 Prerrequisitos

Semana 09 completada: `toolkit.sh finddupes` funcionando, comodidad con
pipelines de `find`/`xargs` y el patrón `grep -c . || true` para contar
una variable que puede estar vacía — esta semana lo reutiliza para
contar procesos encontrados.

## 🗂️ Estructura de la Semana

```
week-10-gestion_de_procesos_y_senales/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: ps/arbol, zombies/huerfanos, jobs, senales, trap, kill, capstone
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 10 de toolkit: subcomando procwatch
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-ps-y-el-arbol-de-procesos.md) | ps y el árbol de procesos | 20 min |
| [02](1-teoria/02-estados-de-proceso-zombies-y-huerfanos.md) | Estados de proceso: zombies y huérfanos | 25 min |
| [03](1-teoria/03-trabajos-y-control-de-shell.md) | Trabajos y control de shell | 20 min |
| [04](1-teoria/04-senales-fundamentales.md) | Señales fundamentales | 20 min |
| [05](1-teoria/05-trap-capturar-senales-en-scripts.md) | trap: capturar señales en scripts | 25 min |
| [06](1-teoria/06-senales-comunes-y-kill-con-criterio.md) | Señales comunes y kill con criterio | 20 min |
| [07](1-teoria/07-construyendo-procwatch-deteccion-y-senales.md) | Construyendo procwatch: detección y señales | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|---|
| [01](2-practicas/01-ps-y-estados-de-proceso.md) | Leer columnas de `ps`, cambiar STAT con SIGSTOP/CONT, visualizar la jerarquía | 45 min |
| [02](2-practicas/02-zombies-huerfanos-y-trabajos.md) | Crear un zombie real, confirmar que kill no tiene efecto, usar disown | 45 min |
| [03](2-practicas/03-senales-y-trap.md) | SIGTERM ignorable vs SIGKILL, código 128+N, la garantía de trap EXIT | 45 min |
| [04](2-practicas/04-procwatch-con-pipes-reales.md) | Construir a mano la lógica completa que después completas en el starter | 45 min |

Y la décima capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `procwatch`, que busca procesos por nombre, distingue
zombies de procesos vivos, y aplica el patrón dry-run/apply para
enviar señales con criterio.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 30 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 10 de `toolkit` | 2 h 20 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `ps -eo pid,%mem,%cpu,cmd --sort=-%mem` ordena por mayor uso de
  memoria, sin tener que leer la lista completa a ojo.
- `trap -p` lista todos los traps activos de la sesión actual, con el
  comando exacto configurado para cada señal.
- `pkill -c -0 "patron"` cuenta coincidencias sin enviar ninguna señal
  real — a diferencia de `pkill -c` solo, que sí la envía mientras cuenta.
- `kill -l 143` traduce un código de salida de vuelta al nombre de la
  señal que lo causó, sin tener que hacer la resta a mano.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `procwatch` funcionando según
   los requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`,
   `logreport`, `logscan`, `topcount`, `sumfield` y `finddupes` de
   semanas anteriores siguen funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 10
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 09](../week-09-busqueda_de_archivos_find_y_xargs/README.md) | Semana 10 | [Semana 11 →](../week-11-usuarios_grupos_y_gestion_de_paquetes/README.md) |

[← Volver al índice del bootcamp](../README.md)
