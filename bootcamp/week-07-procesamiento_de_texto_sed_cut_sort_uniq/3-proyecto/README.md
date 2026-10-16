# Capa 7 de `toolkit`: el subcomando `topcount`

## 🎯 Objetivo

Agregar a `toolkit.sh` un séptimo subcomando, `topcount`, que limpia un
archivo delimitado (comentarios y líneas vacías fuera), extrae una
columna, normaliza mayúsculas/minúsculas, y arma un ranking de los
valores más frecuentes — con un código de salida que avisa si un solo
valor domina más de la mitad de las entradas.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport` y `logscan`
siguen intactos. `topcount` cierra el segundo bloque del proyecto
(Semanas 05-08, procesamiento de contenido de archivos): combina `sed`,
`cut`, `tr` y `sort`/`uniq` en un solo pipeline, en vez de usar cada
herramienta por separado como en las capas anteriores.

Esta capa reutiliza, de forma explícita, dos patrones ya vistos:

- **Tres códigos de salida con significado** (`0` sin dominancia, `1`
  archivo inválido, `2` un valor domina) — el mismo patrón de `audit`,
  `logreport` y `logscan`, aplicado ahora a un ranking de frecuencia.
- **El gotcha de `pipefail` con `grep | wc -l`** de la Semana 06
  reaparece acá, pero con `sed`/`tr`/`cut` en vez de `grep`: cualquier
  comando del pipeline que pueda devolver código distinto de cero sobre
  una entrada "vacía pero válida" necesita la misma atención.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport` y `logscan` siguen funcionando (regresión)
3. `topcount` ignora comentarios y líneas en blanco al contar entradas válidas
4. `topcount` normaliza mayúsculas/minúsculas antes de contar (`ROOT` y `root` cuentan igual)
5. `topcount` sale con código `2` si un valor domina más de la mitad de las entradas
6. `topcount` sale con código `0` si ningún valor domina más de la mitad
7. `topcount` sale con código `1` si el archivo no existe
8. `topcount` sale con código `0` si el archivo no tiene ninguna entrada válida
9. `topcount` usa el campo pasado con `--campo` en vez del primero por defecto
10. `topcount` usa el delimitador pasado con `--delim` en vez de los dos puntos por defecto

## 🎨 Criterios de calidad

- Limpia comentarios (`/^#/d`) y líneas vacías (`/^$/d`) con `sed` en una
  sola pasada, no con dos comandos separados
- Normaliza mayúsculas/minúsculas con `tr` **antes** del primer `sort`,
  no después
- Separa el conteo y el valor más frecuente con `read`, no con `cut`
  sobre la salida de `uniq -c`
- Distingue claramente "archivo inválido" (código `1`) de "un valor
  domina" (código `2`) — nunca el mismo código para ambos

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `topcount` (no evaluado esta semana) |
|---|---|
| Administras varios servidores con logs en formatos distintos | Detectar el delimitador automáticamente en vez de asumir uno fijo |
| Te importan los reportes visuales | Agregar barras de texto proporcionales al conteo (`printf '%*s' N '#'`) |
| Trabajas con datasets muy grandes | Medir cuántas líneas procesa por segundo y reportarlo junto al resultado |
| Prefieres un umbral de dominancia distinto al 50% | Agregar un flag `--umbral N` configurable, en vez de la mitad fija |

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-07-procesamiento_de_texto_sed_cut_sort_uniq/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO de cmd_topcount
./scripts/verificar-semana.sh 07
```

## 🧯 Errores comunes

- Normalizar mayúsculas/minúsculas **después** de ordenar: `ROOT` y
  `root` quedan en posiciones separadas y `uniq` los cuenta como dos
  valores distintos, no uno repetido.
- Olvidar `sed '/^$/d'` y dejar que una línea vacía se cuente como una
  entrada válida más (con valor de columna vacío).
- Confundir `-d` (delimitador de `cut`/`tr -s`) con `-t` (delimitador de
  `sort`) — cada herramienta del pipeline usa su propia bandera para lo
  mismo, con nombres distintos.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-topcount-con-pipes-reales.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
