# Capa 3 de `toolkit`: el subcomando `organize`

## 🎯 Objetivo

Agregar a `toolkit.sh` un tercer subcomando, `organize`, que agrupa los
archivos de un directorio en subcarpetas por extensión — con un modo
dry-run por defecto, y aplicando cambios reales solo con `--apply`.

## 📦 Qué añade esta capa

`doctor` e `inventory` siguen intactos. `organize` es el primer subcomando
que **hace algo destructivo** (mueve archivos), y por eso es también el
primero que implementa el patrón de seguridad de esta semana: nunca
modifica nada por defecto, siempre muestra el plan primero, y requiere un
flag explícito (`--apply`) para ejecutarlo de verdad. Este patrón —
dry-run por defecto, flag explícito para el cambio real — es el que vas a
reutilizar en cualquier subcomando futuro que toque el sistema de archivos
del usuario.

También es la primera vez que `toolkit.sh` necesita ser **idempotente**:
correr `organize --apply` dos veces seguidas no debe fallar ni duplicar
trabajo — la segunda corrida simplemente no encuentra nada nuevo que mover.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. `toolkit.sh` sigue existiendo y ejecutable
2. El subcomando `doctor` sigue funcionando (regresión de la Semana 01)
3. El subcomando `inventory` sigue funcionando (regresión de la Semana 02)
4. `organize` sin `--apply` no mueve ningún archivo
5. `organize` sin `--apply` reporta explícitamente que está en modo dry-run
6. `organize --apply` agrupa archivos de la misma extensión en su propia carpeta
7. `organize --apply` agrupa archivos sin extensión en una carpeta propia
8. Correr `organize --apply` dos veces seguidas no falla ni vuelve a mover nada
9. `organize` sale con código distinto de 0 si la ruta no existe

## 🎨 Criterios de calidad

- El plan impreso en modo dry-run es idéntico, comando por comando, a lo
  que `--apply` ejecuta de verdad — nunca "miente" sobre lo que va a hacer
- Usa `nullglob` al listar el contenido del directorio (visto en la Semana 02)
- Solo mueve archivos regulares del nivel superior, nunca entra en
  subcarpetas ya organizadas (evita duplicar trabajo en corridas repetidas)
- Mensajes de error van a `stderr`

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `organize` (no evaluado esta semana) |
|---|---|
| Tienes una carpeta de Descargas caótica | Agregar reglas por nombre además de por extensión (ej. facturas vs. capturas de pantalla) |
| Trabajas con fechas importantes | Organizar por fecha de modificación (año/mes) en vez de por extensión |
| Te importa no perder nada | Agregar un modo `--backup` que respalde antes de mover, usando el patrón del archivo 03 de proyecto anterior |
| Prefieres revisar antes de confiar | Guardar el plan de dry-run en un archivo de log antes de aplicarlo |

## 🚦 Cómo entregarlo

```bash
cp bootcamp/week-03-manipulacion_de_archivos_y_directorios/3-proyecto/starter/toolkit.sh ~/bin/toolkit.sh
chmod +x ~/bin/toolkit.sh
# completa los TODO de cmd_organize
./scripts/verificar-semana.sh 03
```

## 🧯 Errores comunes

- Mover archivos que ya están dentro de una subcarpeta de extensión (por
  ejemplo, volver a mover algo de `sh/` hacia otro lado) — la causa casi
  siempre es escanear con `-maxdepth` distinto de 1 o sin filtrar `-type f`.
- Ejecutar el `mv` real también en el modo dry-run por olvidar el `if
  [[ "$aplicar" == true ]]` alrededor del movimiento — probar siempre sin
  `--apply` primero y confirmar que nada se mueve.
- Usar `mv` sin `-n` dentro de `organize`, arriesgando sobrescribir un
  archivo que ya exista en la carpeta de destino con el mismo nombre.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-operaciones-seguras-por-lotes.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
