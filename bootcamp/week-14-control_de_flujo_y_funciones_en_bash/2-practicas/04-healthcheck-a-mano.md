# Práctica 04 — `healthcheck` a mano

> Duración estimada: 90 min · Teoría de apoyo: archivos [06](../1-teoria/06-despacho-dinamico-y-estructura-de-un-script.md) y [07](../1-teoria/07-construyendo-healthcheck.md)

Aquí rellenas, **un `TODO` cada vez**, el `healthcheck` del
[`starter/toolkit.sh`](../3-proyecto/starter/toolkit.sh). Tras cada paso lo
entregas al laboratorio y compruebas el comportamiento que acabas de añadir.
Es el mismo trabajo que el proyecto; la práctica te lo parte en pasos
verificables.

Edita el `toolkit.sh` del `starter/` en tu **host** (con tu editor) y usa esta
función para llevarlo al laboratorio. Pégala en la terminal del host, desde la
raíz del repositorio:

```bash
entregar() {
  docker exec ubuntu-lab mkdir -p /root/bin
  docker cp bootcamp/week-14-control_de_flujo_y_funciones_en_bash/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
  docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
}
entregar && docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck; echo "codigo: $?"
# resumen: TODO ( 0  disk mem procs 0 0)
# codigo: 0
```

Es el punto de partida: el esqueleto ya ejecuta, pero el cuerpo de
`cmd_healthcheck` son marcadores (el `resumen: TODO` vuelca las variables que
aún no usas, y sale con `0` porque no hay `exit`).

## Paso 1: Leer el esqueleto antes de tocarlo

**Por qué**: el esqueleto ya trae el asociativo `limite`, el indexado `orden`
y `hc_line`. Reconocerlos evita reescribir lo que ya está y fija el plano de
la función antes de rellenarla.

**Comando**:

```bash
grep -n 'local -A limite\|local -a orden\|^hc_line\|^hc_check_' bootcamp/week-14-control_de_flujo_y_funciones_en_bash/3-proyecto/starter/toolkit.sh | cut -c1-60
# 780:hc_line() { printf '%-5s %s: %s\n' "$1" "$2" "$3"; }
# 789:hc_check_disk() {
# 797:hc_check_mem() {
# 805:hc_check_procs() {
# 814:  local -A limite=([disk]=90 [mem]=128 [procs]=500)
# 815:  local -a orden=(disk mem procs)
```

(Los números de línea pueden variar unas líneas; lo importante es ver `hc_line`, las tres `hc_check_*`, `limite` y `orden`.)

**Verifica**:

```bash
grep -c '# TODO [0-9]' bootcamp/week-14-control_de_flujo_y_funciones_en_bash/3-proyecto/starter/toolkit.sh
# 8
```

## Paso 2: TODO 4 y 5 — opciones y validación de límites

**Por qué**: antes de calcular nada, `healthcheck` debe rechazar el uso
inválido con código `1` y un mensaje en `stderr`. Las opciones escriben en el
asociativo (`limite[disk]="$2"`) y la validación recorre **todos** los límites
con un `for` sobre `orden`: así `--min-mem x` y `--umbral-disco 150` se
rechazan con el mismo código.

**Comando**: sustituye los comentarios `TODO 4` y `TODO 5` **y** la línea `local nombre=""` que los sigue por:

```bash
  local nombre=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --solo | --umbral-disco | --min-mem | --max-procesos)
        if [[ $# -lt 2 ]]; then
          echo "toolkit healthcheck: $1 necesita un valor" >&2
          exit 1
        fi
        case "$1" in
          --solo) solo="$2"; solo_dado=1 ;;
          --umbral-disco) limite[disk]="$2" ;;
          --min-mem) limite[mem]="$2" ;;
          --max-procesos) limite[procs]="$2" ;;
        esac
        shift 2
        ;;
      *)
        echo "toolkit healthcheck: opcion desconocida: $1" >&2
        exit 1
        ;;
    esac
  done

  for nombre in "${orden[@]}"; do
    if ! is_uint "${limite[$nombre]}"; then
      echo "toolkit healthcheck: limite invalido para $nombre: '${limite[$nombre]}'" >&2
      exit 1
    fi
  done
  if [[ "${limite[disk]}" -gt 100 ]]; then
    echo "toolkit healthcheck: limite invalido para disk: '${limite[disk]}'" >&2
    exit 1
  fi
```

(`local nombre=""` va **antes** del `for`: declarar la variable de un bucle
como `local` evita que escape a la shell de quien llama, y con `set -u`
una variable sin valor inicial aborta.)

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --min-mem x; echo "codigo: $?"
# toolkit healthcheck: limite invalido para mem: 'x'
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --nada; echo "codigo: $?"
# toolkit healthcheck: opcion desconocida: --nada
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --umbral-disco 150; echo "codigo: $?"
# toolkit healthcheck: limite invalido para disk: '150'
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --solo; echo "codigo: $?"
# toolkit healthcheck: --solo necesita un valor
# codigo: 1
```

## Paso 3: TODO 1, 2 y 3 — las tres comprobaciones

**Por qué**: cada `hc_check_*` es una función pequeña con un contrato fijo:
límite en `$1`, **una** línea con `hc_line`, y `0`/`1` como estado. El `return 1`
es explícito: no confiamos en `set -e`, que se apaga dentro de un `if`.

**Comando**: sustituye los tres marcadores por:

```bash
hc_check_disk() {
  local limite=$1 uso
  uso=$(sys_disk_usage)
  if [[ "$uso" -lt "$limite" ]]; then
    hc_line ok disk "${uso}% (umbral ${limite}%)"
  else
    hc_line fallo disk "${uso}% (umbral ${limite}%)"
    return 1
  fi
}

hc_check_mem() {
  local limite=$1 mem
  mem=$(sys_mem_mib)
  if [[ "$mem" -ge "$limite" ]]; then
    hc_line ok mem "${mem} MiB (minimo ${limite} MiB)"
  else
    hc_line fallo mem "${mem} MiB (minimo ${limite} MiB)"
    return 1
  fi
}

hc_check_procs() {
  local limite=$1 procesos
  procesos=$(sys_proc_count)
  if [[ "$procesos" -le "$limite" ]]; then
    hc_line ok procs "${procesos} (maximo ${limite})"
  else
    hc_line fallo procs "${procesos} (maximo ${limite})"
    return 1
  fi
}
```

(Las tres comparan **numéricamente**: `-lt`, `-ge`, `-le`. Con `<` dentro de
`[[ ]]` compararías texto: `9` quedaría por encima de `80`.)

**Verifica**: pruébalas **sueltas**, sin la función principal (la guarda de
la teoría 06 lo permite):

```bash
entregar
docker exec ubuntu-lab bash -c 'source ~/bin/toolkit.sh; hc_check_disk 90; hc_check_mem 128; hc_check_procs 500'
# ok    disk: 25% (umbral 90%)
# ok    mem: 9945 MiB (minimo 128 MiB)
# ok    procs: 22 (maximo 500)
docker exec ubuntu-lab bash -c 'source ~/bin/toolkit.sh; hc_check_mem 99999999 || echo "codigo: $?"'
# fallo mem: 9945 MiB (minimo 99999999 MiB)
# codigo: 1
```

(Tus cifras serán otras. El `|| echo` es necesario: sin él, `set -e` cerraría
el `bash -c` al devolver `1`.)

## Paso 4: TODO 6 — la lista de comprobaciones a ejecutar

**Por qué**: por defecto se ejecutan las tres (una **copia** de `orden`);
con `--solo` manda lo que el usuario pidió, **en su orden**. Cada nombre se
valida contra una lista blanca antes de usarlo para construir el nombre de
una función (teoría 06).

**Comando**: sustituye el `TODO 6` y la línea `local -a pedidos=(...)` por:

```bash
  local -a pedidos=("${orden[@]}")
  if [[ "$solo_dado" -eq 1 ]]; then
    IFS=, read -ra pedidos <<< "$solo"
  fi
  if [[ ${#pedidos[@]} -eq 0 ]]; then
    echo "toolkit healthcheck: --solo necesita al menos una comprobacion" >&2
    exit 1
  fi
  for nombre in "${pedidos[@]}"; do
    case "$nombre" in
      disk | mem | procs) ;;
      *)
        echo "toolkit healthcheck: comprobacion desconocida: '$nombre'" >&2
        exit 1
        ;;
    esac
  done
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --solo nada; echo "codigo: $?"
# toolkit healthcheck: comprobacion desconocida: 'nada'
# codigo: 1
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --solo ""; echo "codigo: $?"
# toolkit healthcheck: --solo necesita al menos una comprobacion
# codigo: 1
```

## Paso 5: TODO 7 — el bucle que despacha por nombre

**Por qué**: es el corazón. Un solo `for` llama a `hc_check_disk`, `hc_check_mem`
o `hc_check_procs` según el nombre, y le pasa el límite correspondiente. `if !`
captura el `return 1` **sin abortar**: el contador de fallos sube y el bucle
sigue.

**Comando**: sustituye el `TODO 7` y la línea `local total=0 fallos=0` por:

```bash
  local total=0 fallos=0
  for nombre in "${pedidos[@]}"; do
    total=$(( total + 1 ))
    if ! "hc_check_${nombre}" "${limite[$nombre]}"; then
      fallos=$(( fallos + 1 ))
    fi
  done
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --solo procs,disk
# ok    procs: 22 (maximo 500)
# ok    disk: 25% (umbral 90%)
# resumen: TODO (...)
```

El orden es el que pediste (`procs` primero). El `resumen: TODO` es el
siguiente paso.

## Paso 6: Forzar un fallo y comprobar que no corta

**Por qué**: un informe de salud debe decirte **todo** lo que falla, no solo
lo primero. Para probarlo hay que provocar el fallo: un límite imposible
(`--umbral-disco 0`: el uso siempre es `>= 0`) hace fallar `disk` sin tocar
nada de la máquina.

**Comando**:

```bash
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --umbral-disco 0
# fallo disk: 25% (umbral 0%)
# ok    mem: 9945 MiB (minimo 128 MiB)
# ok    procs: 22 (maximo 500)
# resumen: TODO (...)
```

`disk` falla (primera línea) y aun así se ejecutan `mem` y `procs`. Los otros
dos fallos se fuerzan igual:

```bash
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --min-mem 99999999 --max-procesos 1 | grep -c '^fallo'
# 2
```

**Verifica** (el código de salida llega con el paso 7; por ahora comprueba la
línea y que no se corta):

```bash
docker exec ubuntu-lab bash -c '~/bin/toolkit.sh healthcheck --umbral-disco 0 | grep -c "^ok "'
# 2
docker exec ubuntu-lab bash -c '~/bin/toolkit.sh healthcheck --umbral-disco 0 | grep -q "^fallo *disk: [0-9]*% (umbral 0%)" && echo FALLO-MARCADO'
# FALLO-MARCADO
```

## Paso 7: TODO 8 — el resumen y el código de salida

**Por qué**: el `resumen` cierra el informe y el código de salida es lo que
un `cron` o un `if` leerán: `0` todo bien, `2` si algo falló. El `1` ya lo
usaste para el uso inválido: los tres códigos tienen un significado distinto.

**Comando**: sustituye el `TODO 8` y el `echo "resumen: TODO ..."` por:

```bash
  echo "resumen: $(( total - fallos )) de $total ok"
  if [[ "$fallos" -gt 0 ]]; then
    exit 2
  fi
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck; echo "codigo: $?"
# ok    disk: 25% (umbral 90%)
# ok    mem: 9945 MiB (minimo 128 MiB)
# ok    procs: 22 (maximo 500)
# resumen: 3 de 3 ok
# codigo: 0
docker exec ubuntu-lab /root/bin/toolkit.sh healthcheck --umbral-disco 0; echo "codigo: $?"
# fallo disk: 25% (umbral 0%)
# ok    mem: 9945 MiB (minimo 128 MiB)
# ok    procs: 22 (maximo 500)
# resumen: 2 de 3 ok
# codigo: 2
```

Y para repasar el panel completo de códigos (`0`, `1`, `2`) con un solo bucle:

```bash
for args in "" "--nada" "--umbral-disco 0"; do
  docker exec ubuntu-lab bash -c "~/bin/toolkit.sh healthcheck $args >/dev/null 2>&1; echo \"[$args] -> \$?\""
done
# [] -> 0
# [--nada] -> 1
# [--umbral-disco 0] -> 2
```

## ✅ Resultado

- [ ] Opciones y límites inválidos salen con `1` y un mensaje en `stderr`
- [ ] Las tres `hc_check_*` funcionan sueltas tras `source`
- [ ] `--solo procs,disk` respeta el orden y `--solo nada` sale con `1`
- [ ] Un fallo se marca, **no corta** las demás comprobaciones y sale con `2`
- [ ] `resumen: 3 de 3 ok` sin fallos y `resumen: 2 de 3 ok` con uno

```bash
./scripts/verificar-semana.sh 14
```

(Con esta práctica completa pasan todas las comprobaciones `hc-*`; el resto
depende de que el refactor de `snapshot` del proyecto también esté hecho.)

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `nombre: unbound variable` | Falta `local nombre=""` antes de usarlo (`set -u`) | Declárala antes del `for` |
| `hc_check_x: command not found` | El nombre no pasó por la lista blanca o la función no existe | Revisa el `case` del paso 4 y el nombre de la función |
| Sale `0` aunque hay `fallo` | Falta el `exit 2` del paso 7 | Añade el `if [[ "$fallos" -gt 0 ]]` |
| El script se detiene en el primer fallo | Llamas a `hc_check_*` sin `if !` (y `set -e` aborta) | `if ! "hc_check_${nombre}" ...` |
| `integer expression expected` | Comparas con `-lt` un valor sin validar | `is_uint` antes (paso 2) |
| `((fallos++))` aborta el script | Con `set -e`, `0` es falso | `fallos=$(( fallos + 1 ))` |
| `--umbral-disco 0` no produce fallo | `sys_disk_usage` devolvió texto, no número | Ejecuta `sys_disk_usage` suelta tras `source` |
| `shellcheck` avisa de SC2155 | `local uso=$(...)` en una línea | `local uso` y luego `uso=$(...)` |

---

[← Práctica 03: arrays y refactor de `snapshot`](03-arrays-y-refactor-de-snapshot.md) · [Proyecto: `toolkit` semana 14 →](../3-proyecto/README.md)
