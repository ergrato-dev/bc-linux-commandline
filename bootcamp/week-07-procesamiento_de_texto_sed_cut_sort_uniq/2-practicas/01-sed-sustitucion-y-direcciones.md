# Práctica 01: sed, sustitución y direcciones

Esta práctica reproduce, dentro de `ubuntu-lab`, las sustituciones y
direcciones de `sed` contra un archivo de configuración realista.

## Paso 1: Preparar un archivo de configuración de prueba

**Por qué**: todos los pasos siguientes necesitan un archivo con varias
líneas de distinto tipo (directivas activas, un comentario) para que las
direcciones de `sed` tengan sentido.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
mkdir -p ~/practica-wk07 && cd ~/practica-wk07
cat > config.conf <<'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
#Banner /etc/issue
MaxAuthTries 6
EOF
cat config.conf
```

**Verifica**:

```bash
wc -l config.conf
# 5 config.conf
```

## Paso 2: Sustitución simple, sin tocar el archivo

**Por qué**: confirmar que `sed` sin `-i` solo imprime el resultado — el
archivo original queda intacto.

**Comando**:

```bash
sed 's/^Port 22/Port 2222/' config.conf
cat config.conf
```

**Verifica**: la salida del `sed` muestra `Port 2222`; el `cat`
inmediato después muestra que el archivo todavía dice `Port 22` — nada
cambió todavía.

## Paso 3: Sustitución acotada a una línea por patrón

**Por qué**: cambiar solo la línea que corresponde, sin tocar el resto
del archivo, usando una dirección por patrón en vez de por número de
línea.

**Comando**:

```bash
sed '/PermitRootLogin/s/yes/no/' config.conf
```

**Verifica**: solo la línea de `PermitRootLogin` cambia a `no`; el resto
del archivo (incluido `PasswordAuthentication yes`, que también contiene
`yes`) queda igual.

```bash
sed '/PermitRootLogin/s/yes/no/' config.conf | grep -c 'no$'
# 1
```

## Paso 4: Comentar una línea sin borrarla

**Por qué**: un patrón común de administración real — desactivar una
directiva sin perder el valor, por si hace falta revertir.

**Comando**:

```bash
sed '/^MaxAuthTries/s/^/#/' config.conf
```

**Verifica**:

```bash
sed '/^MaxAuthTries/s/^/#/' config.conf | grep '^#MaxAuthTries'
# #MaxAuthTries 6
```

## Paso 5: Borrar las líneas de comentario con `d`

**Por qué**: distinguir sustituir (`s`) de borrar (`d`) — dos comandos
distintos de `sed`, para dos necesidades distintas.

**Comando**:

```bash
sed '/^#/d' config.conf
```

**Verifica**: el resultado tiene 4 líneas, sin la línea `#Banner
/etc/issue`.

```bash
sed '/^#/d' config.conf | wc -l
# 4
```

## Paso 6: Edición in-place, con respaldo

**Por qué**: pasar del "solo mostrar" al "modificar de verdad", con la
misma disciplina de respaldo de la Semana 03 — nunca `-i` sin pensar en
cómo deshacerlo si algo sale mal.

**Comando**:

```bash
sed -i.bak 's/PasswordAuthentication yes/PasswordAuthentication no/' config.conf
diff config.conf.bak config.conf
```

**Verifica**: `diff` muestra una sola línea cambiada (de `yes` a `no`);
`config.conf.bak` conserva el contenido original completo.

```bash
grep PasswordAuthentication config.conf config.conf.bak
# config.conf:PasswordAuthentication no
# config.conf.bak:PasswordAuthentication yes
```

## ✅ Resultado

- [ ] Confirmaste que `sed` sin `-i` no modifica el archivo original
- [ ] Acotaste una sustitución a una sola línea con una dirección por patrón
- [ ] Comentaste una línea con `s/^/#/` sin borrar su contenido
- [ ] Borraste líneas de comentario con `d`
- [ ] Editaste el archivo con `-i.bak` y confirmaste que el respaldo tiene el contenido original

```bash
./scripts/verificar-semana.sh 07
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El Paso 3 cambia más de una línea | El patrón de dirección (`/PermitRootLogin/`) no coincide exactamente, o se usó `g` sobre el archivo completo en vez de una dirección | Confirmar que la dirección está antes del `s///`, con el patrón exacto de la línea que se quiere afectar |
| `config.conf.bak` no existe después del Paso 6 | El sufijo de `-i` se escribió con espacio (`-i .bak`) en vez de pegado (`-i.bak`) | GNU `sed` requiere el sufijo pegado a `-i`, sin espacio |
| El Paso 5 borra más líneas de las esperadas | El patrón `^#` también coincide con una línea que no era un comentario | Revisar `cat -A config.conf` para confirmar qué líneas empiezan realmente con `#` |

---

[← 07 — Combinando el pipeline](../1-teoria/07-combinando-el-pipeline-cut-tr-sort-uniq.md) · [Práctica 02 →](02-cut-y-sort-con-criterio.md)
