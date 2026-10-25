# Práctica 03: Bits especiales — SUID, SGID, sticky

Esta práctica audita binarios reales con SUID/SGID, confirma que los
scripts lo ignoran, y configura un sticky bit real.

## Paso 1: Auditar binarios con SUID en el sistema

**Por qué**: antes de crear ninguno, conocer qué ya existe y por qué.

**Comando**:

```bash
find / -perm -4000 -type f 2>/dev/null
```

**Verifica**: aparece al menos `/usr/bin/passwd` — explica en una frase por
qué ese binario puntual necesita SUID (pista: escribe en `/etc/shadow`).

## Paso 2: Confirmar que un script ignora SUID

**Por qué**: comprobar en carne propia la protección del kernel contra
SUID en scripts interpretados.

**Comando**:

```bash
cat > /tmp/prueba-suid.sh << 'EOF'
#!/usr/bin/env bash
echo "UID real: $(id -u)"
echo "UID efectivo: $EUID"
EOF
chmod 4755 /tmp/prueba-suid.sh

su estudiante -c '/tmp/prueba-suid.sh'
```

**Verifica**: UID real y UID efectivo son iguales — SUID no tuvo ningún
efecto, a pesar de estar activo.

## Paso 3: SUID en un binario compilado (no un script)

**Por qué**: ver la diferencia real entre script interpretado y binario,
donde SUID sí se aplica.

**Comando**:

```bash
cp /bin/sleep /tmp/sleep-suid
chmod 4755 /tmp/sleep-suid

ls -l /tmp/sleep-suid
```

**Verifica**:

```bash
ls -l /tmp/sleep-suid
# -rwsr-xr-x ...    <- la "s" en la posicion del dueno
```

(No hace falta ejecutarlo para confirmar el bit — alcanza con `ls -l` para
esta práctica. Nunca dejes un binario así corriendo en un sistema real sin
una razón concreta y auditada.)

## Paso 4: Sticky bit en una carpeta compartida

**Por qué**: reproducir, con dos usuarios normales, el problema real que
resuelve el sticky bit.

**Comando**:

```bash
useradd -m -s /bin/bash otro 2>/dev/null

mkdir /tmp/compartida
chmod 1777 /tmp/compartida

su estudiante -c 'touch /tmp/compartida/de-estudiante.txt'
su otro -c 'rm /tmp/compartida/de-estudiante.txt' 2>&1
```

**Verifica**: `otro` no puede borrar el archivo de `estudiante`, aunque el
directorio sea escribible por cualquiera — el sticky bit lo impide.

## Paso 5: Confirmar que sin sticky bit, sí se podría borrar

**Por qué**: ver el contraste directo, no solo confiar en la teoría.

**Comando**:

```bash
mkdir /tmp/sin-sticky
chmod 777 /tmp/sin-sticky

su estudiante -c 'touch /tmp/sin-sticky/de-estudiante.txt'
su otro -c 'rm /tmp/sin-sticky/de-estudiante.txt' 2>&1
ls /tmp/sin-sticky/
```

**Verifica**: sin sticky bit, `otro` sí logra borrar el archivo ajeno.

## ✅ Resultado

- [ ] Encontraste y explicaste al menos un binario con SUID real del sistema
- [ ] Confirmaste que un script ignora SUID, comparando UID real y efectivo
- [ ] Viste la diferencia de SUID en un binario compilado vs. un script
- [ ] Reprodujiste que el sticky bit impide borrar archivos ajenos en una carpeta compartida
- [ ] Confirmaste el contraste sin sticky bit

```bash
./scripts/verificar-semana.sh 04
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El paso 2 muestra UID efectivo distinto del real | Muy raro en un kernel Linux moderno; revisar que el archivo realmente tenga shebang | Confirmar con `head -1 /tmp/prueba-suid.sh` que la primera línea es `#!/usr/bin/env bash` |
| El paso 4 permite borrar igual, sin sticky bit funcionando | El `chmod 1777` no se aplicó, o faltó el `1` inicial | Confirmar con `ls -ld /tmp/compartida` que aparece la `t` al final del permiso |
| `useradd otro` falla diciendo que ya existe | Corriste esta práctica más de una vez | Normal, puedes seguir sin volver a crearlo |

---

[← Práctica 02](02-chown-chgrp-y-umask.md) · [Práctica 04 →](04-acls-y-sudo.md)
