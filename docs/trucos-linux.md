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

---

[← Volver al índice de documentación](README.md)
