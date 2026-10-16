# xargs básico y el gotcha de entrada vacía

> `find` encuentra. `xargs` toma esa lista y la convierte en argumentos
> de otro comando — el pegamento entre "lo que encontré" y "lo que
> quiero hacer con eso". Pero tiene un comportamiento por defecto que
> puede ejecutar un comando **con cero argumentos** cuando no hay nada
> que procesar, y eso puede mentir silenciosamente sobre el resultado.

## 🎯 Objetivos

- Pasar una lista de líneas como argumentos de otro comando con `xargs`
- Limitar cuántos argumentos recibe cada invocación con `-n`
- Reproducir el gotcha de ejecución con cero argumentos sobre entrada vacía
- Corregirlo con `-r`/`--no-run-if-empty`

## 1. Qué problema resuelve

```bash
rm $(find . -name "*.tmp")
```

Esto "funciona" para pocos archivos, pero tiene dos problemas: si no
hay ningún `.tmp`, `rm` corre sin argumentos (y puede comportarse de
forma inesperada); y si hay miles de archivos, la línea de comando
puede superar el límite del sistema operativo. `xargs` existe para
resolver ambos: construye la invocación del comando de forma más
inteligente, dividiendo en varias llamadas si hace falta.

## 2. Cómo funciona

### 2.1 El patrón básico: `comando1 | xargs comando2`

```bash
find . -name "*.txt" | xargs wc -l
```

`xargs` lee líneas de su entrada estándar y las agrega como argumentos
al final de `comando2` — en este caso, equivalente a escribir `wc -l
archivo1 archivo2 archivo3...` a mano, pero generado automáticamente a
partir de lo que `find` encontró.

### 2.2 `-n`: limitar cuántos argumentos por invocación

```bash
printf '1 2 3 4 5\n' | xargs -n2 echo
```

```
1 2
3 4
5
```

`-n2` agrupa de a dos argumentos por invocación de `echo` — en vez de
una sola llamada con los cinco, son tres llamadas separadas. Útil
cuando el comando de destino no admite demasiados argumentos a la vez,
o cuando procesar de a pocos es parte de la lógica necesaria.

### 2.3 El gotcha: entrada vacía puede ejecutar el comando igual

```bash
find /tmp/directorio-vacio -name "*.zzz" | xargs echo "encontrado:"
```

```
encontrado:
```

Si `find` no encuentra nada, no produce ninguna línea — pero `xargs`,
por defecto (comportamiento clásico, no GNU-específico), **igual
ejecuta el comando una vez, sin argumentos**. Para un comando como
`echo`, esto es inofensivo (solo imprime la etiqueta); para un comando
que **lee de stdin cuando no recibe archivos como argumento** (como
`sha256sum`, `cat`, muchos otros), el resultado es mucho más peligroso:

```bash
find /tmp/directorio-vacio -name "*.zzz" -print0 | xargs -0 sha256sum
```

```
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  -
```

¡Esto imprime un hash real, con un guion (`-`) como "nombre de
archivo"! `sha256sum`, al no recibir ningún archivo como argumento, leyó
de stdin (que estaba vacío) y calculó el hash de la nada — un resultado
que **parece** un archivo real procesado, pero es completamente falso.
Un script que confíe en esa salida sin saber de este comportamiento
puede terminar reportando un "archivo" que no existe.

### 2.4 La corrección: `-r` / `--no-run-if-empty`

```bash
find /tmp/directorio-vacio -name "*.zzz" -print0 | xargs -r0 sha256sum
```

```
(sin salida — xargs no ejecuto sha256sum en absoluto)
```

`-r` le dice a `xargs`: "si no hay ningún argumento para pasar, no
ejecutes el comando en absoluto" — la corrección directa del problema
de la sección 2.3. Esta es la razón por la que `toolkit.sh finddupes`
de esta semana usa `xargs -r0` en vez de `xargs -0` a secas: sin `-r`,
un directorio vacío generaría un resultado falso de "archivo analizado"
que no existe.

### 2.5 El código de salida de `xargs` cuando una invocación falla

```bash
printf '1\n2\n3\n' | xargs -n1 sh -c 'test "$1" != 2' _
echo $?
# 123
```

Si alguna invocación del comando falla (código entre 1 y 125), `xargs`
mismo sale con código `123` — no el código original de la invocación
que falló, sino un código propio de `xargs` que señala "algo dentro del
lote falló". Esto es suficiente para que un script sepa que hubo un
problema, pero no **cuál** invocación ni con qué código exacto —
distinto de correr el comando directamente, donde `$?` sí sería el
código real.

### 2.6 `-p`: confirmar cada invocación antes de ejecutarla

```bash
find . -name "*.bak" | xargs -p rm
```

`-p` muestra cada comando que `xargs` va a ejecutar y espera
confirmación interactiva antes de correrlo — una red de seguridad
manual para operaciones destructivas en lote, en el mismo espíritu que
el patrón dry-run/confirmar de la Semana 03, pero integrado a `xargs`
en vez de necesitar un paso de previsualización separado.

## 3. Cómo se usa

```bash
# Contar lineas totales de todos los .py de un proyecto
find . -name "*.py" | xargs wc -l

# Buscar un patron dentro de todos los resultados de find
find . -name "*.conf" | xargs grep -l "Port"

# Version segura: no corre nada si no hay resultados
find . -name "*.conf" -print0 | xargs -r0 grep -l "Port"

# Cambiar permisos en lote, de a 10 archivos por invocacion
find . -name "*.sh" | xargs -n10 chmod +x
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `xargs` sin `-r` cuando el comando de destino lee de stdin sin argumentos | Una entrada vacía ejecuta el comando igual, con cero argumentos — para comandos que caen a leer stdin, el resultado puede ser un "archivo" fantasma | `-r` (`--no-run-if-empty`) por defecto en cualquier pipeline de `find \| xargs` donde la entrada puede estar vacía |
| Asumir que un resultado vacío de `find \| xargs comando` significa "no se ejecutó nada" | Sin `-r`, el comando corrió una vez — puede haber tenido efectos secundarios (escribir un archivo, loguear algo) aunque no hubiera nada que procesar | Verificar explícitamente con `-r`, no asumir el comportamiento por el resultado visual |
| Usar `$(find ...)` en vez de `find ... | xargs` para pasar muchos resultados | Puede superar el límite de longitud de línea de comando del sistema operativo con listas grandes | `xargs`, que divide automáticamente en varias invocaciones si hace falta |
| Pensar que `-n1` es lo mismo que `-exec ... \;` de `find` | Son equivalentes en espíritu (una invocación por elemento), pero sintaxis y banderas distintas — mezclar la sintaxis de uno con el otro da un error | Usar la sintaxis correcta de cada herramienta, aunque el resultado final sea similar |

## 5. Trucos

- `xargs --no-run-if-empty` es la forma larga de `-r` — más clara en un
  script que alguien más va a leer, a costa de ser más larga de
  escribir en la terminal.
- `xargs -t` imprime cada comando antes de ejecutarlo — útil para
  confirmar exactamente qué invocación se va a correr, antes de que
  corra de verdad.
- Si un pipeline con `xargs` "no hizo nada" sin ningún error, la primera
  sospecha debería ser "¿la entrada estaba realmente vacía, o el
  comando corrió una vez con cero argumentos y no produjo salida
  visible?" — confirmarlo con `-t` antes de seguir depurando.

## Resumen

`xargs` convierte líneas de su entrada en argumentos de otro comando;
`-n` limita cuántos por invocación. Por defecto, una entrada vacía
**igual ejecuta el comando una vez, sin argumentos** — peligroso para
comandos que leen de stdin cuando no reciben archivos. `-r`
(`--no-run-if-empty`) corrige esto: sin argumentos que pasar, no corre
el comando en absoluto.

## 📚 Recursos Adicionales

- [POSIX — xargs Utility](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/xargs.html) — la especificación POSIX base, independiente de la implementación de GNU.
- [GNU Findutils Manual — xargs](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Invoking-xargs) — referencia completa de banderas.
- `man xargs` — disponible sin conexión en cualquier distro.

## ✅ Checklist de Verificación

- [ ] Pasaste resultados de `find` como argumentos de otro comando con `xargs`
- [ ] Limitaste argumentos por invocación con `-n`
- [ ] Reprodujiste el gotcha de `xargs` ejecutando un comando con cero argumentos sobre una entrada vacía
- [ ] Corregiste el gotcha con `-r`, confirmando que el comando ya no corre
- [ ] Usaste `-t` para ver exactamente qué comando iba a ejecutar `xargs` antes de que corriera
- [ ] Confirmaste que `xargs` sale con código `123` cuando alguna invocación falla, no el código original

---

[← 03 — find con lógica combinada y acciones directas](03-find-logica-combinada-y-acciones.md) · [05 — xargs seguro: -print0, -I y nombres de archivo peligrosos →](05-xargs-seguro-print0-y-nombres-peligrosos.md)
