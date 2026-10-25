# Práctica 01: Inspeccionar systemd en una máquina viva

> Duración: 60 min · Teoría: archivos [01](../1-teoria/01-systemd-unidades-y-rutas.md), [02](../1-teoria/02-systemctl-inspeccionar-servicios.md) y [04](../1-teoria/04-arranque-rendimiento-y-registros.md)

`ubuntu-lab` no arranca systemd, así que esta práctica se hace en **tu propia
máquina**: una VM Linux, un servidor o WSL2 con `systemd=true` (comprueba con
`ps -p 1 -o comm=`, debe decir `systemd`). Todo es de **solo lectura**: no
cambias nada. Tus salidas serán otras; lo que importa es la forma y los códigos.

Los pasos 1 y 2 sí pueden hacerse en `ubuntu-lab` para ver el contraste.

## Paso 1: Confirmar quién es el PID 1

**Por qué**: `systemctl` solo funciona si systemd es el PID 1. Si no lo es,
fallará con un mensaje que parece un error de tu comando y no de la máquina.

**Comando**:

```bash
# comm= quita la cabecera. En una maquina con systemd el PID 1 se llama systemd.
ps -p 1 -o comm=
```

**Verifica**:

```bash
ps -p 1 -o comm=
# systemd
# (en ubuntu-lab dice "sleep": ahi systemctl status falla con
#  "System has not been booted with systemd as init system (PID 1)")
```

## Paso 2: Localizar el archivo de una unidad y su precedencia

**Por qué**: antes de opinar sobre un servicio hay que saber **qué archivo** se
cargó. Si hay un *drop-in* en `/etc`, manda sobre el del paquete (archivo 01).

**Comando**:

```bash
# FragmentPath = archivo base; DropInPaths = fragmentos que lo modifican.
systemctl show -p FragmentPath,DropInPaths cron
```

**Verifica**:

```bash
systemctl show -p FragmentPath,DropInPaths cron
# FragmentPath=/lib/systemd/system/cron.service
# DropInPaths=
# (en RHEL/Arch la ruta es /usr/lib/systemd/system/...; DropInPaths vacío = sin ajustes locales)
```

## Paso 3: Leer la ficha de estado

**Por qué**: `status` reúne en una pantalla el archivo, el estado, el PID y las
últimas líneas del diario (archivo 02). Hay que saber localizar cada pieza.

**Comando**:

```bash
# --no-pager evita que less espere una tecla; -n 5 limita las lineas del diario.
systemctl status cron --no-pager -n 5
```

**Verifica**:

```bash
systemctl status cron --no-pager -n 5 | grep -E '^\s+(Loaded|Active|Main PID):' | cut -c1-70
#      Loaded: loaded (/lib/systemd/system/cron.service; enabled; ...
#      Active: active (running) since ...
#    Main PID: 1204 (cron)
```

## Paso 4: Aprender los códigos de salida

**Por qué**: un script no lee la ficha; lee el **código**. `is-failed` devuelve
`0` cuando algo **ha fallado**, y eso confunde a casi todos al principio.

**Comando**:

```bash
# Tres preguntas sobre una unidad sana y una que no existe.
for u in cron no-such.service; do
  systemctl is-active "$u" >/dev/null; a=$?
  systemctl is-enabled "$u" >/dev/null 2>&1; e=$?
  systemctl is-failed "$u" >/dev/null; f=$?
  echo "$u active=$a enabled=$e failed=$f"
done
```

**Verifica**:

```bash
# cron           active=0 enabled=0 failed=1
# no-such.service active=3 enabled=1 failed=1
# failed=1 significa "NO esta fallada". Un 0 en la ultima columna seria un fallo real.
```

## Paso 5: Extraer propiedades exactas con `show -p`

**Por qué**: `status` es para ojos; `show -p` da `Clave=valor`. Es lo que usarías
para decidir en un script, y lo que `toolkit harden unit` reproduce sobre un archivo.

**Comando**:

```bash
# --value quita el nombre de la clave: queda el dato desnudo.
pid=$(systemctl show -p MainPID --value cron)
echo "PID de cron: $pid"
systemctl show cron -p User,NoNewPrivileges,Restart
```

**Verifica**:

```bash
ps -p "$(systemctl show -p MainPID --value cron)" -o comm=
# cron
systemctl show cron -p User,NoNewPrivileges
# User=
# NoNewPrivileges=no
# User= vacio = corre como root. Es lo que "harden unit" marcaria como riesgo.
```

## Paso 6: Buscar unidades falladas y dependencias

**Por qué**: `--failed` es la primera orden al llegar a una máquina que va rara.
Y `--reverse` responde «¿qué se rompe si paro esto?».

**Comando**:

```bash
systemctl --failed --no-pager --no-legend | wc -l
systemctl list-dependencies --reverse cron --no-pager | head -4
```

**Verifica**:

```bash
systemctl --failed --no-pager --no-legend | wc -l
# 0     (un numero mayor son unidades falladas: investigalas con status + journalctl -u)
systemctl list-dependencies --reverse cron --no-pager | head -2
# cron.service
# ● └─multi-user.target
```

## Paso 7: La agenda y los temporizadores

**Por qué**: en la Semana 16 programaste tareas; aquí ves las que **ya hay**.
`list-timers` dice cuándo salta cada una y cuándo lo hizo por última vez.

**Comando**:

```bash
systemctl list-timers --no-pager | head -4 | cut -c1-110
```

**Verifica**:

```bash
systemctl list-timers --all --no-pager --plain --no-legend | wc -l
# 12    (el numero varia; debe ser >= 1: toda maquina con systemd trae temporizadores del sistema)
```

## Paso 8: Medir el arranque

**Por qué**: `blame` ordena por lo lento, `critical-chain` por lo que **retrasa**.
Son listas distintas (archivo 04).

**Comando**:

```bash
systemd-analyze                              # tiempo total
systemd-analyze blame --no-pager | head -3   # las 3 mas lentas
systemd-analyze critical-chain --no-pager | head -6
```

**Verifica**:

```bash
systemd-analyze | grep -c 'Startup finished'
# 1
systemd-analyze critical-chain --no-pager | grep -c '@'
# 15    (cada linea de la cadena lleva un @tiempo; el numero varia segun tu maquina, debe ser > 0)
```

## Paso 9: Leer el diario por unidad y por arranque

**Por qué**: el diario de una unidad cuenta qué hizo; el del arranque anterior
cuenta por qué cayó la máquina.

**Comando**:

```bash
journalctl -u cron -n 3 --no-pager -o short-iso
journalctl --list-boots --no-pager | tail -2
```

**Verifica**:

```bash
journalctl -u cron -n 1 --no-pager -q | wc -l
# 1
journalctl --list-boots --no-pager | tail -1 | awk '{print $1}'
# 0     (el arranque actual es siempre el 0; si ves -1 antes, hay diario persistente)
```

## Paso 10: Responder con evidencia

**Por qué**: el objetivo no es teclear comandos, sino contestar. Anota las
respuestas con el comando que las respalda.

**Comando**:

```bash
# Un resumen reproducible de la maquina, en un archivo.
{
  echo "init: $(ps -p 1 -o comm=)"
  echo "cron unit: $(systemctl show -p FragmentPath --value cron)"
  echo "fallidas: $(systemctl --failed --no-legend | wc -l)"
  echo "arranque: $(systemd-analyze | head -1)"
} | tee ~/informe-systemd.txt
```

**Verifica**:

```bash
grep -c '' ~/informe-systemd.txt
# 4
grep '^init:' ~/informe-systemd.txt
# init: systemd
```

## ✅ Resultado

- [ ] Sé que `systemctl` exige systemd como PID 1
- [ ] Localicé el archivo y los drop-ins de una unidad
- [ ] Leí `Loaded`, `Active` y `Main PID` en `status`
- [ ] Interpreto `is-active`, `is-enabled` e `is-failed` por su código
- [ ] Extraje `MainPID` y `User` con `show -p`
- [ ] Distingo `blame` de `critical-chain`
- [ ] Leí el diario de una unidad y listé los arranques

Esta práctica no tiene comprobación automática (necesita systemd): se evalúa en
la rúbrica manual. Cuando acabes las cinco, ejecuta:

```bash
bash scripts/verificar-semana.sh 19
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `System has not been booted with systemd` | El PID 1 no es systemd (contenedor, WSL2 sin systemd) | Usa una VM, o en WSL2 añade `systemd=true` en `/etc/wsl.conf` y reinicia con `wsl --shutdown` |
| `Failed to connect to bus` | Estás en un contenedor sin systemd | Haz esta práctica en el anfitrión |
| `Unit ssh.service could not be found` | Tu distro lo llama `sshd` (RHEL/Arch) | `systemctl list-unit-files \| grep -i ssh` |
| `status` se queda esperando | `less` abierto | Pulsa `q`, y usa `--no-pager` |
| `blame` vacío o error | Máquina recién arrancada o sin permisos | Espera un minuto; en WSL2 puede estar limitado |

---

[← Seguridad de contenedores y `harden`](../1-teoria/08-seguridad-de-contenedores-y-harden.md) · [Práctica 02: Unidades y endurecimiento →](02-unidades-y-endurecimiento.md)
