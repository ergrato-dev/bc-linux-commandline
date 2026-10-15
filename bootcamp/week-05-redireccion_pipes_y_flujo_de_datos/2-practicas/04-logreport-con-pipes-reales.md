# Práctica 04: `logreport` con pipes reales

Esta práctica te hace construir a mano, con pipes y redirecciones, la
misma lógica que `toolkit.sh logreport` automatiza — para que al completar
el starter entiendas exactamente qué estás pidiéndole al script que haga.

## Paso 1: Generar un log de prueba realista

**Por qué**: necesitas datos variados para que el resto de los pasos
tengan sentido.

**Comando**:

```bash
cd /tmp
cat > app-wk05.log << 'EOF'
2026-01-01 10:00:00 INFO arranque correcto
2026-01-01 10:00:05 ERROR fallo de conexion a la base de datos
2026-01-01 10:00:10 INFO reintentando conexion
2026-01-01 10:00:12 INFO conexion restablecida
2026-01-01 10:00:20 ERROR timeout en solicitud externa
2026-01-01 10:00:25 INFO solicitud completada
EOF
```

## Paso 2: Contar líneas totales, a mano

**Por qué**: es exactamente el primer dato que `logreport` calcula.

**Comando**:

```bash
wc -l < app-wk05.log
```

**Verifica**: el resultado es `6`.

## Paso 3: Contar y ver las líneas con `ERROR`, con un pipeline

**Por qué**: practicar el pipeline real antes de que el script lo haga por
ti.

**Comando**:

```bash
grep -c "ERROR" app-wk05.log

grep "ERROR" app-wk05.log | tee errores-wk05.log
```

**Verifica**: el conteo es `2`; `errores-wk05.log` contiene exactamente
esas dos líneas.

## Paso 4: Encadenar todo con códigos de salida con intención

**Por qué**: reproducir la lógica completa que vas a implementar en el
starter.

**Comando**:

```bash
if grep -q "ERROR" app-wk05.log; then
  echo "se encontraron errores" >&2
  codigo_esperado=2
else
  echo "sin errores"
  codigo_esperado=0
fi
echo "codigo esperado: $codigo_esperado"
```

**Verifica**: muestra "se encontraron errores" y "codigo esperado: 2" para
este log de prueba.

## Paso 5: Completar el starter de `toolkit.sh` y compararlo con lo anterior

**Por qué**: confirmar que tu implementación hace exactamente lo que
construiste a mano.

**Comando**:

```bash
toolkit.sh logreport app-wk05.log
echo "codigo real: $?"
cat app-wk05.log.informe.txt
```

**Verifica**: el reporte muestra `lineas totales: 6`, `lineas con ERROR:
2`, código de salida `2`, y el informe contiene las mismas dos líneas que
guardaste a mano en el paso 3.

## ✅ Resultado

- [ ] Contaste líneas totales de un log con `wc -l <`
- [ ] Contaste y guardaste líneas con `ERROR` usando `grep` y `tee`
- [ ] Construiste a mano la lógica completa de código de salida condicional
- [ ] Confirmaste que `toolkit.sh logreport` reproduce exactamente ese resultado

```bash
./scripts/verificar-semana.sh 05
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `toolkit.sh logreport` da un conteo distinto del paso 3 | El starter puede tener algún TODO sin completar, o estar contando con un patrón distinto a `"ERROR"` literal | Revisar `cmd_logreport` en `~/bin/toolkit.sh` contra la lógica de los pasos 2-4 |
| `cat app-wk05.log.informe.txt` dice "No such file" | `logreport` no llegó a escribir el informe, probablemente por un `exit` prematuro en un TODO sin completar | Revisar el orden de las operaciones dentro de `cmd_logreport` |
| El paso 2 da un número distinto de 6 | El heredoc del paso 1 no se guardó completo | Repetir el `cat > app-wk05.log << 'EOF' ... EOF` completo, verificando que las seis líneas quedaron |

---

[← Práctica 03](03-encadenar-comandos-y-codigos-de-salida.md) · [Proyecto: Capa 5 de toolkit →](../3-proyecto/README.md)
