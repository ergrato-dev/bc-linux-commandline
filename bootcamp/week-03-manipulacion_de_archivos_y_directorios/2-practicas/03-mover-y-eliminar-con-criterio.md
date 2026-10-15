# Práctica 03: Mover y eliminar con criterio

Esta práctica combina `mv` (incluida la medición de velocidad según el
disco) con `rm` usado de forma defendible, no por reflejo.

## Paso 1: Medir que mover dentro del mismo disco es instantáneo

**Por qué**: ver el tiempo real, no solo leer que "es instantáneo", fija la
razón detrás del comportamiento.

**Comando**:

```bash
cd /tmp/wk03
dd if=/dev/zero of=archivo-grande.bin bs=1M count=200 2>/dev/null
time mv archivo-grande.bin renombrado.bin
```

**Verifica**: el tiempo reportado por `time` es cercano a cero, sin importar
que el archivo pese 200 MB.

## Paso 2: Renombrar un directorio completo

**Por qué**: confirmar que `mv` funciona igual sobre directorios que sobre
archivos sueltos — es el mismo comando, la misma operación de fondo.

**Comando**:

```bash
mv entrantes-clon carpeta-renombrada
ls
```

**Verifica**: `carpeta-renombrada` existe con todo el contenido que tenía
`entrantes-clon`; `entrantes-clon` ya no aparece.

## Paso 3: Mover en lote con `--` para nombres riesgosos

**Por qué**: practicar el hábito de proteger contra nombres de archivo que
empiecen con guión, antes de que te pase con un nombre real.

**Comando**:

```bash
cd /tmp/wk03/entrantes
touch -- -extraño.txt
ls

mkdir -p ../procesados
for f in *.txt; do
  mv -n -- "$f" ../procesados/
done
ls ../procesados
```

**Verifica**: `-extraño.txt` se movió correctamente sin ser interpretado
como un flag.

## Paso 4: Reproducir la protección de `rm -rf /`

**Por qué**: ver el mensaje de protección real, sin ejecutar nada
destructivo de verdad.

**Comando**:

```bash
rm -rf /
```

**Verifica**:

```
rm: it is dangerous to operate recursively on '/'
rm: use --no-preserve-root to override this failsafe
```

El comando falla — **nunca** agregues `--no-preserve-root` para "hacerlo
funcionar". Esta práctica termina acá para este paso: ya viste la
protección, no hace falta ir más lejos.

## Paso 5: Borrado en lote con confirmación única

**Por qué**: `-I` es el punto medio entre "no preguntar nunca" y "preguntar
demasiado" — practicarlo lo vuelve el reflejo por defecto.

**Comando**:

```bash
cd /tmp/wk03
mkdir -p temporal && touch temporal/a temporal/b temporal/c temporal/d
rm -I -r temporal/
```

**Verifica**: aparece una sola pregunta de confirmación mencionando la
cantidad de archivos, no una por archivo.

## ✅ Resultado

- [ ] Mediste la diferencia de velocidad entre mover dentro del mismo disco y (si tienes otro punto de montaje) entre discos
- [ ] Renombraste un directorio completo con `mv`
- [ ] Protegiste un `mv` en lote con `--` contra nombres que empiezan con guión
- [ ] Viste la protección real de `rm -rf /` sin desactivarla
- [ ] Usaste `rm -I -r` para un borrado en lote con una sola confirmación

```bash
./scripts/verificar-semana.sh 03
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `time mv` muestra un tiempo notable incluso dentro del mismo disco | `/tmp` dentro del contenedor puede estar en un filesystem especial (tmpfs) con comportamiento distinto | Repetir contra una ruta dentro del sistema de archivos principal, por ejemplo `/root` |
| `touch -- -extraño.txt` falla igual | Falta el espacio entre `--` y el nombre, o el `--` se escribió mal | Confirmar la sintaxis exacta: dos guiones, un espacio, después el nombre |
| `rm -rf /` no muestra ninguna protección | Rarísimo en una instalación estándar de Ubuntu; podría ser una imagen modificada | No continuar investigando con comandos reales — reportarlo como hallazgo, no "probar a ver qué pasa" |

---

[← Práctica 02](02-copiar-archivos-y-directorios.md) · [Práctica 04 →](04-operaciones-seguras-por-lotes.md)
