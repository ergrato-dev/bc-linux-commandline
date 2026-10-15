# Eliminar con criterio

> Linux no tiene papelera de reciclaje por defecto. `rm` borra de verdad, y
> ese único hecho explica por qué este es, de lejos, el archivo más
> importante de toda la semana.

## 🎯 Objetivos

- Explicar por qué no existe una papelera de reciclaje estándar en la terminal
- Usar `rm` con los flags que reducen el riesgo real, sin perder velocidad
- Conocer alternativas que sí dan una red de seguridad, cuando hace falta
- Entender cuándo se libera realmente el espacio en disco tras un borrado

## 1. Qué problema resuelve

Cuando borras un archivo en un explorador gráfico, normalmente va a una
papelera: un lugar intermedio del que todavía puedes recuperarlo. `rm` no
tiene ese paso intermedio por diseño — borra la entrada de directorio de
inmediato, y el espacio que ocupaba el contenido queda disponible para
reescribirse. No hay "deshacer". Este archivo existe para que entiendas esa
realidad *antes* de necesitarla, no después de perder algo importante.

## 2. Cómo funciona

### 2.1 Por qué no hay papelera en la terminal

Una papelera requiere que el sistema de archivos sepa "mover a una carpeta
especial en vez de borrar", y que algo (un cron, un límite de tamaño) la
vacíe eventualmente. Eso es una capa adicional que la mayoría de
herramientas de línea de comandos, pensadas para scripts y automatización,
no agregan por diseño: un script que necesita borrar algo necesita que se
borre *ahora*, no "se mueva a un lugar donde podría seguir ocupando
espacio". `rm` es deliberadamente directo.

### 2.2 `rm` básico y sus flags esenciales

```bash
rm archivo.txt                 # borra un archivo
rm archivo1.txt archivo2.txt    # borra varios

rm carpeta
# rm: no se puede eliminar 'carpeta': Es un directorio

rm -r carpeta                  # borra un directorio y todo su contenido
```

| Flag | Qué hace |
|---|---|
| `-r` | Recursivo: necesario para borrar directorios con contenido |
| `-i` | Pregunta antes de cada borrado |
| `-I` | Pregunta **una sola vez** antes de un borrado masivo (3+ archivos, o recursivo) — menos molesto que `-i`, igual de protector |
| `-f` | Fuerza: no pregunta nunca, ignora archivos que no existen, no falla |
| `-v` | Verbose: muestra cada archivo que borra |
| `-d` | Borra un directorio **vacío**, sin necesitar `-r` (equivalente a `rmdir`) |

`-d` vale la pena distinguirlo de `-r`: confirma que la carpeta está vacía
antes de borrarla, en vez de aceptar silenciosamente borrar contenido que
no esperabas que hubiera ahí.

### 2.3 `rm -rf`: la combinación que más respeto merece

```bash
rm -rf carpeta-temporal/
```

`-r` para entrar en subcarpetas, `-f` para no preguntar nunca y no fallar
si algo no existe. Es exactamente lo que necesitas para limpiar algo
temporal en un script — y exactamente lo que más daño hace si el argumento
está mal, porque no hay ninguna pregunta de confirmación que lo frene.

```bash
# El clasico error de un espacio de mas
rm -rf /ruta /temporal        # borra DOS cosas: /ruta y /temporal (raiz!)
rm -rf /ruta/temporal          # borra UNA cosa: la ruta completa
```

Ese espacio de más no es un detalle menor: `rm -rf /ruta /temporal` es
equivalente a correr `rm -rf /ruta` y `rm -rf /temporal` por separado — si
`/temporal` no existía como intención y en realidad era parte de la ruta
anterior, el resultado real es borrar la raíz del segundo argumento tal
cual esté escrito.

### 2.4 Protecciones que ya trae el sistema

Ubuntu (como la mayoría de distros) incluye protecciones mínimas:

```bash
rm -rf /
# rm: it is dangerous to operate recursively on '/'
# rm: use --no-preserve-root to override this failsafe
```

Esta protección existe específicamente porque el error es común — no
es un capricho. **Nunca** se agrega `--no-preserve-root` salvo que
entiendas exactamente, sin ninguna duda, qué estás haciendo.

### 2.5 `-I` como punto medio razonable

```bash
rm -I -r carpeta-con-muchos-archivos/
# rm: ¿remover 47 archivos de forma recursiva? (s/N)
```

`-I` solo interrumpe para operaciones grandes (recursivas, o con 3+
archivos), con una sola pregunta — a diferencia de `-i`, que pregunta
archivo por archivo y vuelve tedioso cualquier borrado de más de dos
archivos. Es el punto medio real entre "nunca preguntar" y "preguntar
demasiado".

### 2.6 Qué borra `rm`, en realidad

Recordando el modelo de inodos visto en la Semana 02: `rm` no borra
contenido directamente, borra la **entrada de directorio** (el nombre) y
decrementa el contador de enlaces del inodo. El espacio en disco se libera
recién cuando ese contador llega a cero **y** ningún proceso tiene el
archivo abierto en ese momento.

Esto explica un caso real y confuso: un proceso que escribe a un archivo de
log gigante, alguien corre `rm` sobre ese log para "liberar espacio", y el
espacio **no se libera** hasta que el proceso cierra el archivo (o termina).
`df` sigue mostrando el disco lleno un rato después del `rm`, lo cual
parece un error pero es exactamente el comportamiento esperado.

```bash
# Si necesitas vaciar un log sin matar el proceso que escribe en el,
# truncarlo in-place es mejor que borrarlo:
> /var/log/aplicacion.log
# el proceso sigue escribiendo al MISMO inodo, ahora vacio
```

## 3. Cómo se usa

```bash
# Flujo recomendado para algo que no estas 100% seguro de borrar
ls carpeta-a-borrar/           # primero mira que hay ahi
rm -I -r carpeta-a-borrar/     # una sola confirmacion antes de borrar todo

# Flujo para un script que necesita limpiar sin interaccion
rm -rf /tmp/trabajo-temporal/  # sin preguntas, para automatizacion

# Ver que se borro, sin sorpresas
rm -v archivo1.txt archivo2.txt
```

```bash
# Antes de un rm -rf importante: respaldo de un segundo, en la misma linea
cp -a carpeta/ carpeta.bak/ && rm -rf carpeta/
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `rm -rf` por reflejo en cualquier borrado, sin pensar en el argumento | Es exactamente el comando sin ninguna red de seguridad — cualquier error de tipeo es irreversible | Reservar `-rf` para scripts ya probados; usar `-I` en uso interactivo |
| Escribir una ruta con variables sin comillas en un `rm -rf` | Si la variable está vacía o mal expandida, `rm -rf $ruta/` puede convertirse en `rm -rf /` | Comillar siempre: `rm -rf "${ruta:?}/"` — el `:?` hace fallar el comando si la variable está vacía, en vez de operar sobre `/` |
| Confiar en que "seguro lo puedo recuperar después" | No hay papelera por defecto; el espacio se reutiliza casi de inmediato | Asumir que todo `rm` es definitivo, y actuar con esa certeza antes de confirmar |
| Agregar `--no-preserve-root` para que un `rm -rf /` "funcione" | Elimina la única protección del sistema contra el error más caro posible | Si un comando pide esa bandera, es la señal de parar y revisar qué se está pidiendo, no de forzarlo |

## 5. Trucos

- `rm -I` es, en la práctica diaria, mejor punto de partida que `rm -i`
  para cualquier borrado que no sea un script ya probado: protege sin
  volverse tedioso.
- `ls carpeta/ | wc -l` antes de un `rm -rf carpeta/` confirma cuántos
  archivos vas a perder, en caso de duda sobre el contenido.
- Herramientas como `trash-cli` (instalable aparte) agregan un comando
  `trash` que sí usa una papelera real — vale la pena para quien quiere esa
  red de seguridad en el día a día, sin perder la velocidad de `rm` para
  scripts.
- `lsof +L1` lista archivos borrados que algún proceso todavía mantiene
  abiertos — la forma directa de confirmar el caso del log que "no libera
  espacio" después de un `rm`.

## Resumen

`rm` borra de inmediato, sin papelera: entiende eso antes de necesitarlo, no
después. `-I` da una red de seguridad barata sin volverse tedioso; `-rf` es
para scripts ya probados, no para el reflejo diario. Y el espacio real en
disco se libera recién cuando el contador de enlaces del inodo llega a cero
y ningún proceso lo tiene abierto — por eso un `rm` sobre un log activo no
libera espacio hasta que el proceso que lo escribe lo cierra.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — rm invocation](https://www.gnu.org/software/coreutils/manual/html_node/rm-invocation.html) — la referencia completa, incluida la explicación oficial de `--no-preserve-root`.
- `man rm` — la misma referencia, offline.
- `man 2 unlink` — la syscall real que ejecuta `rm` por detrás, para quien quiera el detalle a nivel de kernel.
- [trash-cli (GitHub)](https://github.com/andreafrancia/trash-cli) — la papelera de línea de comandos más usada, si decides que la quieres.

## ✅ Checklist de Verificación

- [ ] Reprodujiste la protección de `rm -rf /` y entendiste por qué existe
- [ ] Usaste `-I` en un borrado recursivo y confirmaste que solo pregunta una vez
- [ ] Practicaste el patrón de respaldo rápido (`cp -a` seguido de `rm -rf`) antes de un borrado importante
- [ ] Explicaste por qué una variable sin comillas en `rm -rf` es peligrosa
- [ ] Reprodujiste por qué `rm` sobre un archivo abierto por otro proceso no libera espacio de inmediato

---

[← 03 — Mover y renombrar](03-mover-y-renombrar.md) · [05 — stat y metadatos →](05-stat-y-metadatos.md)
