# Capa 19 de `toolkit`: el subcomando `harden`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `harden`, con cuatro auditorías de seguridad
que comparten un mismo formato de salida:

- `harden unit ARCHIVO` revisa una unidad de systemd: `User`/`DynamicUser`,
  `NoNewPrivileges`, `ProtectSystem`, `PrivateTmp` y `ProtectHome`.
- `harden ssh ARCHIVO` revisa un `sshd_config`: `PermitRootLogin`,
  `PasswordAuthentication`, `PermitEmptyPasswords` y `X11Forwarding`.
- `harden perms DIRECTORIO [--depth N]` busca archivos setuid, setgid, escribibles
  por todos y directorios escribibles por todos sin bit *sticky*.
- `harden container ARCHIVO` revisa la salida guardada de `docker inspect`:
  `Privileged`, `User`, `ReadonlyRootfs`, `NetworkMode` y puertos publicados.

Cada comprobación imprime `ok NOMBRE` o `riesgo NOMBRE: detalle`, el resumen
acaba en `hallazgos: N`, y `--quiet` oculta los `ok`. Es el primer subcomando de
**auditoría**: no cambia nada, solo mira y avisa.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`, `topcount`,
`sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck`, `netcheck`,
`snapshot`, `healthcheck`, `guard`, `schedule`, `dotfiles` y `backup` siguen
intactos y **vienen completos** en el starter. También vienen hechas `harden_line`
(que imprime cada línea y cuenta los riesgos) y `cmd_harden` (el despachador, que
imprime el resumen y sale con `2` si hubo algún riesgo). Tu trabajo nuevo son los
ocho `TODO`: `harden_parse`, `harden_prepare`, `harden_value`, `harden_check`,
`harden_unit`, `harden_ssh`, `harden_perms` y `harden_container`.

Cómo encaja: la Semana 18 te enseñó a **no perder datos**; esta enseña a **no
regalar acceso**. Audita las unidades que generó `schedule gen` (Semana 16), las
copias que crea `backup` (Semana 18) y los contenedores del propio laboratorio. Lo
que desbloquea: la Semana 20 integra todo el `toolkit` en una entrega, y `harden`
será una de sus piezas de diagnóstico.

Reutiliza patrones ya vistos:

- **Opciones con `case` y `shift`** (Semana 14), con mensajes a `stderr`.
- **Validar antes de actuar** (Semanas 12, 15, 16 y 17): `harden_prepare`.
- **Códigos de salida con significado**: `0` limpio, `1` uso, `2` hay hallazgos.
- **`find` con `-printf '\0'` y `sort -z`** (Semana 09), para nombres con espacios.
- **Expresiones regulares en `[[ =~ ]]`** (Semana 06), con el patrón en una variable.
- **Un solo punto de salida** (`harden_line`), como el contador de `healthcheck`.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. Los subcomandos snapshot, healthcheck, guard, schedule, dotfiles y backup siguen funcionando (regresion de las Semanas 13 a 18)
7. harden unit sobre una unidad sin aislamiento da 5 riesgos y sale con codigo 2
8. harden unit sobre una unidad con User y aislamiento da hallazgos: 0 y sale con codigo 0
9. harden unit toma el ultimo valor cuando una directiva de la unidad se repite
10. harden ssh usa la primera aparicion de una directiva, no la ultima
11. harden ssh marca como riesgo que falte PasswordAuthentication, porque por defecto es yes
12. harden ssh ignora lo que viene despues de una linea Match
13. harden perms clasifica suid, sgid, escribible y dir-sin-sticky, ordenados, y no marca un directorio con sticky
14. harden perms --depth 1 no baja a los subdirectorios y un directorio limpio da hallazgos: 0
15. harden container sobre un contenedor privilegiado, root y con puerto abierto da 5 riesgos y sale con codigo 2
16. harden container acepta un contenedor con usuario, sistema raiz de solo lectura y puerto en 127.0.0.1
17. harden sale con codigo 1 ante un archivo inexistente y ante una opcion desconocida
18. harden --quiet no imprime las lineas ok

## 🎨 Criterios de calidad

- `harden_line` es el **único** sitio que imprime un riesgo y suma `HD_COUNT`;
  ninguna auditoría hace su propio `echo`
- `harden_value` lee con `while IFS= read -r linea || [[ -n "$linea" ]]` y deja
  `nocasematch` **desactivado** al terminar
- Los patrones de `=~` van en variables **sin comillas**
- `harden_perms` usa sustitución de procesos (no una tubería) para no perder
  `HD_COUNT`, y ordena con `LC_ALL=C sort -z`
- Siempre `find -xdev`: nunca se cruza a `/proc` ni a otro sistema de archivos
- El valor **por defecto** cuenta: un `PasswordAuthentication` ausente es un riesgo
- Los errores de uso salen por `stderr` con `1`; los hallazgos, con `2` por `stdout`
- `harden` **no modifica nada**: ni archivos auditados ni permisos
- Nunca se usa `eval`, ni se interpola una ruta sin comillas
- Las variables compartidas son las globales `HD_*`, sin `export`
- Asignación y `local` separados donde se captura una salida (SC2155)
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir a tu propio `harden` (no evaluado esta semana) |
|---|---|
| Administras servidores con `nginx` o `postgres` | Más claves en `harden unit` (`ProtectKernelTunables`, `RestrictAddressFamilies`) según lo que mida `systemd-analyze security` |
| Tienes varios servidores SSH | Una acción `harden ssh --all` que recorra `/etc/ssh/sshd_config.d/*.conf` en el orden en que se leen |
| Usas Docker Compose | Una acción `harden compose` que revise `privileged`, `network_mode` y `ports` de un `docker-compose.yml` |
| Tu equipo exige un informe | Una salida `--format json`, con una línea JSON por comprobación |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de harden en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 19
```

El verificador crea su propia maqueta en `/tmp/wk19`: **no toca** tu home ni
cuentas reales, y no ejecuta `docker` dentro del laboratorio (el contenedor se
audita con una salida de `docker inspect` guardada en un archivo). Las prácticas
[05](../2-practicas/05-harden-a-mano.md) y [06](../2-practicas/06-harden-las-cuatro-auditorias.md)
te guían por los ocho `TODO` uno a uno, con una comprobación tras cada paso.

## 🧯 Errores comunes

- Leer una unidad con «la primera gana» o un `sshd_config` con «la última gana»:
  son formatos opuestos.
- Tratar una directiva ausente como `ok`: en SSH, lo que falta tiene un valor por defecto.
- Seguir leyendo tras una línea `Match`: lo de debajo no es global.
- `find ... | while read` y esperar que `HD_COUNT` sobreviva al subshell.
- Dejar `shopt -s nocasematch` activo: cambia el resto del script.
- Imprimir un riesgo con `echo` en vez de `harden_line`: el contador no lo cuenta.
- `harden perms` sin `-xdev` sobre `/`: recorre `/proc` y tarda minutos.
- Marcar como riesgo un directorio con `1777`: ese es el estado **correcto**.
- Confundir `1` (no pude mirar) con `2` (miré y hay hallazgos).

## 🔗 Navegación

[← Práctica 06](../2-practicas/06-harden-las-cuatro-auditorias.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
