# Práctica 02: Escribir, verificar y endurecer una unidad

> Duración: 60 min · Teoría: archivos [03](../1-teoria/03-escribir-y-verificar-una-unidad.md) y [06](../1-teoria/06-endurecer-unidades-y-ssh.md)

Esta práctica **sí** se hace en `ubuntu-lab`: `systemd-analyze verify|security|calendar`
y `systemctl --root=DIR enable` leen archivos y no necesitan systemd en marcha.
Trabajas en `/tmp/sd`, dentro del contenedor; no se instala nada en el sistema.

Los comandos se lanzan desde el anfitrión con `docker exec`. Para no repetirlo,
abre una shell dentro y trabaja ahí:

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Crear la unidad de trabajo

**Por qué**: una unidad `oneshot` es la forma de systemd de una tarea puntual,
como las que programaste en la Semana 16. Escribirla en un directorio de trabajo
y no en `/etc` te deja equivocarte sin consecuencias.

**Comando**:

```bash
rm -rf /tmp/sd && mkdir -p /tmp/sd/etc/systemd/system && cd /tmp/sd
# ExecStart lleva ruta absoluta: systemd no usa tu PATH.
cat > job.service <<'EOF'
[Unit]
Description=Practica: limpieza de temporales

[Service]
Type=oneshot
ExecStart=/usr/bin/find /var/tmp -xdev -name '*.tmp' -mtime +7 -print

[Install]
WantedBy=multi-user.target
EOF
```

**Verifica**:

```bash
grep -c '^\[' job.service
# 3
```

## Paso 2: Verificar una unidad correcta

**Por qué**: `verify` carga la unidad como lo haría systemd. Una unidad sana no
imprime nada y devuelve `0`: el silencio es el éxito.

**Comando**:

```bash
systemd-analyze verify ./job.service; echo "rc=$?"
```

**Verifica**:

```bash
systemd-analyze verify ./job.service; echo "rc=$?"
# rc=0
```

## Paso 3: Provocar un error (ruta inexistente)

**Por qué**: el fallo más frecuente es una ruta mal escrita. `verify` lo detecta
con código `1` antes de que la unidad llegue a ejecutarse.

**Comando**:

```bash
# fnid en vez de find: una errata de tecleo.
sed 's#/usr/bin/find#/usr/bin/fnid#' job.service > bad.service
systemd-analyze verify ./bad.service; echo "rc=$?"
```

**Verifica**:

```bash
systemd-analyze verify ./bad.service 2>&1 | head -1
# bad.service: Command /usr/bin/fnid is not executable: No such file or directory
systemd-analyze verify ./bad.service >/dev/null 2>&1; echo "rc=$?"
# rc=1
```

## Paso 4: Provocar un aviso (clave desconocida)

**Por qué**: una errata en el **nombre** de una directiva es un *aviso*: systemd la
ignora y el código sigue siendo `0`. Una comprobación que solo mire `rc` la dejaría pasar.

**Comando**:

```bash
# Restar en vez de Restart. Al estar al final del archivo cae en [Install].
{ cat job.service; echo 'Restar=on-failure'; } > typo.service
systemd-analyze verify ./typo.service; echo "rc=$?"
```

**Verifica**:

```bash
systemd-analyze verify ./typo.service 2>&1 | grep -c 'Unknown key name'
# 1
systemd-analyze verify ./typo.service >/dev/null 2>&1; echo "rc=$?"
# rc=0
```

## Paso 5: El temporizador y su calendario

**Por qué**: `OnCalendar=` tiene una sintaxis propia. `calendar` la traduce y te
dice si es válida **antes** de esperar a las 3:30 para descubrir que no lo era.

**Comando**:

```bash
cat > job.timer <<'EOF'
[Timer]
OnCalendar=Mon..Fri *-*-* 03:30
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemd-analyze verify ./job.timer ./job.service; echo "rc=$?"
systemd-analyze calendar 'Mon..Fri *-*-* 03:30' | grep Normalized
systemd-analyze calendar 'Mon..Fri 25:00'; echo "rc=$?"
```

**Verifica**:

```bash
systemd-analyze calendar 'Mon..Fri *-*-* 03:30' | grep Normalized
# Normalized form: Mon..Fri *-*-* 03:30:00
systemd-analyze calendar 'Mon..Fri 25:00' 2>&1; echo "rc=$?"
# Failed to parse calendar specification 'Mon..Fri 25:00': Invalid argument
# rc=1
```

## Paso 6: Medir la exposición de partida

**Por qué**: una unidad **válida** puede estar muy expuesta. `security --offline`
la puntúa de 0 a 10 leyendo solo el archivo; esta es la línea base contra la que
medirás lo que añadas.

**Comando**:

```bash
systemd-analyze security --offline=true ./job.service --no-pager | tail -1
```

**Verifica**:

```bash
systemd-analyze security --offline=true ./job.service --no-pager | tail -1
# → Overall exposure level for job.service: 9.4 UNSAFE :-{
```

## Paso 7: Endurecer con un drop-in

**Por qué**: un drop-in añade directivas sin tocar el archivo base (archivo 01 y 06).
Aquí no escribimos al azar: cada línea cierra una familia de riesgos.

**Comando**:

```bash
mkdir job.service.d
cat > job.service.d/10-hard.conf <<'EOF'
[Service]
DynamicUser=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=yes
SystemCallFilter=@system-service
CapabilityBoundingSet=
EOF
systemd-analyze security --offline=true ./job.service --no-pager | tail -1
systemd-analyze verify ./job.service; echo "rc=$?"
```

**Verifica**:

```bash
systemd-analyze security --offline=true ./job.service --no-pager | tail -1
# → Overall exposure level for job.service: 2.0 OK :-)
systemd-analyze verify ./job.service; echo "rc=$?"
# rc=0
```

> ⚠️ La nota baja, pero **no hemos ejecutado la tarea** con estas restricciones.
> Este `find` solo lee `/var/tmp`, así que `ProtectSystem=strict` no lo rompe;
> una tarea que escribiera fuera de `ReadWritePaths=` sí fallaría. En una máquina
> real: reiniciar, `journalctl -u`, y recién entonces dar por buena la unidad.

## Paso 8: Ver la unidad efectiva con `cat-config`

**Por qué**: con el drop-in, la unidad real ya no es solo `job.service`. `cat-config`
muestra el archivo base **más** sus fragmentos, con el origen de cada uno.

**Comando**:

```bash
# La raiz de busqueda es /tmp/sd, asi que copiamos alli la unidad y su drop-in.
cp job.service etc/systemd/system/ && cp -r job.service.d etc/systemd/system/
systemd-analyze --root=/tmp/sd cat-config systemd/system/job.service | grep -E '^# '
```

**Verifica**:

```bash
systemd-analyze --root=/tmp/sd cat-config systemd/system/job.service | grep -E '^# '
# # /tmp/sd/etc/systemd/system/job.service
# # /tmp/sd/etc/systemd/system/job.service.d/10-hard.conf
```

## Paso 9: Activar y desactivar sin systemd

**Por qué**: `enable` solo **crea un enlace simbólico** según la sección `[Install]`.
Con `--root` lo haces sobre un directorio de prueba y ves exactamente qué crea.

**Comando**:

```bash
cp job.timer etc/systemd/system/
systemctl --root=/tmp/sd enable job.timer 2>&1 | grep -v 'non-existent'
systemctl --root=/tmp/sd is-enabled job.timer; echo "rc=$?"
find etc -type l
```

**Verifica**:

```bash
systemctl --root=/tmp/sd is-enabled job.timer; echo "rc=$?"
# enabled
# rc=0
find /tmp/sd/etc -type l
# /tmp/sd/etc/systemd/system/timers.target.wants/job.timer
systemctl --root=/tmp/sd disable job.timer >/dev/null 2>&1
systemctl --root=/tmp/sd is-enabled job.timer; echo "rc=$?"
# disabled
# rc=1
```

(El enlace apunta a `/etc/systemd/system/job.timer`, que es la ruta que tendría en
una máquina real; por eso, `--root` aparte, `find -type l` basta para verlo.)

## Paso 10: Comparar con `toolkit harden unit`

**Por qué**: tu herramienta debe coincidir con lo que dice `systemd-analyze` en lo
que mide. No es el mismo método (cinco comprobaciones frente a decenas), pero sí la
misma dirección.

**Comando**:

```bash
/root/bin/toolkit.sh harden unit job.service; echo "rc=$?"
cat job.service job.service.d/10-hard.conf > merged.service
/root/bin/toolkit.sh harden unit merged.service --quiet; echo "rc=$?"
```

**Verifica**:

```bash
/root/bin/toolkit.sh harden unit job.service | tail -1
# hallazgos: 5
/root/bin/toolkit.sh harden unit merged.service --quiet; echo "rc=$?"
# hallazgos: 0
# rc=0
```

(`harden unit` lee **un** archivo, por eso fusionamos base y drop-in en
`merged.service`. Es una de sus limitaciones documentadas en el archivo 08.)

## ✅ Resultado

- [ ] Escribí una unidad `oneshot` y `verify` la aceptó con `rc=0`
- [ ] Provoqué un error (`rc=1`) y un aviso (`rc=0`) y sé distinguirlos
- [ ] Validé un `OnCalendar=` y rechacé uno inválido
- [ ] Bajé la exposición de 9,4 a 2,0 con un drop-in
- [ ] Activé y desactivé un temporizador con `--root`
- [ ] `harden unit` pasó de 5 hallazgos a 0 sobre la unidad endurecida

```bash
bash scripts/verificar-semana.sh 19
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Failed to connect to bus` con `systemctl enable` | Falta `--root=` | Siempre `systemctl --root=/tmp/sd ...` en el laboratorio |
| `security` dice que no encuentra la unidad | Ruta sin `./` | Usa `./job.service` (con el punto y la barra) |
| `verify` no imprime nada con una errata | La errata está en una clave, no en una ruta | Busca avisos: no basta con `rc` |
| La nota no baja | El drop-in no está en `job.service.d/` | El directorio se llama `NOMBRE.service.d` |
| `cat-config`: `Too few arguments` | Falta la ruta de la unidad | `cat-config systemd/system/job.service` |
| `toolkit.sh: Permission denied` | Perdió el bit de ejecución | `chmod +x /root/bin/toolkit.sh` |

---

[← Práctica 01: Inspeccionar systemd](01-inspeccionar-systemd.md) · [Práctica 03: Seguridad básica y SSH →](03-seguridad-basica-y-ssh.md)
