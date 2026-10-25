# Práctica 05 — `harden` a mano (1/2): entrada y valores

> Duración estimada: 60 min · Teoría de apoyo: archivos [06](../1-teoria/06-endurecer-unidades-y-ssh.md) y [08](../1-teoria/08-seguridad-de-contenedores-y-harden.md)

Aquí rellenas los `TODO` 1 a 4 (la entrada y la lectura de valores) del `harden` del
[`starter/toolkit.sh`](../3-proyecto/starter/toolkit.sh) y, tras cada paso,
compruebas lo añadido. Los `TODO` traen en su comentario **todos** los mensajes
y reglas; aquí van las piezas difíciles. Edita el `starter/` en tu **host** y
llévalo al laboratorio con esta función (desde la raíz del repositorio):

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
docker exec ubuntu-lab apt-get install -y -qq shellcheck >/dev/null
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh harden unit /etc/hostname; echo "codigo: $?"
# hallazgos: 0
# codigo: 0
```

Es el punto de partida: las funciones son marcadores, y por eso un archivo con
mil riesgos sale limpio. (Desde el host, `/root/bin`, **no** `~/bin`.) Los pasos
2 a 5 se prueban con `source`, sin ejecutar `main`.

Las pruebas usan una maqueta que se rehace desde cero (solo borra bajo `/tmp/wk19`):

```bash
docker exec ubuntu-lab bash -c '
rm -rf /tmp/wk19 && mkdir -p /tmp/wk19/p/sub /tmp/wk19/p/tmpd /tmp/wk19/clean && cd /tmp/wk19
printf "[Service]\nExecStart=/usr/bin/sleep 100\n" > bad.service
printf "[Service]\nUser=svc\nNoNewPrivileges=yes\nProtectSystem=strict\nPrivateTmp=yes\nProtectHome=yes\n" > good.service
printf "[Service]\nUser=root\nUser=svc\nPrivateTmp=no\nPrivateTmp=yes\n" > last.service
printf "PermitRootLogin yes\nPasswordAuthentication no\nPermitRootLogin no\nMatch User bob\n PermitEmptyPasswords yes\n" > a.conf
: > e.conf'
```

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae `harden_line` (la única función que imprime y
cuenta riesgos) y `cmd_harden` (que reparte entre las cuatro acciones, imprime el
resumen y sale con `2` si hubo algún riesgo). Y cada `TODO` trae sus mensajes
exactos: no los inventes.

**Comando**: abre `starter/toolkit.sh` en el bloque `# --- harden (Semana 19)` y
lee, sin tocar, `harden_line` y `cmd_harden`. Fíjate en que **nadie más** hace
`echo` de un riesgo.

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/3-proyecto/starter/toolkit.sh
# 8
```

## Paso 2: TODO 1 — `harden_parse`

**Por qué**: cada acción admite **solo** unas opciones. `--depth` solo tiene sentido
en `perms`; aceptarlo en `unit` haría creer a alguien que limita algo. Los errores
de uso salen **aquí**, antes de que otra función toque el disco.

**Comando**: un `while [[ $# -gt 0 ]]` con un `case`. La pieza delicada es `--depth`:
debe existir su valor, y la acción debe ser `perms`.

```bash
      --depth)
        if [[ "$HD_ACTION" != perms ]]; then
          echo "toolkit harden ${HD_ACTION}: opcion desconocida: $1" >&2
          exit 1
        fi
        if [[ $# -lt 2 ]]; then
          echo "toolkit harden ${HD_ACTION}: --depth necesita un valor" >&2
          exit 1
        fi
        HD_DEPTH=$2
        shift 2
        ;;
```

La validación numérica va **al final del bucle**, no al leer el valor: así
`--depth` puede venir antes o después del posicional. Un `--depth 0` pasa
`^[0-9]+$` pero no es válido: por eso hay que comparar también con `0`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
harden_parse perms /d --depth 2 --quiet
echo "$HD_ACTION $HD_POS $HD_DEPTH $HD_QUIET"'
# perms /d 2 1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; harden_parse unit --depth 2'; echo "rc=$?"
# toolkit harden unit: opcion desconocida: --depth
# rc=1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; harden_parse perms --depth 0'; echo "rc=$?"
# toolkit harden perms: --depth debe ser un entero >= 1
# rc=1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; harden_parse unit a b'; echo "rc=$?"
# toolkit harden unit: demasiados argumentos: b
# rc=1
```

## Paso 3: TODO 2 — `harden_prepare`

**Por qué**: valida que lo pedido **existe** y es del tipo esperado antes de leer
nada. `perms` necesita un directorio; las otras tres, un archivo. Y `container`
rechaza un archivo que no es un `docker inspect`, para no auditar un texto cualquiera.

**Comando**: un `case` por acción. El caso especial es `container`:

```bash
    container)
      if ! grep -q 'HostConfig' "$HD_POS"; then
        echo "toolkit harden container: no parece la salida de docker inspect: ${HD_POS}" >&2
        exit 1
      fi
      ;;
```

`grep -q` no imprime nada y solo devuelve el código: es lo que quieres en un `if`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; HD_ACTION=unit; HD_POS=; harden_prepare'; echo "rc=$?"
# toolkit harden unit: falta ARCHIVO
# rc=1
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh; HD_ACTION=perms; HD_POS=/nada; harden_prepare'; echo "rc=$?"
# toolkit harden perms: no existe el directorio: /nada
# rc=1
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; source /root/bin/toolkit.sh; HD_ACTION=container; HD_POS=bad.service; harden_prepare'; echo "rc=$?"
# toolkit harden container: no parece la salida de docker inspect: bad.service
# rc=1
```

## Paso 4: TODO 3 — `harden_value`

**Por qué**: es la pieza que decide **qué valor cuenta**. Una unidad de systemd y un
`sshd_config` se leen al revés: en el primero gana la última aparición, en el segundo
la primera, y en el segundo se deja de leer en `Match`. Si te equivocas aquí, todo
lo demás audita datos falsos.

**Comando**: el patrón de `=~` va en una **variable sin comillas**, y cambia según
el modo:

```bash
  if [[ "$modo" == first ]]; then
    re="^[[:space:]]*${clave}([[:space:]]*=[[:space:]]*|[[:space:]]+)(.*[^[:space:]])?[[:space:]]*$"
    shopt -s nocasematch
  else
    re="^[[:space:]]*${clave}[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$"
  fi
```

En `first`, el valor está en `BASH_REMATCH[2]` y se hace `break`; en `last`, en
`BASH_REMATCH[1]` y se sigue leyendo para quedarse con la última. `shopt -u nocasematch`
al terminar: dejarlo activo cambiaría el comportamiento de **todo** el script.
Fíjate en `(.*[^[:space:]])?`: acepta un valor vacío y recorta los espacios finales.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; source /root/bin/toolkit.sh
harden_value last User last.service
harden_value last PrivateTmp last.service
harden_value first PermitRootLogin a.conf
harden_value first permitrootlogin a.conf'
# svc
# yes
# yes
# yes
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; source /root/bin/toolkit.sh
echo "[$(harden_value first PermitEmptyPasswords a.conf)]"
echo "[$(harden_value first PasswordAuthentication e.conf)]"'
# []
# []
printf 'Alias = x\n# User=comentario\n  ProtectHome = yes  \n' | docker exec -i ubuntu-lab sh -c 'cat > /tmp/wk19/sp.service'
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; source /root/bin/toolkit.sh; echo "[$(harden_value last ProtectHome sp.service)] [$(harden_value last User sp.service)]"'
# [yes] []
```

Tres casos que no deben fallar: la **última** gana (`User=svc`, no `root`), la
**primera** gana en `sshd` (`yes`, aunque luego diga `no`), y lo que está **tras
`Match`** no cuenta (`PermitEmptyPasswords` queda vacío).

## Paso 5: TODO 4 — `harden_check`

**Por qué**: las comprobaciones de `unit` y `ssh` repiten el mismo patrón: «si el
valor casa con esto, ok; si no, riesgo». Escribirlo una vez evita que cuatro
comprobaciones copien un `if` con pequeñas diferencias.

**Comando**: pasa el valor a minúsculas con `${2,,}` y compara con el patrón en una
variable. Llama a `harden_line ok` o `harden_line riesgo`; **no** hagas `echo`:

```bash
harden_check() {
  local valor=${2,,} patron=$3
  if [[ "$valor" =~ $patron ]]; then
    harden_line ok "$1"
  else
    harden_line riesgo "$1" "$4"
  fi
}
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'source /root/bin/toolkit.sh
HD_QUIET=0; HD_COUNT=0
harden_check A YES "^(yes|on)\$" "falta A"
harden_check B "" "^(yes|on)\$" "falta B"
echo "count=$HD_COUNT"'
# ok A
# riesgo B: falta B
# count=1
```

## ✅ Resultado

- [ ] Los `TODO` 1 a 4 están resueltos
- [ ] `harden_parse` rechaza opciones desconocidas, `--depth` fuera de `perms` y valores no válidos
- [ ] `harden_prepare` rechaza lo que falta o no es del tipo esperado
- [ ] `harden_value` respeta «última gana», «primera gana» y el corte en `Match`
- [ ] `harden_check` imprime solo con `harden_line` y suma riesgos

Sigue con la [parte 2](06-harden-las-cuatro-auditorias.md): las cuatro auditorías.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `harden` siempre da `hallazgos: 0` | Las funciones siguen siendo marcadores del starter | Quita el `: "${...}"` y escribe el cuerpo del `TODO` |
| `harden_value` devuelve vacío con una clave presente | El patrón de `=~` va entre comillas | Guárdalo en una variable y úsalo **sin** comillas |
| `PermitRootLogin` no distingue `yes` de `YES` | Falta `shopt -s nocasematch` en modo `first` | Actívalo antes del bucle y desactívalo (`-u`) al salir |
| `--depth 0` se acepta | Solo comprobaste `^[0-9]+$` | Compara también con `0` |
| `toolkit.sh: Permission denied` tras `docker cp` | `cp` pierde el bit de ejecución | `entregar` ya hace `chmod +x` |

---

[← Práctica 04: Contenedores desde el anfitrión](04-contenedores-desde-el-anfitrion.md) · [Práctica 06: Las cuatro auditorías →](06-harden-las-cuatro-auditorias.md)
