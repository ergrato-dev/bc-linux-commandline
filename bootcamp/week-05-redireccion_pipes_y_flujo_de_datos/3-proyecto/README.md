# Capa 5 de `toolkit`: el subcomando `logreport`

## 🎯 Objetivo

Agregar a `toolkit.sh` un quinto subcomando, `logreport`, que resume un
archivo de log: cuenta líneas totales, detecta líneas con `ERROR`, guarda
un informe aparte con esas líneas, y sale con un código de salida distinto
según lo que encuentre.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize` y `audit` siguen intactos. `logreport` es
el primer subcommand del **segundo bloque** del proyecto (Semanas 05-09):
en vez de explorar/organizar el sistema de archivos, empieza a procesar
**contenido** de archivos — el tema central de las próximas cinco semanas
(pipes, grep, sed/awk, find).

Esta capa reutiliza, de forma explícita, dos patrones ya vistos:

- **Tres códigos de salida con significado** (`0` limpio, `1` ruta
  inválida, `2` riesgo/hallazgo) — el mismo patrón de `audit` (Semana 04),
  aplicado ahora a contenido de archivos en vez de permisos.
- **Redirección y pipes reales** dentro del propio script: `wc -l <`,
  `grep -c`, y escribir el informe con redirección — no builtins de bash
  que simulen esto, sino las herramientas mismas de esta semana.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory`, `organize` y `audit` siguen funcionando (regresión)
3. `logreport` cuenta correctamente las líneas totales del log
4. `logreport` detecta líneas con `ERROR` y sale con código `2`
5. `logreport` sale con código `0` si no hay líneas con `ERROR`
6. `logreport` guarda las líneas con `ERROR` en un archivo de informe aparte
7. `logreport` sale con código `1` si el archivo no existe

## 🎨 Criterios de calidad

- Usa `wc -l <` (redirección de entrada), no `wc -l archivo` seguido de
  parseo manual de la salida
- El informe se escribe con una redirección real (`>`), no con un bucle
  manual que reconstruye el archivo línea por línea
- Distingue claramente "archivo no existe" (código `1`) de "archivo existe
  pero tiene errores" (código `2`) — nunca el mismo código para ambos
- El nombre del archivo de informe es predecible (`archivo.informe.txt`
  por defecto) y configurable con `--salida`

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `logreport` (no evaluado esta semana) |
|---|---|
| Administras servidores con muchos logs | Agregar soporte para procesar varios archivos en una sola corrida |
| Te importa el formato de salida | Agregar un modo `--json` para integrarlo con otras herramientas |
| Trabajas con logs muy grandes | Medir el tiempo de procesamiento y reportarlo junto al resto |
| Prefieres alertas por severidad | Distinguir `WARN` de `ERROR` con conteos separados |

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-05-redireccion_pipes_y_flujo_de_datos/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO de cmd_logreport
./scripts/verificar-semana.sh 05
```

## 🧯 Errores comunes

- Usar `grep -c "ERROR" archivo` sin manejar el caso de cero coincidencias:
  bajo `set -e`, `grep -c` sin coincidencias sale con código `1`, lo que
  puede cortar el script entero si no se maneja con `|| true` o similar.
- Olvidar `2>/dev/null` o similar al redirigir el resultado de `grep` al
  informe, dejando mensajes de error mezclados con el contenido esperado.
- Confundir el código de salida de `logreport` mismo con el de `grep`
  internamente — el script decide su propio código al final, no hereda el
  de un comando interno sin pensarlo.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-logreport-con-pipes-reales.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
