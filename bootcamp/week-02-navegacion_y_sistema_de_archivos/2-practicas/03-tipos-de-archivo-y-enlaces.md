# Práctica 03: Tipos de archivo y enlaces

Esta práctica combina lectura de `ls -l` con la creación de enlaces
simbólicos y duros, para que la diferencia entre ambos quede en las manos,
no solo en la teoría.

## Paso 1: Leer `ls -l` columna por columna, sin ayuda

**Por qué**: antes de automatizar nada con `toolkit.sh`, confirma que puedes
leer una línea de `ls -l` de corrido, sin contar con los dedos.

**Comando**:

```bash
ls -l /etc/hostname /etc/shadow /bin
```

**Verifica**: para cada línea, identificá en voz alta (o por escrito):
tipo, permisos, enlaces duros, dueño, grupo, tamaño, fecha, nombre. `/bin`
debería aparecer como enlace simbólico (`l` al inicio, con `->`).

## Paso 2: Confirmar tipos con `file`, no con la extensión

**Por qué**: la extensión de un nombre es una sugerencia, no una garantía —
esta es la comprobación real.

**Comando**:

```bash
echo "esto no es un pdf real" > /tmp/falso.pdf
file /tmp/falso.pdf
file /usr/bin/bash
file /etc/hostname
```

**Verifica**:

```bash
file /tmp/falso.pdf
# /tmp/falso.pdf: ASCII text
```

## Paso 3: Crear y romper un enlace simbólico

**Por qué**: ver un enlace roto con tus propios ojos es más efectivo que leer
sobre ellos — y vas a reconocerlos al instante de ahí en más.

**Comando**:

```bash
echo "contenido real" > /tmp/original.txt
ln -s /tmp/original.txt /tmp/enlace-simbolico
ls -l /tmp/enlace-simbolico

rm /tmp/original.txt
ls -l /tmp/enlace-simbolico
cat /tmp/enlace-simbolico
```

**Verifica**: después del `rm`, `ls -l` sigue mostrando el enlace (en rojo,
si tu terminal soporta colores), pero `cat` falla porque el destino ya no
existe.

## Paso 4: Crear un enlace duro y confirmar el inodo compartido

**Por qué**: la prueba definitiva de que un enlace duro no es una copia —
es el mismo contenido con otro nombre.

**Comando**:

```bash
echo "dato compartido" > /tmp/nombre-a.txt
ln /tmp/nombre-a.txt /tmp/nombre-b.txt

ls -li /tmp/nombre-a.txt /tmp/nombre-b.txt

echo "se agrego algo" >> /tmp/nombre-a.txt
cat /tmp/nombre-b.txt
```

**Verifica**: ambas líneas de `ls -li` muestran el mismo número de inodo (la
primera columna); `cat /tmp/nombre-b.txt` incluye la línea agregada por el
otro nombre.

## Paso 5: Borrar uno de los dos nombres del enlace duro

**Por qué**: confirma que el contenido sobrevive mientras quede al menos un
nombre apuntando al inodo.

**Comando**:

```bash
rm /tmp/nombre-a.txt
cat /tmp/nombre-b.txt
ls -l /tmp/nombre-b.txt
```

**Verifica**: el contenido sigue intacto en `/tmp/nombre-b.txt`, y el
contador de enlaces (columna 2 de `ls -l`) bajó de 2 a 1.

## ✅ Resultado

- [ ] Leíste tres líneas de `ls -l` completas sin ayuda
- [ ] Desenmascaraste un archivo con extensión falsa usando `file`
- [ ] Creaste y rompiste un enlace simbólico, y viste el efecto con `ls -l` y `cat`
- [ ] Creaste un enlace duro y confirmaste el inodo compartido con `ls -li`
- [ ] Borraste un nombre del enlace duro y confirmaste que el contenido sobrevivió

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ln /tmp/nombre-a.txt /tmp/nombre-b.txt` falla con "Invalid cross-device link" | Estás intentando crear un enlace duro entre dos sistemas de archivos distintos | Los enlaces duros requieren estar en la misma partición; prueba dentro de `/tmp` en vez de cruzar a otro punto de montaje |
| El enlace simbólico no aparece en rojo después del `rm` | Depende de la configuración de colores de tu terminal (`LS_COLORS`), no todos los temas lo marcan igual | Confirma con `ls -l` (sin depender del color) que el tamaño/fecha del destino ya no se puede leer con `cat` |
| `ls -li` muestra números de inodo distintos para el "enlace duro" | Probablemente usaste `ln -s` por error (creaste un simbólico, no un duro) | `ln` sin `-s` es el duro; `ln -s` es el simbólico — confirma cuál corriste |

---

[← Práctica 02](02-explorando-el-fhs.md) · [Práctica 04 →](04-globbing-y-expansion-de-patrones.md)
