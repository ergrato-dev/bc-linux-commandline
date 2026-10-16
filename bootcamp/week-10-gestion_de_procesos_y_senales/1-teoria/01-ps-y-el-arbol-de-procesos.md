# ps y el árbol de procesos

> Todo proceso en Linux tiene un padre, salvo el primero. Esa relación
> — quién creó a quién — es lo que explica qué pasa cuando un proceso
> termina, qué hereda, y por qué matar al padre no siempre mata a los
> hijos. `ps` es la ventana a ese árbol completo.

## 🎯 Objetivos

- Leer las columnas esenciales de `ps`: PID, PPID, STAT, CMD
- Interpretar los códigos más comunes de la columna STAT
- Visualizar la jerarquía de procesos con `ps --forest`/`-ejH`
- Buscar procesos por nombre con `pgrep`, entendiendo contra qué compara por defecto

## 1. Qué problema resuelve

"¿Qué proceso es este PID?", "¿quién lo inició?", "¿está realmente
corriendo o colgado?" — preguntas que no se responden mirando una lista
plana de nombres. `ps` expone el estado real de cada proceso: su
identidad (PID), su origen (PPID), y su condición actual (STAT) — la
base para cualquier decisión sobre qué hacer con él.

> **Divergencia de distro**: `ps`/`pgrep`/`pkill` vienen del paquete
> `procps` — preinstalado en `ubuntu-lab` y `arch-lab`, pero ausente en
> imágenes mínimas de `debian-lab`/`rhel-lab` (hay que instalarlo
> explícitamente). Ver
> [`docs/divergencia-distros.md`](../../../docs/divergencia-distros.md).

## 2. Cómo funciona

### 2.1 Columnas esenciales: PID, PPID, STAT, CMD

```bash
ps -eo pid,ppid,stat,cmd | head -3
```

```
    PID    PPID STAT CMD
      1       0 Ss+  sleep infinity
   2054       1 Z    [bash] <defunct>
```

| Columna | Significa |
|---|---|
| PID | identificador único del proceso |
| PPID | PID del proceso padre — quién lo creó |
| STAT | estado actual (sección 2.2) |
| CMD | el comando, tal como se invocó |

`-eo` elige exactamente qué columnas mostrar, en el orden que se
pida — más control que `ps aux` (que trae un conjunto fijo de
columnas) cuando solo interesan algunas.

### 2.2 Los códigos de STAT más comunes

| Código | Significa |
|:--:|---|
| `R` | *Running* — ejecutando o lista para ejecutar |
| `S` | *Sleeping* — esperando un evento (interrumpible) |
| `D` | esperando E/S (no interrumpible) |
| `T` | detenido (por una señal, o en depuración) |
| `Z` | *Zombie* — terminó, pero el padre no lo "recogió" todavía (archivo 02) |

Modificadores que se agregan al código principal:

| Modificador | Significa |
|:--:|---|
| `+` | está en el grupo de procesos de foreground de su terminal |
| `s` | es líder de sesión |
| `<` | prioridad alta |
| `l` | multi-hilo |

```bash
sleep 5 & spid=$!
kill -STOP "$spid"; ps -p "$spid" -o pid,stat   # T
kill -CONT "$spid"; ps -p "$spid" -o pid,stat   # S
```

`SIGSTOP` pausa un proceso (STAT pasa a `T`) sin terminarlo;
`SIGCONT` lo reanuda — la misma pausa que produce `Ctrl+Z` en una
sesión interactiva, vista aquí de forma explícita con señales
(profundizado en el archivo 04 de esta semana).

### 2.3 Visualizar la jerarquía: `--forest` / `-ejH`

```bash
ps -ejH | head -5
```

```
    PID    PGID     SID TTY          TIME CMD
   3839    3839    3839 ?        00:00:00 bash
   3849    3839    3839 ?        00:00:00   ps
   3850    3839    3839 ?        00:00:00   head
```

La indentación muestra la relación padre-hijo visualmente — `ps` y
`head` aparecen debajo de `bash` porque son procesos que `bash` generó
para ejecutar ese mismo comando. `--forest` (equivalente, más legible)
hace lo mismo con cualquier selección de columnas.

### 2.4 `pgrep`: buscar procesos por nombre, no por línea de `ps`

```bash
pgrep sleep
```

`pgrep` evita el patrón `ps aux | grep patron` (y su antipatrón de
automatchearse, visto en la Semana 06) — busca directo, sin necesitar
`grep` en absoluto. Pero por defecto, compara contra el **nombre del
proceso** (`comm`, limitado a 15 caracteres por el kernel), no contra
la línea de comando completa:

```bash
pgrep nombre-de-proceso-muy-largo
```

```
pgrep: pattern that searches for process name longer than 15 characters will result in zero matches
Try `pgrep -f' option to match against the complete command line.
```

Un patrón de más de 15 caracteres **nunca** puede coincidir contra
`comm` — `pgrep` avisa de esto explícitamente, en vez de fallar en
silencio. `-f` (buscar contra la línea de comando completa) existe para
este caso, con una salvedad importante que el archivo 06 de esta semana
cubre en detalle.

### 2.5 `/proc`: la fuente real detrás de `ps`

```bash
cat /proc/1/status | head -5
```

```
Name:	sleep
Umask:	0022
State:	S (sleeping)
Tgid:	1
Ngid:	0
```

`ps` no tiene magia propia — lee exactamente esta información desde
`/proc/PID/status` (y archivos vecinos) por cada proceso. `State: S
(sleeping)` es, literalmente, el mismo dato que `ps` resume como `S`
en la columna STAT. Cuando `ps` no está disponible (un contenedor muy
mínimo) o hace falta un dato que no expone directamente, `/proc`
siempre está ahí, en bruto.

### 2.6 Ordenar por uso de recursos

```bash
ps -eo pid,%mem,%cpu,cmd --sort=-%mem | head -4
```

`--sort=-%mem` ordena de mayor a menor uso de memoria (el signo `-`
invierte el orden, igual que en `find`/`sort` de semanas anteriores)
— útil para encontrar rápido qué proceso está consumiendo más,
sin tener que leer la lista completa a ojo.

## 3. Cómo se usa

```bash
# Ver el estado completo de un proceso especifico
ps -p 1234 -o pid,ppid,stat,%cpu,%mem,cmd

# Confirmar si un proceso esta realmente corriendo o colgado
ps -o stat= -p 1234

# Arbol completo de procesos del sistema
ps -ejH

# Buscar todos los procesos de un usuario
ps -u www-data -o pid,cmd
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Asumir que un PID visto hace un rato sigue siendo el mismo proceso | Los PID se reciclan — un PID que existía puede corresponder a un proceso completamente distinto más tarde | Confirmar con `ps -p PID -o cmd` antes de actuar sobre un PID que no se acaba de consultar |
| Usar `ps aux \| grep patron` cuando `pgrep patron` hace lo mismo sin el antipatrón de automatchearse | Un paso de más, con el riesgo ya visto de que el propio `grep` aparezca en el resultado | `pgrep`/`pgrep -a` para buscar procesos por nombre directamente |
| Esperar que `pgrep patron` encuentre algo cuando el patrón tiene más de 15 caracteres | `comm` (lo que compara `pgrep` por defecto) está truncado a 15 caracteres a nivel de kernel — no es un límite de `pgrep`, es un límite del sistema | Usar un patrón de 15 caracteres o menos, o `-f` para comparar contra la línea de comando completa (con la salvedad del archivo 06) |
| Confundir STAT `D` con un proceso colgado | `D` (esperando E/S no interrumpible) es normal durante una operación de disco lenta — no significa que el proceso esté roto | Esperar y volver a revisar; un `D` persistente por mucho tiempo sí es señal de un problema real de E/S |

## 5. Trucos

- `ps -eo pid,ppid,stat,cmd --sort=-pid` ordena por PID descendente —
  útil para ver los procesos más recientes primero, sin otro comando.
- `ps -p $$ -o pid,ppid,cmd` muestra la información del propio shell
  actual — útil para confirmar en qué proceso estás parado.
- `watch -n1 'ps -eo pid,stat,cmd | grep patron'` (si `watch` está
  instalado) refresca la vista de un proceso cada segundo, sin tener
  que repetir el comando a mano.

## Resumen

`ps -eo pid,ppid,stat,cmd` expone la identidad, el origen y el estado
de cada proceso. STAT usa códigos de una letra (`R`, `S`, `D`, `T`,
`Z`) más modificadores. `-ejH`/`--forest` visualiza la jerarquía
padre-hijo con indentación. `pgrep` busca por nombre sin el antipatrón
de `ps | grep`, pero compara contra `comm` (truncado a 15 caracteres)
por defecto, no contra la línea de comando completa.

## 📚 Recursos Adicionales

- [man7.org — ps(1)](https://man7.org/linux/man-pages/man1/ps.1.html) — referencia completa de columnas y códigos de STAT.
- [man7.org — pgrep(1)](https://man7.org/linux/man-pages/man1/pgrep.1.html) — comportamiento exacto de `-f` y el resto de banderas.

## ✅ Checklist de Verificación

- [ ] Leíste PID, PPID, STAT y CMD de un proceso real con `ps -eo`
- [ ] Reprodujiste el cambio de STAT entre `S` y `T` con `SIGSTOP`/`SIGCONT`
- [ ] Visualizaste la jerarquía de procesos con `ps -ejH`
- [ ] Buscaste un proceso por nombre con `pgrep`, sin usar `grep`
- [ ] Reprodujiste el límite de 15 caracteres de `pgrep` sin `-f`

---

[← Semana 10](../README.md) · [02 — Estados de proceso: zombies y huérfanos →](02-estados-de-proceso-zombies-y-huerfanos.md)
