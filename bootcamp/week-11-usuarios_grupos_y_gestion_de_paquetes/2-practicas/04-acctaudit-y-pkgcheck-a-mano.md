# Práctica 04: acctaudit y pkgcheck a mano

Esta práctica construye **a mano**, paso por paso, la lógica exacta que
después completas en el starter de `toolkit.sh`. Si entiendes cada paso de
aquí, completar los `TODO` es traducir esto a variables de bash.

Todo corre dentro de `ubuntu-lab`, sobre **archivos de prueba en `/tmp`**:
nunca tocas el `/etc/passwd` real.

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Preparar un directorio de cuentas limpio

**Por qué**: `acctaudit` recibe un directorio con `passwd`, `group` y
`shells` (archivo 07). Un directorio de prueba permite provocar cada
hallazgo sin crear usuarios peligrosos de verdad.

**Comando**:

```bash
base=/tmp/p11/limpio
mkdir -p "$base"
printf 'root:x:0:0:root:/root:/bin/bash\ndaemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin\nsync:x:4:65534:sync:/bin:/bin/sync\nana:x:1000:1000:Ana:/home/ana:/bin/bash\nluis:x:1001:1001:Luis:/home/luis:/bin/bash\n' > "$base/passwd"
printf 'root:x:0:\ndaemon:x:1:\nana:x:1000:\nluis:x:1001:\nnogroup:x:65534:\n' > "$base/group"
printf '# /etc/shells\n/bin/sh\n/bin/bash\n' > "$base/shells"
```

Una función que copia el directorio limpio y le añade **una** línea
problemática (y, si hace falta, una línea de grupo):

```bash
nuevo_caso() {
  local d="/tmp/p11/$1"
  rm -rf "$d"; cp -r "$base" "$d"
  printf '%s\n' "$2" >> "$d/passwd"
  [[ -n "${3:-}" ]] && printf '%s\n' "$3" >> "$d/group"
  echo "$d"
}
```

**Verifica**:

```bash
wc -l "$base/passwd" "$base/group" "$base/shells"
#  5 /tmp/p11/limpio/passwd
#  5 /tmp/p11/limpio/group
#  3 /tmp/p11/limpio/shells
#  13 total
```

## Paso 2: Las cuatro reglas, una a una

**Por qué**: cada regla evita un falso positivo concreto (archivo 07). Ver
cada una **sola** enseña qué condición la dispara.

**Comando** (regla *cuenta de sistema con shell*, la más sutil):

```bash
# NR == FNR: el primer archivo (shells) llena la tabla; el segundo (passwd) se evalua.
d=$(nuevo_caso sis 'svc:x:998:998:svc:/opt/svc:/bin/bash' 'svc:x:998:')
awk -F: 'NR == FNR { if ($0 !~ /^#/) v[$0]; next }
         $3 > 0 && $3 < 1000 && ($7 in v) { print "hallazgo: cuenta de sistema con shell: " $1 " (" $7 ")" }' \
    "$d/shells" "$d/passwd"
```

**Verifica**: solo `svc`; **`sync` no aparece** aunque su shell no sea
`nologin`, porque `/bin/sync` no figura en `shells`.

```bash
# hallazgo: cuenta de sistema con shell: svc (/bin/bash)
```

**Regla UID duplicado**:

```bash
d=$(nuevo_caso dup 'pepe:x:1001:1001:Pepe:/home/pepe:/bin/bash')
awk -F: '$3 != 0 { n[$3]++; q[$3] = q[$3] (n[$3] > 1 ? ", " : "") $1 }
         END { for (u in n) if (n[u] > 1) print "hallazgo: UID duplicado: " u " (" q[u] ")" }' "$d/passwd"
# hallazgo: UID duplicado: 1001 (luis, pepe)
```

**Regla grupo primario inexistente**:

```bash
d=$(nuevo_caso gid 'maria:x:1002:4242:Maria:/home/maria:/bin/bash')
awk -F: 'NR == FNR { g[$3]; next }
         !($4 in g) { print "hallazgo: grupo primario inexistente: " $1 " (GID " $4 ")" }' "$d/group" "$d/passwd"
# hallazgo: grupo primario inexistente: maria (GID 4242)
```

**Regla UID 0 extra**:

```bash
d=$(nuevo_caso uid0 'toor:x:0:0:toor:/root:/bin/bash')
awk -F: '$3 == 0 && $1 != "root" { print "hallazgo: UID 0 extra: " $1 }' "$d/passwd"
# hallazgo: UID 0 extra: toor
```

## Paso 3: Juntarlo todo con un código de salida

**Por qué**: el starter hace lo mismo en una sola pasada de `awk`, con tres
archivos y `FILENAME`. Aquí lo montas como una función y compruebas los
**tres** resultados: limpio, hallazgo y código.

**Comando**:

```bash
cat > /tmp/p11/auditar.sh <<'EOS'
auditar() {
  local etc="$1" hallazgos cantidad
  hallazgos=$(awk -F: -v shells="$etc/shells" -v groups="$etc/group" '
    FILENAME == shells { if ($0 !~ /^#/ && $0 != "") valida[$0] = 1; next }
    FILENAME == groups { gid[$3] = 1; next }
    NF < 7 { next }
    {
      if ($3 == 0 && $1 != "root") print "hallazgo: UID 0 extra: " $1
      if ($3 > 0 && $3 < 1000 && ($7 in valida)) print "hallazgo: cuenta de sistema con shell: " $1 " (" $7 ")"
      if (!($4 in gid)) print "hallazgo: grupo primario inexistente: " $1 " (GID " $4 ")"
      if ($3 != 0) { n[$3]++; quienes[$3] = quienes[$3] (n[$3] > 1 ? ", " : "") $1 }
    }
    END { for (u in n) if (n[u] > 1) print "hallazgo: UID duplicado: " u " (" quienes[u] ")" }
  ' "$etc/shells" "$etc/group" "$etc/passwd" | sort)
  cantidad=$(printf '%s\n' "$hallazgos" | grep -c .) || true
  if [[ "$cantidad" -eq 0 ]]; then echo "sin hallazgos"; return 0; fi
  echo "$hallazgos"; echo "hallazgos: $cantidad"; return 2
}
EOS
. /tmp/p11/auditar.sh
auditar "$base"; echo "codigo: $?"
```

**Verifica**: el directorio limpio no da hallazgos y devuelve `0`.

```bash
auditar "$base"; echo "codigo: $?"
# sin hallazgos
# codigo: 0

auditar "$(nuevo_caso uid0 'toor:x:0:0:toor:/root:/bin/bash')"; echo "codigo: $?"
# hallazgo: UID 0 extra: toor
# hallazgos: 1
# codigo: 2
```

Y con **varios problemas a la vez** (`sort` mantiene el orden estable):

```bash
d=$(nuevo_caso todos 'toor:x:0:0:toor:/root:/bin/bash')
printf '%s\n' 'svc:x:998:998:svc:/opt/svc:/bin/bash' 'pepe:x:1001:1001:Pepe:/home/pepe:/bin/bash' >> "$d/passwd"
auditar "$d"
# hallazgo: UID 0 extra: toor
# hallazgo: UID duplicado: 1001 (luis, pepe)
# hallazgo: cuenta de sistema con shell: svc (/bin/bash)
# hallazgo: grupo primario inexistente: svc (GID 998)
# hallazgos: 4
```

Observa el último: `svc` aparece **dos veces** porque, además de tener
shell de login, su grupo `998` no está en `group`. Dos reglas distintas,
dos hallazgos legítimos.

## Paso 4: Decidir el gestor de paquetes

**Por qué**: `pkgcheck` no pregunta "¿qué distro es?": pregunta qué
herramienta existe (archivo 07). Funciona igual en una derivada.

**Comando**:

```bash
for g in dpkg-query rpm pacman; do
  if command -v "$g" >/dev/null 2>&1; then echo "gestor: $g"; break; fi
done
```

**Verifica**:

```bash
# gestor: dpkg-query
```

## Paso 5: La versión instalada, la ausente y la trampa de `rc`

**Por qué**: "instalado" no es "la base de datos conoce el paquete". El
estado importa, y este paso lo enseña con un caso real.

**Comando**:

```bash
dpkg-query -W -f='${db:Status-Status} ${Version}\n' bash
dpkg-query -W -f='${db:Status-Status} ${Version}\n' paquete-inexistente; echo "codigo: $?"
```

**Verifica**:

```bash
dpkg-query -W -f='${db:Status-Status} ${Version}\n' bash
# installed 5.2.21-2ubuntu4

dpkg-query -W -f='${db:Status-Status} ${Version}\n' paquete-inexistente; echo "codigo: $?"
# dpkg-query: no packages found matching paquete-inexistente
# codigo: 1

# Quedarte solo con la version cuando el estado es "installed":
dpkg-query -W -f='${db:Status-Status} ${Version}\n' bash | awk '$1 == "installed" { print $2 }'
# 5.2.21-2ubuntu4
```

Ahora la trampa: un paquete quitado con `remove` (estado `rc`) **sigue
teniendo versión** en la base de `dpkg`:

```bash
apt-get update >/dev/null && apt-get install -y cron >/dev/null
apt-get remove -y cron >/dev/null
dpkg-query -W -f='${Version}\n' cron
# 3.0pl1-184ubuntu2                  <- tiene version pero NO esta instalado

dpkg-query -W -f='${db:Status-Status} ${Version}\n' cron
# config-files 3.0pl1-184ubuntu2     <- el estado lo delata: no es "installed"
```

Limpia lo instalado: `apt-get purge -y cron >/dev/null`.

## Paso 6: Pasarlo al starter

**Por qué**: ya tienes la lógica probada. Los `TODO` del starter son
exactamente estos pasos.

**Comando** (desde **tu máquina**, no desde el contenedor):

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
docker exec ubuntu-lab /root/bin/toolkit.sh pkgcheck bash
```

**Verifica**: mientras no completes los `TODO`, `pkgcheck bash` imprime
`gestor: TODO`; cuando termines, imprime `gestor: apt (dpkg)`.

## ✅ Resultado

- [ ] Provocaste cada una de las cuatro reglas por separado y viste su mensaje exacto
- [ ] Comprobaste que `sync` **no** se marca (`/bin/sync` no está en `shells`)
- [ ] Montaste `auditar` con código de salida `0` limpio y `2` con hallazgos
- [ ] Decidiste el gestor con `command -v`, sin mirar el nombre de la distro
- [ ] Viste que un paquete `rc` conserva versión pero no está instalado

```bash
./scripts/verificar-semana.sh 11
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `auditar` imprime `sin hallazgos` en un caso con problema | Pasaste `$base` en lugar del directorio devuelto por `nuevo_caso` | Usa `auditar "$(nuevo_caso ...)"` con las comillas |
| El awk del Paso 2 imprime todas las shells | Falta `next` tras llenar la tabla | Cada bloque de carga termina en `next` |
| `nuevo_caso: command not found` | Cerraste la shell entre pasos | Vuelve a pegar la función del Paso 1 |
| `auditar: command not found` | No hiciste `. /tmp/p11/auditar.sh` | Ejecuta `. /tmp/p11/auditar.sh` en la misma sesión |
| `dpkg-query` del Paso 5 no muestra `config-files` | El `cron` no se instaló o se purgó ya | Repite `apt-get install -y cron` y `remove` |

---

[← Práctica 03](03-paquetes-en-cuatro-familias.md) · [Proyecto: capa 11 de toolkit →](../3-proyecto/README.md)
