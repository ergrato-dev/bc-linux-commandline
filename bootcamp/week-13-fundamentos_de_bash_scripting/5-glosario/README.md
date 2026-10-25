# Glosario — Semana 13

**argumento posicional** (*positional parameter*): cada palabra que sigue al
nombre de un script al ejecutarlo. Se leen como `$1`, `$2`... y `$#` dice
cuántos hay; `shift` descarta el primero.

**BASH_REMATCH**: array que deja `[[ cadena =~ regex ]]`: la posición `0` es
la coincidencia completa y las siguientes, cada grupo entre paréntesis.

**bashismo** (*bashism*): característica de bash que no existe en `sh`
POSIX, como `[[ ]]`, los arrays o `${v^^}`. En `dash` falla con
`[[: not found`.

**CRLF**: final de línea de Windows (`\r\n`). En un script, hace que el
shebang pida un intérprete llamado `bash\r` y falle; se arregla con
`sed -i 's/\r$//'`.

**dash**: shell mínima y rápida, POSIX, que es `/bin/sh` en Debian y Ubuntu
(en RHEL y Arch, `/bin/sh` es `bash`). No conoce `[[ ]]`.

**división en palabras** (*word splitting*): etapa de la expansión en la que
bash parte el resultado de una variable o sustitución sin comillas por los
caracteres de `IFS`. Por eso `"$var"` va entre comillas.

**env** (`/usr/bin/env`): programa que ejecuta otro buscándolo en el `PATH`;
`#!/usr/bin/env bash` evita fijar la ruta del intérprete.

**expansión de parámetros** (*parameter expansion*): la sintaxis `${...}`:
valores por defecto (`${v:-x}`), recortes (`${v##*/}`), sustitución
(`${v//a/b}`) y longitud (`${#v}`).

**export**: marca una variable para que la hereden los procesos hijo. Nunca
sube valores al proceso padre.

**getopts**: orden interna de bash que procesa opciones **cortas** (`-v`,
`-o valor`) dejando el valor en `OPTARG`. No admite opciones largas.

**here-string**: `<<< "texto"`: envía una cadena a la entrada estándar de un
comando, sin here-doc de varias líneas.

**IFS** (*Internal Field Separator*): caracteres por los que bash parte las
palabras tras una expansión (por defecto espacio, tabulador y salto de
línea). `IFS=, read -ra v <<< "a,b"` lo cambia solo para ese `read`.

**nounset** (`set -u`): hace que usar una variable sin definir sea un error,
con código `1`, en lugar de expandirse a vacío.

**octal (trampa)**: en `$(( ))`, un número con cero delante se lee en base 8
(`010` es 8, `08` es un error). `10#08` fuerza la base decimal.

**quoting** (*entrecomillado*): conjunto de reglas (`'..'`, `".."`, `\`) que
controlan qué expansiones aplica bash a un texto. Las comillas dobles
conservan `$` pero impiden la división en palabras y el globbing.

**readonly**: declara una variable como constante: reasignarla da
`readonly variable`.

**shebang** (`#!`): los dos primeros bytes de un script; el kernel lee el
resto de la línea para saber qué intérprete lanzar.

**ShellCheck**: analizador estático de scripts de shell. Cada aviso lleva un
código `SCnnnn` y una gravedad (`error`, `warning`, `info`, `style`); sale
con `1` si encuentra cualquier hallazgo.

**shift**: descarta el primer argumento posicional y renumera el resto;
`shift 2` descarta dos. Con `set -e`, sin argumentos que quitar, aborta.

**source** (`.`): carga y ejecuta un script **en la shell actual**, sin
proceso hijo: sus variables y su `cd` persisten.

**subshell**: copia de la shell que ejecuta `( ... )`, `$( ... )` o cada
parte de una tubería. Lo que cambia dentro (variables, `cd`) no sale.

**sustitución de comandos** (*command substitution*): `$(comando)` se
reemplaza por la salida estándar del comando, sin los saltos de línea finales.

**test** (`[ ]`, `[[ ]]`): condiciones de archivo, cadena y número que
devuelven un código de salida. `[[ ]]` es sintaxis de bash y no parte las
variables; `[ ]` es POSIX.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Índice del bootcamp →](../../README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
