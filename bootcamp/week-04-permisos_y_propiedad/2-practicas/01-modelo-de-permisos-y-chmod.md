# Práctica 01: Modelo de permisos y `chmod`

El usuario por defecto de `ubuntu-lab` es `root`, que no está sujeto a la
mayoría de estas comprobaciones. Esta práctica arranca creando un usuario
normal — lo vas a reutilizar en el resto de la semana.

## Paso 0: Crear el usuario de prueba de toda la semana

**Por qué**: sin esto, ningún "Permission denied" de esta semana se va a
reproducir de verdad.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
useradd -m -s /bin/bash estudiante
su estudiante -c 'whoami'
```

**Verifica**:

```bash
su estudiante -c 'whoami'
# estudiante
```

## Paso 1: Leer permisos de archivos reales, sin ayuda

**Por qué**: entrenar la lectura directa de los nueve caracteres antes de
calcular nada.

**Comando**:

```bash
ls -l /etc/hostname /etc/shadow /usr/bin/passwd
```

**Verifica**: para cada línea, identificá en voz alta dueño/grupo/otros y
qué letra falta en cada ámbito.

## Paso 2: Reproducir que `root` ignora el permiso de tránsito

**Por qué**: confirmar en carne propia la advertencia del archivo 01 de
teoría, antes de seguir con el resto de la semana.

**Comando**:

```bash
mkdir /tmp/sin-x
chmod 600 /tmp/sin-x

cd /tmp/sin-x
pwd
cd /tmp
su estudiante -c 'cd /tmp/sin-x' 2>&1
```

**Verifica**: como `root`, el primer `cd` funciona sin problema; como
`estudiante`, el segundo falla con "Permission denied".

## Paso 3: Calcular permisos octales a mano

**Por qué**: construir el cálculo a mano, no copiarlo de una tabla.

**Comando**:

```bash
touch script-privado.sh datos.csv clave.pem

chmod 700 script-privado.sh
chmod 644 datos.csv
chmod 600 clave.pem

ls -l script-privado.sh datos.csv clave.pem
```

**Verifica**: los tres archivos muestran exactamente los permisos
calculados — compará cada letra con la suma `r=4, w=2, x=1` antes de seguir.

## Paso 4: Notación simbólica para un cambio puntual

**Por qué**: practicar la diferencia entre "modificar" (simbólico) y
"fijar" (octal).

**Comando**:

```bash
chmod u+x script-privado.sh
ls -l script-privado.sh

chmod go-r datos.csv
ls -l datos.csv
```

**Verifica**: el primer cambio agregó `x` solo al dueño sin tocar el resto;
el segundo quitó lectura a grupo y otros, dejando intacto el dueño.

## Paso 5: Confirmar por qué borrar depende del directorio, no del archivo

**Por qué**: reproducir, con `estudiante`, el caso que en teoría solo se
leyó.

**Comando**:

```bash
mkdir -p /tmp/protegido
chown estudiante /tmp/protegido
touch /tmp/protegido/archivo.txt
chown estudiante /tmp/protegido/archivo.txt
chmod 444 /tmp/protegido/archivo.txt

su estudiante -c 'rm /tmp/protegido/archivo.txt'
```

**Verifica**: aparece la pregunta de confirmación por archivo protegido
contra escritura; respondiendo `y`, el archivo se borra igual — porque
`estudiante` tiene `w` sobre el directorio.

## ✅ Resultado

- [ ] Creaste el usuario `estudiante` y confirmaste que no es root
- [ ] Reprodujiste que `root` ignora el permiso de tránsito y `estudiante` no
- [ ] Calculaste tres permisos octales a mano, sin tabla
- [ ] Usaste notación simbólica para un cambio puntual sin pisar el resto
- [ ] Confirmaste que borrar depende del directorio, no del archivo

```bash
./scripts/verificar-semana.sh 04
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `su estudiante -c 'cd ...'` no da error, igual que root | `estudiante` quedó creado sin shell bash, o el `chown`/`chmod` no se aplicaron a la carpeta correcta | Confirmar `getent passwd estudiante` muestra `/bin/bash` al final |
| El paso 5 no pregunta nada, borra directo | Falta `chown estudiante` sobre el archivo o el directorio, o se corrió como root sin el `su` | Revisar que el comando completo esté dentro de `su estudiante -c '...'` |
| `useradd` dice que el usuario ya existe | Ya lo creaste en una corrida anterior | Normal, puedes seguir sin volver a crearlo |

---

[← 06 — ACLs y el modelo de sudo](../1-teoria/06-acls-y-el-modelo-de-sudo.md) · [Práctica 02 →](02-chown-chgrp-y-umask.md)
