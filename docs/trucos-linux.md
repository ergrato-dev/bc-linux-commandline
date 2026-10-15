# Trucos de Linux — acumulativo

Cheatsheet que crece una sección por semana. Si el README de una semana y
esta sección difieren, **gana el README de la semana** (es el que se escribe
primero).

---

## Semana 01 — Terminal, shell y primeros pasos

- `type -a comando` muestra **todas** las coincidencias de un nombre (alias,
  función, builtin, archivo), no solo la que gana — útil para ver qué está
  tapando a qué.
- `hash -r` fuerza a bash a olvidar rutas memorizadas y volver a buscar en
  `$PATH` — el arreglo real detrás de "lo instalé pero dice que no existe".
- `man -k .` (un punto como patrón) lista todas las páginas de manual
  instaladas en el sistema — una forma de "explorar" cuando no sabes qué
  buscar.
- `Ctrl+X Ctrl+E` abre el comando que estás escribiendo en tu editor
  (`$EDITOR`) — mejor que editar carácter por carácter para comandos largos.

## Semana 02 — Navegación y sistema de archivos

- `cd -` alterna entre los dos últimos directorios sin escribir ninguna ruta.
- `readlink -f ruta` resuelve cualquier cadena de enlaces simbólicos hasta el
  destino final real.
- `cp archivo{,.bak}` respalda un archivo en un solo comando, usando
  expansión de llaves.
- `dircolors --print-database` vuelca la paleta completa que interpreta
  `LS_COLORS`, por si un color inesperado te genera dudas.

## Semana 03 — Manipulación de archivos y directorios

- `cp --backup=numbered` respalda el destino existente antes de
  sobrescribirlo, en vez de perderlo sin rastro.
- `rm -I` pregunta una sola vez en borrados masivos — más seguro que `-f`,
  menos tedioso que `-i`.
- `touch -r modelo destino` copia la fecha de un archivo a otro sin
  calcularla a mano.
- `stat -c '%Y %n' * | sort -rn` ordena archivos por fecha real de
  modificación, más preciso que fiarse del orden visual de `ls -lt`.

## Semana 04 — Permisos y propiedad

- `namei -l /ruta/completa` muestra los permisos de cada componente de una
  ruta, uno por uno — útil cuando el problema está en un directorio
  intermedio, no en el archivo final.
- `chmod --reference=otro-archivo` copia permisos exactos sin calcular el
  número.
- `find / -perm -4000 -type f 2>/dev/null` audita todos los binarios con
  SUID activo en el sistema.
- `getfacl archivo1 | setfacl --set-file=- archivo2` copia una ACL completa
  de un archivo a otro.

---

[← Volver al índice de documentación](README.md)
