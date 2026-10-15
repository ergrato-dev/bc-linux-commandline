# Glosario — Semana 04

**ACL** (*Access Control List*): extensión del modelo clásico de permisos
que permite dar acceso a usuarios o grupos puntuales.

**Ámbito**: cada uno de los tres grupos a los que aplican los permisos:
dueño, grupo, otros.

**GID**: identificador numérico de un grupo.

**mask**: límite máximo efectivo de cualquier entrada de ACL de usuario o
grupo en un archivo.

**Principio de menor privilegio**: dar exactamente el acceso necesario
para una tarea, nunca más.

**Sticky bit**: bit especial que, en un directorio compartido, restringe
quién puede borrar o renombrar a solo el dueño de cada archivo (o `root`).

**SGID** (*Set Group ID*): bit especial que, en un binario, ejecuta con
los privilegios del grupo dueño; en un directorio, hace que los archivos
nuevos hereden ese grupo.

**SUID** (*Set User ID*): bit especial que ejecuta un binario con los
privilegios de su dueño, no de quien lo corre.

**sudoers**: archivo (`/etc/sudoers`) que define qué puede hacer cada
usuario con `sudo`. Se edita con `visudo`, nunca directamente.

**UID**: identificador numérico de un usuario.

**umask**: máscara que se resta del permiso máximo por defecto al crear un
archivo o directorio nuevo.

---

[← Webgrafía](../4-recursos/webgrafia/README.md) · [Semana 05 →](../../week-05-redireccion_pipes_y_flujo_de_datos/README.md)

[Glosario global](../../../docs/glosario-global.md) · [Índice del bootcamp](../../README.md)
