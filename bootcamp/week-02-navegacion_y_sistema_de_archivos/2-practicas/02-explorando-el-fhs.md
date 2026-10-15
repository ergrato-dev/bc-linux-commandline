# Práctica 02: Explorando el FHS

Esta práctica te hace recorrer los directorios de primer nivel con tus
propias manos, en vez de solo leer la tabla de la teoría.

## Paso 1: Recorrer la raíz con criterio

**Por qué**: ver la raíz completa de una sola vez, antes de entrar en
detalle, te da el mapa general antes de perderte en los detalles.

**Comando**:

```bash
ls -la /
```

**Verifica**: identificas al menos `/etc`, `/var`, `/usr`, `/home`, `/tmp`,
`/proc` en la lista.

## Paso 2: Confirmar el usr-merge

**Por qué**: es la demostración directa de que `/bin` no es una carpeta real
separada en Ubuntu 24.04, sino un enlace.

**Comando**:

```bash
ls -la / | grep -E '^l.*(bin|sbin|lib)( -> |$)'
readlink -f /bin
```

**Verifica**:

```bash
readlink -f /bin
# /usr/bin
```

## Paso 3: Buscar configuración en `/etc`

**Por qué**: entrenar el reflejo de "la configuración está en `/etc`" antes
de necesitarlo bajo presión en una semana futura.

**Comando**:

```bash
ls /etc | wc -l
cat /etc/os-release
ls /etc | grep -i ssh
```

**Verifica**: `/etc` tiene decenas de archivos y carpetas; `/etc/os-release`
confirma Ubuntu 24.04.

## Paso 4: Diferenciar `/usr` de `/var`

**Por qué**: confirmar con tus propios ojos la distinción conceptual entre
software instalado (no cambia solo) y datos que sí cambian mientras el
sistema corre.

**Comando**:

```bash
du -sh /usr 2>/dev/null
du -sh /var 2>/dev/null
ls /var/log | head -5
```

**Verifica**: `/usr` suele ser bastante más grande que `/var` en una imagen
recién instalada como esta — a medida que el sistema se usa, `/var` crece
con logs y cachés mientras `/usr` se mantiene relativamente estable.

## Paso 5: Explorar `/proc` como lo que es: una vista, no archivos reales

**Por qué**: `/proc` es el primer contacto con la idea de "sistema de
archivos virtual", que vas a reencontrar en la Semana 10 para leer el estado
de procesos.

**Comando**:

```bash
cat /proc/cpuinfo | grep "model name" | head -1
cat /proc/meminfo | head -3
ls /proc | grep -E '^[0-9]+$' | wc -l
```

**Verifica**: el último comando cuenta cuántos procesos hay vivos ahora
mismo, como directorios dentro de `/proc` — ninguno de estos archivos existe
en disco, el kernel los genera al leerlos.

## Paso 6: Comparar el FHS entre distros

**Por qué**: confirmar en la práctica que el estándar es el mismo, aunque el
"poblado" inicial de cada familia varíe.

**Comando**:

```bash
docker exec -it rhel-lab cat /etc/os-release | grep PRETTY_NAME
docker exec -it rhel-lab ls /etc/sysconfig 2>&1 | head -5

docker exec -it arch-lab cat /etc/os-release | grep PRETTY_NAME
docker exec -it arch-lab ls /var/log 2>&1 | wc -l
```

**Verifica**: `rhel-lab` tiene `/etc/sysconfig` (convención propia de esa
familia, no universal); `arch-lab` arranca con un `/var/log` mucho más vacío
que `ubuntu-lab`, reflejando su filosofía de base mínima.

## ✅ Resultado

- [ ] Confirmaste el usr-merge con `readlink -f /bin`
- [ ] Ubicaste configuración real en `/etc` sin adivinar
- [ ] Comparaste tamaño y propósito de `/usr` vs `/var`
- [ ] Exploraste `/proc` y contaste procesos vivos
- [ ] Comparaste al menos una divergencia real entre `ubuntu-lab`, `rhel-lab` y `arch-lab`

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `docker exec -it rhel-lab` o `arch-lab` dice "No such container" | Esos contenedores de exploración no están levantados | Correr `./scripts/start.sh` desde la raíz del repositorio — levanta los cuatro contenedores juntos |
| `du -sh /usr` tarda mucho o no responde | Ubuntu tiene muchos archivos pequeños en `/usr`; `du` recorre todo el árbol | Es normal que tarde unos segundos; si se cuelga por minutos, revisar `docker stats` |
| `/etc/sysconfig` no existe en `rhel-lab` | La imagen puede variar entre versiones de `rockylinux` | Confirmar la versión con `cat /etc/os-release`; el punto pedagógico (una convención propia de familia) se mantiene aunque el ejemplo puntual varíe |

---

[← Práctica 01](01-rutas-absolutas-y-relativas.md) · [Práctica 03 →](03-tipos-de-archivo-y-enlaces.md)
