# Capa 14 de `toolkit`: el subcomando `healthcheck`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `healthcheck`: tres comprobaciones de salud
(disco, memoria, procesos) contra límites que el usuario puede cambiar, que
dice cuáles pasan, **no se detiene en el primer fallo** y sale con un código
que un script o `cron` puede usar. Es el primer subcomando que nace ya con
las herramientas de la semana: bucles, funciones con `local`, un array
indexado, uno asociativo y llamadas a funciones por nombre.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck`,
`netcheck` y `snapshot` siguen intactos y **vienen completos** en el starter.
Una diferencia con la Semana 13: `snapshot` llega ya **refactorizado en
funciones** (`sys_*`, `snapshot_report`, `snapshot_emit`) con la misma salida
que antes: lo recorriste en la práctica 03 y sus comprobaciones se mantienen
como regresión. Tu trabajo nuevo es `healthcheck`, que **reutiliza** esas
funciones `sys_*`.

Qué desbloquea: la Semana 15 le pondrá a `toolkit` manejo de errores robusto
(`trap`, registro y limpieza) y la 16 lanzará `healthcheck` desde `cron` y
desde un temporizador de systemd: por eso sale con `2` si algo falla.

Reutiliza, de forma explícita, patrones ya vistos:

- **Tres códigos de salida con significado** (`0` bien, `1` uso inválido, `2`
  hallazgo): el contrato de toda la Fase 3 y de `snapshot`.
- **Validación antes de comparar** (`is_uint` antes de `-gt`): la lección de
  la Semana 12 sobre aritmética.
- **`while` + `case` + `shift`** para las opciones, ahora con cuatro
  opciones que comparten el control del valor.
- **Las funciones `sys_*` de `snapshot`**: un dato, una función.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. snapshot sigue dando el informe de 11 lineas, sale con 2 ante una alerta y con 1 ante un umbral invalido tras el refactor en funciones
7. healthcheck sin opciones ejecuta las tres comprobaciones y las da por buenas
8. healthcheck informa del disco con su porcentaje y el umbral por defecto
9. healthcheck informa de la memoria en MiB y el minimo por defecto
10. healthcheck informa del numero de procesos y el maximo por defecto
11. healthcheck --solo ejecuta las comprobaciones pedidas en el orden pedido
12. healthcheck sale con codigo 1 si --solo nombra una comprobacion que no existe
13. healthcheck sale con codigo 1 si un limite no es un entero
14. healthcheck sale con codigo 1 ante una opcion que no conoce
15. healthcheck sale con codigo 2 cuando una comprobacion falla
16. healthcheck marca como fallo la comprobacion que no pasa, con su valor y su limite
17. healthcheck sigue con las demas comprobaciones despues de un fallo
18. healthcheck cuenta los fallos en el resumen

## 🎨 Criterios de calidad

- Cada `hc_check_*` recibe su límite como **argumento** (`$1`), imprime
  **una** línea con `hc_line` y devuelve `0`/`1` con `return` explícito
- Toda variable de las funciones lleva `local`, y `local` va **separada** de la
  asignación cuando el valor viene de `$( )` (SC2155)
- Los límites viven en un array **asociativo** y el orden por defecto en uno
  **indexado**; no hay variables sueltas por comprobación
- Las comprobaciones se llaman **por nombre** (`"hc_check_${nombre}"`) y solo
  después de validar el nombre con una lista blanca; no hay `eval`
- Los contadores se incrementan con `x=$(( x + 1 ))`, nunca con `((x++))`
- Los límites se validan con `is_uint` **antes** de cualquier `-gt`/`-lt`
- Los errores de uso van a `stderr` y las líneas del informe a `stdout`
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas `snapshot` ni los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir a tu propio `healthcheck` (no evaluado esta semana) |
|---|---|
| Administras un servidor con carga | Una cuarta comprobación `load` con `/proc/loadavg`: solo hay que añadir `hc_check_load`, un límite y su nombre en la lista blanca |
| Lo vas a lanzar desde `cron` (Semana 16) | Una opción `--silencioso` que solo imprima las líneas de `fallo` |
| Tienes varios discos | Aceptar `--ruta /var` y comprobar ese sistema de archivos en lugar de `/` |
| Quieres un informe legible por otros programas | Una opción `--formato csv` que imprima `nombre,estado,valor` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-14-control_de_flujo_y_funciones_en_bash/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de healthcheck en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 14
```

La [práctica 04](../2-practicas/04-healthcheck-a-mano.md) te guía por los ocho
`TODO` uno a uno.

## 🧯 Errores comunes

- Dejar que una `hc_check_*` haga `exit`: mata el script en vez de devolver un
  estado, y `healthcheck` no llega a contar los fallos.
- Llamarlas sin `if !`: con `set -e`, el primer `return 1` aborta y las demás
  comprobaciones no se ejecutan.
- Escribir `((fallos++))`: con `set -e`, la primera vez vale `0` (falso) y
  aborta. Usa `fallos=$(( fallos + 1 ))`.
- Comparar el límite sin validarlo: `--min-mem x` rompe con
  `integer expression expected` en lugar de salir con `1`.
- Asignar a `limite[disk]` sin `local -A limite`: el array indexado normal
  convierte las claves en `0`.
- Usar `${!limite[@]}` para el orden: es arbitrario; para eso existe `orden`.
- Olvidar `local nombre=""`: con `set -u`, `$nombre` sin valor aborta.
- Probar un fallo con una máquina "enferma" real en vez de un límite
  imposible (`--umbral-disco 0`): no hace falta romper nada para ver el `2`.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-healthcheck-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
