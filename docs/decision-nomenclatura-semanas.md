# ADR-001: Esquema de Nomenclatura de Carpetas por Semana

**Fecha**: 2026-10-15
**Estado**: Aceptado

---

## Contexto

Este bootcamp nace directamente con 20 semanas de contenido planificado; no
hay un esquema previo que migrar (a diferencia de `bc-sql`, que sí renombró
carpetas `week-XX` existentes). Aun así, se adopta el mismo esquema que ya
usan los bootcamps hermanos del canal, para mantener consistencia entre
repositorios.

## Decisión

Se adopta el esquema `week-XX-tema_principal`, donde:

- `XX` es el número de semana con cero a la izquierda (dos dígitos).
- `tema_principal` es el tema central de la semana en **snake_case ASCII**,
  derivado exclusivamente del título del `README.md` de la semana.

## Mapeo completo

| Semana | Carpeta |
|:--:|---|
| 01 | `week-01-terminal_shell_y_primeros_pasos` |
| 02 | `week-02-navegacion_y_sistema_de_archivos` |
| 03 | `week-03-manipulacion_de_archivos_y_directorios` |
| 04 | `week-04-permisos_y_propiedad` |
| 05 | `week-05-redireccion_pipes_y_flujo_de_datos` |
| 06 | `week-06-busqueda_de_texto_con_grep_y_regex` |
| 07 | `week-07-procesamiento_de_texto_sed_cut_sort_uniq` |
| 08 | `week-08-awk_y_pipelines_de_datos` |
| 09 | `week-09-busqueda_de_archivos_find_y_xargs` |
| 10 | `week-10-gestion_de_procesos_y_senales` |
| 11 | `week-11-usuarios_grupos_y_gestion_de_paquetes` |
| 12 | `week-12-redes_desde_la_linea_de_comandos` |
| 13 | `week-13-fundamentos_de_bash_scripting` |
| 14 | `week-14-control_de_flujo_y_funciones_en_bash` |
| 15 | `week-15-scripts_robustos_manejo_de_errores` |
| 16 | `week-16-automatizacion_y_tareas_programadas` |
| 17 | `week-17-personalizacion_del_entorno_y_productividad` |
| 18 | `week-18-archivado_compresion_y_registros_del_sistema` |
| 19 | `week-19-systemd_seguridad_y_contenedores_desde_cli` |
| 20 | `week-20-proyecto_final_toolkit_integrado` |

## Reglas para nuevas semanas

1. El `tema_principal` se extrae **únicamente** del título `h1` del
   `README.md` de la semana (primera línea del archivo).
2. Se convierte a **snake_case** usando solo caracteres ASCII (sin tildes ni
   ñ).
3. Se usa **minúsculas** en todo el sufijo.
4. Los separadores entre palabras son guiones bajos (`_`).
5. El separador entre el número y el tema es un guión (`-`).

**Ejemplo:** Si el README dice `# Semana 21 — Contenedores Básicos`, la
carpeta sería `week-21-contenedores_basicos`.

## Consecuencias

- **Positivo**: el nombre de la carpeta comunica su contenido de forma
  inmediata en el explorador de archivos y en GitHub.
- **Positivo**: facilita la navegación sin necesidad de abrir el README.
- **Positivo**: consistencia con `bc-curl`, `bc-github` y `bc-sql` facilita
  reutilizar tooling (`verificar-enlaces.sh`, skills de autoría) entre
  repositorios del canal.
- **A tener en cuenta**: al crear pull requests o ramas, usar el nombre
  completo de la carpeta: `feat(week-05-redireccion_pipes_y_flujo_de_datos): ...`
