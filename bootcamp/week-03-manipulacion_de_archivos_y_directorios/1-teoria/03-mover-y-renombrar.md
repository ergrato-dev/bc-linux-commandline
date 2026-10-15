# Mover y renombrar

> `mv` hace dos cosas que parecen distintas — mover y renombrar — porque en
> realidad son la misma operación vista desde dos ángulos. Entender eso
> también explica por qué `mv` a veces es instantáneo y a veces no.

![mv dentro del mismo disco contra entre discos distintos](../0-assets/01-mv-mismo-disco-vs-otro-disco.svg)

## 🎯 Objetivos

- Mover y renombrar archivos y directorios con `mv`
- Explicar por qué mover dentro del mismo disco es instantáneo y entre discos no
- Evitar la pérdida de datos al mover hacia un destino que ya existe
- Aplicar el patrón de escritura atómica en un caso real

## 1. Qué problema resuelve

"Renombrar un archivo" y "mover un archivo a otra carpeta" parecen dos
operaciones distintas, pero en Linux son el mismo comando (`mv`) y, en el
caso más común, literalmente la misma operación a nivel de sistema de
archivos: cambiar a qué nombre apunta un inodo, sin tocar el contenido. Esa
unificación es lo que hace que mover un archivo de 10 GB dentro del mismo
disco sea instantáneo — y es también la causa de una sorpresa real cuando
el destino está en otro disco.

## 2. Cómo funciona

### 2.1 `mv` básico: mover y renombrar son el mismo comando

```bash
mv archivo.txt /otra/carpeta/              # mover
mv nombre-viejo.txt nombre-nuevo.txt       # renombrar
mv carpeta-vieja carpeta-nueva             # renombrar una carpeta entera
```

No hay un comando `rename` separado para el caso simple: `mv` cubre ambos,
porque a nivel del sistema de archivos ambos son la misma operación —
reasignar una entrada de directorio a un nombre distinto.

### 2.2 Por qué mover es instantáneo dentro del mismo disco

Cuando origen y destino están en el **mismo sistema de archivos** (misma
partición, mismo disco), `mv` no toca el contenido en absoluto: solo
actualiza la entrada de directorio para que el nombre nuevo apunte al mismo
inodo. No importa si el archivo pesa 10 KB o 10 GB — la operación es
igual de rápida, porque no se copia ni un byte de contenido.

```bash
dd if=/dev/zero of=/tmp/archivo-grande.bin bs=1M count=500 2>/dev/null
time mv /tmp/archivo-grande.bin /tmp/renombrado.bin
# real    0m0.003s     <- instantaneo, sin importar el tamaño
```

### 2.3 Por qué mover entre discos es lento (y por qué eso tiene sentido)

Cuando destino y origen están en **sistemas de archivos distintos** (otro
disco, otra partición, otro punto de montaje), no existe la posibilidad de
"solo reapuntar": el contenido tiene que copiarse físicamente al otro
disco, y recién después se borra el original. `mv` lo hace de forma
transparente, pero el tiempo que tarda ahora sí depende del tamaño:

```bash
time mv /tmp/archivo-grande.bin /otro-punto-de-montaje/
# real    0m2.140s     <- ahora si tarda, proporcional al tamaño
```

Este es el mismo mensaje de error que viste con `ln` en la Semana 02
("Invalid cross-device link") — la causa de fondo es la misma: una
operación que depende de estar en el mismo sistema de archivos para ser
"gratis".

### 2.4 Mover hacia un destino que ya existe

```bash
mv origen.txt destino-existente.txt
# sobrescribe destino-existente.txt sin preguntar ni avisar
```

A diferencia de `cp`, `mv` **sobrescribe por defecto, en silencio**, si
tienes permiso para hacerlo. No hay una versión "segura" por defecto — hay
que pedirla.

```bash
mv -i origen.txt destino-existente.txt     # pregunta antes de sobrescribir
mv -n origen.txt destino-existente.txt     # nunca sobrescribe, salta en silencio
```

### 2.5 Mover varios archivos a la vez

```bash
mv *.txt /tmp/destino/
mv archivo1.txt archivo2.txt archivo3.txt /tmp/destino/
```

Cuando el último argumento es una carpeta existente, `mv` mueve todos los
argumentos anteriores *dentro* de ella. Si el destino no es una carpeta
existente y hay más de un origen, `mv` falla — no tiene forma de "fusionar"
varios archivos en un nombre de destino único.

### 2.6 Por qué "mover es atómico" importa para scripts reales

Que `mv` dentro del mismo disco sea una simple reasignación de nombre tiene
una consecuencia práctica enorme: es **atómico** — en cualquier instante,
el nombre de destino o bien no existe todavía, o bien ya es el archivo
completo y final. Nunca hay un estado intermedio donde el destino exista a
medio escribir.

Esto es la base de un patrón de escritura segura muy usado en scripts y
herramientas reales:

```bash
# Patron de escritura atomica: escribir a un temporal, mover al final
generar_reporte > /tmp/reporte.tmp
mv /tmp/reporte.tmp /var/www/reporte.html
```

Si `generar_reporte` falla a mitad de camino, `/var/www/reporte.html`
sigue siendo la versión anterior completa — nunca queda un archivo a medio
escribir donde otro proceso (un servidor web, otro script) pudiera leerlo
en un estado roto. Escribir *directo* al destino final, en cambio, sí deja
una ventana donde el archivo existe pero está incompleto.

## 3. Cómo se usa

```bash
# Renombrar con seguridad: nunca sobrescribir
mv -n viejo.txt nuevo.txt

# Mover un directorio completo, con confirmacion
mv -i carpeta-vieja/ /otro/lugar/

# Mover con verbose, para confirmar cada movimiento
mv -v *.log /var/log/archivados/
```

```bash
# Confirmar si origen y destino comparten disco antes de mover algo grande
df --output=source /origen /destino
# si ambas lineas muestran el mismo dispositivo, el mv sera instantaneo
```

```bash
# Renombrar en lote, agregando un prefijo (patron real de uso diario)
for f in *.txt; do
  mv -n -- "$f" "borrador-$f"
done
```

El `--` antes de `"$f"` protege contra nombres de archivo que empiecen con
`-` (que de otra forma `mv` interpretaría como un flag) — un hábito de
seguridad barato que vale la pena incorporar ya.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Asumir que `mv` siempre es instantáneo sin importar el destino | Entre sistemas de archivos distintos, `mv` copia y borra — tarda proporcional al tamaño | Si el destino está en otro disco/punto de montaje, esperar que tarde como una copia |
| Mover hacia un nombre existente sin `-i` ni `-n` en uso interactivo | `mv` sobrescribe en silencio por defecto — sin aviso, sin posibilidad de arrepentirse | Usar `-i` para confirmar antes, `-n` si prefieres que simplemente no haga nada en ese caso |
| Renombrar en lote sin `--` antes del nombre de archivo | Un nombre que empieza con `-` se interpreta como flag y rompe el comando | Usar `--` para marcar "lo que sigue son nombres de archivo, no flags" |
| Esperar que `mv varios-archivos destino-que-no-es-carpeta` "fusione" los archivos | `mv` no tiene forma de combinar contenido — falla si hay más de un origen y el destino no es una carpeta existente | Confirmar que el destino es una carpeta real antes de mover varios orígenes ahí |
| Escribir directo al archivo final en vez de a un temporal + `mv` | Otro proceso puede leer el archivo a medio escribir, en un estado roto o incompleto | Adoptar el patrón de escritura atómica cuando el archivo lo lee algo más mientras se genera |

## 5. Trucos

- `mv -v` muestra cada movimiento como `'origen' -> 'destino'` — útil para
  confirmar un renombrado en lote antes de que termine.
- `rename` (el comando, distinto de `mv`) usa expresiones regulares para
  renombrar muchos archivos de una según un patrón — vale la pena como
  referencia, aunque no viene preinstalado en todas las distros por igual.
- Para "deshacer" un `mv` reciente sin confirmar manualmente la ruta
  anterior, el historial de bash (`history | grep mv`, visto en la Semana
  01) suele tener el comando exacto que lo causó.
- `mv -b` crea un respaldo (`destino~`) del archivo sobrescrito, sin
  necesidad de armar a mano el patrón de `cp --backup` visto en el
  archivo anterior.

## Resumen

Mover y renombrar son la misma operación: dentro del mismo disco, `mv` solo
reasigna un nombre a un inodo existente, por eso es instantáneo sin importar
el tamaño, y por eso es atómico — la base del patrón "escribir a un
temporal, mover al final" que evita que otro proceso vea un archivo a medio
escribir. Entre discos distintos, la operación deja de ser gratis: copia y
borra, con el mismo costo que `cp` más limpieza.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — mv invocation](https://www.gnu.org/software/coreutils/manual/html_node/mv-invocation.html) — la referencia completa de todos los flags de `mv`.
- `man mv` — la misma referencia, offline.
- `man 2 rename` — la syscall real detrás de `mv` dentro del mismo sistema de archivos, para quien quiera ver el nivel de detalle del kernel.

## ✅ Checklist de Verificación

- [ ] Midieron con `time` la diferencia entre mover dentro del mismo disco y entre dos puntos de montaje distintos
- [ ] Reprodujiste que `mv` sobrescribe en silencio sin `-i`/`-n`
- [ ] Renombraste varios archivos en lote con un bucle, usando `--` antes del nombre
- [ ] Explicaste con tus palabras por qué mover y renombrar son, a nivel de sistema, la misma operación
- [ ] Aplicaste el patrón "escribir a temporal, mover al final" en un caso propio

---

[← 02 — Copiar archivos y directorios](02-copiar-archivos-y-directorios.md) · [04 — Eliminar con criterio →](04-eliminar-con-criterio.md)
