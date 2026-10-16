# Práctica 01: find básico y criterios

Esta práctica reproduce, dentro de `ubuntu-lab`, búsquedas por nombre,
tipo, profundidad y antigüedad contra un pequeño proyecto simulado.

## Paso 1: Preparar un proyecto de prueba

**Por qué**: un árbol con subdirectorios y archivos de distinta
antigüedad deja probar varios criterios de `find` sin inventar nada en
cada paso.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
mkdir -p ~/practica-wk09b && cd ~/practica-wk09b
mkdir -p proyecto/src proyecto/logs
touch proyecto/src/app.py proyecto/src/util.py proyecto/README.md
touch -d "40 days ago" proyecto/logs/viejo.log
touch -d "2 hours ago" proyecto/logs/nuevo.log
find proyecto
```

**Verifica**:

```bash
find proyecto -type f | wc -l
# 5
```

## Paso 2: Buscar por patrón de nombre

**Por qué**: confirmar `-name` con un patrón glob, entre comillas.

**Comando**:

```bash
find proyecto -name "*.py"
```

**Verifica**:

```bash
find proyecto -name "*.py" | wc -l
# 2
```

## Paso 3: Limitar la profundidad de la búsqueda

**Por qué**: confirmar que `-maxdepth` corta la búsqueda antes de bajar
a los subdirectorios.

**Comando**:

```bash
find proyecto -maxdepth 1 -type d
```

**Verifica**:

```bash
find proyecto -maxdepth 1 -type d | wc -l
# 3
```

`proyecto`, `proyecto/src` y `proyecto/logs` — ninguno más abajo.

## Paso 4: Filtrar por antigüedad

**Por qué**: confirmar `-mtime` con el signo correcto.

**Comando**:

```bash
find proyecto/logs -name "*.log" -mtime +7
```

**Verifica**:

```bash
find proyecto/logs -name "*.log" -mtime +7
# proyecto/logs/viejo.log
```

Solo el log de hace 40 días — el de hace 2 horas no cumple `+7` (más de
7 días).

## Paso 5: Reproducir el error de patrón sin comillas

**Por qué**: ver el error real antes de que te pase sin entender por
qué, en un script propio. Para que la shell tenga algo que expandir
"mal", hacen falta al menos dos archivos `.py` en el directorio
**actual** (no dentro de `proyecto/`).

**Comando**:

```bash
touch decoy1.py decoy2.py
find proyecto -name *.py
```

**Verifica**: el comando falla con un error de `find` sobre "paths must
precede expression" — la shell expandió `*.py` a `decoy1.py decoy2.py`
**antes** de que `find` viera el patrón.

```bash
find proyecto -name *.py 2>&1 | grep -c "must precede"
# 1
```

## ✅ Resultado

- [ ] Contaste archivos de un árbol completo con `find | wc -l`
- [ ] Buscaste por patrón de nombre con `-name`, entre comillas
- [ ] Limitaste la profundidad de una búsqueda con `-maxdepth`
- [ ] Filtraste por antigüedad con `-mtime +N`
- [ ] Reprodujiste el error de un patrón de `-name` sin comillas

```bash
./scripts/verificar-semana.sh 09
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 2 cuenta más o menos de 2 archivos | El árbol no se creó exactamente como en el Paso 1 | Recrear `proyecto/` desde cero con los comandos del Paso 1 |
| El Paso 4 no muestra `viejo.log` | El sistema no aceptó `touch -d "40 days ago"` como se esperaba | Confirmar con `stat proyecto/logs/viejo.log` que la fecha de modificación quedó en el pasado |
| El Paso 5 no produce ningún error | Hay menos de dos archivos `.py` en el directorio actual — con cero o uno, la shell no tiene nada ambiguo para expandir | Confirmar que `decoy1.py` y `decoy2.py` existen en el directorio actual con `ls *.py` antes de repetir el paso |

---

[← 07 — Construyendo finddupes](../1-teoria/07-construyendo-finddupes-find-xargs-hashing.md) · [Práctica 02 →](02-find-avanzado-logica-y-acciones.md)
