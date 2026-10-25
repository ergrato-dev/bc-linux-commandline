# Capa 11 de `toolkit`: los subcomandos `acctaudit` y `pkgcheck`

## 🎯 Objetivo

Añadir a `toolkit.sh` dos subcomandos que contestan las dos preguntas de
administración de esta semana: `acctaudit`, que audita las cuentas de un
directorio tipo `/etc` (UID 0 extra, cuentas de sistema con shell,
UID duplicados, grupos primarios inexistentes), y `pkgcheck`, que dice si un
paquete está instalado y en qué versión usando el gestor de la máquina.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield`, `finddupes` y `procwatch` siguen intactos (y
`procwatch` ya viene **completo** en el starter de esta semana: lo
terminaste en la Semana 10). Esta capa continúa la Fase 3 del bootcamp
(Semanas 09-12): `finddupes` miró el sistema de archivos, `procwatch` la
tabla de procesos, y ahora `acctaudit` y `pkgcheck` miran **quién** hay en
la máquina y **qué** hay instalado. La Semana 12 añadirá la última pieza,
la red, y juntas las capas 10-12 forman el `sys-snapshot` del hilo conductor.

Esta capa reutiliza, de forma explícita, varios patrones ya vistos:

- **Tres códigos de salida con significado** (`0` limpio, `1` entrada
  inválida, `2` hallazgo): el mismo patrón de toda la fase.
- **`grep -c . || true`** para contar una variable que puede estar vacía
  (Semanas 07-10), aquí aplicado a los hallazgos.
- **`awk` con varios archivos** (Semana 08, `NR == FNR`), extendido a tres
  archivos con `FILENAME`.
- **Un directorio como argumento** para poder probar sin tocar el sistema
  real: el mismo principio de dry-run de `organize` (Semana 03).

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
3. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
4. acctaudit sale con codigo 1 si el directorio no tiene passwd, group y shells
5. acctaudit cuenta las cuentas regulares (UID 1000-60000) de un directorio de prueba
6. acctaudit informa sin hallazgos y sale con 0 en cuentas limpias, sync incluida (su shell /bin/sync no figura en shells)
7. acctaudit detecta una segunda cuenta con UID 0
8. acctaudit detecta una cuenta de sistema con una shell de login valida
9. acctaudit detecta dos cuentas que comparten el mismo UID
10. acctaudit detecta una cuenta cuyo grupo primario no existe en group
11. acctaudit sale con codigo 2 si encuentra al menos un hallazgo
12. pkgcheck sale con codigo 1 si no se le pasa ningun paquete
13. pkgcheck identifica el gestor de paquetes de la maquina (apt en ubuntu-lab)
14. pkgcheck reporta como instalado un paquete que sabemos que lo esta (bash)
15. pkgcheck imprime la version instalada del paquete
16. pkgcheck sale con codigo 2 si el paquete no esta instalado

## 🎨 Criterios de calidad

- `acctaudit` recibe el directorio como argumento y usa `/etc` solo como
  valor por defecto: así se prueba con directorios falsos, sin crear
  cuentas peligrosas de verdad
- La regla de "cuenta de sistema con shell" compara contra `/etc/shells`,
  no contra la palabra `nologin`, para no marcar a `sync`
- `pkgcheck` decide "instalado" por el **estado** del paquete (`installed`),
  no por la existencia de una versión: un paquete `rc` no está instalado
- `pkgcheck` detecta el gestor con `command -v`, no por el nombre de la
  distro, y se queda en la capa baja (`dpkg-query`, `rpm`, `pacman -Q`)
- Cada conteo de una variable posiblemente vacía va protegido con
  `grep -c . || true`
- `shellcheck` limpio sobre el script completo

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `acctaudit`/`pkgcheck` (no evaluado esta semana) |
|---|---|
| Administras servidores con varios administradores | Agregar una regla que liste quién pertenece a `sudo`/`wheel` y marque a quien no esté en una lista autorizada |
| Te preocupa la caducidad de contraseñas | Leer `shadow` (como `root`) y reportar cuentas con contraseña vacía o sin caducidad (`chage -l`) |
| Gestionas muchas máquinas | Hacer que `pkgcheck` acepte varios paquetes y devuelva `2` si **alguno** falta |
| Automatizas despliegues | Agregar a `pkgcheck` un modo `--version-minima` que compare versiones con `sort -V` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO de cmd_acctaudit y cmd_pkgcheck en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
./scripts/verificar-semana.sh 11
```

## 🧯 Errores comunes

- Contar las cuentas regulares con `UID >= 1000` sin el límite superior:
  `nobody` (65534) se contaría como persona.
- Usar `NR == FNR` con **tres** archivos: solo es cierto durante el primero;
  los otros dos se tratarían como si fueran `passwd`. Se compara `FILENAME`.
- Decidir "instalado" por la versión que devuelve `dpkg-query`: un paquete
  quitado con `remove` (`rc`) la conserva y `pkgcheck` mentiría.
- Guardar la salida de `rpm -q` sin mirar su código de salida: el mensaje
  `package X is not installed` sale por stdout y se tomaría por una versión.
- Olvidar el `|| true` tras el `grep -c .` que cuenta hallazgos: con cero
  hallazgos, `set -e` corta el script antes de imprimir `sin hallazgos`.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-acctaudit-y-pkgcheck-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
