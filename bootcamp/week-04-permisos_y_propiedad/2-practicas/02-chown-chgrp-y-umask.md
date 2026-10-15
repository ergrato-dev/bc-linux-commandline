# Práctica 02: `chown`, `chgrp` y `umask`

Esta práctica reproduce, con `estudiante` (creado en la práctica 01), por
qué cambiar de dueño requiere privilegios y cómo configurar una carpeta de
equipo con herencia de grupo.

## Paso 1: Confirmar que `chown` sin privilegios falla

**Por qué**: ver la restricción real, no solo leerla.

**Comando**:

```bash
touch /tmp/de-estudiante.txt
chown estudiante /tmp/de-estudiante.txt

su estudiante -c 'chown root /tmp/de-estudiante.txt'
```

**Verifica**: falla con "Operation not permitted" — `estudiante` no puede
regalar la propiedad de su propio archivo.

## Paso 2: `chown` con privilegios, dueño y grupo juntos

**Por qué**: practicar el atajo `usuario:grupo` en un solo comando.

**Comando**:

```bash
groupadd equipo
chown estudiante:equipo /tmp/de-estudiante.txt
ls -l /tmp/de-estudiante.txt
```

**Verifica**:

```bash
ls -l /tmp/de-estudiante.txt
# -rw-r--r-- 1 estudiante equipo ...
```

## Paso 3: `chgrp` a un grupo del que no se es miembro

**Por qué**: confirmar que esta restricción también es real, no solo para
`chown`.

**Comando**:

```bash
groupadd otrogrupo
su estudiante -c 'chgrp otrogrupo /tmp/de-estudiante.txt'
```

**Verifica**: falla con "Operation not permitted" — `estudiante` no
pertenece a `otrogrupo`.

## Paso 4: Carpeta de equipo con herencia de grupo (SGID)

**Por qué**: resolver de verdad el problema de "la carpeta compartida pierde
el grupo correcto".

**Comando**:

```bash
mkdir /tmp/proyecto-equipo
chgrp equipo /tmp/proyecto-equipo
chmod 2775 /tmp/proyecto-equipo

su estudiante -c 'touch /tmp/proyecto-equipo/archivo-de-estudiante.txt'
ls -l /tmp/proyecto-equipo/
```

**Verifica**: el archivo nuevo pertenece al grupo `equipo`, no al grupo
principal de `estudiante` — SGID hizo su trabajo.

## Paso 5: Calcular y configurar un `umask` restrictivo

**Por qué**: practicar el cálculo completo, no solo el valor por defecto.

**Comando**:

```bash
su estudiante -c 'umask'

su estudiante -c '
umask 077
touch /tmp/sensible-de-estudiante.txt
ls -l /tmp/sensible-de-estudiante.txt
'
```

**Verifica**:

```bash
ls -l /tmp/sensible-de-estudiante.txt
# -rw-------    <- 666 menos 077, nada para grupo ni otros
```

## ✅ Resultado

- [ ] Confirmaste que `chown` sin privilegios falla, con privilegios funciona
- [ ] Usaste `chown usuario:grupo` en un solo comando
- [ ] Confirmaste que `chgrp` a un grupo ajeno falla sin privilegios
- [ ] Configuraste SGID en una carpeta y viste la herencia de grupo funcionar
- [ ] Calculaste y aplicaste un `umask 077` y verificaste el resultado

```bash
./scripts/verificar-semana.sh 04
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El paso 1 no falla, `chown` funciona igual | El comando se corrió como `root`, sin el `su estudiante -c` | Revisar que el `chown root ...` esté dentro de las comillas del `su` |
| El archivo del paso 4 no hereda el grupo `equipo` | El `chmod 2775` no se aplicó, o se escribió `755` sin el `2` inicial | Confirmar con `ls -ld /tmp/proyecto-equipo` que aparece la `s` en el permiso de grupo |
| `umask 077` no afecta el archivo nuevo | El `touch` se corrió en una sub-shell distinta de donde se fijó el `umask` | Usar el mismo bloque `su estudiante -c '...'` para ambos comandos, como en el ejemplo |

---

[← Práctica 01](01-modelo-de-permisos-y-chmod.md) · [Práctica 03 →](03-bits-especiales-suid-sgid-sticky.md)
