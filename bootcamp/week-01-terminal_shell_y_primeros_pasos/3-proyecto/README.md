# Capa 1 de `toolkit`: el entrypoint y `doctor`

## 🎯 Objetivo

Crear el esqueleto de `toolkit.sh`: el único punto de entrada que vas a
extender durante veinte semanas, con un primer subcomando (`doctor`) que
reporta el estado básico del entorno donde corre.

## 📦 Qué añade esta capa

Esta es la primera capa, así que no hay nada previo que mantener — pero sí
hay un contrato que las próximas diecinueve capas van a respetar: **un solo
archivo ejecutable, con subcomandos**, no un script nuevo por semana. Lo que
armas acá (el patrón `case "$1" in ... esac` para despachar subcomandos) es
la estructura que la Semana 10 extiende con `sys-snapshot`, la Semana 16
refactoriza en un entrypoint más robusto, y la Semana 20 pule para entrega
final.

`doctor` es deliberadamente simple: reporta versión de bash, distro, y
distingue builtins de externos para un par de comandos — exactamente los
conceptos de esta semana, verificables de forma automática.

## ✅ Requisitos verificables

(Copiados literal de `checks.json` — si tu entrega no cumple la descripción
exacta, `verificar-semana.sh` te va a decir cuál.)

1. `toolkit.sh` existe y es ejecutable
2. `toolkit.sh` arranca con shebang `env bash` y `set -euo pipefail`
3. `toolkit.sh doctor` reporta la versión de bash en uso
4. `toolkit.sh doctor` reporta la distro vía `/etc/os-release`
5. `toolkit.sh doctor` sale con código distinto de 0 si `$HOME` no está definido
6. `~/bin` está en el `$PATH` del usuario
7. `~/.bashrc` fija `HISTSIZE` y `HISTFILESIZE` por encima del valor por defecto
8. El alias `ll` está definido en `~/.bashrc`
9. `toolkit.sh doctor --tipos` distingue `cd` (builtin) de otros comandos

## 🎨 Criterios de calidad

Lo que el autograding no mide, pero sí la rúbrica manual:

- Mensajes de `doctor` legibles, no solo variables sueltas sin contexto
- Nombres de variable y función en inglés, `snake_case`, como marca `CLAUDE.md`
- Comentarios que expliquen **por qué**, no que repitan qué hace la línea

## 💡 Adaptación a tu dominio

`toolkit` opera siempre sobre tu propia máquina, pero el subcomando `doctor`
puede priorizar distinto según tu contexto:

| Tu situación | Qué agregar primero a `doctor` (opcional, no evaluado esta semana) |
|---|---|
| Administras tu propia laptop | Espacio en disco, batería si es notebook |
| Vas a usar esto en servidores remotos | Uptime, carga del sistema |
| Te interesa la seguridad | Última actualización de paquetes instalada |
| Programas además de administrar | Versión de lenguajes instalados (`python3 --version`, etc.) |

No es obligatorio esta semana — es solo para que empieces a pensar en qué
dirección vas a llevar tu `toolkit` cuando, desde la Semana 17, el proyecto
empiece a dar lugar a elegir subcomandos propios.

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-01-terminal_shell_y_primeros_pasos/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO del archivo
./scripts/verificar-semana.sh 01
```

## 🧯 Errores comunes

- Olvidar `chmod +x` después de copiar el starter — `verificar-semana.sh`
  falla en el primer check con un mensaje claro.
- Dejar un `TODO` sin completar que hace que `doctor` imprima vacío en vez de
  la información esperada — revisar la salida con tus propios ojos antes de
  correr el autograding, no solo confiar en que "no tiró error".

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-builtins-externos-y-tu-path.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
