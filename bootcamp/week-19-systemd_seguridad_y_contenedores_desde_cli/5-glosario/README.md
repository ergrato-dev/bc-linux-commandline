# Glosario — Semana 19

**auditoría** (*audit*): revisión que mira y avisa sin cambiar nada. `toolkit harden`
es una: sale con `2` si encuentra algo.

**cadena crítica** (*critical chain*): la ruta de dependencias que determinó el
tiempo de arranque. `systemd-analyze critical-chain`.

**capacidades** (*capabilities*): los poderes de root repartidos en piezas
(`CAP_NET_BIND_SERVICE`, `CAP_DAC_READ_SEARCH`…). `--cap-drop ALL` las quita todas.

**`cgroup`**: mecanismo del kernel que agrupa procesos para medirlos y limitar su
CPU, memoria y número. Lo que `docker stats` lee.

**contenedor** (*container*): proceso de Linux con una vista recortada del sistema
(*namespaces*) y recursos limitados (*cgroups*). No tiene kernel propio.

**drop-in**: fragmento `NOMBRE.service.d/*.conf` que modifica una unidad sin tocar
el archivo del paquete. Se lee en orden alfabético.

**`DynamicUser=`**: directiva que hace que systemd cree un usuario temporal para el
servicio. Alternativa a `User=nobody`.

**endurecer** (*harden*): quitar a un servicio o cuenta lo que no necesita para
reducir el daño si se compromete.

**`ExecStart=`**: línea de la unidad con el comando que se ejecuta. Ruta absoluta;
no es una shell.

**mínimo privilegio** (*least privilege*): dar a cada cuenta o servicio solo lo
que necesita para su tarea.

**`namespace`**: vista aislada de un recurso del kernel (PIDs, red, montajes,
usuarios). Dos procesos con el mismo identificador en `/proc/PID/ns/` lo comparten.

**`NoNewPrivileges=`**: directiva (y bandera `no-new-privileges` de Docker) que
impide ganar privilegios mediante setuid o `sudo`.

**`oneshot`**: `Type=` de una unidad cuyo proceso termina; para tareas puntuales.

**`PID 1`**: primer proceso de un sistema o contenedor. Debe recoger (*wait*) a los
hijos huérfanos; si no, quedan zombis.

**`PrivateTmp=`**: directiva que da al servicio su propio `/tmp`, invisible para los demás.

**`ProtectSystem=`**: directiva que monta `/usr`, `/boot` y `/etc` (con `strict`,
todo el sistema) en solo lectura para el servicio.

**setgid / setuid** (*set group/user ID*): bit que hace que un ejecutable corra con
el grupo o el usuario de su **propietario**, no de quien lo lanza (`2755`, `4755`).

**`sshd -T`**: imprime la configuración **efectiva** de SSH, ya resuelta. `sshd -t`
solo valida la sintaxis.

**sticky** (*bit sticky*): bit (`1777`) de un directorio compartido: solo el dueño
de un archivo, o root, puede borrarlo o renombrarlo.

**`sudoers`**: reglas de `sudo`. Se comprueban con `visudo -c` antes de instalarlas.

**`systemd-analyze security`**: puntúa de 0 a 10 la exposición de una unidad. Con
`--offline=true` lee el archivo sin necesitar systemd en marcha.

**`umask`**: máscara que se resta de los permisos máximos al crear un archivo
(`022` → `644`; `077` → `600`).

**unidad** (*unit*): archivo de configuración de systemd (`.service`, `.timer`,
`.target`…) con secciones `[Unit]`, el tipo y `[Install]`.

**zombi** (*zombie*): proceso que ya terminó pero cuyo padre aún no ha llamado a
`wait()`. No se mata con `kill -9`: hay que arreglar al padre.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 20: Proyecto final →](../../week-20-proyecto_final_toolkit_integrado/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
