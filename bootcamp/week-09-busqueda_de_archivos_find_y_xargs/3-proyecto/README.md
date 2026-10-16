# Capa 9 de `toolkit`: el subcomando `finddupes`

## 🎯 Objetivo

Agregar a `toolkit.sh` un noveno subcomando, `finddupes`, que encuentra
archivos con contenido idéntico en un árbol de directorios, calculando
un hash por archivo de forma segura ante nombres de archivo raros y
árboles vacíos.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount` y `sumfield` siguen intactos. `finddupes` abre la Fase 3 del
bootcamp (Semanas 09-12, sistema y procesos): es la primera capa que
recorre árboles de archivos combinando `find` y `xargs` directamente,
en vez de usar `grep -r` (Semana 06) para texto o `cut`/`sort`/`uniq`/`awk`
(Semanas 07-08) para columnas.

Esta capa reutiliza, de forma explícita, dos patrones ya vistos:

- **Tres códigos de salida con significado** (`0` sin duplicados, `1`
  directorio inválido, `2` duplicados encontrados) — el mismo patrón de
  todas las capas anteriores.
- **`sort | uniq -d` y `awk -v` para agrupar** (Semanas 07 y 08): en vez
  de contar frecuencias o sumar un campo, agrupan hashes para encontrar
  cuáles se repiten.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`, `topcount` y `sumfield` siguen funcionando (regresión)
3. `finddupes` cuenta correctamente los archivos analizados, recursivo
4. `finddupes` detecta un grupo de archivos con el mismo contenido
5. `finddupes` sale con código `2` si encuentra archivos duplicados
6. `finddupes` sale con código `0` si ningún archivo está duplicado
7. `finddupes` sale con código `0` y cero archivos si el directorio está vacío
8. `finddupes` sale con código `1` si el directorio no existe
9. `finddupes` filtra por la extensión pasada con `--ext`

## 🎨 Criterios de calidad

- Usa `find -print0` y `xargs -r0`, nunca `find | xargs` sin protección
  — ni ante nombres con espacios, ni ante un directorio vacío
- Agrupa hashes con `sort | uniq -d`, no con una estructura de datos
  reconstruida a mano
- Protege cada conteo con `grep -c . || true`, consistente con el
  mismo gotcha de `set -e` ya visto en semanas anteriores
- Distingue claramente "directorio inválido" (código `1`) de
  "duplicados encontrados" (código `2`)

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `finddupes` (no evaluado esta semana) |
|---|---|
| Tienes discos con muchos archivos grandes | Filtrar primero por tamaño (`find -size`) antes de hashear, para no leer contenido de archivos con tamaño único |
| Te importa la velocidad en árboles grandes | Agregar `-P` a `xargs` para calcular hashes en paralelo |
| Quieres limpiar duplicados, no solo encontrarlos | Agregar un modo `--apply` que borre todas las copias de un grupo salvo la primera, con la misma disciplina de dry-run por defecto que `organize` |
| Trabajas con fotos o videos | Filtrar por extensión (`--ext jpg`, `--ext mp4`) para no perder tiempo hasheando archivos que no interesan |

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-09-busqueda_de_archivos_find_y_xargs/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO de cmd_finddupes
./scripts/verificar-semana.sh 09
```

## 🧯 Errores comunes

- Omitir `-r` en `xargs -r0 sha256sum`: un directorio vacío (o filtrado
  a cero resultados por `--ext`) hace que `sha256sum` corra con cero
  argumentos, leyendo de stdin y devolviendo un hash falso con `-` como
  nombre de archivo.
- Omitir `-print0`/`-0`: un archivo con espacio en el nombre se parte
  en varios argumentos falsos para `sha256sum`.
- Usar `wc -l` en vez de `grep -c .` para contar líneas de una variable
  que puede estar vacía — `wc -l` sobre una cadena vacía todavía cuenta
  `1` línea fantasma.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-finddupes-con-pipes-reales.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
