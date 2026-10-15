# Semana 01 — Terminal, shell y primeros pasos

> Antes de memorizar comandos, entiende quién los ejecuta: la terminal, el
> shell y el kernel son tres cosas distintas, y confundirlas te va a costar
> horas de diagnóstico más adelante.

## 🎯 Objetivos de la Semana

- Distinguir emulador de terminal, TTY/PTY, shell y kernel
- Leer tu propio prompt y explicar cada parte de `$PS1`
- Diferenciar comandos builtin de externos y razonar sobre `$PATH`
- Usar `man`, `--help` y `apropos` para resolver dudas sin depender de internet
- Dominar historial y atajos de edición de línea en vez de backspace y flechas

## 📋 Prerrequisitos

Ninguno — esta es la primera semana del bootcamp. Solo necesitas tener
levantado el laboratorio: [`docs/setup-entorno.md`](../../docs/setup-entorno.md).

## 🗂️ Estructura de la Semana

```
week-01-terminal_shell_y_primeros_pasos/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 6 archivos: TTY, shell, prompt, PATH, ayuda, historial
├── 2-practicas/           # 4 practicas sobre ubuntu-lab
├── 3-proyecto/            # Capa 1 de toolkit: entrypoint + doctor
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-terminal-consola-y-tty.md) | Terminal, consola y TTY | 25 min |
| [02](1-teoria/02-el-shell-bash-como-interprete.md) | El shell: bash como intérprete | 25 min |
| [03](1-teoria/03-anatomia-del-prompt.md) | Anatomía del prompt | 20 min |
| [04](1-teoria/04-builtins-externos-y-path.md) | Builtins, externos y `$PATH` | 25 min |
| [05](1-teoria/05-obtener-ayuda-man-help-info.md) | Obtener ayuda: man, --help, info | 20 min |
| [06](1-teoria/06-historial-y-edicion-de-linea.md) | Historial y edición de línea | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-primer-contacto-con-ubuntu-lab.md) | Entrar al laboratorio, configurar prompt, historial y tu primer alias | 55 min |
| [02](2-practicas/02-navegar-la-ayuda-y-el-manual.md) | Resolver ambigüedades de `man` y encontrar comandos por descripción | 40 min |
| [03](2-practicas/03-dominar-historial-y-atajos.md) | `Ctrl+R`, `!!`, `!$` y atajos de edición de línea | 40 min |
| [04](2-practicas/04-builtins-externos-y-tu-path.md) | Tu primer script en `~/bin`, agregado al `$PATH` | 55 min |

Y la primera capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el entrypoint del proyecto y su primer subcomando, `doctor`.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (6 archivos) | 2 h 15 min |
| Prácticas (4 archivos) | 3 h 10 min |
| Proyecto: Capa 1 de `toolkit` | 2 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 5 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `type -a comando` muestra **todas** las coincidencias de un nombre (alias,
  función, builtin, archivo), no solo la que gana — útil para ver qué está
  tapando a qué.
- `hash -r` fuerza a bash a olvidar rutas memorizadas y volver a buscar en
  `$PATH` — el arreglo real detrás de "lo instalé pero dice que no existe".
- `man -k .` (un punto como patrón) lista todas las páginas de manual
  instaladas en el sistema — una forma de "explorar" cuando no sabes qué
  buscar.
- `Ctrl+X Ctrl+E` abre el comando que estás escribiendo en tu editor
  (`$EDITOR`) — mejor que editar carácter por carácter para comandos largos.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `doctor` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. `~/.bashrc` con prompt que muestra el código de salida, historial
   ampliado, `histappend` y el alias `ll`
3. `~/bin` agregado de forma persistente a tu `$PATH`
4. Las 10 preguntas de conocimiento respondidas con tus propias palabras
   (no hace falta entregarlas por separado — se evalúan en la revisión)

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 01
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| — | Semana 01 | [Semana 02 →](../week-02-navegacion_y_sistema_de_archivos/README.md) |

[← Volver al índice del bootcamp](../README.md)
