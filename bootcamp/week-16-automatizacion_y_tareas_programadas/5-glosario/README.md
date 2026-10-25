# Glosario — Semana 16

**anacron**: programa que ejecuta tareas diarias, semanales o mensuales que se
perdieron porque la máquina estaba apagada. En RHEL y Arch viene con `cronie`.

**at**: orden que ejecuta un comando **una sola vez** a una hora dada. Lo
atiende el demonio `atd` y copia el entorno de quien lo programa.

**AccuracySec**: ventana en que systemd puede retrasar un temporizador para
agrupar despertares. Por defecto es de un minuto.

**calendario** (*calendar event*): expresión de `OnCalendar` como
`Mon..Fri *-*-* 02:30:00`; se valida con `systemd-analyze calendar`.

**campo** (*field*): cada una de las cinco partes de una expresión de cron:
minuto, hora, día del mes, mes y día de la semana.

**cron**: demonio que ejecuta comandos en horas fijas leyendo las tablas
(`crontab`) de cada usuario y de `/etc`. En Debian y Ubuntu es `cron`; en
RHEL y Arch, `cronie`.

**crontab**: la tabla de tareas de un usuario, y la orden que la edita
(`crontab -e`) o lista (`crontab -l`). `crontab archivo` la **reemplaza** entera.

**`/etc/cron.d`**: directorio de tablas del sistema. Cada línea lleva un
campo extra con el **usuario** que ejecuta la tarea.

**especificador** (*specifier*): secuencia `%x` en una unidad de systemd
(`%n`, `%h`...). Para escribir un `%` literal se duplica: `%%`.

**expresión de cron** (*cron expression*): los cinco campos que dicen cuándo
corre una tarea. Admite listas (`1,15`), rangos (`9-17`) y pasos (`*/15`).

**monotónico** (*monotonic timer*): temporizador relativo (`OnBootSec`,
`OnUnitActiveSec`) que cuenta desde un evento, no desde el reloj de pared.

**OnCalendar**: directiva de un `.timer` que programa por fecha y hora, como
haría `cron`.

**oneshot**: tipo de servicio (`Type=oneshot`) que se ejecuta y termina; es
el que usa un temporizador para lanzar una tarea.

**Persistent**: opción (`Persistent=true`) que ejecuta al arrancar una
tarea de `OnCalendar` que se perdió con la máquina apagada.

**run-parts**: programa que ejecuta todos los scripts de un directorio
(`/etc/cron.daily`); ignora los no ejecutables y los nombres con punto o `~`.

**temporizador** (*timer unit*): unidad `.timer` de systemd que activa la
unidad `.service` del mismo nombre.

**unidad** (*unit*): archivo que describe algo que systemd gestiona
(`.service`, `.timer`...).

**verify**: subcomando de `systemd-analyze` que comprueba la sintaxis de
unas unidades y que sus ejecutables existen; no valida la semántica.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 17: Personalización del entorno y productividad →](../../week-17-personalizacion_del_entorno_y_productividad/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
