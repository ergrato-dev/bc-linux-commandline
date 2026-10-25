# Semana 11 — Usuarios, grupos y gestión de paquetes

> Cada archivo, cada proceso y cada paquete que instalas pertenece a
> alguien o viene de alguien. Esta semana aprendes a leer quién es quién
> en una máquina Linux, a dar privilegios sin regalar `root`, y a instalar
> software sabiendo de dónde viene.

## 🎯 Objetivos de la Semana

- Leer `/etc/passwd`, `/etc/shadow` y `/etc/group` campo por campo, y explicar por qué el kernel solo mira el UID
- Crear, modificar, bloquear y dar de baja usuarios y grupos sin dejar archivos huérfanos ni borrar grupos por accidente
- Dar privilegios con `sudo` aplicando el mínimo privilegio, con reglas validadas por `visudo`
- Operar `apt`, `dnf` y `pacman` con el mismo modelo mental, y consultar qué paquete es dueño de un archivo
- Explicar la cadena de confianza de un repositorio (clave, firma del índice, hash del paquete)

## 📋 Prerrequisitos

Semana 10 completada: `toolkit.sh procwatch` funcionando, comodidad con el
patrón `grep -c . || true` para contar una variable que puede estar vacía
(esta semana lo reutiliza para contar hallazgos). Semana 04 (permisos,
SGID, `umask`) para el directorio compartido del archivo 02, Semana 08
(`awk`, `NR == FNR`) y Semana 09 (`sha256sum`) para el análisis de cuentas y
la verificación de paquetes.

## 🗂️ Estructura de la Semana

```
week-11-usuarios_grupos_y_gestion_de_paquetes/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 7 archivos: cuentas, usuarios/grupos, sudo, gestor, apt/dnf/pacman, repositorios, capstone
├── 2-practicas/           # 4 practicas sobre los cuatro contenedores del laboratorio
├── 3-proyecto/            # Capa 11 de toolkit: subcomandos acctaudit y pkgcheck
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

Dos diagramas, no más: la anatomía de una línea de `/etc/passwd` (siete
campos que apuntan a otros tres archivos) y las capas de un gestor de
paquetes (dos capas en Debian/RHEL, una en Arch) son estructuras que
cuestan descifrar en prosa. El resto (`sudo`, ciclos de `apt`, firmas) se
explica mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-usuarios-uid-y-los-archivos-de-cuentas.md) | Usuarios, UID y los archivos de cuentas | 20 min |
| [02](1-teoria/02-crear-y-modificar-usuarios-y-grupos.md) | Crear y modificar usuarios y grupos | 20 min |
| [03](1-teoria/03-sudo-su-y-minimo-privilegio.md) | sudo, su y mínimo privilegio | 20 min |
| [04](1-teoria/04-que-es-un-gestor-de-paquetes.md) | Qué es un gestor de paquetes | 25 min |
| [05](1-teoria/05-apt-dnf-y-pacman-lado-a-lado.md) | apt, dnf y pacman lado a lado | 25 min |
| [06](1-teoria/06-repositorios-firmas-y-confianza.md) | Repositorios, firmas y confianza | 20 min |
| [07](1-teoria/07-construyendo-acctaudit-y-pkgcheck.md) | Construyendo acctaudit y pkgcheck | 20 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|---|
| [01](2-practicas/01-usuarios-y-grupos-reales.md) | Crear usuarios, reproducir la trampa de `usermod -G`, localizar un home huérfano, probar un directorio SGID | 45 min |
| [02](2-practicas/02-sudo-con-criterio.md) | Validar una regla con `visudo`, comprobar lo permitido y lo prohibido, comparar `sudo`/`wheel` entre familias | 45 min |
| [03](2-practicas/03-paquetes-en-cuatro-familias.md) | Instalar, consultar y quitar con `apt`, `dnf` y `pacman`; simular `autoremove`; verificar firma y hash | 45 min |
| [04](2-practicas/04-acctaudit-y-pkgcheck-a-mano.md) | Construir a mano la lógica completa que después completas en el starter | 45 min |

Y la undécima capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— los subcomandos `acctaudit` (audita cuentas: UID 0 extra, cuentas de
sistema con shell, UID duplicados, grupos inexistentes) y `pkgcheck` (dice
si un paquete está instalado, con el gestor de la máquina).

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (7 archivos) | 2 h 30 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 11 de `toolkit` | 2 h 20 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `su -s /bin/bash www-data -c id` ejecuta algo como una cuenta de
  servicio **con shell `nologin`**: `-s` fuerza una shell para esa orden,
  sin tocar `/etc/passwd`. Sin `-s`, `su www-data -c id` solo imprime
  `This account is currently not available.`
- `dpkg-query -W -f='${Installed-Size}\t${Package}\n' | sort -rn | head -3`
  lista los paquetes que más espacio ocupan (en KiB), sin parsear
  `dpkg -l`: el formato lo eliges tú con `-f`.
- `passwd -Sa | awk '$2 == "L"'` lista de golpe todas las cuentas con la
  contraseña bloqueada; `passwd -Sa` sola da el estado de **todas**.
- `getent passwd 1000` busca por **UID numérico** (y `getent group 27` por
  GID): la forma de traducir el número que ves en `ls -n` a un nombre.

## 📌 Entregables

1. `~/bin/toolkit.sh` con los subcomandos `acctaudit` y `pkgcheck`
   funcionando según los requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`,
   `logreport`, `logscan`, `topcount`, `sumfield`, `finddupes` y
   `procwatch` de semanas anteriores siguen funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 11
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 10](../week-10-gestion_de_procesos_y_senales/README.md) | Semana 11 | [Semana 12 →](../week-12-redes_desde_la_linea_de_comandos/README.md) |

[← Volver al índice del bootcamp](../README.md)
