# Práctica 02: Copiar archivos y directorios

Esta práctica reproduce, con tus propias manos, la diferencia entre una
copia simple y una copia que preserva metadatos y enlaces.

## Paso 1: Copiar sin flags y notar qué se pierde

**Por qué**: ver la fecha y permisos "nuevos" de una copia simple es más
convincente que leerlo en la teoría.

**Comando**:

```bash
cd /tmp/wk03/entrantes
touch -d "2020-01-01" factura-002.txt
chmod 600 factura-002.txt
cp factura-002.txt copia-simple.txt

stat -c '%y %a' factura-002.txt
stat -c '%y %a' copia-simple.txt
```

**Verifica**: la fecha y los permisos (`%a`) de `copia-simple.txt` son
distintos de los del original — la copia usa la fecha actual y tu `umask`.

## Paso 2: Copiar con `-p` y confirmar que ahora sí preserva

**Por qué**: la comparación directa entre ambos resultados es la prueba
definitiva de qué hace `-p`.

**Comando**:

```bash
cp -p factura-002.txt copia-preservada.txt
stat -c '%y %a' factura-002.txt
stat -c '%y %a' copia-preservada.txt
```

**Verifica**: ahora la fecha y los permisos coinciden entre original y
copia.

## Paso 3: Copiar un árbol completo con `-a`

**Por qué**: practicar el flag que vas a usar siempre que necesites
"clonar" una carpeta tal cual es.

**Comando**:

```bash
cd /tmp/wk03
cp -a entrantes/ entrantes-clon/
diff -r entrantes/ entrantes-clon/
ls -la entrantes/ entrantes-clon/
```

**Verifica**: `diff -r` no reporta ninguna diferencia; los permisos de
ambas carpetas son idénticos.

## Paso 4: Enlaces simbólicos al copiar: con y sin `-d`

**Por qué**: reproducir la diferencia entre "copiar el enlace" y "copiar lo
que el enlace apunta" evita una sorpresa real con árboles que tienen
enlaces.

**Comando**:

```bash
cd /tmp/wk03/entrantes
ln -s factura-001.txt enlace-factura.txt

cp enlace-factura.txt copia-siguiendo.txt
cp -d enlace-factura.txt copia-sin-seguir.txt

ls -la copia-siguiendo.txt copia-sin-seguir.txt
```

**Verifica**: `copia-siguiendo.txt` es un archivo regular (empieza con `-`
en `ls -l`); `copia-sin-seguir.txt` sigue siendo un enlace (`l`, con `->`).

## Paso 5: Copiar sin sobrescribir, de forma segura para scripts

**Por qué**: `-n` es el flag que vas a usar en cualquier script que no
pueda darse el lujo de esperar una respuesta interactiva.

**Comando**:

```bash
echo "version nueva" > factura-001.txt
cp -n factura-001.txt copia-simple.txt
cat copia-simple.txt
```

**Verifica**: `copia-simple.txt` **no** cambió — `-n` saltó la copia porque
el destino ya existía.

## ✅ Resultado

- [ ] Confirmaste qué pierde una copia simple (fecha, permisos)
- [ ] Confirmaste que `-p` preserva ambos
- [ ] Copiaste un árbol completo con `-a` y lo verificaste con `diff -r`
- [ ] Reprodujiste la diferencia entre copiar un enlace con y sin `-d`
- [ ] Usaste `-n` para confirmar que no sobrescribe nada existente

```bash
./scripts/verificar-semana.sh 03
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `diff -r` reporta diferencias después de `cp -a` | Puede haber quedado algo de una corrida anterior en `entrantes-clon/` | Borrar ambas carpetas y repetir el paso desde cero |
| `copia-siguiendo.txt` también aparece como enlace | Se usó `-d` sin querer, o el orden de los comandos se invirtió | Revisar qué flag llevó cada `cp`, confirmando con `ls -l` cuál es cuál |
| `cp -n` sobrescribe igual | Puede que el destino no existiera todavía en el momento de correr el comando | Confirmar con `ls` que el destino existía *antes* de la copia |

---

[← Práctica 01](01-crear-archivos-y-directorios.md) · [Práctica 03 →](03-mover-y-eliminar-con-criterio.md)
