# Probar una herramienta

> Una herramienta que nadie prueba funciona hasta el día que dejas de mirarla.
> Una autoprueba pequeña, que se ejecuta sola y falla con un código claro, vale más que cien comprobaciones a ojo.

## 🎯 Objetivos

- Distinguir una prueba de humo (*smoke test*) de una prueba exhaustiva y saber cuándo basta cada una
- Escribir un caso de prueba que compara el **código de salida** esperado con el real
- Aislar cada caso en su propio proceso para que un fallo no contamine al siguiente
- Preparar un entorno de prueba descartable con `mktemp -d` y limpiarlo con `trap`
- Usar `shellcheck` como primera línea de defensa y leer sus niveles

## 1. Qué problema resuelve

`toolkit` llega a esta semana con veinte subcomandos escritos a lo largo de diecinueve semanas.
Cada uno funcionaba cuando lo escribiste. Pero al tocar una función compartida
(`die`, el parser de opciones, un `trap`), ¿cómo sabes que no has roto uno de los otros
diecinueve? Probarlos a mano uno por uno no escala, y lo que no se prueba se rompe sin ruido.

Una **autoprueba** responde en un segundo a una sola pregunta: «¿sigue funcionando lo
esencial?». No demuestra que no haya fallos; demuestra que no has roto lo evidente.

## 2. Cómo funciona

### 2.1 Prueba de humo frente a prueba exhaustiva

| | Prueba de humo | Prueba exhaustiva |
|---|---|---|
| Pregunta | ¿Arranca y hace lo básico? | ¿Todos los caminos hacen lo correcto? |
| Tamaño | Unos pocos casos | Cientos |
| Coste | Segundos | Minutos o más |
| Cuándo | Antes de cada empaquetado | En integración continua |

`toolkit selftest` es de **humo**: cinco casos, uno por zona del conjunto, elegidos
para que cada uno pueda fallar por un motivo distinto. La regla de elección:

> Un caso por **tipo de comportamiento**, no por subcomando.

Los cinco cubren: detectar un riesgo (`audit`), buscar en texto (`logscan`), una
ida y vuelta con efecto en disco (`backup`), análisis de una configuración
(`harden`) y rechazo de una entrada inválida (`schedule`).

### 2.2 Un caso es un código de salida

La clave de todo el diseño: las herramientas de la línea de comandos **ya comunican
su resultado** con el código de salida. Un caso solo tiene que comparar:

```bash
selftest_case NOMBRE ESPERADO CMD...
# Ejecuta CMD, descarta su salida y compara su codigo con ESPERADO.
```

```bash
selftest_case() {
  local nombre=$1 esperado=$2 rc=0
  shift 2
  ( "$@" ) >/dev/null 2>&1 || rc=$?
  ...
}
```

Tres detalles que no son decorativos:

1. **`( "$@" )` entre paréntesis** ejecuta el comando en un subproceso. Si el comando
   hace `exit 2`, no mata la autoprueba; si cambia una variable global, no la
   contamina.
2. **`|| rc=$?`** captura el código **sin que `set -e` aborte** el script. Sin ese `||`,
   el primer comando que devuelve distinto de 0 terminaría la autoprueba entera.
3. **`>/dev/null 2>&1`**: la salida del comando probado no es lo que se prueba y
   taparía el resumen.

El caso fallido imprime lo que esperaba y lo que obtuvo, que es lo que quieres leer
a las tres de la mañana:

```
falla audit-detecta-riesgo: esperaba 2, salio 0
```

### 2.3 Probar el fallo, no solo el éxito

Fíjate en que **cuatro de los cinco casos esperan un código `2`**. Una prueba que solo
confirma que «todo va bien» no demuestra que la herramienta detecte nada: una
herramienta que siempre devuelve 0 pasaría. Para comprobar que `audit` *sirve*, le
das una carpeta con un archivo `0777` y exiges que **proteste**:

```bash
mkdir -p "$ST_DIR/audit" && touch "$ST_DIR/audit/f" && chmod 0777 "$ST_DIR/audit/f"
selftest_case audit-detecta-riesgo 2 "$TK_SELF" audit "$ST_DIR/audit"
```

Se llama **prueba de caso negativo**, y es la que atrapa el error más peligroso de
una herramienta de auditoría: el falso negativo.

### 2.4 Un entorno de prueba descartable

Los casos necesitan archivos concretos (un log con `ERROR`, un archivo `0777`, una
unidad sin endurecer). Se crean en un directorio temporal único que se borra siempre:

```bash
ST_DIR=$(mktemp -d)
trap 'rm -rf "${ST_DIR}"' EXIT
```

`mktemp -d` evita choques entre ejecuciones simultáneas; `trap … EXIT` limpia aunque
la autoprueba aborte a medias. Y como el fixture se crea con **tus propias órdenes**,
la prueba no depende de lo que haya en la máquina.

### 2.5 Salida y códigos de la propia autoprueba

La autoprueba es una herramienta más, así que sigue el mismo contrato:

```bash
toolkit selftest
# ok audit-detecta-riesgo
# ok logscan-detecta-error
# ok backup-ida-y-vuelta
# ok harden-detecta-riesgos
# ok schedule-rechaza-expresion
# pruebas: 5, fallos: 0
echo $?
# 0
```

| Código | Significa |
|---|---|
| `0` | Todos los casos pasan |
| `1` | Uso incorrecto (`toolkit selftest --zz`) |
| `2` | Al menos un caso falla |

Con `--quiet` solo se imprime el resumen (y los fallos), pensado para `cron` o para
encadenar: `toolkit selftest --quiet && toolkit release build --out dist`.

### 2.6 `shellcheck`: la prueba que no ejecuta nada

`shellcheck` analiza el script **sin correrlo** y encuentra una clase de errores que
una autoprueba difícilmente toca: variables sin comillas, `cd` sin comprobar, bucles
sobre la salida de `ls`. Tiene cuatro niveles de severidad:

| Nivel | Ejemplo |
|---|---|
| `error` | Sintaxis que bash no acepta |
| `warning` | Variable usada sin asignar (SC2154) |
| `info` | Falta de comillas dobles (SC2086) |
| `style` | Sugerencias de estilo |

```bash
shellcheck -S warning toolkit.sh     # solo warning y error
shellcheck -f gcc toolkit.sh         # una linea por hallazgo, facil de procesar
```

Dos cosas importantes. Su código de salida es `0` si **no hay hallazgos del nivel
pedido**, así que `-S error` puede salir con 0 aunque haya avisos de menor nivel.
Y cada `# shellcheck disable=SC2154` es una deuda: escríbelo siempre con un comentario
que explique por qué es un falso positivo.

## 3. Cómo se usa

### 3.1 El orden de las defensas

1. `bash -n toolkit.sh` — ¿es sintaxis válida? (solo comprueba eso)
2. `shellcheck toolkit.sh` — ¿hay errores de estilo o de lógica evidentes?
3. `toolkit selftest` — ¿sigue funcionando lo esencial?
4. `toolkit release build` + `release verify` — ¿el paquete contiene lo que debe?

Cada paso es más caro que el anterior y descarta un tipo de fallo distinto. Si
`shellcheck` falla, ni siquiera lances la autoprueba.

### 3.2 Probar la propia prueba

Una autoprueba que nunca falla no demuestra nada. Para asegurarte, **rómpela a
propósito**: cambia un `2` esperado por un `0` y comprueba que sale con código 2 y
muestra `falla …`. Es el equivalente a comprobar que una alarma suena.

```bash
bash -c 'source ~/bin/toolkit.sh; ST_QUIET=0; ST_TOTAL=0; ST_FAILS=0
         selftest_case a 0 false
         echo "$ST_TOTAL $ST_FAILS"'
# falla a: esperaba 0, salio 1
# 1 1
```

(`source` carga las funciones sin ejecutar `main`, porque el script protege su
punto de entrada.)

### 3.3 Divergencia de distro

`shellcheck` se instala con `apt install shellcheck` (Debian/Ubuntu) y `pacman -S shellcheck`
(Arch); en la familia RHEL el paquete se llama `ShellCheck` (`dnf info ShellCheck`
lo confirma en `rhel-lab`). Las pruebas en sí no cambian de una distro a otra.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Probar solo el camino feliz | Una herramienta que siempre devuelve 0 pasa | Incluir casos negativos que exijan el fallo |
| Casos que comparten estado | Un fallo arrastra a los demás | Un proceso por caso: `( "$@" )` |
| Probar contra datos reales de la máquina | El resultado depende de dónde corra | Un `mktemp -d` con datos propios |
| Dejar el fixture sin limpiar | Basura en `/tmp` y falsos positivos | `trap 'rm -rf …' EXIT` |
| `set -e` sin `\|\| rc=$?` | El primer fallo mata la autoprueba | Capturar el código |
| Silenciar `shellcheck` con `disable` sin motivo | Se esconde un fallo real | Comentar cada excepción |
| Autoprueba de media hora | Nadie la ejecuta | Humo rápido; lo exhaustivo, aparte |
| Confiar en que «lo probé ayer» | El código cambió desde entonces | Autoprueba antes de cada empaquetado |

## 5. Trucos

- **`bash -x script`** imprime cada comando con sus expansiones antes de ejecutarlo.
  Para una autoprueba que falla sin explicación es lo más rápido que hay.
- **`shellcheck -f gcc … | wc -l`** cuenta hallazgos: un número que puedes seguir en el
  tiempo. Con `-S warning` ignoras el ruido de estilo.
- **`PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '`** escrita **dentro del script**, justo
  antes de `set -x`, hace que la traza indique archivo y línea de cada comando
  (bash no hereda `PS4` del entorno en un script, así que `PS4=… bash -x` no sirve).

## 📚 Recursos Adicionales

- [ShellCheck Wiki: lista de códigos SC](https://www.shellcheck.net/wiki/)
- `help trap`, `help set` (en bash)

## ✅ Checklist de Verificación

- [ ] Ejecutas `toolkit selftest` y ves cinco `ok` y `fallos: 0`
- [ ] Explicas por qué cuatro de los cinco casos esperan el código `2`
- [ ] Provocas un fallo con `selftest_case x 0 false` y lees el mensaje
- [ ] Explicas para qué sirve cada una de las tres piezas de `( "$@" ) >/dev/null 2>&1 || rc=$?`
- [ ] Ejecutas `shellcheck` con `-S warning` y con `-f gcc`
- [ ] Ordenas bash -n, shellcheck, selftest y release verify y dices qué descarta cada uno

---

[← Documentar una herramienta](04-documentar-una-herramienta.md) · [Construir release y selftest →](06-construir-release-y-selftest.md)
