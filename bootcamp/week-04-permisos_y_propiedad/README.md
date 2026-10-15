# Semana 04 — Permisos y propiedad

> `rwx`, dueño, grupo, otros. Esta semana da el modelo completo de quién
> puede hacer qué en Linux — y por qué `root`, el usuario por defecto del
> laboratorio, no te va a dejar ver ninguno de los errores reales.

## 🎯 Objetivos de la Semana

- Leer y calcular permisos `rwx` en octal y simbólico, sin tabla de referencia
- Cambiar dueño y grupo con `chown`/`chgrp`, entendiendo sus restricciones
- Calcular qué permisos nacen por defecto según el `umask` activo
- Usar SUID, SGID y sticky bit donde realmente corresponden
- Dar acceso puntual con ACLs y delegar privilegios con `sudo`

## 📋 Prerrequisitos

Semana 03 completada: `toolkit.sh organize` funcionando, con el patrón
dry-run/`--apply` entendido.

**Importante**: el usuario por defecto de `ubuntu-lab` es `root`, que no
está sujeto a la mayoría de los permisos que esta semana enseña. La
práctica 01 empieza creando un usuario normal (`estudiante`) — sin ese
paso, buena parte de los ejemplos de esta semana no se van a reproducir
como están descritos.

## 🗂️ Estructura de la Semana

```
week-04-permisos_y_propiedad/
├── 0-assets/              # 2 diagramas SVG
├── 1-teoria/              # 6 archivos: rwx, chmod, chown/chgrp, umask, bits especiales, ACLs/sudo
├── 2-practicas/           # 4 practicas sobre ubuntu-lab (con un usuario de prueba propio)
├── 3-proyecto/            # Capa 4 de toolkit: subcomando audit
├── 4-recursos/            # ebooks, video y webgrafia
└── 5-glosario/            # Terminos de esta semana
```

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01](1-teoria/01-modelo-de-permisos-rwx.md) | Modelo de permisos: rwx y los tres ámbitos | 25 min |
| [02](1-teoria/02-chmod-octal-y-simbolico.md) | `chmod`: octal y simbólico | 20 min |
| [03](1-teoria/03-chown-y-chgrp.md) | `chown` y `chgrp`: propietario y grupo | 20 min |
| [04](1-teoria/04-umask.md) | `umask` | 20 min |
| [05](1-teoria/05-bits-especiales-suid-sgid-sticky.md) | Bits especiales: SUID, SGID, sticky | 25 min |
| [06](1-teoria/06-acls-y-el-modelo-de-sudo.md) | ACLs y el modelo de confianza de `sudo` | 25 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01](2-practicas/01-modelo-de-permisos-y-chmod.md) | Crear el usuario de prueba, calcular permisos a mano | 50 min |
| [02](2-practicas/02-chown-chgrp-y-umask.md) | Reproducir restricciones de `chown`/`chgrp`, configurar SGID y `umask` | 45 min |
| [03](2-practicas/03-bits-especiales-suid-sgid-sticky.md) | Auditar SUID real, confirmar que scripts lo ignoran, sticky bit | 45 min |
| [04](2-practicas/04-acls-y-sudo.md) | Resolver un caso con ACL, configurar una regla de `sudo` mínima | 50 min |

Y la cuarta capa de `toolkit`: [`3-proyecto/README.md`](3-proyecto/README.md)
— el subcomando `audit`, que detecta riesgos de permisos y cierra el
bloque de semanas 02-04 del proyecto.

## ⏱️ Distribución del Tiempo (10 horas)

| Actividad | Tiempo |
|---|:--:|
| Teoría (6 archivos) | 2 h 15 min |
| Prácticas (4 archivos) | 3 h 10 min |
| Proyecto: Capa 4 de `toolkit` | 2 h 30 min |
| Rúbrica de conocimiento (10 preguntas) | 1 h |
| Repaso, glosario y recursos | 1 h 5 min |
| **Total** | **10 h** |

## 🎩 Trucos y atajos

- `namei -l /ruta/completa` muestra los permisos de cada componente de una
  ruta, uno por uno — útil cuando el problema está en un directorio
  intermedio, no en el archivo final.
- `chmod --reference=otro-archivo` copia permisos exactos sin calcular el
  número.
- `find / -perm -4000 -type f 2>/dev/null` audita todos los binarios con
  SUID activo en el sistema.
- `getfacl archivo1 | setfacl --set-file=- archivo2` copia una ACL completa
  de un archivo a otro.

## 📌 Entregables

1. `~/bin/toolkit.sh` con el subcomando `audit` funcionando según los
   requisitos de [`3-proyecto/README.md`](3-proyecto/README.md)
2. Los subcomandos `doctor`, `inventory` y `organize` de semanas anteriores
   siguen funcionando sin regresiones
3. Las 10 preguntas de conocimiento respondidas con tus propias palabras

## ✅ Verificación

```bash
./scripts/verificar-semana.sh 04
```

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|:--:|---|
| [← Semana 03](../week-03-manipulacion_de_archivos_y_directorios/README.md) | Semana 04 | [Semana 05 →](../week-05-redireccion_pipes_y_flujo_de_datos/README.md) |

[← Volver al índice del bootcamp](../README.md)
