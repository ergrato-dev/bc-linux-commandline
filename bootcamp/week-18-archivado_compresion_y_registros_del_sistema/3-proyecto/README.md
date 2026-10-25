# Capa 18 de `toolkit`: el subcomando `backup`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `backup`, con cinco acciones sobre copias de
seguridad en `.tar.gz`:

- `backup create ORIGEN` crea `NOMBRE-AAAAMMDD-HHMMSS.tar.gz` y su `.sha256`, con
  `--exclude` (repetible), `--name`, `--dest` y `--dry-run`.
- `backup verify ARCHIVO` comprueba la suma y que `tar` pueda leer el archivo.
- `backup list` enseña las copias con su tamaño y cuántas hay.
- `backup restore ARCHIVO --to DIR` verifica, rechaza rutas peligrosas y extrae
  **solo** en un directorio vacío.
- `backup prune --name N --keep K` conserva las K últimas de una serie y borra el
  resto, con `--dry-run` para ver el plan.

Es el primer subcomando cuyo trabajo es **no perder datos**: se diseña alrededor
de escribir de forma atómica, comprobar antes de confiar y no pisar nada.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`, `topcount`,
`sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck`, `netcheck`,
`snapshot`, `healthcheck`, `guard`, `schedule` y `dotfiles` siguen intactos y
**vienen completos** en el starter. También vienen hechas `backup_archives` (que
sabe cómo se llama una copia y las devuelve ordenadas) y `cmd_backup` (el
despachador de las cinco acciones). Tu trabajo nuevo son los ocho `TODO`:
`backup_parse`, `backup_prepare`, `backup_safe_members`, `backup_create`,
`backup_verify`, `backup_list`, `backup_restore` y `backup_prune`.

Cómo encaja: la Semana 17 te enseñó a llevar tu entorno de una máquina a otra y a
respaldar antes de reemplazar; esta semana convierte esa idea en una herramienta.
Lo que desbloquea: la Semana 19 inspecciona servicios con `systemctl`, entre ellos
el que dispara tu copia, y la Semana 20 integra todo el `toolkit` en una entrega.

Reutiliza patrones ya vistos:

- **Escritura atómica con `mktemp` y `mv`** (Semana 15): `backup_create`.
- **Validar antes de actuar** (Semanas 12, 15, 16 y 17): `backup_prepare`.
- **Códigos de salida con significado**: `0`, `1` (uso) y `2` (copia no fiable).
- **Opciones con `case` y `shift`** de la Semana 14, con mensajes a `stderr`.
- **Ver el plan antes de ejecutarlo**: `--dry-run`, como en `dotfiles`.
- **Programarlo con `schedule gen` y `guard`** (Semana 16).

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. Los subcomandos snapshot, healthcheck, guard, schedule y dotfiles siguen funcionando (regresion de las Semanas 13 a 17)
7. backup create crea el .tar.gz y su .sha256 en el directorio de copias
8. backup create --exclude deja fuera del archivo lo que casa con el patron
9. backup create --dry-run anuncia el archivo y no escribe nada
10. backup create sale con codigo 1 si el origen no existe
11. backup create rechaza con codigo 1 un nombre que intenta salir del directorio de copias
12. backup verify da ok sobre una copia buena y sale con codigo 2 cuando el archivo ha cambiado
13. backup list muestra cada copia con su tamano y termina con copias: N
14. backup restore devuelve un directorio identico al origen
15. backup restore sale con codigo 1 si el destino ya tiene contenido y no lo toca
16. backup restore sale con codigo 2 ante un archivo con rutas ..  y no escribe fuera del destino
17. backup prune --keep 2 borra las copias mas antiguas de la serie y deja las dos ultimas con sus sumas
18. backup prune --dry-run ensena lo que borraria y no borra nada

## 🎨 Criterios de calidad

- `backup_create` escribe en un temporal de `mktemp` y **renombra** al final: un
  corte nunca deja un `.tar.gz` a medias con nombre de copia buena
- La suma se calcula **desde el directorio** de las copias, con el nombre sin ruta
- El nombre pasa una regex anclada **antes** de construir ninguna ruta
- `backup_safe_members` lee el listado con sustitución de procesos (no con una
  tubería, que se tragaría el `exit`) y se ejecuta **antes** de extraer
- `restore` verifica, comprueba rutas y solo entonces extrae, con `--no-same-owner`
- `prune` borra únicamente la serie indicada y su `.sha256`, nunca otra serie
- `--dry-run` imprime las mismas líneas que la ejecución real, con prefijo, y no
  crea ni borra nada
- Los errores de uso salen por `stderr` con `1`; una copia no fiable, con `2`
- Nunca se usa `tar -P`, ni `eval`, ni se registra una ruta sin comillas
- Las variables compartidas son las globales `BK_*`, sin `export`
- Asignación y `local` separados donde se captura una salida (SC2155)
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir a tu propio `backup` (no evaluado esta semana) |
|---|---|
| Quieres copias más pequeñas | Una opción `--compress xz` (con `tar -cJf`) y el nombre `.tar.xz` |
| Copias enormes que cambian poco | `--listed-incremental` de GNU `tar` con un archivo `.snar` por serie |
| Quieres sacarlas de la máquina | Una acción `backup push` que copie el par con `scp` o `rsync` a un servidor |
| Tus datos son sensibles | Cifrar el `.tar.gz` con `gpg` o `age` antes de calcular la suma |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-18-archivado_compresion_y_registros_del_sistema/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de backup en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 18
```

El verificador crea su propia maqueta en `/tmp/wk18`: **no toca** tu home ni tus
copias reales. La [práctica 04](../2-practicas/04-backup-a-mano.md) te guía por los
ocho `TODO` uno a uno, con una comprobación tras cada paso.

## 🧯 Errores comunes

- Crear el archivo directamente con su nombre final: un corte lo deja a medias.
- Calcular la suma con una ruta absoluta: solo se puede comprobar en esa máquina.
- Validar el nombre después de construir la ruta: `--name ../x` escribe fuera.
- Usar `tar -tzf | while read` y esperar que el `exit` salga de la función.
- `restore` que extrae antes de comprobar las rutas, o sobre un directorio con contenido.
- `prune` que no filtra por serie y borra copias de otra cosa.
- `--dry-run` que llama a `mktemp`, `tar` o `rm`.
- Guardar el destino de las copias dentro del propio origen: la copia se incluye a sí misma.
- Copias legibles por todos: contienen lo mismo que el original.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-backup-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
