# ShellCheck: el revisor que no se cansa

> `shellcheck` lee tu script **sin ejecutarlo** y te señala los errores que
> bash deja pasar en silencio: comillas que faltan, `cd` sin comprobar,
> variables sin usar. Es lo más parecido a un compañero senior revisando cada
> línea que tendrás a las tres de la mañana.

## 🎯 Objetivos

- Instalar `shellcheck` en las cuatro familias de distribución y ejecutarlo
- Leer un aviso (código `SCnnnn`, severidad, línea, columna, sugerencia)
- Arreglar los avisos más frecuentes entendiendo **por qué** lo son
- Silenciar un aviso concreto con una directiva **y una justificación**
- Integrarlo como parte de la entrega: el toolkit debe quedar con cero avisos

## 1. Qué problema resuelve

Bash perdona casi todo. `cd $dir` con la variable vacía, `rm $f` con un
espacio dentro, `[ $? -eq 0 ]`: funcionan **casi siempre**, y el día que no,
borran lo que no debían. Esos fallos no son de lógica sino de **sintaxis
tramposa**, y se detectan mirando el código. `shellcheck` es un analizador
estático (no ejecuta nada) con cientos de reglas, cada una con un identificador
estable (`SC2086`) y una página de explicación.

## 2. Cómo funciona

### 2.1 Instalarlo

> ⚠️ **Divergencia real**: el paquete se llama distinto y en RHEL **no está
> en los repositorios base**:

| Familia | Instalación | Versión en el laboratorio |
|---|---|:--:|
| Ubuntu 24.04 / Debian 12 | `apt-get install -y shellcheck` | 0.9.0 |
| Rocky/RHEL 9 | `dnf install -y epel-release && dnf install -y ShellCheck` | 0.10.0 |
| Arch | `pacman -S --noconfirm shellcheck` | 0.11.0 |

Ojo con `ShellCheck` (mayúsculas) en `dnf`. La imagen mínima de `ubuntu-lab`
no lo trae, igual que no traía `dig` ni `ss`: instálalo como en la Semana 12.

```bash
docker exec ubuntu-lab apt-get update
docker exec ubuntu-lab apt-get install -y shellcheck
docker exec ubuntu-lab shellcheck --version
# ShellCheck - shell script analysis tool
# version: 0.9.0
```

Las reglas y los textos pueden variar un poco entre versiones; los códigos
`SCnnnn` que verás aquí son estables.

### 2.2 Leer un aviso

Un script con cinco defectos típicos:

```bash
cat > sc.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

dir=$1
cd $dir
for f in $(ls); do
  echo $f
done
local_v=`date`
f() { local r=$(false); echo "$r"; }
grep -q x /etc/passwd
if [ $? -eq 0 ]; then echo si; fi
unused=1
EOS
shellcheck sc.sh
```

```
In sc.sh line 5:
cd $dir
   ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
cd "$dir"

In sc.sh line 6:
for f in $(ls); do
         ^---^ SC2045 (error): Iterating over ls output is fragile. Use globs.
...
```

Cada bloque dice: **dónde** (línea, y `^--^` bajo el trozo exacto),
**qué regla** (`SC2086`), **gravedad** entre paréntesis y **qué hacer** (a
veces con "Did you mean"). La gravedad:

| Nivel | Significa |
|---|---|
| `error` | Casi seguro un fallo (`for f in $(ls)`) |
| `warning` | Probable fallo (variable sin usar, `local v=$(...)`) |
| `info` | Funciona hoy y falla con ciertos datos (falta de comillas) |
| `style` | Mejora de legibilidad (comillas invertidas, `$?`) |

**Cualquier hallazgo, hasta `style`, hace que `shellcheck` salga con `1`**
(con el script limpio, con `0`): es lo que comprueba `checks.json` con
`shellcheck ~/bin/toolkit.sh`. Para ver solo lo grave: `shellcheck -S warning
sc.sh` (`-S` = severidad mínima: `error`, `warning`, `info`, `style`).

### 2.3 Los avisos que verás el 90 % del tiempo

| Código | Qué dice | Arreglo | Archivo |
|---|---|---|:--:|
| `SC2086` | Variable sin comillas | `"$var"` | 03 |
| `SC2046` | `$(...)` sin comillas | `"$(...)"` | 03 |
| `SC2045` | `for f in $(ls)` | `for f in *` | 03 |
| `SC2164` | `cd` sin comprobar si falla | `cd "$d" \|\| exit 1` | 05 |
| `SC2155` | `local v=$(cmd)` oculta el código | `local v` y `v=$(cmd)` | 06 |
| `SC2181` | `if [ $? -eq 0 ]` | `if comando; then` | 04 |
| `SC2006` | Comillas invertidas | `$(...)` | 06 |
| `SC2034` | Variable que nadie usa | quítala, o `export`ala si es para otros | 02 |
| `SC2154` | Variable usada sin asignar | asígnala o revisa el nombre | 02 |
| `SC2162` | `read` sin `-r` | `read -r` | 06 |
| `SC2148` | Sin shebang: ni sabe qué shell es | `#!/usr/bin/env bash` | 01 |
| `SC2115` | `rm -rf "$d/"*` con `d` posiblemente vacía | `"${d:?}"/*` | 02 |
| `SC3010` | `[[ ]]` en un script `#!/bin/sh` | shebang `bash`, o `[ ]` | 01 |

`SC3010` es la regla que enlaza con la divergencia de `dash`: con
`#!/bin/sh` y un `[[ ]]`, `shellcheck` avisa **en tu máquina** de lo que
fallaría en Ubuntu. Y `SC2148` indica que, **sin shebang**, ni siquiera sabe
qué reglas aplicar (se puede forzar con `shellcheck -s bash archivo`).

### 2.4 Silenciar un aviso (con motivo)

A veces `shellcheck` se equivoca, o la excepción es deliberada. Se desactiva
**una regla en un sitio concreto** con una directiva en el comentario de
encima, y **siempre con el porqué**:

```bash
# shellcheck disable=SC2034
unused=1
```

Un ejemplo real del toolkit de esta semana:

```bash
  # shellcheck source=/dev/null  # /etc/os-release lo lee bash en ejecucion, no shellcheck
  sistema=$( . /etc/os-release && echo "$PRETTY_NAME" )
```

`source=/dev/null` le dice a `shellcheck` "no intentes seguir ese archivo":
sin esa línea avisa `SC1091` (*Not following: /etc/os-release*) porque no
analiza archivos que no se le han dado.

> ⚠️ La opción `-e SC2086,SC2034...` por línea de comandos silencia las reglas
> en **todo** el script: es esconder los problemas. Úsala solo para una
> regla que **sepas** que no aplica a todo el proyecto. En este bootcamp, un
> `disable` sin justificación es una penalización moderada de la rúbrica.

### 2.5 Formatos de salida

- `shellcheck -f gcc archivo` imprime `archivo:línea:columna: nivel: mensaje
  [SCnnnn]`, una por línea: lo entienden los editores (VS Code, Vim).
- `shellcheck -f json archivo` imprime JSON (un `[]` si no hay avisos): para
  procesarlo con `jq`.
- `shellcheck -x archivo` **sigue** los `source` que encuentre, para analizar
  también esos archivos.

## 3. Cómo se usa

Tres momentos del flujo de trabajo:

1. **Mientras escribes**: el editor (extensión de ShellCheck en VS Code) lo
   corre solo y subraya. Es el mejor punto: el aviso llega cuando aún
   recuerdas qué querías hacer.
2. **Antes de cada commit**: `shellcheck 3-proyecto/starter/*.sh`.
3. **En la entrega**: `verificar-semana.sh` ejecuta `shellcheck` sobre tu
   `toolkit.sh`. Cero avisos.

Y un flujo para limpiar un script grande: `shellcheck -S warning` primero (lo
que probablemente falla), luego el resto, **de arriba abajo** (muchos avisos
posteriores son consecuencia del primero).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Añadir `# shellcheck disable=...` sin leer el aviso | Escondes un fallo real | Lee la página `shellcheck.net/wiki/SCnnnn` y entiende la regla |
| `shellcheck -e` con una lista larga en el comando de entrega | El resultado "limpio" no significa nada | Directiva local, con comentario |
| Arreglar el aviso sin entender el porqué (poner comillas a todo "porque sí") | Lo rompes al revés: `"$@"` frente a `"$*"` | Reproduce el fallo con `printf '<%s>\n'` |
| Ejecutar `shellcheck` y no leer la **salida de `bash -x`** | Detecta sintaxis tramposa, no lógica | Probar el script; shellcheck complementa |
| Un script sin shebang | `SC2148` y reglas equivocadas | Siempre `#!/usr/bin/env bash` |
| Dar por bueno un script solo por pasar shellcheck | No ve errores de lógica (un umbral mal comparado) | Ejecutarlo y comprobar su salida y su código |

## 5. Trucos

- **`shellcheck -S error`** en integración continua: bloquea solo lo grave
  sin frenar al equipo por avisos de estilo.
- **`shellcheck -o all archivo`** activa reglas opcionales (por ejemplo,
  `SC2250`, exigir llaves en cada variable): más estricto; la lista sale con
  `shellcheck --list-optional`.
- **La página de cada código** (`https://www.shellcheck.net/wiki/SC2086`) trae
  el ejemplo malo, el bueno y **cuándo está bien ignorarlo**: léela una vez
  por cada aviso nuevo.
- **`bash -n` y `shellcheck` son complementarios**: `bash -n` solo
  encuentra errores de sintaxis; `shellcheck` encuentra construcciones
  legales pero peligrosas.

## 📚 Recursos Adicionales

- [shellcheck.net](https://www.shellcheck.net/): la versión web, útil para pegar un fragmento y ver el aviso
- [El wiki de ShellCheck](https://www.shellcheck.net/wiki/): una página por código

## ✅ Checklist de Verificación

- [ ] `docker exec ubuntu-lab shellcheck --version` imprime una versión
- [ ] Reproduces `sc.sh` y encuentras `SC2086`, `SC2045`, `SC2155` y `SC2181`
- [ ] Tras arreglarlo, `shellcheck sc.sh` sale con `0` y sin salida
- [ ] Explicas por qué `-S warning` salta los avisos de `info` y `style`
- [ ] Sabes la diferencia de paquete entre `apt` (`shellcheck`) y `dnf` (`ShellCheck` + `epel-release`)

---

[← Sustitución de comandos, here-docs y printf](06-sustitucion-de-comandos-heredocs-y-printf.md) · [Construyendo `snapshot` →](08-construyendo-snapshot.md)
