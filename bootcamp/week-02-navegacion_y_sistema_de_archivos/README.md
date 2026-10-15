# Semana 02 — Navegación y sistema de archivos

> Moverte por un sistema Linux sin GUI empieza acá: rutas, el mapa del FHS,
> cómo leer `ls`, qué tipo de archivo es cada cosa, y globbing.

## 🎯 Objetivos de la Semana

- Navegar con rutas absolutas y relativas sin confundirte de directorio
- Explicar el FHS y ubicar configuración, datos variables y software instalado
- Leer una línea de `ls -l` completa, columna por columna
- Distinguir enlaces simbólicos de enlaces duros, y usar `file`/`stat` sin adivinar
- Construir patrones de globbing con precisión, sin tratarlos como regex

## 📋 Prerrequisitos

Semana 01 completada: prompt con código de salida visible, `~/bin` en tu
`$PATH`, `toolkit.sh` con el subcomando `doctor` funcionando.

## 🗂️ Estructura de la Semana

```
week-02-navegacion_y_sistema_de_archivos/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 6 archivos: rutas, FHS, ls, tipos de archivo, globbing, pushd/popd
├── 2-practicas/           # 4 practicas sobre ubuntu-lab (+ comparacion con rhel-lab/arch-lab)
├── 3-proyecto/            # Capa 2 de toolkit: subcomando inventory
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-rutas-absolutas-y-relativas.md) | Rutas absolutas y relativas | 20 min |
| [02](1-teoria/02-el-estandar-fhs.md) | El estándar FHS: qué vive dónde | 25 min |
| [03](1-teoria/03-listar-e-interpretar-ls.md) | Listar e interpretar `ls` | 20 min |
| [04](1-teoria/04-tipos-de-archivo-y-enlaces.md) | Tipos de archivo y enlaces | 25 min |
| [05](1-teoria/05-globbing-y-expansion-de-patrones.md) | Globbing y expansión de patrones | 25 min |
| [06](1-teoria/06-navegacion-eficiente-pushd-popd-cdpath.md) | Navegación eficiente: pushd, popd, CDPATH | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-rutas-absolutas-y-relativas.md) | Navegar `ubuntu-lab` con rutas absolutas, relativas y atajos | 45 min |
| [02](2-practicas/02-explorando-el-fhs.md) | Explorar el FHS real y compararlo entre `ubuntu-lab`, `rhel-lab` y `arch-lab` | 45 min |
| [03](2-practicas/03-tipos-de-archivo-y-enlaces.md) | Leer `ls -l`, crear enlaces simbólicos y duros | 50 min |
| [04](2-practicas/04-globbing-y-expansion-de-patrones.md) | Construir y previsualizar patrones de globbing | 50 min |

Y la segunda capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `inventory`, que cuenta archivos por tipo y filtra por
extensión.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (6 archivos) | 2 h 15 min |
| Prácticas (4 archivos) | 3 h 10 min |
| Proyecto: Capa 2 de `toolkit` | 2 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 5 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `cd -` alterna entre los dos últimos directorios sin escribir ninguna ruta.
- `readlink -f ruta` resuelve cualquier cadena de enlaces simbólicos hasta el
  destino final real.
- `cp archivo{,.bak}` respalda un archivo en un solo comando, usando
  expansión de llaves.
- `dircolors --print-database` vuelca la paleta completa que interpreta
  `LS_COLORS`, por si un color inesperado te genera dudas.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `inventory` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. El subcomando `doctor` de la Semana 01 sigue funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 02
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 01](../week-01-terminal_shell_y_primeros_pasos/README.md) | Semana 02 | [Semana 03 →](../week-03-manipulacion_de_archivos_y_directorios/README.md) |

[← Volver al índice del bootcamp](../README.md)
