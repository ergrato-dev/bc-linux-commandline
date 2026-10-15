# Práctica 04: Operaciones seguras por lotes

Esta práctica cierra la semana combinando dry-run, respaldo y confirmación
en un flujo completo — y usándolo sobre tu propio `toolkit.sh organize`.

## Paso 1: Dry-run manual con `echo` antes de un `mv` en lote

**Por qué**: practicar el patrón general antes de usarlo a través del
subcomando `organize`.

**Comando**:

```bash
cd /tmp/wk03/procesados
ls *.txt

for f in *.txt; do
  echo mv "$f" "revisados-$f"
done
```

**Verifica**: la lista de comandos impresos es exactamente la que esperas,
sin haber movido nada todavía.

## Paso 2: Ejecutar recién después de confirmar visualmente

**Por qué**: el paso final del patrón — sacar el `echo` solo cuando ya
confías en el plan.

**Comando**:

```bash
for f in *.txt; do
  mv "$f" "revisados-$f"
done
ls
```

**Verifica**: los archivos ahora tienen el prefijo `revisados-`.

## Paso 3: Respaldo con fecha antes de una operación masiva

**Por qué**: practicar el hábito de respaldar con un nombre que no se pisa
solo.

**Comando**:

```bash
cd /tmp/wk03
cp -a entrantes/ "respaldos/entrantes-$(date +%Y%m%d%H%M)/"
ls respaldos/
```

**Verifica**: aparece una carpeta con fecha y hora en el nombre, con una
copia completa de `entrantes/`.

## Paso 4: Probar `toolkit.sh organize` en modo dry-run

**Por qué**: confirmar que tu propio subcomando respeta el mismo patrón que
acabas de practicar a mano.

**Comando**:

```bash
mkdir -p /tmp/wk03-organize-demo
touch /tmp/wk03-organize-demo/a.sh /tmp/wk03-organize-demo/b.txt /tmp/wk03-organize-demo/README

toolkit.sh organize /tmp/wk03-organize-demo
```

**Verifica**: la salida muestra un plan (`mkdir`/`mv` por cada archivo) y
termina con "nada se movio todavia" — y los archivos siguen en su lugar
original si corres `ls /tmp/wk03-organize-demo`.

## Paso 5: Aplicar el plan con `--apply` y confirmar que es idempotente

**Por qué**: comprobar la garantía más importante de un subcomando
destructivo: correrlo dos veces no debería romper nada ni duplicar
trabajo.

**Comando**:

```bash
toolkit.sh organize /tmp/wk03-organize-demo --apply
find /tmp/wk03-organize-demo

toolkit.sh organize /tmp/wk03-organize-demo --apply
```

**Verifica**: la segunda corrida reporta "total movimientos planeados: 0" —
no hay nada más que mover porque ya quedó todo organizado.

## ✅ Resultado

- [ ] Aplicaste dry-run con `echo` antes de un `mv` en lote real
- [ ] Hiciste un respaldo con fecha en el nombre antes de operar
- [ ] Confirmaste que `toolkit.sh organize` no mueve nada sin `--apply`
- [ ] Confirmaste que correr `organize --apply` dos veces es seguro (idempotente)

```bash
./scripts/verificar-semana.sh 03
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El `for` con `echo` no imprime nada | El glob `*.txt` no matcheó ningún archivo en ese directorio | Confirmar con `ls *.txt` antes del bucle |
| `toolkit.sh organize` dice "command not found" | `~/bin` no está en el `$PATH` de esta sesión, o el archivo no es ejecutable | Repetir `source ~/.bashrc`, o `chmod +x ~/bin/toolkit.sh` |
| La segunda corrida de `--apply` sí mueve algo | El subcomando no está completando correctamente el TODO que filtra qué ya está organizado | Revisar que `cmd_organize` solo planee sobre archivos regulares (`-f`) directamente en la carpeta, no sobre lo que ya está en subcarpetas |

---

[← Práctica 03](03-mover-y-eliminar-con-criterio.md) · [Proyecto: Capa 3 de toolkit →](../3-proyecto/README.md)
