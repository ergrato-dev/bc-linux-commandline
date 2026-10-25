# Seguridad de contenedores y diseño de `harden`

> Un contenedor por defecto corre como root, con el sistema de archivos escribible y más privilegios de los que necesita.
> Aquí aprendes las banderas que lo cierran y diseñas `toolkit harden`, que audita unidades, SSH, permisos y contenedores con el mismo formato.

## 🎯 Objetivos

- Lanzar un contenedor endurecido con `--user`, `--read-only`, `--cap-drop` y `no-new-privileges`
- Explicar por qué `--privileged`, `--network host` y publicar puertos sin dirección son riesgos
- Publicar un puerto solo en `127.0.0.1`
- Entender el diseño de `toolkit harden`: una línea por comprobación, contador de hallazgos y código de salida `2`
- Saber qué **no** detecta esta herramienta

## 1. Qué problema resuelve

Un contenedor comparte el kernel con el anfitrión. Si el proceso de dentro es
root y tiene capacidades de sobra, un fallo en la aplicación se parece mucho a
un fallo en el anfitrión. Las banderas de `docker run` reducen eso, igual que
las directivas de aislamiento reducían una unidad (archivo 06).

Y la auditoría debe ser **repetible**: una herramienta que mire las mismas
cosas siempre, con una salida que un script pueda leer.

## 2. Cómo funciona

### 2.1 Las banderas que cierran un contenedor

```bash
docker run --rm --name wk19-h --read-only --user 1000 --cap-drop ALL \
  --security-opt no-new-privileges ubuntu:24.04 \
  sh -c 'id -u; touch /x; grep -E "CapEff|NoNewPrivs" /proc/self/status'
# 1000
# touch: cannot touch '/x': Read-only file system
# CapEff:	0000000000000000
# NoNewPrivs:	1
```

| Bandera | Efecto | Equivalente en systemd (archivo 06) |
|---|---|---|
| `--user 1000` | No corre como root | `User=` / `DynamicUser=` |
| `--read-only` | Raíz en solo lectura | `ProtectSystem=strict` |
| `--cap-drop ALL` | Sin capacidades de root (`CapEff` a cero) | `CapabilityBoundingSet=` |
| `--security-opt no-new-privileges` | setuid no concede privilegios | `NoNewPrivileges=yes` |
| `--memory`, `--pids-limit` | Tope de memoria y de procesos (cgroups) | `MemoryMax=`, `TasksMax=` |
| `--tmpfs /tmp` | Un `/tmp` en memoria escribible | `PrivateTmp=yes` |

Con `--read-only` la aplicación falla si escribe en cualquier sitio: dale un
`--tmpfs /tmp` o un volumen para lo que **sí** debe escribir. Y, si necesita una
capacidad concreta, se añade **después** de quitarlas todas
(`--cap-drop ALL --cap-add NET_BIND_SERVICE`).

### 2.2 Los tres riesgos clásicos

| Configuración | Por qué es un riesgo |
|---|---|
| `--privileged` | Todas las capacidades y acceso a los dispositivos: casi no hay aislamiento |
| `--network host` | Comparte la red del anfitrión: sin aislamiento de red, ve sus puertos |
| `-p 8080:80` (sin dirección) | Publica en **todas** las interfaces (`0.0.0.0`): accesible desde fuera |

Lo último se corrige indicando la dirección. En este laboratorio nunca se publica
nada fuera de `localhost` (regla de seguridad del bootcamp):

```bash
docker run -d --rm -p 127.0.0.1:18081:80 --user 1000 --read-only ubuntu:24.04 sleep 90
docker port $(docker ps -lq)
# 80/tcp -> 127.0.0.1:18081
docker stop $(docker ps -lq)
```

Solo tu máquina llega a ese puerto. Es una práctica, así que se para y se borra
al terminar (`--rm`).

### 2.3 El diseño de `toolkit harden`

La Semana 19 añade una capa con cuatro auditorías y un mismo contrato:

```
toolkit harden unit|ssh|perms|container OBJETIVO [--quiet] [--depth N (solo perms)]
```

| Subcomando | Objetivo | Qué lee |
|---|---|---|
| `unit` | un archivo `.service` | `User`, `NoNewPrivileges`, `ProtectSystem`, `PrivateTmp`, `ProtectHome` |
| `ssh` | un `sshd_config` | `PermitRootLogin`, `PasswordAuthentication`, `PermitEmptyPasswords`, `X11Forwarding` |
| `perms` | un directorio | setuid, setgid, escribibles por todos, directorios sin sticky |
| `container` | la salida de `docker inspect` | `Privileged`, `User`, `ReadonlyRootfs`, `NetworkMode`, `HostIp` |

La salida es una línea por comprobación y un resumen:

```
ok Privileged
riesgo User: corre como root (User vacio o root)
riesgo ReadonlyRootfs: el sistema de archivos raiz es escribible
ok NetworkMode
ok Ports
hallazgos: 2
```

Y el código de salida lleva el resultado, para usarlo en un `if` o en `cron`:

| Código | Significa |
|---|---|
| `0` | Sin hallazgos |
| `1` | Uso incorrecto, o archivo/directorio inexistente |
| `2` | Hay al menos un hallazgo |

Separar `1` de `2` es lo importante: un script de vigilancia debe distinguir «no
pude mirar» de «miré y encontré algo».

### 2.4 Las decisiones de diseño

- **Un solo punto de salida.** `harden_line ESTADO NOMBRE DETALLE` imprime y cuenta;
  `--quiet` oculta los `ok`. Ninguna auditoría imprime por su cuenta, así que el
  formato no se desvía.
- **Una función de lectura por semántica.** `harden_value MODO CLAVE ARCHIVO` tiene
  dos modos porque los dos formatos de configuración se leen al revés:

  | Modo | Formato | Reglas |
  |---|---|---|
  | `last` | Unidad systemd | `Clave=valor`, distingue mayúsculas, **gana la última**, se admiten espacios alrededor de `=` |
  | `first` | `sshd_config` | No distingue mayúsculas, **gana la primera**, deja de leer en la primera línea `Match` |

- **Los valores por defecto cuentan.** Si `PasswordAuthentication` no aparece, sshd
  usa `yes`: la auditoría lo trata como riesgo y lo dice (`por defecto, yes`).
- **`perms` ordena con `LC_ALL=C sort -z`** y recorre con `-printf 'TIPO %p\0'`:
  los nombres de archivo pueden contener espacios o saltos de línea (Semana 09),
  y el orden no puede depender del idioma del sistema.
- **`container` lee `docker inspect` desde un archivo**, no llama a `docker`.
  Así se prueba dentro de `ubuntu-lab` (que no tiene `docker`) con una salida
  guardada, y el mismo código sirve contra un anfitrión real:
  `docker inspect NOMBRE > c.json && toolkit.sh harden container c.json`.

### 2.5 Lo que `harden` no ve

Es una auditoría de **cuatro cosas concretas**, no un escáner de seguridad:

- No analiza el binario ni busca vulnerabilidades conocidas.
- `unit` lee **un archivo**: no aplica `.d/*.conf` (lo hace `systemd-analyze cat-config`) ni el valor efectivo en un systemd vivo.
- `ssh` lee un archivo, no la configuración efectiva: para eso, `sshd -T`.
- `container` no ve montajes (`-v /:/host` es otro riesgo grave), ni `--cap-add`, ni el perfil seccomp.

Un `ok` significa «esta comprobación pasó», nunca «esto es seguro».

## 3. Cómo se usa

### 3.1 Contra datos reales

```bash
# Un contenedor del laboratorio, guardado y auditado dentro de ubuntu-lab
docker inspect ubuntu-lab | docker exec -i ubuntu-lab sh -c 'cat > /tmp/ins.json'
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/ins.json; echo "rc=$?"
# ok Privileged
# riesgo User: corre como root (User vacio o root)
# riesgo ReadonlyRootfs: el sistema de archivos raiz es escribible
# ok NetworkMode
# ok Ports
# hallazgos: 2
# rc=2
```

El laboratorio tiene dos hallazgos a propósito: necesita root para instalar
paquetes y escribir en `/etc`. Un contenedor de **producción** no debería.

### 3.2 En una vigilancia

```bash
if ! toolkit.sh harden ssh /etc/ssh/sshd_config --quiet; then
  echo "SSH con riesgos" >&2      # rc 1 o 2: aquí distingue luego con $?
fi
```

### 3.3 Divergencia de distro

`harden unit` y `harden ssh` leen formatos idénticos en las cuatro familias. Cambia
dónde están los archivos (`/usr/lib/systemd/system/` frente a `/lib/systemd/system/`,
y la unidad SSH `ssh` frente a `sshd`). En RHEL, SELinux añade una capa que `harden`
no mira; en Debian/Ubuntu, AppArmor hace lo propio.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `--privileged` «para que funcione» | Elimina casi todo el aislamiento | Descubrir qué capacidad falta y añadir solo esa |
| `-p 8080:80` sin dirección | Se publica en todas las interfaces | `-p 127.0.0.1:8080:80` |
| `--network host` por comodidad | Sin aislamiento de red | Una red de Compose y puertos publicados |
| Contenedor como root «porque la imagen lo hace» | Un fallo da root dentro | `--user` o `USER` en la imagen |
| Montar `/var/run/docker.sock` dentro | Equivale a root en el anfitrión | No hacerlo; usar una API con permisos acotados |
| Tratar `ok` como «seguro» | Solo cubre las comprobaciones listadas | Leer el alcance (2.5) |
| Imprimir cada auditoría con su propio `echo` | Los formatos se desvían y el contador falla | Una sola `harden_line` |

## 5. Trucos

- **`docker run --rm --read-only --tmpfs /tmp ...`** prueba si una aplicación
  escribe donde no debe: si falla, el mensaje señala la ruta exacta.
- **`docker inspect --format '{{json .HostConfig.Binds}}' NOMBRE`** lista los
  montajes de archivos del anfitrión: la comprobación que `harden` no hace.
- **`toolkit.sh harden perms /usr/bin --depth 1`** audita solo el primer nivel,
  rápido; sin `--depth` recorre todo el árbol sin cruzar sistemas de archivos.

## 📚 Recursos Adicionales

- [Docker: seguridad](https://docs.docker.com/engine/security/)
- `man capabilities`: la lista completa de capacidades

## ✅ Checklist de Verificación

- [ ] Lanzas un contenedor con `--read-only`, `--user` y `--cap-drop ALL` y compruebas `CapEff` a cero
- [ ] Publicas un puerto solo en `127.0.0.1` y lo ves con `docker port`
- [ ] Explicas por qué `--privileged` y `--network host` son riesgos
- [ ] Describes qué significan los códigos `0`, `1` y `2` de `harden`
- [ ] Explicas por qué `ssh` lee «la primera» y `unit` «la última»
- [ ] Nombras tres cosas que `harden container` no detecta

---

[← Contenedores desde la CLI](07-contenedores-desde-la-cli.md) · [Práctica 01: Inspeccionar systemd →](../2-practicas/01-inspeccionar-systemd.md)
