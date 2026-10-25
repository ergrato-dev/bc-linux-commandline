# Práctica 06 — `harden` a mano (2/2): las cuatro auditorías

> Duración estimada: 60 min · Teoría de apoyo: archivos [05](../1-teoria/05-menor-privilegio-y-permisos.md), [06](../1-teoria/06-endurecer-unidades-y-ssh.md) y [08](../1-teoria/08-seguridad-de-contenedores-y-harden.md)

Continúas la [parte 1](05-harden-a-mano.md) con los `TODO` 5 a 8: `harden_unit`,
`harden_ssh`, `harden_perms` y `harden_container`. Necesitas `entregar()`, la
maqueta de `/tmp/wk19` y el `shellcheck` instalado, tal como los dejaste en la
parte 1 (si borraste la maqueta, rehaz el bloque de la parte 1). Cada paso se
prueba ejecutando `toolkit.sh` de verdad.

## Paso 1: TODO 5 — `harden_unit`

**Por qué**: un servicio como root, sin `NoNewPrivileges`, con el sistema escribible,
sin `/tmp` propio y con acceso a `/home` es el perfil de una unidad por defecto
(la que mediste en la Práctica 02 con 9,4).

**Comando**: `User` con `harden_line` directamente (tiene una excepción: `DynamicUser=yes`
sirve en su lugar) y las otras cuatro con `harden_check` y `harden_value last`:

```bash
  harden_check NoNewPrivileges "$(harden_value last NoNewPrivileges "$HD_POS")" '^(yes|true|1|on)$' "falta NoNewPrivileges=yes"
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden unit bad.service'; echo "rc=$?"
# riesgo User: corre como root (falta User= o DynamicUser=yes)
# riesgo NoNewPrivileges: falta NoNewPrivileges=yes
# riesgo ProtectSystem: falta ProtectSystem=strict
# riesgo PrivateTmp: falta PrivateTmp=yes
# riesgo ProtectHome: falta ProtectHome=yes
# hallazgos: 5
# rc=2
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden unit good.service --quiet'; echo "rc=$?"
# hallazgos: 0
# rc=0
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden unit last.service --quiet'; echo "rc=$?"
# riesgo NoNewPrivileges: falta NoNewPrivileges=yes
# riesgo ProtectSystem: falta ProtectSystem=strict
# riesgo ProtectHome: falta ProtectHome=yes
# hallazgos: 3
# rc=2
```

`last.service` demuestra la regla: `User=root` y luego `User=svc` (gana `svc`, ok), y
`PrivateTmp=no` y luego `yes` (gana `yes`, ok).

## Paso 2: TODO 6 — `harden_ssh`

**Por qué**: los valores **por defecto** también cuentan. Si `PasswordAuthentication`
no aparece, sshd usa `yes`: el archivo no dice que sea seguro, solo calla. Por eso un
`sshd_config` vacío debe dar riesgo en contraseñas.

**Comando**: `harden_value first` y `harden_check`. Dos particularidades: el patrón de
`PermitRootLogin` acepta el valor **vacío** (`...|forced-commands-only|)`) y el detalle
de `PasswordAuthentication` dice `por defecto, yes` si el valor está vacío:

```bash
  harden_check PasswordAuthentication "$v" '^no$' "admite contrasenas (valor: ${v:-por defecto, yes})"
```

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden ssh a.conf'; echo "rc=$?"
# riesgo PermitRootLogin: permite entrar como root (valor: yes)
# ok PasswordAuthentication
# ok PermitEmptyPasswords
# ok X11Forwarding
# hallazgos: 1
# rc=2
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden ssh e.conf --quiet'
# riesgo PasswordAuthentication: admite contrasenas (valor: por defecto, yes)
# hallazgos: 1
docker exec ubuntu-lab /root/bin/toolkit.sh harden ssh /etc/ssh/sshd_config --quiet
# riesgo PasswordAuthentication: admite contrasenas (valor: por defecto, yes)
# riesgo X11Forwarding: reenvia X11 (valor: yes)
# hallazgos: 2
```

En `a.conf` la primera `PermitRootLogin` es `yes` (riesgo, aunque después diga `no`) y
el `PermitEmptyPasswords yes` bajo `Match` ni se mira. El `sshd_config` real de Ubuntu
trae `X11Forwarding yes`.

## Paso 3: TODO 7 — `harden_perms`

**Por qué**: es la única auditoría que recorre el disco, y la única donde el **orden**
y los nombres raros importan. Los nombres pueden llevar espacios o saltos de línea
(Semana 09); el orden no puede depender del idioma del sistema.

**Comando**: cuatro `find`, en un bloque, ordenados con `LC_ALL=C sort -z`, leídos
desde una **sustitución de procesos**. Una tubería metería el `while` en un subshell
y `HD_COUNT` se perdería:

```bash
  while IFS=' ' read -r -d '' tipo ruta; do
    harden_line riesgo "$tipo" "$ruta"
  done < <(
    {
      find "$HD_POS" "${opciones[@]}" -type f -perm -4000 -printf 'suid %p\0'
      # ... sgid, escribible, dir-sin-sticky ...
    } | LC_ALL=C sort -z
  )
```

Si no hubo hallazgos (`HD_COUNT` igual que al empezar), `harden_line ok perms`.

**Verifica**:

```bash
entregar
docker exec ubuntu-lab bash -c 'cd /tmp/wk19
echo x > p/a && chmod 4755 p/a; echo x > p/b && chmod 2755 p/b
echo x > p/sub/w && chmod 666 p/sub/w; chmod 777 p/tmpd; mkdir p/st && chmod 1777 p/st
/root/bin/toolkit.sh harden perms p --quiet'; echo "rc=$?"
# riesgo dir-sin-sticky: p/tmpd
# riesgo escribible: p/sub/w
# riesgo sgid: p/b
# riesgo suid: p/a
# hallazgos: 4
# rc=2
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden perms p --depth 1 --quiet'
# riesgo dir-sin-sticky: p/tmpd
# riesgo sgid: p/b
# riesgo suid: p/a
# hallazgos: 3
docker exec ubuntu-lab bash -c 'cd /tmp/wk19; /root/bin/toolkit.sh harden perms clean'; echo "rc=$?"
# ok perms
# hallazgos: 0
# rc=0
```

El directorio `p/st` (`1777`, con sticky) **no** sale: es correcto. Con `--depth 1`
desaparece `p/sub/w`, que está a profundidad 2.

## Paso 4: TODO 8 — `harden_container`

**Por qué**: lee texto, no JSON: `docker inspect` es un JSON con una clave por línea, y
con `grep` es suficiente para estos cinco campos. (Un analizador JSON sería más
robusto, pero `ubuntu-lab` no tiene `jq` de serie; es un límite que el archivo 08
documenta.)

**Comando**: una comprobación por campo. La del usuario es la más fina:

```bash
  usuario=$(grep -m1 -E '"User":' "$HD_POS" | sed -E 's/.*"User": *"([^"]*)".*/\1/')
  if [[ -z "$usuario" || "$usuario" =~ ^(root|0)(:.*)?$ ]]; then
    harden_line riesgo User "corre como root (User vacio o root)"
  fi
```

`-m1` toma la **primera** línea con `"User":`. El patrón `^(root|0)(:.*)?$` cubre
`root`, `0`, `0:0` y `root:grupo`, pero no `rootless` ni `1000`.

**Verifica**:

```bash
entregar
printf '[\n{\n"HostConfig": {\n"NetworkMode": "host",\n"PortBindings": {"80/tcp": [{"HostIp": "0.0.0.0", "HostPort": "8080"}]},\n"Privileged": true,\n"ReadonlyRootfs": false\n},\n"Config": {\n"User": ""\n}\n}\n]\n' | docker exec -i ubuntu-lab sh -c 'cat > /tmp/wk19/bad.json'
printf '[\n{\n"HostConfig": {\n"NetworkMode": "bridge",\n"PortBindings": {"80/tcp": [{"HostIp": "127.0.0.1", "HostPort": "8080"}]},\n"Privileged": false,\n"ReadonlyRootfs": true\n},\n"Config": {\n"User": "1000"\n}\n}\n]\n' | docker exec -i ubuntu-lab sh -c 'cat > /tmp/wk19/good.json'
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/wk19/bad.json; echo "rc=$?"
# riesgo Privileged: el contenedor es privilegiado
# riesgo User: corre como root (User vacio o root)
# riesgo ReadonlyRootfs: el sistema de archivos raiz es escribible
# riesgo NetworkMode: comparte la red del anfitrion (host)
# riesgo Ports: hay puertos publicados en todas las interfaces
# hallazgos: 5
# rc=2
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/wk19/good.json --quiet; echo "rc=$?"
# hallazgos: 0
# rc=0
```

## Paso 5: `shellcheck`, y datos reales

**Por qué**: un script de auditoría con una errata de comillas puede dar un `ok`
falso, que es peor que no tener auditoría. `shellcheck` es la red de seguridad. Y el
último paso es el que de verdad importa: pasarle datos que **no** has fabricado.

**Comando**:

```bash
docker exec ubuntu-lab shellcheck /root/bin/toolkit.sh; echo "shellcheck=$?"
docker inspect ubuntu-lab | docker exec -i ubuntu-lab sh -c 'cat > /tmp/wk19/real.json'
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/wk19/real.json --quiet
docker exec ubuntu-lab /root/bin/toolkit.sh harden perms /usr/bin --depth 1 --quiet | tail -2
```

**Verifica**:

```bash
docker exec ubuntu-lab shellcheck /root/bin/toolkit.sh; echo "shellcheck=$?"
# shellcheck=0
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/wk19/real.json --quiet
# riesgo User: corre como root (User vacio o root)
# riesgo ReadonlyRootfs: el sistema de archivos raiz es escribible
# hallazgos: 2
docker exec ubuntu-lab /root/bin/toolkit.sh harden perms /usr/bin --depth 1 --quiet | tail -2
# riesgo suid: /usr/bin/umount
# hallazgos: 13
```

Cuando todo esto coincida, limpia la maqueta y pasa la verificación:

```bash
docker exec ubuntu-lab rm -rf /tmp/wk19
bash scripts/verificar-semana.sh 19
```

## ✅ Resultado

- [ ] Los ocho `TODO` están resueltos
- [ ] `harden unit`, `ssh`, `perms` y `container` dan la salida y el código esperados
- [ ] El código de salida es `0` sin hallazgos, `1` si el uso es incorrecto y `2` si hay riesgos
- [ ] `shellcheck` no avisa de nada
- [ ] `bash scripts/verificar-semana.sh 19` en verde

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `harden perms` da `hallazgos: 0` con riesgos reales | Usaste una tubería y `HD_COUNT` se perdió en el subshell | Sustitución de procesos: `done < <( ... )` |
| Los hallazgos de `perms` salen desordenados | Falta `LC_ALL=C sort -z` | Ordena el bloque `{ ...; }` completo |
| `rc=0` aunque hay riesgos | Tu `harden_line` no suma | Déjala como viene: ya cuenta `HD_COUNT` |
| `harden ssh` da `ok` en contraseñas con el archivo vacío | Falta contar el valor por defecto | Un valor vacío **no** casa con `^no$` |
| `shellcheck` avisa de `SC2154` o variable sin usar | Una variable del marcador quedó sin uso | Quita el `: "${...}"` cuando uses la variable |
| `toolkit.sh: Permission denied` tras `docker cp` | `cp` pierde el bit de ejecución | `entregar` ya hace `chmod +x` |

---

[← Práctica 05: `harden` a mano (1/2)](05-harden-a-mano.md) · [Proyecto: `toolkit harden` →](../3-proyecto/README.md)
