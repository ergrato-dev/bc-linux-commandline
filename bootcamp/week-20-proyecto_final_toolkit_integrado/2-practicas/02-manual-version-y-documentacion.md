# Práctica 02: Manual, versión y documentación

> Usas `toolkit version`, lees y compruebas la página de manual que el starter ya trae escrita, y contrastas lo que documenta con lo que el programa hace de verdad.
> Documentar es comprobar que lo escrito y lo ejecutado dicen lo mismo.

**Teoría de apoyo**: [02 · Control, versión y numeración](../1-teoria/02-control-version-y-numeracion.md) y [04 · Documentar una herramienta](../1-teoria/04-documentar-una-herramienta.md).
**Duración estimada**: 1 h · **Entorno**: `ubuntu-lab`

## Preparación

El `starter` de esta semana ya incluye completos `toolkit version` y la página de manual (`release_manpage`). Cópialo al laboratorio con el bit de ejecución y trabaja en un directorio desechable:

```bash
# Desde tu maquina: copia el starter al laboratorio y dale permiso de ejecucion.
docker cp bootcamp/week-20-proyecto_final_toolkit_integrado/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
docker exec -it ubuntu-lab bash
rm -rf /tmp/wk20 && mkdir -p /tmp/wk20 && cd /tmp/wk20
```

---

## Paso 1: Consultar la versión

**Por qué**: la versión es lo primero que te piden cuando algo falla. `toolkit version` la imprime para personas (`toolkit 1.0.0`) y `--short` para scripts (`1.0.0`, sin texto alrededor). Dos formatos para dos lectores: nunca obligues a un script a recortar con `cut` lo que podrías haberle dado limpio.

**Comando**:

```bash
~/bin/toolkit.sh version
~/bin/toolkit.sh version --short
~/bin/toolkit.sh version --zz; echo "rc=$?"
```

**Verifica**:

```bash
~/bin/toolkit.sh version
# toolkit 1.0.0
~/bin/toolkit.sh version --short
# 1.0.0
~/bin/toolkit.sh version --zz; echo "rc=$?"
# toolkit version: opcion desconocida: --zz
# rc=1
```

Una opción desconocida sale con `1` (uso incorrecto), como en todas las capas anteriores.

---

## Paso 2: Localizar la única fuente de la versión

**Por qué**: la versión debe escribirse **en un solo sitio**. Si existe en tres lugares, tarde o temprano dos discrepan. Comprueba que aquí es así antes de fiarte de ella.

**Comando**:

```bash
# Busca todas las lineas que asignan la constante. Debe haber exactamente una.
grep -n '^TOOLKIT_VERSION=' ~/bin/toolkit.sh
```

**Verifica**:

```bash
grep -c '^TOOLKIT_VERSION=' ~/bin/toolkit.sh
# 1
```

El número de línea exacto puede variar si añades código; lo que importa es que sea una sola.

---

## Paso 3: Generar la página de manual

**Por qué**: el starter trae `release_manpage`, una función que imprime la página en formato `roff` usando la versión que haya en `RL_VERSION`. Cargas el script con `source` (que define las funciones sin ejecutar ningún subcomando) y llamas a la función, igual que hará `release build` en la práctica 05.

**Comando**:

```bash
# source carga las funciones; RL_VERSION es la variable que usa la cabecera .TH.
bash -c 'source ~/bin/toolkit.sh; RL_VERSION=9.9.9; release_manpage' > toolkit.1
head -3 toolkit.1
```

**Verifica**:

```bash
head -3 toolkit.1
# .TH TOOLKIT 1 "" "toolkit 9.9.9" "Comandos de usuario"
# .SH NAME
# toolkit \- caja de herramientas personal de sysadmin
wc -l < toolkit.1
# 43
```

La versión `9.9.9` que ves en la cabecera no es la del script: la **inyectaste** al llamar a la función. Es el mismo mecanismo por el que `release build --version 1.2.3` hará que el paquete declare `1.2.3`.

---

## Paso 4: Renderizar la página sin `man`

**Por qué**: en la imagen mínima `man` es un sustituto que solo imprime un aviso. Quien hace el trabajo de verdad es `groff`. Verás exactamente lo que verá el lector.

**Comando**:

```bash
# -Tascii: texto plano. -P-c: formato clasico sin secuencias de escape.
# col -b elimina los retrocesos que usa groff para simular negritas.
groff -man -Tascii -P-c toolkit.1 | col -b | sed -n 1,8p
```

**Verifica**:

```bash
groff -man -Tascii -P-c toolkit.1 | col -b | sed -n 1,7p
# TOOLKIT(1)                  Comandos de usuario                  TOOLKIT(1)
#
# NAME
#        toolkit - caja de herramientas personal de sysadmin
#
# SYNOPSIS
#        toolkit subcomando [opciones]
```

Si ves caracteres raros, falta `-P-c` o `col -b`; con `-Tutf8` aparecen guiones largos que `col` deja como bytes sueltos, por eso se usa `-Tascii`.

---

## Paso 5: Comprobar la página con `groff -z -ww`

**Por qué**: `groff -z -ww` es el `shellcheck` de las páginas de manual: no genera salida (`-z`) y activa todos los avisos (`-ww`). Pero hay una trampa: **imprime los avisos por `stderr` y sale con 0**. Si solo miras el código de salida, jamás verás un fallo.

**Comando**:

```bash
# Pagina correcta: no debe imprimir nada.
groff -man -z -ww toolkit.1; echo "rc=$?"
# Pagina con una macro inexistente: avisa, pero rc sigue en 0.
cp toolkit.1 bad.1 && printf '.ZZ nada\n' >> bad.1
groff -man -z -ww bad.1; echo "rc=$?"
```

**Verifica**:

```bash
groff -man -z -ww toolkit.1; echo "rc=$?"
# rc=0
groff -man -z -ww bad.1; echo "rc=$?"
# troff:bad.1:44: warning: macro 'ZZ' not defined
# rc=0
test -z "$(groff -man -z -ww toolkit.1 2>&1)" && echo limpia
# limpia
test -z "$(groff -man -z -ww bad.1 2>&1)" || echo "con avisos"
# con avisos
```

La comprobación fiable es **que la salida combinada esté vacía**, no el código de salida.

---

## Paso 6: Comprimir de forma reproducible

**Por qué**: las páginas de manual se instalan comprimidas. Si `gzip` guarda la fecha del archivo, dos construcciones del mismo paquete producen archivos distintos y el `SHA256SUMS` cambia sin que el contenido haya cambiado. `-n` evita guardar nombre y fecha.

**Comando**:

```bash
# Con -n: la suma no depende de la fecha del archivo.
gzip -9nc toolkit.1 | md5sum | cut -c1-8
sleep 1; touch toolkit.1
gzip -9nc toolkit.1 | md5sum | cut -c1-8
# Sin -n: guarda la fecha y la suma cambia.
gzip -9c toolkit.1 | md5sum | cut -c1-8
sleep 1; touch toolkit.1
gzip -9c toolkit.1 | md5sum | cut -c1-8
```

**Verifica**:

```bash
# Las dos primeras sumas son iguales; las dos últimas, distintas entre sí.
# 61d23e6e
# 61d23e6e
# 54b9abdd
# 4f964e19
```

Tus valores exactos serán otros (dependen del contenido y de la fecha), pero el patrón debe repetirse: **igual, igual, distinto, distinto**.

---

## Paso 7: Contrastar el manual con el programa

**Por qué**: una página de manual que documenta un código de salida que el programa no devuelve es peor que no tener documentación. Comprueba los tres códigos que promete (`0`, `1`, `2`) contra el comportamiento real.

**Comando**:

```bash
# 1: uso incorrecto (sin subcomando).
~/bin/toolkit.sh >/dev/null 2>&1; echo "uso: rc=$?"
# 2: algo que reportar (una unidad systemd sin endurecer).
printf '[Service]\nExecStart=/bin/true\n' > b.service
~/bin/toolkit.sh harden unit b.service >/dev/null; echo "hallazgo: rc=$?"
# 1: archivo inexistente.
~/bin/toolkit.sh audit /no-existe >/dev/null 2>&1; echo "inexistente: rc=$?"
# La sección que promete esos códigos:
groff -man -Tascii -P-c toolkit.1 | col -b | sed -n '/EXIT STATUS/,/SEE ALSO/p'
```

**Verifica**:

```bash
# uso: rc=1
# hallazgo: rc=2
# inexistente: rc=1
# EXIT STATUS
#        0      Todo en orden.
#
#        1      Uso incorrecto o archivo inexistente.
#
#        2      Se encontro algo que reportar.
#
# SEE ALSO
```

El manual y el comportamiento coinciden. Cuando cambies un código de salida en el futuro, este es el contraste que debes repetir (y la razón de que `selftest` fije los códigos esperados).

---

## Paso 8: Comparar versiones como `dpkg`

**Por qué**: `dpkg` decide si instalar es actualizar o degradar comparando versiones por trozos, no como texto. Conviene ver con tus ojos que `1.10.0` es mayor que `1.9.0` y que `~` ordena antes.

**Comando**:

```bash
# dpkg --compare-versions A OP B: sale con 0 si se cumple.
for c in "1.10.0 gt 1.9.0" "1.0.0~rc1 lt 1.0.0" "2.0.0 gt 1.99.99" "1.0.0 gt 1.0.0"; do
  dpkg --compare-versions $c && echo "$c: si" || echo "$c: no"
done
```

**Verifica**:

```bash
# 1.10.0 gt 1.9.0: si
# 1.0.0~rc1 lt 1.0.0: si
# 2.0.0 gt 1.99.99: si
# 1.0.0 gt 1.0.0: no
```

(`$c` va sin comillas a propósito: necesitas que el shell la parta en tres palabras.)

---

## Paso 9: Validar el formato `MAYOR.MENOR.PARCHE`

**Por qué**: `release build --version` rechazará lo que no tenga forma de tres números. La validación es una expresión regular **anclada** (`^…$`) en una variable **sin comillas**; ensayarla ahora te evita depurarla dentro del script.

**Comando**:

```bash
re='^[0-9]+\.[0-9]+\.[0-9]+$'
for v in 1.0.0 1.0 v1.0.0 1.0.0-1 01.2.3; do
  [[ $v =~ $re ]] && echo "$v valida" || echo "$v invalida"
done
```

**Verifica**:

```bash
# 1.0.0 valida
# 1.0 invalida
# v1.0.0 invalida
# 1.0.0-1 invalida
# 01.2.3 valida
```

Fíjate en el último: `01.2.3` pasa la expresión, aunque probablemente no era lo que querías. La regex valida la **forma**, no las convenciones. Si fueras a exigir que no haya ceros a la izquierda tendrías que endurecerla; para esta herramienta, la forma basta.

---

## Paso 10: Limpiar

**Por qué**: deja el laboratorio como lo encontraste.

> **Aviso**: `rm -rf` es destructivo. Comprueba con `pwd` que estás en `/tmp/wk20` antes de borrarlo.

**Comando**:

```bash
pwd
# /tmp/wk20
cd / && rm -rf /tmp/wk20
```

**Verifica**:

```bash
test ! -e /tmp/wk20 && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] `toolkit version` y `--short` imprimen lo previsto y una opción inválida sale con `1`
- [ ] Comprobaste que `TOOLKIT_VERSION` se declara en una sola línea
- [ ] Generaste la página de manual con una versión inyectada
- [ ] La renderizaste con `groff -man -Tascii -P-c | col -b`
- [ ] Sabes comprobarla con `groff -z -ww` leyendo la salida, no el código
- [ ] Demostraste que `gzip -n` produce el mismo resultado y `gzip` sin `-n` no
- [ ] Contrastaste los tres códigos de salida del manual con el programa
- [ ] Comparaste versiones con `dpkg --compare-versions` y validaste el formato con una regex

```bash
bash scripts/verificar-semana.sh 20
# version-imprime debe pasar (los demás de release aún no)
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `version` responde con el `Uso:` general | Copiaste un `toolkit.sh` de una semana anterior | Repite `docker cp` del starter y `chmod +x` |
| `Permission denied` al ejecutar `~/bin/toolkit.sh` | `docker cp` no conserva el bit de ejecución | `docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh` |
| `release_manpage: command not found` | `source` falló o no cargó el starter | Ejecuta `bash -c 'source ~/bin/toolkit.sh; type release_manpage'` |
| `groff: command not found` | Imagen sin `groff` | Está en `ubuntu-lab`; si trabajas en otro contenedor, instala `groff-base` |
| El renderizado muestra `^H` o `[1m` | Falta `-P-c` o `col -b` | Añade ambos |
| `groff -z -ww` no muestra nada con `bad.1` | Miras el código de salida (siempre 0) | Mira la salida: los avisos van por `stderr` |
| Las sumas de `gzip -n` difieren | Comprimes archivos distintos | Usa el mismo `toolkit.1` en ambas |

---

[← Práctica 01: Un .deb por dentro](01-un-deb-por-dentro.md) · [Práctica 03: Instalar, verificar y quitar →](03-instalar-verificar-y-quitar.md)
