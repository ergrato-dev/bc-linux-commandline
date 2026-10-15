# Práctica 01: Rutas absolutas y relativas

Esta práctica te hace recorrer el sistema de archivos de `ubuntu-lab` usando
solo lo visto en el primer archivo de teoría: rutas absolutas, relativas, y
los atajos `~`, `.`, `..`, `-`.

## Paso 1: Confirmar dónde estás parado, siempre

**Por qué**: antes de cualquier `cd`, saber tu punto de partida evita
confusiones sobre si una ruta es relativa a donde piensas o a donde
realmente estás.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
pwd
```

**Verifica**:

```bash
pwd
# /root   (o tu home, segun el usuario de la imagen)
```

## Paso 2: Moverte con rutas absolutas

**Por qué**: una ruta absoluta siempre apunta al mismo lugar, sin importar
desde dónde la escribas — es la forma más predecible de moverte.

**Comando**:

```bash
cd /var/log
pwd
cd /etc/systemd
pwd
```

**Verifica**:

```bash
pwd
# /etc/systemd
```

## Paso 3: La misma ruta relativa, dos resultados distintos

**Por qué**: esta es la demostración directa de por qué una ruta relativa
depende de dónde estás parado — el mismo texto, dos destinos diferentes.

**Comando**:

```bash
cd /etc
ls system | head -3

cd /usr/lib
ls system 2>&1 | head -3
```

**Verifica**: el primer `ls system` lista contenido real de
`/etc/systemd` (si existe esa subcarpeta); el segundo probablemente falla o
muestra algo completamente distinto — mismo texto `system`, resultados
distintos, según el directorio actual.

## Paso 4: Encadenar `..` para subir varios niveles

**Por qué**: contar niveles con `..` es más rápido que escribir una ruta
absoluta larga cuando solo necesitas subir unos pocos pasos.

**Comando**:

```bash
cd /usr/share/doc/bash
pwd
cd ../../../..
pwd
```

**Verifica**:

```bash
pwd
# /
```

## Paso 5: Usar `cd -` para alternar entre dos lugares

**Por qué**: es el atajo más rápido para ir y volver entre dos directorios
sin escribir ninguna ruta de memoria.

**Comando**:

```bash
cd /var/log
cd /etc
cd -
pwd
cd -
pwd
```

**Verifica**: el primer `cd -` te deja en `/var/log`; el segundo te devuelve
a `/etc` — alterna entre los dos últimos lugares cada vez que lo usas.

## Paso 6: `pwd` vs `pwd -P` con un enlace simbólico

**Por qué**: confirma en carne propia la diferencia entre la ruta "como la
escribiste" y la ruta real después de resolver enlaces.

**Comando**:

```bash
mkdir -p /tmp/real
ln -s /tmp/real /tmp/atajo
cd /tmp/atajo
pwd
pwd -P
```

**Verifica**:

```bash
pwd
# /tmp/atajo
pwd -P
# /tmp/real
```

## ✅ Resultado

- [ ] Te moviste con rutas absolutas y confirmaste el destino con `pwd`
- [ ] Reprodujiste cómo la misma ruta relativa apunta a dos lugares distintos
- [ ] Subiste varios niveles encadenando `..`
- [ ] Usaste `cd -` para alternar entre dos directorios
- [ ] Viste la diferencia entre `pwd` y `pwd -P` con un enlace simbólico propio

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `cd ..` repetido te deja en un lugar inesperado | Perdiste la cuenta de cuántos niveles subiste | Correr `pwd` después de cada `cd ..`, o usar la ruta absoluta si la conoces |
| `cd -` no vuelve adonde esperabas | `cd -` alterna entre los **dos últimos** lugares, no mantiene un historial completo | Revisar con `pwd` en cada paso; para más de dos lugares, usar `pushd`/`popd` (archivo 06 de teoría) |
| `pwd` y `pwd -P` muestran lo mismo | No hay ningún enlace simbólico en la ruta actual | Confirmar con `ls -la` que `/tmp/atajo` es realmente un enlace (`l` al inicio) |

---

[← 06 — Navegación eficiente](../1-teoria/06-navegacion-eficiente-pushd-popd-cdpath.md) · [Práctica 02 →](02-explorando-el-fhs.md)
