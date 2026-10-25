# Semana 12 — Redes desde la línea de comandos

> "No funciona" no es un diagnóstico. Esta semana aprendes a localizar el
> fallo de red capa por capa (interfaz, ruta, DNS, puerto, aplicación) con
> los comandos que existen en cualquier Linux, y a entrar a otra máquina por SSH con claves.

## 🎯 Objetivos de la Semana

- Leer interfaces, direcciones y rutas con `ip` y directamente desde `/sys` y `/proc`
- Distinguir `getent` (lo que ve tu programa) de `dig` (lo que dice el DNS)
- Listar qué escucha en la máquina con `ss` y probar un puerto remoto, distinguiendo *refused* de *timeout*
- Usar los códigos de salida de `curl` para saber en qué capa falló
- Entrar por SSH con claves, resolver un aviso de huella cambiada y abrir un túnel
- Construir `netcheck`, un diagnóstico por capas con código de salida

## 📋 Prerrequisitos

Semana 11 completada: `toolkit.sh acctaudit` y `pkgcheck` funcionando, y
`apt` para instalar las herramientas de red que la imagen mínima no trae.
Semana 10 (el patrón de tres códigos de salida `0`/`1`/`2`), Semana 05 (códigos de salida y `||`) y Semana 08 (`awk` para
extraer columnas de `/proc/net/route`). Semana 04 (modos `600`/`700`) para
las claves SSH.

## 🗂️ Estructura de la Semana

```
week-12-redes_desde_la_linea_de_comandos/
├── 0-assets/              # 3 diagramas SVG
├── 1-teoria/              # 8 archivos: interfaces, rutas, DNS, puertos, curl, diagnóstico, SSH, netcheck
├── 2-practicas/           # 4 prácticas sobre los cuatro contenedores del laboratorio
├── 3-proyecto/            # Capa 12 de toolkit: subcomando netcheck
├── 4-recursos/            # ebooks, video y webgrafía
└── 5-glosario/            # Términos de esta semana
```

Tres diagramas, uno por idea que cuesta descifrar en prosa: las cinco capas
del diagnóstico y qué comando contesta cada una; los dos caminos distintos
para resolver un nombre (`getent` frente a `dig`); y la confianza de SSH
en **dos** direcciones (huellas en `known_hosts`, claves en
`authorized_keys`). El resto se explica mejor con comandos y su salida real.

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-interfaces-y-direcciones-ip.md) | Interfaces y direcciones IP | 20 min |
| [02](1-teoria/02-rutas-y-puerta-de-enlace.md) | Rutas y puerta de enlace | 20 min |
| [03](1-teoria/03-dns-desde-la-linea-de-comandos.md) | DNS desde la línea de comandos | 25 min |
| [04](1-teoria/04-puertos-sockets-y-ss.md) | Puertos, sockets y `ss` | 25 min |
| [05](1-teoria/05-curl-y-http-desde-la-cli.md) | `curl` y HTTP desde la CLI | 25 min |
| [06](1-teoria/06-diagnostico-por-capas.md) | Diagnóstico por capas | 20 min |
| [07](1-teoria/07-ssh-claves-config-y-scp.md) | SSH: claves, config y `scp` | 30 min |
| [08](1-teoria/08-construyendo-netcheck.md) | Construyendo `netcheck` | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-interfaces-rutas-y-puertos.md) | Leer interfaces y rutas, decodificar el gateway a mano, demostrar `127.0.0.1` frente a `0.0.0.0` | 45 min |
| [02](2-practicas/02-dns-y-curl-contra-el-laboratorio.md) | Comparar `getent` y `dig`, provocar cada código de salida de `curl` y diagnosticar un servidor apagado | 45 min |
| [03](2-practicas/03-ssh-entre-contenedores.md) | Montar SSH con claves entre dos contenedores, provocar un aviso de huella cambiada y abrir un túnel | 45 min |
| [04](2-practicas/04-netcheck-a-mano.md) | Construir a mano las cuatro capas de `netcheck` y su código de salida | 45 min |

Y la duodécima capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `netcheck`, que prueba interfaz, ruta por defecto, DNS y
puerto TCP hacia un destino y sale con `0` o `2`.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 3 h 10 min |
| Prácticas (4 archivos) | 3 h |
| Proyecto: Capa 12 de `toolkit` | 1 h 40 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 10 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `getent -s dns hosts nombre` consulta **solo** la fuente `dns` de NSS, y
  `getent -s files hosts nombre` solo `/etc/hosts`: separa "es mi archivo
  local" de "es el DNS" sin salir de `getent`.
- `ss -tni state established` añade por conexión los contadores internos
  de TCP (`rtt`, `cwnd`, `mss`): el tiempo de ida y vuelta real de una
  conexión viva, sin `ping`.
- `ssh -J servidor-intermedio usuario@destino` salta por un servidor
  intermedio con una sola orden (*ProxyJump*): llega a una máquina que solo
  se ve desde el intermedio.
- `ssh -o ControlMaster=auto -o ControlPath=/tmp/cm-%r@%h:%p -o ControlPersist=30 host`
  reutiliza **una** conexión para las siguientes: tres `ssh` seguidos
  tardaron 0,56 s sin ella y 0,21 s con ella en el laboratorio.
- `sed -i` falla sobre `/etc/hosts` dentro de un contenedor (`Device or
  resource busy`) porque Docker lo monta como archivo: se escribe **dentro**
  con `>>` o `cat >`, y se restaura con `cp`.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `netcheck` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory`, `organize`, `audit`,
   `logreport`, `logscan`, `topcount`, `sumfield`, `finddupes`,
   `procwatch`, `acctaudit` y `pkgcheck` de semanas anteriores siguen
   funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 12
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 11](../week-11-usuarios_grupos_y_gestion_de_paquetes/README.md) | Semana 12 | [Semana 13 →](../week-13-fundamentos_de_bash_scripting/README.md) |

[← Volver al índice del bootcamp](../README.md)
