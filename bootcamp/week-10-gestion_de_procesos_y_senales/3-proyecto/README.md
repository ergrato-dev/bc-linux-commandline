# Capa 10 de `toolkit`: el subcomando `procwatch`

## 🎯 Objetivo

Agregar a `toolkit.sh` un décimo subcomando, `procwatch`, que busca
procesos por nombre, detecta cuáles son zombies entre las coincidencias,
y opcionalmente envía una señal a los que siguen vivos — con el mismo
patrón dry-run/apply de `organize` (Semana 03).

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield` y `finddupes` siguen intactos. `procwatch`
continúa la Fase 3 del bootcamp (Semanas 09-12, sistema y procesos):
donde `finddupes` buscaba en el sistema de archivos, `procwatch` busca
en la tabla de procesos — con el mismo cuidado de no actuar sobre algo
sin confirmar primero qué es.

Esta capa reutiliza, de forma explícita, varios patrones ya vistos:

- **Tres códigos de salida con significado** (`0` sin zombies, `1`
  falta el patrón, `2` zombie encontrado) — el mismo patrón de toda la
  semana anterior.
- **`pgrep` sin `-f`**, a propósito: comparar contra el nombre del
  proceso (no la línea de comando completa) evita que `procwatch`
  pueda coincidir con su propia invocación — el gotcha central del
  archivo 06 de teoría de esta semana.
- **Dry-run por defecto, `--apply` explícito** — el mismo patrón de
  `organize` (Semana 03), ahora aplicado a enviar señales en vez de
  mover archivos.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`, `topcount`, `sumfield` y `finddupes` siguen funcionando (regresión)
3. `procwatch` sale con código `1` si no se le pasa ningún patrón
4. `procwatch` sale con código `0` si no encuentra ningún proceso con ese patrón
5. `procwatch` encuentra un proceso real en ejecución por su nombre
6. `procwatch` sale con código `0` cuando las coincidencias no incluyen ningún zombie
7. `procwatch` detecta un proceso zombie entre las coincidencias
8. `procwatch` sale con código `2` si encuentra al menos un zombie
9. `procwatch` envía la señal de verdad solo cuando se pasa `--apply`

## 🎨 Criterios de calidad

- Usa `pgrep -a` sin `-f`, evitando el riesgo de automatcheo con la
  propia invocación del script
- Nunca intenta enviar una señal a un proceso ya identificado como
  zombie — lo reporta, y nada más
- Dry-run por defecto: sin `--apply`, informa qué señal enviaría, sin
  enviarla
- Protege cada conteo de una variable que puede estar vacía con
  `grep -c . || true`, consistente con el resto del proyecto

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `procwatch` (no evaluado esta semana) |
|---|---|
| Administras servicios que a veces generan zombies | Agregar un modo que identifique y reporte también el PID del padre de cada zombie, no solo el zombie |
| Te importa automatizar reinicios | Agregar un modo `--reiniciar comando` que relance el proceso después de señalizarlo |
| Trabajas con muchos procesos del mismo nombre | Agregar un filtro por usuario (`-u`, como `pkill -u`) además del patrón de nombre |
| Prefieres confirmación interactiva | Agregar un modo que pida confirmación antes de cada señal real, similar a `kill -p`/`xargs -p` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-10-gestion_de_procesos_y_senales/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO de cmd_procwatch
./scripts/verificar-semana.sh 10
```

## 🧯 Errores comunes

- Usar `pgrep -f` en vez de `pgrep -a` (sin `-f`): el patrón puede
  coincidir con la propia invocación de `toolkit.sh procwatch`,
  afectando al script que lo está corriendo.
- Intentar enviar una señal a un PID sin confirmar su STAT primero —
  un zombie "acepta" la señal (código de salida `0`) sin que tenga
  ningún efecto real.
- Enviar la señal real sin que el usuario haya pasado `--apply`,
  rompiendo la expectativa de que el comportamiento por defecto es
  siempre seguro de ejecutar.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-procwatch-con-pipes-reales.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
