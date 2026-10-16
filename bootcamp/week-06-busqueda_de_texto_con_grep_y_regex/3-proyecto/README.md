# Capa 6 de `toolkit`: el subcomando `logscan`

## 🎯 Objetivo

Agregar a `toolkit.sh` un sexto subcomando, `logscan`, que busca un
patrón de regex extendida (por defecto, `ERROR|WARN|CRIT`) en todos los
archivos `.log` de un árbol de directorios, cuenta cuántos archivos y
líneas coinciden, y sale con un código de salida distinto según lo que
encuentre.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit` y `logreport` siguen intactos.
`logscan` extiende el segundo bloque del proyecto (Semanas 05-09,
procesamiento de contenido de archivos): donde `logreport` resumía **un**
archivo conocido de antemano, `logscan` busca en **todo un árbol** de
directorios, sin saber cuántos archivos hay ni dónde están, filtrando por
extensión y usando una regex de verdad, no un texto literal.

Esta capa reutiliza, de forma explícita, dos patrones ya vistos:

- **Tres códigos de salida con significado** (`0` limpio, `1` ruta
  inválida, `2` coincidencias encontradas) — el mismo patrón de `audit`
  (Semana 04) y `logreport` (Semana 05), aplicado ahora a una búsqueda
  recursiva de regex.
- **`pipefail` bajo presión real**: contar coincidencias con `grep -r |
  wc -l` bajo `set -euo pipefail` puede cortar el script entero cuando
  `grep` no encuentra nada (código `1`) — el mismo mecanismo que la
  Semana 05 enseñó con `pipefail`, ahora aplicado a un caso donde "no
  encontrar nada" es un resultado válido, no un error.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit` y `logreport` siguen funcionando (regresión)
3. `logscan` cuenta correctamente los archivos `.log`, recursivo, e ignora otras extensiones
4. `logscan` cuenta las líneas que coinciden con el patrón por defecto (`ERROR|WARN|CRIT`)
5. `logscan` sale con código `2` si encuentra coincidencias
6. `logscan` sale con código `0` si ningún log tiene coincidencias
7. `logscan` sale con código `1` si el directorio no existe
8. `logscan` usa el patrón pasado con `--patron` en vez del valor por defecto
9. `logscan` cuenta cuántos archivos distintos tienen al menos una coincidencia
10. `logscan` ignora archivos que no terminan en `.log` aunque contengan el patrón

## 🎨 Criterios de calidad

- Usa `grep -E` (extendida) con alternancia, no tres `grep` separados
  combinados a mano
- Protege cada `grep | wc -l` del gotcha de `pipefail` cuando no hay
  coincidencias, con `{ grep ... || true; } | wc -l`, no desactivando
  `pipefail` ni `set -e`
- Distingue "líneas coincidentes totales" (`-h`) de "archivos con al
  menos una coincidencia" (`-l`) como dos números separados, no el mismo
  número reinterpretado
- Filtra por `.log` con `--include`, no revisando todos los archivos del
  árbol sin distinción

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `logscan` (no evaluado esta semana) |
|---|---|
| Administras varios servidores con logs rotados | Aceptar varios directorios en una sola corrida, no solo uno |
| Te importan los falsos positivos | Agregar `-w` o `\b` al patrón por defecto para evitar coincidencias parciales |
| Trabajas con logs de aplicaciones en inglés y español | Hacer que el patrón por defecto incluya ambos idiomas (`ERROR|WARN|error|aviso`) |
| Necesitas exportar resultados | Agregar un modo `--salida archivo.txt` que guarde el listado completo, como ya hace `logreport` |

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-06-busqueda_de_texto_con_grep_y_regex/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO de cmd_logscan
./scripts/verificar-semana.sh 06
```

## 🧯 Errores comunes

- Contar coincidencias con `grep -rh "$patron" "$dir" | wc -l` sin
  proteger el `grep` de salir con código `1` cuando no hay coincidencias
  — bajo `set -euo pipefail`, eso corta el script entero justo en el caso
  donde "no encontrar nada" es un resultado perfectamente válido.
- Confundir `grep -rc` (conteo **por archivo**, formato `archivo:N`) con
  un total real de líneas — sumar esa salida a mano, o peor, usarla
  directo como si ya fuera el total.
- Olvidar `--include='*.log'` y dejar que `logscan` revise cualquier
  archivo del árbol, con falsos positivos de archivos que no son logs.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-logscan-con-pipes-y-regex-reales.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
