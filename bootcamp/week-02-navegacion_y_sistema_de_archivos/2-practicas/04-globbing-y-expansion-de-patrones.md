# Práctica 04: Globbing y expansión de patrones

Esta práctica te hace construir y previsualizar patrones de globbing antes
de ejecutarlos contra algo real — el hábito que evita un `rm` destructivo
por un patrón mal pensado.

## Paso 1: Preparar un directorio de prueba variado

**Por qué**: necesitas una mezcla de nombres para que los patrones de los
próximos pasos tengan sentido.

**Comando**:

```bash
mkdir -p /tmp/wk02-glob && cd /tmp/wk02-glob
touch informe1.txt informe2.txt informe10.txt notas.md .config.bak Reporte.txt
ls -a
```

**Verifica**: ves seis archivos listados, incluido el oculto `.config.bak`.

## Paso 2: Confirmar que bash expande el patrón, no el comando

**Por qué**: es la demostración directa de que `echo` solo recibe texto ya
resuelto — no sabe nada de archivos.

**Comando**:

```bash
echo *.txt
echo no-existe-nada*.xyz
```

**Verifica**: el primero imprime los nombres reales que matchean; el
segundo imprime el patrón **literal**, sin expandir, porque no hubo ninguna
coincidencia.

## Paso 3: Usar `?` para matchear exactamente un carácter

**Por qué**: distinguir `?` (un carácter) de `*` (cualquier cantidad) evita
sorpresas cuando los nombres tienen longitudes parecidas.

**Comando**:

```bash
ls informe?.txt
ls informe??.txt
```

**Verifica**: `informe?.txt` matchea `informe1.txt` e `informe2.txt` (un solo
dígito), pero no `informe10.txt` (dos dígitos); `informe??.txt` es al revés.

## Paso 4: Rangos y negación con corchetes

**Por qué**: practicar la sintaxis que vas a reutilizar constantemente para
filtrar por rango o excluir un patrón puntual.

**Comando**:

```bash
ls informe[12].txt
ls [!.]*
ls .*
```

**Verifica**: `[!.]*` excluye los ocultos (empieza con "no sea un punto");
`.*` muestra solo los ocultos, incluidos `.` y `..`.

## Paso 5: Reproducir y corregir el error de glob sin coincidencias

**Por qué**: entender el mensaje de error real, en vez de asumir "no
encuentra el archivo" literalmente.

**Comando**:

```bash
ls *.pdf
```

**Verifica**: el error menciona `*.pdf` como si fuera un nombre de archivo —
porque, sin coincidencias, bash lo dejó literal y así le llegó a `ls`.

```bash
shopt -s nullglob
archivos=(*.pdf)
echo "cantidad: ${#archivos[@]}"
shopt -u nullglob
```

**Verifica**: con `nullglob` activo, el array queda vacío (`cantidad: 0`) en
vez de contener el patrón literal.

## Paso 6: Expansión de llaves para crear estructura de una vez

**Por qué**: es el patrón real que vas a reutilizar para armar esqueletos de
carpetas sin repetir `mkdir` varias veces.

**Comando**:

```bash
mkdir -p /tmp/wk02-glob/proyecto/{src,docs,tests}
ls /tmp/wk02-glob/proyecto

cp /tmp/wk02-glob/notas.md{,.bak}
ls /tmp/wk02-glob/notas.md*
```

**Verifica**: las tres subcarpetas existen de una; `notas.md.bak` es una
copia exacta generada con un solo comando.

## ✅ Resultado

- [ ] Confirmaste con `echo` que un glob sin coincidencias queda literal
- [ ] Distinguiste `?` de `*` en la práctica, no solo en la teoría
- [ ] Usaste `[!.]*` y `.*` para separar ocultos de no ocultos
- [ ] Corregiste el comportamiento de "sin coincidencias" con `nullglob`
- [ ] Usaste expansión de llaves para crear estructura o respaldar un archivo

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ls *.pdf` no da error, lista algo inesperado | Puede haber un archivo llamado literalmente `*.pdf` de un paso anterior | Confirmar con `ls -a` qué existe realmente antes de interpretar el resultado |
| `nullglob` sigue mostrando el patrón literal | Olvidaste activarlo antes de la asignación al array, o lo desactivaste antes de leer el array | Verificar el orden: `shopt -s nullglob` → asignar el array → leer `${#array[@]}` → recién ahí `shopt -u nullglob` |
| `cp notas.md{,.bak}` da error de sintaxis | Falta la coma pegada a la llave de apertura sin espacio | La sintaxis exacta es `{,.bak}` — una coma, sin espacios, dentro de las llaves |

---

[← Práctica 03](03-tipos-de-archivo-y-enlaces.md) · [Proyecto: Capa 2 de toolkit →](../3-proyecto/README.md)
