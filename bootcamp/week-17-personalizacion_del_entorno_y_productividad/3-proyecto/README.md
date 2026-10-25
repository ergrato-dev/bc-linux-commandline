# Capa 17 de `toolkit`: el subcomando `dotfiles`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `dotfiles`, con tres acciones sobre un
repositorio de configuración (`bashrc`, `vimrc`, `tmux.conf`…, **sin** el punto):

- `dotfiles status` **compara** el repositorio con tu home y dice, archivo a
  archivo, si está enlazado, falta o choca con algo que ya existe.
- `dotfiles link` **enlaza** cada archivo como `~/.NOMBRE`, con `--force` para
  respaldar lo que había (`.toolkit-bak`) y `--dry-run` para ver el plan.
- `dotfiles unlink` **deshace**: quita solo los enlaces propios y restaura los
  respaldos.

Es el primer subcomando que **modifica tu home**, así que todo se diseña en torno
a una idea: validar antes de cambiar nada y poder volver atrás.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`, `topcount`,
`sumfield`, `finddupes`, `procwatch`, `acctaudit`, `pkgcheck`, `netcheck`,
`snapshot`, `healthcheck`, `guard` y `schedule` siguen intactos y **vienen
completos** en el starter. También vienen hechas `dotfiles_line` (el formato del
informe) y `cmd_dotfiles` (el despachador de `status`/`link`/`unlink`). Tu
trabajo nuevo son los ocho `TODO`: `dotfiles_list`, `dotfiles_state`,
`dotfiles_parse`, `dotfiles_prepare`, `dotfiles_status`, `dotfiles_link_check`,
`dotfiles_link` y `dotfiles_unlink`.

Cómo encaja: la Semana 16 te enseñó a programar tareas; esta semana te enseña a
llevar **tu entorno** (y el de `toolkit`, con su autocompletado) a cualquier
máquina. Lo que desbloquea: la Semana 18 trata el archivado y los registros, donde
respaldar antes de reemplazar vuelve a ser la regla.

Reutiliza patrones ya vistos:

- **Validar antes de actuar** (Semanas 12, 15 y 16): `dotfiles_link_check`.
- **Códigos de salida con significado**: `0`, `1` (uso) y `2` (estado a corregir).
- **Opciones con `case` y `shift`** de la Semana 14, con mensajes a `stderr`.
- **Ver el plan antes de ejecutarlo**: `organize` no mueve nada sin `--apply`; aquí es `--dry-run`.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. shellcheck no reporta ningun hallazgo sobre toolkit.sh
3. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
4. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
5. Los subcomandos acctaudit, pkgcheck y netcheck siguen funcionando (regresion de las Semanas 11 y 12)
6. Los subcomandos snapshot, healthcheck, guard y schedule siguen funcionando (regresion de las Semanas 13 a 16)
7. dotfiles status cuenta 2 archivos que faltan e ignora el README y los ocultos del repositorio
8. dotfiles status sale con codigo 2 cuando falta algun enlace
9. dotfiles sale con codigo 1 si el repositorio no existe
10. dotfiles link crea ~/.bashrc y ~/.vimrc como enlaces simbolicos al repositorio
11. dotfiles link ejecutado dos veces no cambia nada la segunda
12. dotfiles status informa ok=2 y sale con codigo 0 cuando todo esta enlazado
13. dotfiles link sale con codigo 2 si ya hay un archivo real y no se pide --force
14. Con un conflicto, dotfiles link no crea ningun enlace ni modifica el archivo real
15. dotfiles link --force guarda el original como .toolkit-bak y enlaza
16. dotfiles link --dry-run no crea ningun enlace
17. dotfiles unlink quita los enlaces y restaura el archivo original guardado
18. dotfiles unlink no borra un archivo real que no es un enlace del repositorio

## 🎨 Criterios de calidad

- `dotfiles_link_check` se ejecuta **antes** de cualquier `mv` o `ln`: un conflicto
  no deja el home a medias
- `dotfiles_state` pregunta primero por `-L`, y compara el destino del enlace con
  la ruta **física** del repositorio (`pwd -P`)
- Un directorio no se reemplaza nunca, ni con `--force`; un respaldo existente no
  se pisa
- `unlink` borra **solo** lo que `dotfiles_state` marca `ok`
- `--dry-run` imprime las mismas líneas que la ejecución real, con prefijo, y no
  llama a `mv` ni a `ln`
- Los errores de uso salen por `stderr` con `1`; los conflictos, con `2`
- Las variables compartidas son las globales `DOT_*`, sin `export` ni `eval`
- Ningún nombre del repositorio acaba en `~/.algo` sin pasar la regex anclada
- Asignación y `local` separados donde se captura una salida (SC2155)
- `shellcheck` limpio sobre el script completo, **sin** `disable` injustificados
- No tocas los subcomandos anteriores

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías añadir a tu propio `dotfiles` (no evaluado esta semana) |
|---|---|
| Quieres subcarpetas (`config/nvim/init.lua`) | Que `dotfiles_list` baje un nivel y cree los directorios padre con `mkdir -p` |
| Compartes el repositorio entre máquinas | Archivos `NOMBRE.local` que `status` ignore y que tu `bashrc` cargue si existen |
| Prefieres enlaces relativos (como `stow`) | Calcular la ruta relativa con `realpath --relative-to` al crear el enlace |
| Quieres instalar el autocompletado de `toolkit.sh` | Un `dotfiles install-completion` que copie el archivo a `~/.local/share/bash-completion/completions/` |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-17-personalizacion_del_entorno_y_productividad/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO 1 a 8 de dotfiles en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
docker exec ubuntu-lab apt-get install -y shellcheck   # si aun no lo instalaste
./scripts/verificar-semana.sh 17
```

El verificador crea su propia maqueta en `/tmp/wk17`: **no toca** tu home. La
[práctica 04](../2-practicas/04-dotfiles-a-mano.md) te guía por los ocho `TODO`
uno a uno, con una comprobación tras cada paso.

## 🧯 Errores comunes

- Preguntar por `-e` antes que por `-L`: un enlace roto parece «falta».
- Comparar el destino del enlace con una ruta relativa: `ok` nunca sale.
- Enlazar algunos archivos y fallar con el siguiente: valida **todo** primero.
- `shift 2` con una opción sin valor: aborta con un error opaco en vez de tu
  mensaje.
- `--dry-run` que ejecuta el `mv` y solo protege el `ln`.
- Borrar en `unlink` lo que no es un enlace al repositorio: es el único borrado
  del script, y solo en el estado `ok`.
- Dejar que el glob enlace `README.md`, `LICENSE` o un enlace simbólico del repositorio.
- Meter tokens o claves en el repositorio de dotfiles: acaban en un servicio público.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-dotfiles-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
