# Semana 19 — Inspección de systemd, seguridad básica y contenedores desde la CLI

> Llegas a una máquina que no conoces: ¿qué corre, con qué permisos, y qué puerta ha quedado abierta?
> Esta semana lees el estado de los servicios con `systemctl`, das a cada cuenta solo lo que necesita, endureces SSH y las unidades, y miras un contenedor como lo que es: un proceso.

## 🎯 Objetivos de la Semana

- Leer `systemctl status` y usar `is-active`, `is-enabled`, `is-failed` y `show -p` en scripts, conociendo sus códigos de salida
- Escribir una unidad con `[Unit]`, `[Service]` e `[Install]`, y comprobarla con `systemd-analyze verify` distinguiendo errores de avisos
- Medir un arranque con `systemd-analyze` (`blame` frente a `critical-chain`) y leer el diario por unidad y por arranque
- Conceder un comando con `sudo` en lugar de una shell de root, y comprobar las reglas con `visudo -cf`
- Encontrar archivos setuid y setgid, y directorios escribibles por todos sin bit *sticky*
- Endurecer una unidad con un *drop-in* y medirlo con `systemd-analyze security --offline`
- Leer la configuración efectiva de SSH con `sshd -T` sabiendo que la primera aparición gana
- Listar, inspeccionar y leer los registros de un contenedor con `docker`, y explicar qué es en términos de *namespaces* y *cgroups*
- Lanzar un contenedor endurecido y publicado solo en `127.0.0.1`
- Construir `harden`: cuatro auditorías con una salida común, un contador de hallazgos y códigos `0`/`1`/`2`

## 📋 Prerrequisitos

Semana 18 completada: `toolkit.sh` con `backup` funcionando y `shellcheck`
instalado en `ubuntu-lab`. Semana 16 (`schedule gen`, cuyas unidades auditarás),
Semana 15 (códigos de salida y validar antes de actuar), Semana 14 (funciones,
`case` y `shift`), Semana 11 (usuarios, grupos y `sudo`), Semana 10 (procesos,
señales y zombis), Semana 09 (`find`, `-printf` con `\0` y `sort -z`), Semana 06
(expresiones regulares) y Semana 04 (permisos).

Para las prácticas 01 y 04 necesitas además **tu propia máquina**: la 01 requiere
systemd en marcha (el laboratorio no lo tiene) y la 04 requiere `docker` en el
anfitrión.

## 🗂️ Estructura de la Semana

```
week-19-systemd_seguridad_y_contenedores_desde_cli/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 8 archivos: systemd, systemctl, unidades, arranque, permisos, endurecimiento, contenedores y harden
├── 2-practicas/           # 6 prácticas: 4 en ubuntu-lab y el anfitrión, 2 para construir harden
├── 3-proyecto/            # Capa 19 de toolkit: subcomando harden
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Dos diagramas, cada uno para algo que la prosa cuenta mal: **dónde vive una
unidad y quién gana** (`/etc` sobre `/run` sobre `/usr/lib`, y los *drop-ins*) y
**un contenedor como proceso del anfitrión** (la misma tarea vista desde dentro y
desde fuera). El resto se enseña mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-systemd-unidades-y-rutas.md) | systemd: unidades, rutas y precedencia | 20 min |
| [02](1-teoria/02-systemctl-inspeccionar-servicios.md) | Inspeccionar servicios con `systemctl` | 20 min |
| [03](1-teoria/03-escribir-y-verificar-una-unidad.md) | Escribir y verificar una unidad | 20 min |
| [04](1-teoria/04-arranque-rendimiento-y-registros.md) | Arranque, rendimiento y registros de una unidad | 20 min |
| [05](1-teoria/05-menor-privilegio-y-permisos.md) | Menor privilegio y permisos peligrosos | 20 min |
| [06](1-teoria/06-endurecer-unidades-y-ssh.md) | Endurecer unidades y SSH | 25 min |
| [07](1-teoria/07-contenedores-desde-la-cli.md) | Contenedores desde la CLI | 15 min |
| [08](1-teoria/08-seguridad-de-contenedores-y-harden.md) | Seguridad de contenedores y diseño de `harden` | 10 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-inspeccionar-systemd.md) | `status`, `is-*`, `show -p`, `list-*`, `blame`, `critical-chain` y `journalctl -u`, en una máquina con systemd | 60 min |
| [02](2-practicas/02-unidades-y-endurecimiento.md) | Escribir y verificar una unidad, un temporizador, medir la exposición, endurecer con un *drop-in* y activar con `--root` | 60 min |
| [03](2-practicas/03-seguridad-basica-y-ssh.md) | Una regla de `sudo` mínima con `visudo -cf`, setuid/setgid, directorios sin sticky, `umask` y SSH con `sshd -T` | 60 min |
| [04](2-practicas/04-contenedores-desde-el-anfitrion.md) | `docker ps/top/stats/logs/exec/inspect/diff`, *namespaces* y un contenedor endurecido en `127.0.0.1` | 60 min |
| [05](2-practicas/05-harden-a-mano.md) | Rellenar los `TODO` 1 a 4 de `harden`: argumentos, validación, lectura de valores y comprobaciones | 60 min |
| [06](2-practicas/06-harden-las-cuatro-auditorias.md) | Rellenar los `TODO` 5 a 8: `unit`, `ssh`, `perms` y `container`, con `shellcheck` al final | 60 min |

Y la decimonovena capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `harden`: `unit`, `ssh`, `perms` y `container` imprimen `ok` o
`riesgo` por cada comprobación y un `hallazgos: N` final; salen con `0` (limpio),
`1` (uso incorrecto) o `2` (hay hallazgos), y `--quiet` oculta los `ok`.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 30 min |
| Prácticas (6 archivos) | 6 h |
| Proyecto: Capa 19 de `toolkit` | 40 min |
| Rúbrica de conocimiento (10 preguntas) | 40 min |
| Repaso, glosario y recursos | 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `find /usr/bin -xdev -type f -perm /6000` encuentra setuid **o** setgid en una
  sola pasada: el `/` delante del modo significa «cualquiera de estos bits». Con
  `-6000` (guion) exigiría los dos a la vez y no saldría casi nada.
- `diff <(sshd -T | sort) <(sshd -T -f otro.conf | sort)` compara la configuración
  **efectiva** de SSH antes y después de un cambio: ves exactamente qué valores
  cambian (`passwordauthentication yes` → `no`) y nada más, sin releer el archivo.
- `docker inspect -f '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}
  (rw={{.RW}}){{"\n"}}{{end}}' NOMBRE` lista los montajes de un contenedor con su
  modo de escritura: el riesgo que `harden container` no mira.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `harden` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`, `logreport`,
   `logscan`, `topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit`,
   `pkgcheck`, `netcheck`, `snapshot`, `healthcheck`, `guard`, `schedule`,
   `dotfiles` y `backup` de semanas anteriores siguen funcionando sin
   regresiones, y `shellcheck ~/bin/toolkit.sh` sale limpio
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 19
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 18](../week-18-archivado_compresion_y_registros_del_sistema/README.md) | Semana 19 | [Semana 20 →](../week-20-proyecto_final_toolkit_integrado/README.md) |

[← Volver al índice del bootcamp](../README.md)
