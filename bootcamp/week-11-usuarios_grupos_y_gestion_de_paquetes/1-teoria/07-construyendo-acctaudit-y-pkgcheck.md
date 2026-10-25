# Construyendo acctaudit y pkgcheck

> Este archivo cierra la semana combinando todo lo anterior en dos
> subcomandos de `toolkit.sh`: `acctaudit`, que audita las cuentas de una
> máquina, y `pkgcheck`, que pregunta al gestor de paquetes correcto si
> algo está instalado. Cada decisión de diseño evita un gotcha ya visto.

## 🎯 Objetivos

- Diseñar una auditoría que se pueda probar sin tocar el sistema real
- Combinar `awk` con tres archivos de entrada para aplicar cuatro reglas a la vez
- Detectar el gestor de paquetes de la máquina y consultar su base de datos
- Reconocer por qué cada decisión del diseño evita un error de los archivos anteriores

## 1. Qué problema resuelve

Dos preguntas de administración que, hasta ahora, respondías mirando
a ojo: "¿hay en esta máquina cuentas que no deberían estar así?" y "¿este
paquete está instalado, y en qué versión?". Hacerlo a mano con `cut` y
`dpkg -l` sirve una vez; en una auditoría semanal, o en un script de
`cron` (Semana 16), hace falta una herramienta con **códigos de salida**
que un programa pueda leer sin parsear texto.

`acctaudit` y `pkgcheck` repiten el patrón de todo `toolkit`:
`0` limpio, `1` entrada inválida, `2` hallazgo.

## 2. Cómo funciona

### 2.1 `acctaudit`: un directorio como argumento

```bash
toolkit.sh acctaudit            # audita /etc, el valor por defecto
toolkit.sh acctaudit /tmp/prueba   # audita un directorio con su propio passwd/group/shells
```

La decisión central: `acctaudit` **no tiene `/etc` escrito a fuego**,
recibe el directorio como argumento. Esto resuelve un problema de
verificación: para probar que detecta "un segundo UID 0" habría que
**crear de verdad** un usuario `toor` con UID 0 en el sistema, lo que es
un fallo de seguridad en sí mismo. Con un directorio de prueba
(`passwd`, `group` y `shells` falsos), todo se prueba sin tocar nada
real. Es el mismo principio de dry-run de `organize` (Semana 03) aplicado
al diseño: **la herramienta debe poder observar sin actuar**.

Lo primero que hace es comprobar que los tres archivos existen:

```bash
for archivo in passwd group shells; do
  if [[ ! -f "$etc/$archivo" ]]; then
    echo "toolkit acctaudit: falta '$etc/$archivo'" >&2
    exit 1
  fi
done
```

### 2.2 Contar por tipo de cuenta con un solo `awk`

```bash
conteos=$(awk -F: 'NF >= 7 {
  total++
  if ($3 < 1000) sistema++
  else if ($3 <= 60000) regulares++
} END { print total + 0, sistema + 0, regulares + 0 }' "$etc/passwd")
read -r total sistema regulares <<<"$conteos"
```

Tres detalles heredados de la Semana 08: `NF >= 7` ignora líneas
mal formadas o vacías; el `+ 0` del `END` fuerza un número cuando un
contador nunca se tocó (sin él, `awk` imprimiría una cadena vacía y
`read` asignaría mal); y los límites `1000` y `60000` son los
`UID_MIN`/`UID_MAX` del archivo 01.

### 2.3 Tres archivos, un `awk`, cuatro reglas

El corazón del subcomando. `awk` recibe **tres** archivos en este orden
y los distingue por `FILENAME`:

```bash
awk -F: -v shells="$etc/shells" -v groups="$etc/group" '
  FILENAME == shells { if ($0 !~ /^#/ && $0 != "") valida[$0] = 1; next }
  FILENAME == groups { gid[$3] = 1; next }
  NF < 7 { next }
  {
    if ($3 == 0 && $1 != "root") print "hallazgo: UID 0 extra: " $1
    if ($3 > 0 && $3 < 1000 && ($7 in valida))
      print "hallazgo: cuenta de sistema con shell: " $1 " (" $7 ")"
    if (!($4 in gid)) print "hallazgo: grupo primario inexistente: " $1 " (GID " $4 ")"
    if ($3 != 0) { n[$3]++; quienes[$3] = quienes[$3] (n[$3] > 1 ? ", " : "") $1 }
  }
  END { for (u in n) if (n[u] > 1) print "hallazgo: UID duplicado: " u " (" quienes[u] ")" }
' "$etc/shells" "$etc/group" "$etc/passwd" | sort
```

En la Semana 08 viste el truco `NR == FNR` para **dos** archivos. Con
tres no sirve (`NR == FNR` solo es cierto durante el primero), por eso se
compara el nombre del archivo en curso, `FILENAME`. Los archivos se
**cargan primero** (shells y grupos) y se **evalúan después** (passwd):
cuando `awk` llega a `passwd`, las tablas ya están llenas.

Las cuatro reglas, cada una con la decisión que evita un falso positivo:

| Regla | Condición | Falso positivo que evita |
|---|---|---|
| UID 0 extra | `$3 == 0 && $1 != "root"` | Nada: toda cuenta extra con UID 0 es root encubierto |
| Sistema con shell | UID entre 1 y 999 **y** shell en `/etc/shells` | `sync` (shell `/bin/sync`, no listada) no se marca (archivo 01) |
| Grupo inexistente | GID primario no está en `group` | Un grupo sin miembros extra existe igual: se busca el GID, no la lista de miembros |
| UID duplicado | Dos cuentas, mismo UID (salvo el 0) | El 0 ya lo cubre la regla uno: no se reporta dos veces |

Los resultados van por `| sort` para que el orden sea **estable** aunque
`awk` itere los arrays en orden arbitrario (el `END` recorre `n` con
`for (u in n)`).

### 2.4 El informe y el código de salida

```bash
hallazgos=$(awk ... | sort)
cantidad=$(printf '%s\n' "$hallazgos" | grep -c .) || true
if [[ "$cantidad" -eq 0 ]]; then
  echo "sin hallazgos"
  exit 0
fi
echo "$hallazgos"
echo "hallazgos: $cantidad"
exit 2
```

El mismo patrón `grep -c . || true` de las Semanas 07-10: cuenta líneas
**no vacías** de una variable que puede estar vacía, sin que `set -e`
corte el script cuando `grep -c` no encuentra nada que contar.

Una máquina limpia, con el directorio de prueba `/tmp/wk11-limpio`:

```bash
toolkit.sh acctaudit /tmp/wk11-limpio; echo "codigo: $?"
# == toolkit acctaudit ==
# directorio: /tmp/wk11-limpio
# cuentas totales: 6
# cuentas de sistema (UID < 1000): 3
# cuentas regulares (UID 1000-60000): 2
# sin hallazgos
# codigo: 0
```

Y una con una cuenta de servicio mal configurada (`svc` con UID 998 y
`/bin/bash`):

```bash
toolkit.sh acctaudit /tmp/wk11-sis; echo "codigo: $?"
# cuentas totales: 7
# cuentas de sistema (UID < 1000): 4
# cuentas regulares (UID 1000-60000): 2
# hallazgo: cuenta de sistema con shell: svc (/bin/bash)
# hallazgos: 1
# codigo: 2
```

Contra el `/etc` real de `ubuntu-lab` la salida es "sin hallazgos": las
imágenes oficiales vienen limpias, y `sync` **no** se marca gracias a
`/etc/shells`.

### 2.5 `pkgcheck`: detectar el gestor y preguntarle

```bash
if command -v dpkg-query >/dev/null 2>&1; then
  gestor="apt (dpkg)"
  version=$(dpkg-query -W -f='${db:Status-Status} ${Version}' "$paquete" 2>/dev/null \
    | awk '$1 == "installed" { print $2 }') || true
elif command -v rpm >/dev/null 2>&1; then
  gestor="dnf (rpm)"
  version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$paquete" 2>/dev/null) || version=""
elif command -v pacman >/dev/null 2>&1; then
  gestor="pacman"
  version=$(pacman -Q "$paquete" 2>/dev/null | awk '{ print $2 }') || true
else
  echo "toolkit pkgcheck: no encontre apt, dnf ni pacman en esta maquina" >&2
  exit 1
fi
```

Se consulta la **capa baja** (`dpkg-query`, `rpm`, `pacman -Q`) y no
`apt`/`dnf`: es la que responde "qué hay instalado" sin red (archivo 04) y
la que tiene salida estable para scripts. Se pregunta `command -v` por la
herramienta, no por el nombre de la distro: así funciona también en
derivadas (Mint, Alma, Manjaro) sin una lista de nombres.

Dos trampas que el código evita, ambas verificadas:

**1. Un paquete quitado con `remove` sigue en la base de `dpkg`.** El
archivo 05 mostró el estado `rc`. Si se preguntara solo por la versión,
`dpkg-query -W -f='${Version}'` la devolvería aunque el programa ya no
esté. Por eso se pide también `${db:Status-Status}` y solo se acepta
`installed`:

```bash
dpkg-query -W -f='${db:Status-Status} ${Version}\n' cron
# config-files 3.0pl1-184ubuntu2     <- quitado con remove: NO esta instalado
```

**2. `rpm -q` imprime el error por stdout.** Un paquete ausente produce
`package X is not installed` **en la salida estándar**, no en el error: si
se guardara tal cual, `version` contendría esa frase y `pkgcheck` diría
"instalado". Por eso solo se mira el **código de salida**
(`|| version=""`).

La misma lógica corre sin cambios en las cuatro familias (comprobado con
`mawk` en Ubuntu/Debian y `gawk` en Rocky/Arch):

```bash
toolkit.sh pkgcheck bash        # en ubuntu-lab
# gestor: apt (dpkg)
# estado: instalado
# version: 5.2.21-2ubuntu4

toolkit.sh pkgcheck bash        # en rhel-lab
# gestor: dnf (rpm)
# estado: instalado
# version: 5.1.8-6.el9_1

toolkit.sh pkgcheck bash        # en arch-lab
# gestor: pacman
# estado: instalado
# version: 5.3.20-1
```

### 2.6 Los códigos de salida

| Código | `acctaudit` | `pkgcheck` |
|:--:|---|---|
| `0` | Sin hallazgos | Paquete instalado |
| `1` | Faltan `passwd`, `group` o `shells` en el directorio | Sin nombre de paquete, o sin gestor reconocido |
| `2` | Hay al menos un hallazgo | Paquete no instalado |

Un script de monitoreo puede reaccionar solo con `$?`:

```bash
toolkit.sh pkgcheck sudo || echo "sudo no esta instalado: instalalo antes de continuar" >&2
```

## 3. Cómo se usa

```bash
# Auditar las cuentas reales de la maquina
toolkit.sh acctaudit

# Auditar una copia de /etc traida de otro servidor (analisis forense sin riesgo)
toolkit.sh acctaudit /srv/evidencia/etc

# Un cron semanal que avisa SOLO si hay hallazgos (Semana 16)
toolkit.sh acctaudit >/dev/null || echo "revisar cuentas de $(hostname)" >&2

# Comprobar prerrequisitos de un script
toolkit.sh pkgcheck sudo
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir `/etc/passwd` a fuego en la herramienta | Para probar las reglas habría que modificar las cuentas reales | Recibir el directorio como argumento, con `/etc` como valor por defecto |
| Marcar "toda cuenta de sistema sin `nologin`" | `sync` y otras con shell no listada dan falsos positivos | Comparar contra `/etc/shells`, la definición real de "shell de login" |
| Decidir "instalado" por la **versión**, no por el estado | Un paquete quitado con `remove` conserva versión en `dpkg` | Pedir también el estado (`${db:Status-Status}`) y exigir `installed` |
| Guardar la salida de `rpm -q` sin mirar su código | El mensaje "not installed" sale por stdout y se tomaría por una versión | Decidir por el código de salida |
| Parsear `dpkg -l` con `awk` | La tabla recorta nombres y cambia de ancho | `dpkg-query -W -f=` con el formato que tú eliges |

## 5. Trucos

- `toolkit.sh acctaudit /ruta` sobre una copia de `/etc` de **otro
  servidor** audita su estado sin entrar en él: basta con traer `passwd`,
  `group` y `shells`.
- Probar `pkgcheck` primero con `bash` (siempre instalado) y con un nombre
  inventado confirma las dos ramas del código de salida antes de
  fiarte del resultado.
- Si una nueva regla de `acctaudit` produce ruido, añádela primero como
  **hallazgo informativo** y revisa a mano su salida contra un `/etc`
  real: es la forma de calibrar antes de que alerte a nadie.

## 📚 Recursos Adicionales

- `man awk`, `man dpkg-query` (sección *Output format*), `man rpm` (`--queryformat`)
- Archivos 01 y 04 de esta semana, que explican de dónde sale cada dato

## ✅ Checklist de Verificación

- [ ] `toolkit.sh acctaudit /tmp/inexistente` sale con código `1`
- [ ] Con un `passwd` de prueba que repite el UID `1001`, `acctaudit` imprime `UID duplicado: 1001` y sale con `2`
- [ ] `toolkit.sh pkgcheck bash` imprime `estado: instalado` y una versión
- [ ] `toolkit.sh pkgcheck paquete-inventado` sale con código `2`
- [ ] `./scripts/verificar-semana.sh 11` termina con `16/16 comprobaciones superadas.`

---

[← 06 — Repositorios, firmas y confianza](06-repositorios-firmas-y-confianza.md) · [Práctica 01 →](../2-practicas/01-usuarios-y-grupos-reales.md)
