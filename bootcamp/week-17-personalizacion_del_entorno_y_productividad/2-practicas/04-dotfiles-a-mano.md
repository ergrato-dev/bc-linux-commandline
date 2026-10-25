# Práctica 04 — `dotfiles` a mano

> Duración estimada: 120 min · Teoría de apoyo: archivos [03](../1-teoria/03-alias-y-funciones.md) y [08](../1-teoria/08-dotfiles-y-construyendo-dotfiles.md)

Aquí rellenas, **un `TODO` cada vez**, el `dotfiles` del
[`starter/toolkit.sh`](../3-proyecto/starter/toolkit.sh) y, tras cada paso,
compruebas lo añadido. Los `TODO` traen en su comentario **todos** los mensajes
y reglas; aquí van las piezas difíciles. Edita el `starter/` en tu **host** y
llévalo al laboratorio con esta función (desde la raíz del repositorio):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-17-personalizacion_del_entorno_y_productividad/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
docker exec ubuntu-lab apt-get install -y -qq shellcheck >/dev/null
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles status --repo /tmp --home /tmp; echo "codigo: $?"
# TODO: 1
# codigo: 0
```

Es el punto de partida: ejecuta, pero las funciones son marcadores. (Desde el
host usa `/root/bin`, **no** `~/bin`: se expandiría en tu máquina.) Los pasos
2 a 4 se prueban con `source`, sin ejecutar `main`.

Todas las pruebas usan una maqueta que se crea una vez y se rehace cuando se
indica. **Nunca** apuntes `--home` a tu home real mientras pruebas:

```bash
docker exec ubuntu-lab bash -c '
rm -rf /tmp/wk17 && mkdir -p /tmp/wk17/repo /tmp/wk17/home && cd /tmp/wk17
echo a > repo/bashrc; echo b > repo/vimrc; echo r > repo/README.md
mkdir repo/.git repo/sub; ln -s bashrc repo/enlace; echo "x y" > "repo/raro nombre"
ls -A repo'
# .git README.md bashrc enlace raro nombre sub vimrc (uno por linea)
```

De los siete elementos del repositorio **solo dos** deben enlazarse: `bashrc` y
`vimrc`. Los demás tienen cada uno su motivo para quedar fuera.

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae `dotfiles_line` (el formato del informe) y
`cmd_dotfiles` (que reparte entre `status`, `link` y `unlink`): no los
reescribas. Y las ocho funciones se llaman en un orden concreto.

**Comando**: abre `starter/toolkit.sh` en el bloque
`# --- dotfiles (Semana 17)` (hacia la línea 1356) y lee, sin tocar,
`dotfiles_line` y `cmd_dotfiles`.

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-17-personalizacion_del_entorno_y_productividad/3-proyecto/starter/toolkit.sh
# 8
```

## Paso 2: TODO 1 y 2 — `dotfiles_list` y `dotfiles_state`

**Por qué**: la primera decide **qué** se enlaza; la segunda, **en qué estado**
está cada destino. Todo lo demás se apoya en estas dos.

**Comando**: `dotfiles_list` recorre `"$1"/*` (el glob no casa con los ocultos:
`.git` queda fuera solo) y descarta, por este orden, lo que no es un archivo
regular o es un enlace (`-f` es cierto para un enlace a un archivo, por eso hace
falta además `-L`), los nombres `README*`/`LICENSE*` (un `case`) y los que no
casan con `^[A-Za-z0-9][A-Za-z0-9._-]*$`. Guarda solo `${ruta##*/}`.

En `dotfiles_state` el **orden** de las pruebas es lo que importa: `-L` primero
(y dentro, `readlink` contra `"${DOT_REPO}/$1"` decide `ok` o `conflicto-enlace`),
luego `-d`, luego `-e`, y al final `falta`. Un enlace **roto** no pasa `-e`;
preguntando antes por `-e` caería en `falta` y no te avisaría.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
dotfiles_list /tmp/wk17/repo; printf "%s\n" "${DOT_FILES[@]}"
DOT_REPO=/tmp/wk17/repo; DOT_HOME=/tmp/wk17/home
ln -s /tmp/wk17/repo/bashrc /tmp/wk17/home/.bashrc; echo y > /tmp/wk17/home/.vimrc
ln -s /nada /tmp/wk17/home/.zshrc; mkdir /tmp/wk17/home/.sub
for n in bashrc vimrc zshrc sub nuevo; do echo "$n: $(dotfiles_state $n)"; done
rm -rf /tmp/wk17/home/.[a-z]*'
# bashrc
# vimrc
# bashrc: ok
# vimrc: conflicto-archivo
# zshrc: conflicto-enlace
# sub: conflicto-directorio
# nuevo: falta
```

## Paso 3: TODO 3 — `dotfiles_parse`

**Por qué**: las opciones se leen **una vez**, en un sitio, y dejan su resultado
en las globales `DOT_*`. Las incompatibles se rechazan antes de tocar nada.

**Comando**: un `while [[ $# -gt 0 ]]` con un `case`. Los casos que se olvidan:
una opción **sin su valor** (`--repo` al final de la línea) y una opción que no
corresponde a la acción:

```bash
      --repo | --home)
        if [[ $# -lt 2 ]]; then
          echo "toolkit dotfiles ${accion}: $1 necesita un valor" >&2; exit 1
        fi
        ... guarda $2 y haz shift 2 ...
```

Sin el `-lt 2`, `shift 2` falla con un solo argumento y, bajo `set -e`, aborta
con un error opaco en vez de tu mensaje.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
dotfiles_parse link --repo /r --force --dry-run; echo "$DOT_REPO $DOT_HOME $DOT_FORCE $DOT_DRY"'
# /r /root 1 1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; dotfiles_parse status --force'; echo "rc=$?"
# toolkit dotfiles status: --force solo vale para link
# rc=1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; dotfiles_parse link --repo'; echo "rc=$?"
# toolkit dotfiles link: --repo necesita un valor
# rc=1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; dotfiles_parse link --zzz'; echo "rc=$?"
# toolkit dotfiles link: opcion desconocida: --zzz
# rc=1
```

## Paso 4: TODO 4 — `dotfiles_prepare`

**Por qué**: dos validaciones y una normalización. Si el repositorio no existe,
mejor decirlo aquí que dejar que `ln -s` falle a medias. Y las rutas se pasan a
**físicas absolutas** (`pwd -P`): el enlace se escribe y se compara con esa ruta,
y una relativa (`--repo ../dotfiles`) o con un enlace por medio nunca coincidiría.

**Comando**:

```bash
  DOT_REPO=$(cd -- "$DOT_REPO" && pwd -P)
  DOT_HOME=$(cd -- "$DOT_HOME" && pwd -P)
```

Después, `dotfiles_list "$DOT_REPO"` y el error del repositorio vacío. En el
`TODO` están los tres mensajes exactos. Observa que esta función usa
`exit 1`, no `return`: es una validación de **uso**.

**Verifica** (la maqueta ya tiene `repo` con archivos y `vacio` sin ellos):

```bash
entregar
docker exec ubuntu-lab mkdir -p /tmp/wk17/vacio
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles status --repo /tmp/wk17/nada --home /tmp/wk17/home; echo "rc=$?"
# toolkit dotfiles: no existe el repositorio: /tmp/wk17/nada
# rc=1
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles status --repo /tmp/wk17/repo --home /tmp/wk17/nada; echo "rc=$?"
# toolkit dotfiles: no existe el directorio home: /tmp/wk17/nada
# rc=1
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles status --repo /tmp/wk17/vacio --home /tmp/wk17/home; echo "rc=$?"
# toolkit dotfiles: el repositorio no tiene archivos para enlazar: /tmp/wk17/vacio
# rc=1
```

## Paso 5: TODO 5 — `dotfiles_status`

**Por qué**: es la orden que **solo mira**, la que puedes ejecutar sin miedo en
cualquier momento. Su código de salida (`2` si algo falta o choca) la hace útil
en un script.

**Comando**: un `for` sobre `DOT_FILES`; el estado, con la asignación separada
del `local`:

```bash
  estado=$(dotfiles_state "$nombre")
  dotfiles_line "$estado" "$nombre"
  case "$estado" in ok) ... ;; falta) ... ;; *) conflicto=$((conflicto + 1)) ;; esac
```

(`local estado=$(...)` en una sola línea ocultaría el código de salida de la
orden: es el SC2155 de la Semana 15.) Al final, `resumen:` y `exit 2` si
`falta + conflicto > 0`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'rm -rf /tmp/wk17/home && mkdir /tmp/wk17/home'
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles status --repo /tmp/wk17/repo --home /tmp/wk17/home; echo "rc=$?"
# falta      .bashrc
# falta      .vimrc
# resumen: ok=0 falta=2 conflicto=0
# rc=2
docker exec ubuntu-lab bash -c 'ln -s /tmp/wk17/repo/bashrc /tmp/wk17/home/.bashrc; ln -s /tmp/wk17/repo/vimrc /tmp/wk17/home/.vimrc'
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles status --repo /tmp/wk17/repo --home /tmp/wk17/home; echo "rc=$?"
# ok         .bashrc
# ok         .vimrc
# resumen: ok=2 falta=0 conflicto=0
# rc=0
```

## Paso 6: TODO 6 — `dotfiles_link_check`

**Por qué**: la regla de oro de `link` es **validar todo antes de tocar nada**.
Si el tercer archivo de cinco choca, enlazar los dos primeros y fallar deja el
home a medias. Por eso esta función existe aparte y se llama la primera.

**Comando**: recorre `DOT_FILES` y cuenta `problemas`. El caso interesante es
el de un archivo o enlace ajeno **con** `--force`: solo es problema si ya
existe el respaldo (`-e` o `-L`, porque un respaldo puede ser un enlace roto):

```bash
  elif [[ -e "${DOT_HOME}/.${nombre}.toolkit-bak" || -L "${DOT_HOME}/.${nombre}.toolkit-bak" ]]; then
    echo "conflicto  .${nombre} (ya existe .${nombre}.toolkit-bak)" >&2
```

Un directorio es **siempre** problema, con o sin `--force`. Si `problemas > 0`:
el mensaje del `TODO` a `stderr` y `exit 2`.

**Verifica**: como `dotfiles_link` aún no hace nada, esta comprobación solo
llega hasta el error:

```bash
entregar
docker exec ubuntu-lab bash -c 'rm -rf /tmp/wk17/home && mkdir /tmp/wk17/home && echo z > /tmp/wk17/home/.vimrc'
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles link --repo /tmp/wk17/repo --home /tmp/wk17/home; echo "rc=$?"
# conflicto  .vimrc (archivo real)
# toolkit dotfiles link: 1 conflictos; no se ha cambiado nada (--force respalda y reemplaza; anade --dry-run para ver antes el plan)
# rc=2
docker exec ubuntu-lab ls -A /tmp/wk17/home
# .vimrc
```

## Paso 7: TODO 7 — `dotfiles_link`

**Por qué**: la única función que **modifica** el home. Tras `dotfiles_link_check`
ya sabes que nada chocará, así que solo queda hacerlo; y con `--dry-run`, contarlo
sin hacerlo, con las mismas líneas y un prefijo.

**Comando**: el truco para no escribir cada línea dos veces es un `prefijo`
que vale `""` o `"[dry-run] "`, y proteger **solo** el `mv` y el `ln`:

```bash
  if [[ "$DOT_DRY" -eq 0 ]]; then ln -s -- "${DOT_REPO}/${nombre}" "$destino"; fi
```

Las tres ramas por archivo son `ok` (solo informa), `falta` (enlaza) y «otro»
(respalda con `mv --` y enlaza). El resumen lleva el mismo prefijo.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles link --repo /tmp/wk17/repo --home /tmp/wk17/home --dry-run --force; echo "rc=$?"
# [dry-run] enlazado .bashrc -> /tmp/wk17/repo/bashrc
# [dry-run] respaldado .vimrc -> .vimrc.toolkit-bak
# [dry-run] enlazado .vimrc -> /tmp/wk17/repo/vimrc
# [dry-run] enlazados: 2, ya estaban: 0, respaldados: 1
# rc=0
docker exec ubuntu-lab ls -A /tmp/wk17/home
# .vimrc
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles link --repo /tmp/wk17/repo --home /tmp/wk17/home --force; echo "rc=$?"
# enlazado .bashrc -> /tmp/wk17/repo/bashrc
# respaldado .vimrc -> .vimrc.toolkit-bak
# enlazado .vimrc -> /tmp/wk17/repo/vimrc
# enlazados: 2, ya estaban: 0, respaldados: 1
# rc=0
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles link --repo /tmp/wk17/repo --home /tmp/wk17/home
# ya enlazado .bashrc
# ya enlazado .vimrc
# enlazados: 0, ya estaban: 2, respaldados: 0
```

El `--dry-run` no cambió nada (el `ls` sigue mostrando solo `.vimrc`), y la
tercera ejecución es **idempotente**: repetirla no rompe nada.

## Paso 8: TODO 8 — `dotfiles_unlink`

**Por qué**: deshacer es parte del contrato. Un `link --force` que no se puede
revertir da miedo y la gente deja de usarlo.

**Comando**: tres casos según `dotfiles_state`. La pieza delicada es el único
borrado que hace el script: **solo** del estado `ok`, que garantiza que es un
enlace a **este** repositorio:

```bash
      ok) rm -- "$destino"   # si existe .toolkit-bak: mv de vuelta y "restaurado"; si no, "quitado" ;;
```

El resto (`falta` y «otro») solo imprime `omitido` y no toca nada. Un archivo
real que no es tuyo **nunca** se borra.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'echo mio > /tmp/wk17/home/.zz'
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles unlink --repo /tmp/wk17/repo --home /tmp/wk17/home; echo "rc=$?"
# quitado    .bashrc
# restaurado .vimrc
# quitados: 1, restaurados: 1, omitidos: 0
# rc=0
docker exec ubuntu-lab cat /tmp/wk17/home/.vimrc
# z
docker exec ubuntu-lab /root/bin/toolkit.sh dotfiles unlink --repo /tmp/wk17/repo --home /tmp/wk17/home
# omitido    .bashrc (no existe)
# omitido    .vimrc (no es un enlace de este repositorio)
# quitados: 0, restaurados: 0, omitidos: 2
```

El contenido original de `.vimrc` (`z`) volvió, y `.zz` (que no es del
repositorio) ni se mencionó. La segunda ejecución prueba que `unlink` no borra lo
que no es suyo.

## Paso 9: `shellcheck` y una prueba con una shell de verdad

**Por qué**: un `link` correcto no sirve si lo enlazado no funciona. Cierras
con dos comprobaciones: el análisis estático y la prueba real, con una shell
interactiva que arranca desde un `HOME` enlazado.

**Comando**:

```bash
docker exec ubuntu-lab shellcheck /root/bin/toolkit.sh && echo limpio
# limpio
docker exec ubuntu-lab bash -c '
rm -rf /tmp/wk17 && mkdir -p /tmp/wk17/repo /tmp/wk17/home
echo "alias saluda=\"echo hola-desde-el-repo\"" > /tmp/wk17/repo/bashrc
/root/bin/toolkit.sh dotfiles link --repo /tmp/wk17/repo --home /tmp/wk17/home
HOME=/tmp/wk17/home bash -ic "saluda" 2>/dev/null'
# enlazado .bashrc -> /tmp/wk17/repo/bashrc
# enlazados: 1, ya estaban: 0, respaldados: 0
# hola-desde-el-repo
```

El alias vive en el **repositorio**, el `HOME` solo tiene un enlace, y una
shell interactiva (que lee `.bashrc`, ver [teoría 01](../1-teoria/01-como-arranca-bash.md))
lo encuentra. Ese es todo el sistema funcionando.

**Verifica**: con la versión completa instalada, la verificación de la semana:

```bash
./scripts/verificar-semana.sh 17
# ...
# 18/18 comprobaciones superadas.
```

## ✅ Resultado

- [ ] `dotfiles_list` enlaza `bashrc` y `vimrc` y descarta `.git`, `README.md`, el enlace, el directorio y el nombre raro
- [ ] `dotfiles_state` devuelve los cinco estados, preguntando primero por `-L`
- [ ] `dotfiles_parse` rechaza una opción sin valor, una incompatible y una desconocida con `exit 1`
- [ ] `dotfiles_prepare` normaliza con `pwd -P` y rechaza repositorio/home inexistentes y repositorio vacío
- [ ] `status` informa y sale con `2` si algo falta o choca
- [ ] `link` valida todo antes de cambiar nada, respalda con `--force` y enseña el plan con `--dry-run`
- [ ] `link` es idempotente y `unlink` restaura los respaldos sin borrar lo ajeno
- [ ] `shellcheck` en limpio y un alias del repositorio funciona en una shell real

Con las ocho funciones, pasa al [proyecto](../3-proyecto/README.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `dotfiles_list` incluye `enlace` | Falta el `! -L` | `[[ ! -f "$ruta" \|\| -L "$ruta" ]] && continue` |
| Un enlace roto sale como `falta` | Preguntas por `-e` antes que por `-L` | `-L` primero |
| `shift 2` aborta sin mensaje | Falta el `$# -lt 2` | Compruébalo antes del `shift` |
| `ok` nunca sale tras `link` | Comparas con una ruta relativa | `pwd -P` en `dotfiles_prepare` |
| `link` enlaza algunos y falla | `dotfiles_link_check` no se llama primero | Es la primera línea de `dotfiles_link` |
| `--dry-run` cambia el home | `mv` o `ln` sin proteger | Envuélvelos en `if [[ "$DOT_DRY" -eq 0 ]]` |
| SC2155 en `local estado=$(...)` | Asignación y `local` juntos | Sepáralos |
| `unlink` borra un archivo real | Borras fuera del estado `ok` | Un único `rm`, solo en `ok` |

---

[← Práctica 03: autocompletado y `tmux`](03-autocompletado-y-tmux.md) · [Proyecto: `toolkit dotfiles` →](../3-proyecto/README.md)
