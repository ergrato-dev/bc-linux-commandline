# Capa 4 de `toolkit`: el subcomando `audit`

## 🎯 Objetivo

Agregar a `toolkit.sh` un cuarto subcomando, `audit`, que reporta el
`umask` activo y detecta dos riesgos de permisos en un directorio:
entradas escribibles por cualquier usuario, y archivos con SUID/SGID
activo — saliendo con un código de error distinto según lo que encuentre.

## 📦 Qué añade esta capa

`doctor`, `inventory` y `organize` siguen intactos. `audit` cierra el
bloque de semanas 02-04 del proyecto (exploración y organización de
archivos, ahora con permisos) con la primera auditoría de seguridad básica
de `toolkit` — una versión en miniatura de lo que se profundiza en la
Semana 19.

Esta capa también introduce un patrón nuevo: **tres códigos de salida
distintos** (`0` = sin riesgos, `1` = ruta inválida, `2` = riesgos
encontrados), en vez del simple "funcionó / no funcionó" de las capas
anteriores. Esto permite que un script que llame a `toolkit.sh audit`
distinga "no pude auditar nada" de "auditié, y encontré algo".

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. Los subcomandos `doctor`, `inventory` y `organize` siguen funcionando (regresión)
3. `audit` reporta el `umask` actual de la sesión
4. `audit` detecta un archivo escribible por otros y sale con código `2`
5. `audit` sale con código `0` si no encuentra ningún riesgo
6. `audit` detecta un archivo con SUID activo
7. `audit` sale con código `1` (no `2`) si la ruta no existe

## 🎨 Criterios de calidad

- Los tres códigos de salida (`0`, `1`, `2`) son distintos y documentados en
  el uso del comando, no solo "funciona o no"
- Las comprobaciones de riesgo (escribible por otros, SUID/SGID) usan
  `find -perm`, no parseo manual de `ls -l`
- Los mensajes de riesgo van a `stderr`, el resto del reporte a `stdout`
- No requiere privilegios de `root` para auditar — cualquier usuario puede
  correr `audit` sobre un directorio donde tenga permiso de lectura

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `audit` (no evaluado esta semana) |
|---|---|
| Administras servidores compartidos | Agregar detección de archivos sin dueño reconocible (UID huérfano) |
| Te importa la seguridad de credenciales | Detectar archivos `.pem`/`.key` con permisos más abiertos que `600` |
| Trabajas con ACLs | Agregar un conteo de archivos con ACLs activas (el `+` de `ls -l`) |
| Prefieres un resumen ejecutivo | Agregar un modo `--resumen` que solo imprima la cuenta de riesgos, sin el detalle |

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-04-permisos_y_propiedad/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO de cmd_audit
./scripts/verificar-semana.sh 04
```

## 🧯 Errores comunes

- Usar `exit 1` tanto para "ruta inválida" como para "riesgos encontrados"
  — perdiendo la distinción que la capa pide expresamente.
- Olvidar que detectar SUID/SGID requiere `-perm -4000`/`-perm -2000` (con
  el guión antes del número), no `-perm 4000` (que pide una coincidencia
  exacta, no "al menos este bit").
- Correr `audit` como `root` durante el desarrollo y no notar que un
  riesgo real (por ejemplo, escribible por otros) no se manifiesta igual
  para un usuario sin privilegios — probar siempre también con el usuario
  `estudiante` creado en la práctica 01.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-acls-y-sudo.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
