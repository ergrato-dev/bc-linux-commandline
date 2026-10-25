# Capa 2 de `toolkit`: el subcomando `inventory`

## 🎯 Objetivo

Agregar a `toolkit.sh` un segundo subcomando, `inventory`, que reporta la
composición de un directorio (archivos regulares, subdirectorios, enlaces
simbólicos) resolviendo siempre la ruta a su forma absoluta, y que puede
filtrar por extensión usando globbing.

## 📦 Qué añade esta capa

El `doctor` de la Semana 01 sigue intacto — esta capa **agrega**, no
reemplaza. `inventory` es el primer subcomando que trabaja con argumentos
posicionales y flags propios (`--ext`), estableciendo el patrón de
despacho de argumentos que vas a reutilizar en cada capa futura: un `while`
que consume `$@` reconociendo flags conocidos y tratando cualquier otra cosa
como el argumento posicional principal.

Esta capa también es la primera vez que `toolkit.sh` **falla con un mensaje
claro** cuando el usuario le da algo inválido (una ruta que no existe) — el
patrón de validación temprano que vas a repetir en cada subcomando nuevo.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. El subcomando `doctor` de la Semana 01 sigue funcionando (regresión)
3. `inventory` corre sin argumentos usando el directorio actual
4. `inventory` muestra la ruta absoluta aunque se le pase una ruta relativa
5. `inventory` cuenta correctamente los archivos regulares de un directorio
6. `inventory` cuenta correctamente los subdirectorios, sin contarse a sí mismo
7. `inventory` cuenta correctamente los enlaces simbólicos
8. `inventory --ext` filtra por extensión usando globbing, sin contar archivos de otra extensión
9. `inventory` sale con código distinto de 0 si la ruta no existe

## 🎨 Criterios de calidad

- Usa `nullglob` (visto en 1-teoria/05) al filtrar por extensión, no
  concatenación de strings que rompería con cero coincidencias
- Resuelve la ruta absoluta con `cd ... && pwd`, no con manipulación manual
  de strings (que falla con `.`, `..` o rutas con `~`)
- Mensajes de error van a `stderr` (`>&2`), no se mezclan con la salida normal
- El conteo de archivos/directorios/enlaces usa `-maxdepth 1` (no recursivo
  — la recursión llega recién en la Semana 09 con `find`)

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `inventory` (no evaluado esta semana) |
|---|---|
| Administras tu propia laptop | Agregar conteo de archivos ocultos por separado |
| Trabajas con muchos proyectos de código | Filtrar por varias extensiones a la vez (`--ext sh,py,md`) |
| Te importa el espacio en disco | Sumar el tamaño total con `du` en vez de solo contar |
| Prefieres salida para otros scripts | Agregar una bandera `--json` que emita el resultado estructurado |

## 🚦 Cómo entregarlo

```bash
# Si sigues desde la Semana 01, extiende tu propio ~/bin/toolkit.sh.
# Si prefieres partir del esqueleto de esta semana (ya trae doctor
# completo mas los TODO de inventory):
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-02-navegacion_y_sistema_de_archivos/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO de cmd_inventory
./scripts/verificar-semana.sh 02
```

## 🧯 Errores comunes

- Olvidar `nullglob` al filtrar por extensión: sin coincidencias, el patrón
  literal queda en el array y rompe el conteo.
- Resolver la ruta absoluta con `$(pwd)/$ruta` en vez de `cd ... && pwd`:
  falla si `$ruta` ya era absoluta, o si contenía `..`.
- No validar que la ruta exista antes de intentar listar su contenido: el
  error de `find`/`ls` resultante es menos claro que uno propio.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-globbing-y-expansion-de-patrones.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
