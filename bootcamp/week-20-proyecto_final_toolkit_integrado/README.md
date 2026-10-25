# Semana 20 — Proyecto final: toolkit integrado

> Veinte semanas de piezas sueltas se juntan en una sola herramienta que otra persona puede instalar, comprobar y quitar.
> Esta semana empaquetas el `toolkit` como `.deb`, lo verificas con sumas y lo haces probarse a sí mismo.

## 🎯 Objetivos de la Semana

- Explicar qué hay dentro de un `.deb` (`debian-binary`, `control.tar`, `data.tar`) e inspeccionarlo sin instalarlo con `dpkg-deb`
- Construir un paquete a mano con `dpkg-deb --build --root-owner-group` y reconocer sus dos fallos clásicos
- Escribir un `control` válido y aplicar el versionado `MAYOR.MENOR.PARCHE`, comparando versiones como lo hace `dpkg`
- Instalar, actualizar, degradar, verificar y quitar un paquete con `dpkg`, y explicar lo que `dpkg --verify` sí y no detecta
- Escribir y comprobar una página de manual en `roff` con `groff`, y documentar los códigos de salida
- Publicar un archivo de forma atómica (temporal + `mv`) y mantener un `SHA256SUMS` sin duplicados
- Escribir un arnés de pruebas por código de salida, con casos negativos, subprocesos aislados y una maqueta temporal
- Construir `version`, `release build`, `release verify` y `selftest`
- Repasar las veinte capas y saber dónde acaba este bootcamp y adónde ir después

## 📋 Prerrequisitos

Semana 19 completada: `toolkit.sh` con `harden` funcionando y `shellcheck`
instalado en `ubuntu-lab`. Semana 18 (`sha256sum`, `tar` y `backup`, cuyo ciclo
ida y vuelta probará `selftest`), Semana 15 (`trap`, temporales con `mktemp`,
códigos de salida y validar antes de actuar), Semana 14 (funciones, `case` y
`shift`), Semana 11 (`dpkg`, `apt` y la consulta de paquetes), Semana 09 (`find
-print0`, `sort -z` y `xargs -0`), Semana 06 (expresiones regulares) y Semana 04
(permisos y modos).

Todo ocurre dentro de `ubuntu-lab` (más `rhel-lab` para comprobar un caso de
divergencia). **Instalarás y quitarás un paquete de verdad**, pero solo dentro del
contenedor desechable: no lo hagas en tu máquina principal.

## 🗂️ Estructura de la Semana

```
week-20-proyecto_final_toolkit_integrado/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: paquetes, control y versión, dpkg, documentación, pruebas, construcción y repaso
├── 2-practicas/           # 6 prácticas: 4 de exploración y 2 para construir release y selftest
├── 3-proyecto/            # Capa 20 de toolkit: version, release y selftest
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, cada uno para algo que la prosa cuenta mal: **la anatomía de un
`.deb`** (un archivo `ar` con tres miembros y las órdenes de `dpkg-deb` que leen
cada uno) y **el `toolkit` en veinte capas** (qué añadió cada fase y dónde encaja
la de esta semana). El resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-empaquetar-una-herramienta.md) | Empaquetar una herramienta: el `.deb` por dentro | 20 min |
| [02](1-teoria/02-control-version-y-numeracion.md) | Control, versión y numeración | 20 min |
| [03](1-teoria/03-instalar-verificar-y-quitar.md) | Instalar, verificar y quitar | 20 min |
| [04](1-teoria/04-documentar-una-herramienta.md) | Documentar una herramienta | 20 min |
| [05](1-teoria/05-probar-una-herramienta.md) | Probar una herramienta | 25 min |
| [06](1-teoria/06-construir-release-y-selftest.md) | Construir `release` y `selftest` | 25 min |
| [07](1-teoria/07-repaso-y-siguientes-pasos.md) | Repaso y siguientes pasos | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-un-deb-por-dentro.md) | Montar un árbol, escribir el `control`, construir con `dpkg-deb`, abrirlo sin instalar y provocar sus dos fallos | 60 min |
| [02](2-practicas/02-manual-version-y-documentacion.md) | `version`, generar y comprobar la página de manual con `groff`, `gzip -n`, comparar versiones y validar el formato | 60 min |
| [03](2-practicas/03-instalar-verificar-y-quitar.md) | Instalar, consultar, verificar, manipular, actualizar, degradar y quitar `toolkit` con `dpkg` y `apt` | 60 min |
| [04](2-practicas/04-probar-con-selftest.md) | Un arnés de pruebas por código de salida: casos negativos, subproceso, `trap`, `shellcheck` y `PS4` | 60 min |
| [05](2-practicas/05-release-a-mano.md) | Rellenar los `TODO` 1 a 4: `release_parse`, `release_prepare`, `release_stage` y `release_build` | 60 min |
| [06](2-practicas/06-verify-y-selftest-a-mano.md) | Rellenar los `TODO` 5 a 8: `release_verify`, `selftest_case`, la maqueta y `cmd_selftest`, con `shellcheck` al final | 60 min |

Y la vigésima capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— `version` imprime la versión; `release build` crea `toolkit_V_all.deb` con su
`SHA256SUMS`; `release verify` comprueba seis cosas del paquete y sale con `2` si
alguna falla; `selftest` ejecuta cinco casos sobre capas anteriores y sale con `2`
si alguno falla.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 30 min |
| Prácticas (6 archivos) | 6 h |
| Proyecto: Capa 20 de `toolkit` | 40 min |
| Rúbrica de conocimiento (10 preguntas) | 40 min |
| Repaso, glosario y recursos | 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `dpkg-deb -R paquete.deb carpeta` extrae **todo**, incluida la parte de control en
  `carpeta/DEBIAN/`, con la forma exacta que acepta `dpkg-deb --build`. Es la manera
  más rápida de corregir un paquete: editas `DEBIAN/control`, ajustas permisos y lo
  reconstruyes, sin repetir el árbol entero.
- `dpkg-deb --ctrl-tarfile p.deb | tar -xO ./control` imprime **un archivo** de la
  parte de control por la salida estándar sin extraer nada a disco (`-O` es «a
  stdout»). Cámbialo por `--fsys-tarfile` para leer un archivo instalable.
- `apt-get -s install ./p.deb` **simula** la instalación: lista las líneas `Inst` y
  `Conf` de lo que haría (incluidas las dependencias que traería) y no toca el
  sistema. `-s` es lo primero que se prueba con un paquete ajeno.
- `readlink -f "${BASH_SOURCE[0]}"` da la ruta **real** de un script aunque lo
  llamen por un enlace simbólico o desde otro directorio (`$0` solo diría
  `./enlace`). Es lo que permite a `toolkit` empaquetarse a sí mismo. Y
  `[[ "${BASH_SOURCE[0]}" == "$0" ]]` distingue «ejecutado» de «cargado con `source`»:
  la guarda que deja probar las funciones sin lanzar el programa.
- `install -D -m 0755 origen /destino/usr/bin/toolkit` crea también los directorios
  intermedios que falten, así que ahorra el `mkdir -p` previo. Los crea con modo 755
  aunque el `umask` sea más estricto.

## 📌 Entregables

1. `~/bin/toolkit.sh` con `version`, `release` y `selftest` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los veinte subcomandos de semanas anteriores (`doctor`, `inventory`, `organize`,
   `audit`, `logreport`, `logscan`, `topcount`, `sumfield`, `finddupes`,
   `procwatch`, `acctaudit`, `pkgcheck`, `netcheck`, `snapshot`, `healthcheck`,
   `guard`, `schedule`, `dotfiles`, `backup` y `harden`) siguen funcionando sin
   regresiones, y `shellcheck ~/bin/toolkit.sh` sale limpio
3. Un paquete `toolkit_1.0.0_all.deb` con su `SHA256SUMS`, construido con
   `toolkit release build` y con `release verify` en `fallos: 0`
4. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 20
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 19](../week-19-systemd_seguridad_y_contenedores_desde_cli/README.md) | Semana 20 | Fin del bootcamp |

[← Volver al índice del bootcamp](../README.md)
