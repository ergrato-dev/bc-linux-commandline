# Práctica 03: Dominar historial y atajos

Esta práctica reemplaza el hábito de "flecha arriba quince veces" por los
atajos reales de readline y el historial de bash.

## Paso 1: Generar historial real para trabajar

**Por qué**: necesitas algunas líneas variadas en el historial antes de
poder buscarlas o repetirlas con sentido.

**Comando**:

```bash
cat /etc/os-release
ls -la /etc | head -5
whoami
uname -a
echo "fin de la generacion de historial"
```

**Verifica**:

```bash
history | tail -5
```

## Paso 2: Búsqueda incremental con `Ctrl+R`

**Por qué**: es la forma más rápida de reencontrar un comando largo sin
escribirlo de nuevo ni contar cuántas veces apretar la flecha arriba.

**Comando** (interactivo, no se "pega" como texto):

```
Ctrl+R
escribe: os-release
```

**Verifica**: la línea del prompt cambia a `(reverse-i-search)` y muestra
`cat /etc/os-release` resaltado. Aprieta `Enter` para ejecutarlo, o `Ctrl+G`
para cancelar sin correr nada.

## Paso 3: Repetir con `!!` y reutilizar argumentos con `!$`

**Por qué**: son los dos atajos de expansión de historial que más vas a usar
en los scripts y prácticas del resto del bootcamp.

**Comando**:

```bash
mkdir -p /tmp/practica03
cd !$
pwd
```

```bash
echo "necesita sudo esto"
sudo !!
```

**Verifica**: `cd !$` te deja parado en `/tmp/practica03` sin haber escrito
la ruta dos veces. El segundo bloque antepone `sudo` al comando anterior
exacto.

## Paso 4: Editar la línea sin backspace

**Por qué**: corregir un comando largo con quince backspaces es más lento que
tres atajos de readline.

**Comando** (practica cada uno sobre esta línea, sin ejecutarla):

```bash
echo "esta es una linea de prueba para practicar atajos de edicion"
```

- `Ctrl+A` → cursor al inicio
- `Ctrl+E` → cursor al final
- `Alt+B` tres veces → retrocede tres palabras
- `Ctrl+W` → borra la palabra anterior al cursor
- `Ctrl+U` → borra todo antes del cursor

**Verifica**: después de `Ctrl+U` parado en algún punto de la línea, lo que
queda a la derecha del cursor original sigue intacto — solo se borró lo de
la izquierda.

## Paso 5: Configurar `histappend` para no perder historial entre sesiones

**Por qué**: sin esto, si tienes dos terminales abiertas, la que cierra
último "gana" y pisa el historial que la otra ya había guardado.

**Comando**:

```bash
cat >> ~/.bashrc << 'EOF'

shopt -s histappend
EOF

source ~/.bashrc
```

**Verifica**:

```bash
shopt histappend
# histappend     	on
```

## ✅ Resultado

- [ ] Usaste `Ctrl+R` para encontrar un comando sin escribirlo de nuevo
- [ ] Usaste `!!` con `sudo` y `!$` para reutilizar un argumento
- [ ] Practicaste al menos cuatro atajos de edición de línea sin backspace
- [ ] `histappend` quedó activo en `~/.bashrc`

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Ctrl+R` no hace nada visible | El terminal no está en modo readline interactivo, o hay un `.inputrc` conflictivo | Confirmar `set -o` incluye `emacs on`; revisar si existe un `~/.inputrc` que redefine atajos |
| `!!` ejecuta un comando distinto al esperado | Hubo un comando intermedio que no viste (por ejemplo, de autocompletado) | Revisar `history | tail -3` antes de usar `!!` para confirmar qué es "el último" realmente |
| `shopt histappend` dice `off` después de `source` | El bloque se agregó pero el `source` se ejecutó en otra sesión | Verificar que estás en la misma sesión donde editaste `~/.bashrc`, y repetir `source ~/.bashrc` |

---

[← Práctica 02](02-navegar-la-ayuda-y-el-manual.md) · [Práctica 04 →](04-builtins-externos-y-tu-path.md)
