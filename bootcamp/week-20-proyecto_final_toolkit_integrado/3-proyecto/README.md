# Capa 20 de `toolkit`: `version`, `release` y `selftest`

## 🎯 Objetivo

Cerrar el `toolkit` con tres piezas que lo convierten en una herramienta
**entregable**:

- `version [--short]` imprime `toolkit 1.0.0` (o solo `1.0.0`).
- `release build --out DIR [--version V] [--dry-run]` construye
  `DIR/toolkit_V_all.deb` y anota su suma en `DIR/SHA256SUMS`.
- `release verify ARCHIVO [--quiet]` comprueba seis cosas del paquete (suma,
  paquete, versión, ejecutable, manual y permisos) y sale con `2` si alguna falla.
- `selftest [--quiet]` ejecuta cinco casos de humo sobre capas anteriores
  (`audit`, `logscan`, `backup`, `harden` y `schedule`) y sale con `2` si alguno falla.

Es la primera capa que **no analiza el sistema, sino al propio `toolkit`**: lo
empaqueta, lo comprueba y se prueba a sí mismo.

## 📦 Qué añade esta capa

Los veinte subcomandos anteriores siguen intactos y **vienen completos** en el
starter. También vienen hechas `cmd_version`, `release_line` (que imprime cada
chequeo de `verify` y cuenta los fallos), `release_manpage` (la página de manual
en `roff`), `cmd_release` (el despachador) y `selftest_backup`. Tu trabajo nuevo
son los ocho `TODO`: `release_parse`, `release_prepare`, `release_stage`,
`release_build`, `release_verify`, `selftest_case`, `selftest_fixture` y
`cmd_selftest`.

Cómo encaja: la Semana 19 te enseñó a **no regalar acceso**; esta te enseña a
**entregar con garantías**. `selftest` prueba cinco capas anteriores
(`audit`, `logscan`, `backup`, `harden` y `schedule`), y `release` empaqueta
todo lo anterior. No desbloquea ninguna semana siguiente: es el cierre del
bootcamp. Lo que sí te deja es una herramienta que puedes instalar en otra máquina.

Reutiliza patrones ya vistos:

- **Opciones con `case` y `shift`** (Semana 14), con mensajes a `stderr`.
- **Validar antes de actuar** (Semanas 12, 15, 16, 17 y 19): `release_prepare`.
- **Temporal + `mv` y `trap` de limpieza** (Semanas 15 y 18), para no dejar un `.deb` a medias.
- **`find -print0 | sort -z | xargs -0`** (Semana 09), para el `md5sums` del paquete.
- **Sumas de verificación** (Semana 18): `sha256sum` y `sha256sum -c`.
- **Códigos de salida con significado**: `0` bien, `1` uso, `2` hay fallos.
- **Subproceso aislado y `|| rc=$?`** (Semana 15), el corazón de `selftest_case`.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. Los subcomandos snapshot, healthcheck, guard, schedule, dotfiles, backup y harden siguen funcionando (regresion de las Semanas 13 a 19)
7. version imprime toolkit 1.0.0 y con --short solo el numero
8. release build crea el .deb con Package y Version correctos y su linea en SHA256SUMS
9. release build imprime paquete: RUTA y sha256: con la suma real del archivo
10. El .deb lleva toolkit ejecutable 755, la pagina de manual comprimida y nada escribible por grupo u otros
11. El toolkit extraido del .deb se ejecuta y declara la version del paquete, no la del script original
12. release build rechaza con codigo 1 una version que no es MAYOR.MENOR.PARCHE y no crea nada
13. release build --dry-run anuncia el paquete y no escribe nada
14. release verify da seis ok y fallos: 0 sobre un paquete recien construido
15. release verify sale con 2 y marca falla suma cuando el .deb ha cambiado despues de construirlo
16. release sale con codigo 1 sin --out, ante una opcion desconocida y ante un paquete inexistente
17. selftest sale con 0, imprime cinco ok y pruebas: 5, fallos: 0; con --quiet solo el resumen
18. selftest_case marca falla con el codigo esperado y el obtenido cuando no coinciden, y cuenta el fallo

## 🎨 Criterios de calidad

- `release_line` es el **único** sitio que imprime un chequeo de `verify` y suma `RL_COUNT`
- El `.deb` se escribe en un temporal **dentro de `--out`** y se publica con `mv`
- `trap … EXIT` limpia los temporales, y `trap - EXIT` los suelta tras el éxito
- `SHA256SUMS` guarda una línea por paquete y no duplica al reconstruir
- La versión se estampa **solo** en la copia del paquete: tu script no cambia
- Los patrones de `=~` van en variables **sin comillas**
- `--dry-run` no crea ni borra nada, ni siquiera un directorio temporal
- Todo error de uso sale por `stderr` con `1`, y el prefijo es siempre `toolkit release ACCION: `
- `selftest_case` ejecuta cada caso en un subproceso y nunca oculta un fallo
- `selftest` lanza los casos con `"$TK_SELF"` (proceso aparte), no llamando a funciones
- La maqueta de `selftest` es un `mktemp -d` borrado con `trap`
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir (no evaluado esta semana) |
|---|---|
| Distribuyes a equipos con RHEL o Fedora | Una acción `release build --format rpm` con un `.spec` mínimo y `rpmbuild` |
| Quieres publicar fuera de tu máquina | Firmar `SHA256SUMS` con `gpg --detach-sign` y verificar la firma en `release verify` |
| Tu herramienta crece mucho | Más casos en `selftest` (uno por subcomando) y un `--filter PATRON` |
| Trabajas con integración continua | `selftest --quiet` como paso previo y `release build` como artefacto |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de release y selftest en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 20
```

El verificador crea su propia maqueta en `/tmp/wk20`: **no toca** tu home ni
instala nada en el sistema (extrae el `.deb` con `dpkg-deb -x`, no con
`dpkg -i`). Las prácticas [05](../2-practicas/05-release-a-mano.md) y
[06](../2-practicas/06-verify-y-selftest-a-mano.md) te guían por los ocho `TODO`
uno a uno, con una comprobación tras cada paso.

Para entregar de verdad, además del autograding: construye tu paquete final
(`toolkit release build --out dist`), comprueba que `toolkit release verify`
da `fallos: 0`, e instálalo **dentro del laboratorio** para ver la herramienta
funcionando como un usuario la encontraría.

## 🧯 Errores comunes

- Dejar `mktemp -d` con permisos `0700` como raíz del paquete: `dpkg-deb` lo rechaza.
- Escribir la versión del paquete pero no estamparla: el programa instalado miente.
- Calcular la suma con la ruta completa: `sha256sum -c` no encontrará el archivo.
- Usar `grep -v` con la versión como patrón al reescribir `SHA256SUMS`: el punto es un comodín.
- Poner el temporal en `/tmp` y mover a otro disco: `mv` deja de ser atómico.
- Olvidar `trap - EXIT` y borrar el resultado bueno.
- Quitar la captura `|| rc=$?` en `selftest_case`: el primer caso negativo mata la autoprueba.
- Fiarte de `groff -z -ww` o de `dpkg --verify` por su código de salida: avisan por la salida.
- Confundir `1` (uso incorrecto) con `2` (el chequeo encontró un fallo).

## 🔗 Navegación

[← Práctica 06: `verify` y `selftest` a mano](../2-practicas/06-verify-y-selftest-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
