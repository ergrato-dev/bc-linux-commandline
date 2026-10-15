# Práctica 04: ACLs y `sudo`

Esta práctica instala y usa ACLs para dar permiso puntual, y configura una
regla mínima de `sudo` con el principio de menor privilegio.

## Paso 1: Instalar las herramientas

**Por qué**: ni ACLs ni `sudo` vienen preinstalados en la imagen base.

**Comando**:

```bash
apt-get update -qq
apt-get install -y acl sudo
```

**Verifica**:

```bash
which setfacl getfacl sudo visudo
```

## Paso 2: Confirmar que el modelo clásico no alcanza

**Por qué**: reproducir el problema antes de la solución.

**Comando**:

```bash
useradd -m -s /bin/bash otro 2>/dev/null

touch /tmp/informe.txt
chown estudiante /tmp/informe.txt
chmod 600 /tmp/informe.txt

su otro -c 'cat /tmp/informe.txt' 2>&1
```

**Verifica**: falla con "Permission denied" — con permisos clásicos, no hay
forma de darle acceso a `otro` sin tocar dueño, grupo u "otros" en general.

## Paso 3: Resolver con una ACL puntual

**Por qué**: dar acceso a `otro` sin abrir el archivo a cualquiera.

**Comando**:

```bash
setfacl -m u:otro:r /tmp/informe.txt
getfacl /tmp/informe.txt

su otro -c 'cat /tmp/informe.txt'
```

**Verifica**: ahora `otro` puede leer el archivo; `ls -l` muestra el `+` al
final de los permisos.

## Paso 4: Reproducir el límite del `mask`

**Por qué**: ver con tus propios ojos por qué un permiso "que está ahí" a
veces no se aplica.

**Comando**:

```bash
setfacl -m mask::r /tmp/informe.txt
getfacl /tmp/informe.txt
```

**Verifica**: si había alguna entrada con `w`, ahora aparece con
`#effective:r--` — el `mask` la recortó.

## Paso 5: Configurar una regla mínima de `sudo`

**Por qué**: practicar el principio de menor privilegio, no solo leerlo.

**Comando**:

```bash
echo 'estudiante ALL=(ALL) NOPASSWD: /usr/bin/apt update' > /etc/sudoers.d/estudiante
visudo -c -f /etc/sudoers.d/estudiante
chmod 440 /etc/sudoers.d/estudiante

su estudiante -c 'sudo apt update' | tail -3
su estudiante -c 'sudo whoami' 2>&1
```

**Verifica**: `sudo apt update` funciona sin pedir contraseña; `sudo
whoami` falla — no está en la regla, por más que sea un comando trivial.

## Paso 6: Auditar la regla con `sudo -l`

**Por qué**: confirmar que se puede revisar, sin adivinar, qué privilegios
tiene delegado cualquier usuario.

**Comando**:

```bash
sudo -l -U estudiante
```

**Verifica**: la salida muestra exactamente `(ALL) NOPASSWD: /usr/bin/apt
update`, ni más ni menos.

## ✅ Resultado

- [ ] Instalaste `acl` y `sudo`
- [ ] Reprodujiste el límite del modelo clásico y lo resolviste con una ACL
- [ ] Viste el `+` de `ls -l` y el detalle completo con `getfacl`
- [ ] Reprodujiste cómo el `mask` recorta un permiso de ACL
- [ ] Configuraste y validaste una regla de `sudo` de comando puntual
- [ ] Auditaste la regla con `sudo -l`

```bash
./scripts/verificar-semana.sh 04
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `setfacl`/`getfacl` dicen "command not found" | El paquete `acl` no se instaló, o la instalación falló en silencio | Repetir `apt-get install -y acl` y revisar el final de la salida por errores |
| `sudo whoami` como `estudiante` no pide nada, funciona directo | La regla quedó como `ALL` en vez del comando puntual, o se escribió mal el `sudoers.d` | Revisar con `cat /etc/sudoers.d/estudiante` que diga exactamente `/usr/bin/apt update`, no `ALL` |
| `visudo -c -f` reporta error de sintaxis | Falta algún espacio o los dos puntos exactos del formato `usuario ALL=(ALL) comando` | Comparar carácter por carácter con el ejemplo del paso 5 |

---

[← Práctica 03](03-bits-especiales-suid-sgid-sticky.md) · [Proyecto: Capa 4 de toolkit →](../3-proyecto/README.md)
