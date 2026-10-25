# Práctica 04: Contenedores desde el anfitrión

> Duración: 60 min · Teoría: archivos [07](../1-teoria/07-contenedores-desde-la-cli.md) y [08](../1-teoria/08-seguridad-de-contenedores-y-harden.md)

A diferencia de las demás, esta práctica se hace **en tu máquina (el anfitrión)**,
con la CLI de `docker` hablando con los contenedores del laboratorio. Dentro de
`ubuntu-lab` no hay `docker`. Solo tocas contenedores cuyo nombre acaba en `-lab`
y uno temporal llamado `wk19-p04` que tú creas y borras.

> ⚠️ Filtra siempre por nombre (`--filter name=-lab`). En una máquina con otros
> contenedores, `docker ps` los mostrará todos: no los inspecciones ni los pares.

## Paso 1: Ver los contenedores del laboratorio

**Por qué**: antes de diagnosticar, saber qué hay y desde cuándo. `--format` con
`table` da columnas legibles sin el ruido del `docker ps` por defecto.

**Comando**:

```bash
docker ps --filter name=-lab --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
```

**Verifica**:

```bash
docker ps --filter name=-lab --format '{{.Names}}' | sort
# arch-lab
# debian-lab
# rhel-lab
# ubuntu-lab
```

## Paso 2: Los procesos de un contenedor son procesos tuyos

**Por qué**: un contenedor es un proceso del anfitrión con otra vista. `docker top`
lo demuestra: lista los procesos con los PID **del anfitrión**.

**Comando**:

```bash
docker top ubuntu-lab -eo pid,ppid,user,comm | head -4
docker inspect --format '{{.State.Pid}}' ubuntu-lab
```

**Verifica**:

```bash
pid=$(docker inspect --format '{{.State.Pid}}' ubuntu-lab)
ps -p "$pid" -o comm=
# sleep
# (el PID 1 del contenedor es "sleep infinity"; fuera de el, tiene un PID grande)
docker exec ubuntu-lab cat /proc/1/cmdline | tr '\0' ' '; echo
# sleep infinity
```

## Paso 3: Medir el consumo

**Por qué**: los *cgroups* limitan y miden CPU, memoria y número de procesos.
`stats --no-stream` toma una sola muestra; sin esa bandera, el comando no termina.

**Comando**:

```bash
docker stats --no-stream --format '{{.Name}} {{.CPUPerc}} {{.MemUsage}} {{.PIDs}}' ubuntu-lab
```

**Verifica**:

```bash
docker stats --no-stream --format '{{.Name}}' ubuntu-lab
# ubuntu-lab
docker stats --no-stream --format '{{.PIDs}}' ubuntu-lab | grep -cE '^[0-9]+$'
# 1
```

## Paso 4: Extraer con `inspect --format` lo que importa para seguridad

**Por qué**: los campos `Privileged`, `User` y `ReadonlyRootfs` son los que mira
`toolkit harden container`. Leerlos a mano una vez te hace entender el informe.

**Comando**:

```bash
docker inspect --format '{{.HostConfig.Privileged}} {{printf "%q" .Config.User}} {{.HostConfig.ReadonlyRootfs}} {{.HostConfig.NetworkMode}}' ubuntu-lab
```

**Verifica**:

```bash
docker inspect --format '{{.HostConfig.Privileged}} {{printf "%q" .Config.User}} {{.HostConfig.ReadonlyRootfs}}' ubuntu-lab
# false "" false
# privilegiado=no, usuario vacio (= root), raiz escribible
```

## Paso 5: Registros de un contenedor

**Por qué**: `docker logs` muestra lo que el PID 1 escribe en su salida estándar. Lo
compruebas escribiendo tú en el descriptor 1 del PID 1.

**Comando**:

```bash
docker exec ubuntu-lab sh -c 'echo p04-linea > /proc/1/fd/1'
docker logs --tail 1 ubuntu-lab
```

**Verifica**:

```bash
docker logs --tail 1 ubuntu-lab
# p04-linea
```

## Paso 6: Entrar como otro usuario y ver qué cambia

**Por qué**: `exec` sin `-u` entra como el usuario del contenedor (root aquí). Con
`-u 1000` ves cómo se ve el sistema sin privilegios.

**Comando**:

```bash
docker exec -u 1000 ubuntu-lab id -un
docker exec -u 1000 ubuntu-lab sh -c 'touch /etc/p04 2>&1 | head -1'
```

**Verifica**:

```bash
docker exec -u 1000 ubuntu-lab id -un
# ubuntu
docker exec -u 1000 ubuntu-lab sh -c 'touch /etc/p04 2>&1'
# touch: cannot touch '/etc/p04': Permission denied
```

## Paso 7: Qué ha escrito el contenedor (`diff`)

**Por qué**: `docker diff` lista lo que cambió respecto a la imagen original: A
añadido, C cambiado, D borrado. Sirve para descubrir dónde escribe una aplicación.

**Comando**:

```bash
docker exec ubuntu-lab touch /root/p04.txt
docker diff ubuntu-lab | grep p04
docker exec ubuntu-lab rm /root/p04.txt
```

**Verifica**:

```bash
docker exec ubuntu-lab touch /root/p04.txt; docker diff ubuntu-lab | grep p04
# A /root/p04.txt
docker exec ubuntu-lab rm /root/p04.txt; docker diff ubuntu-lab | grep -c p04
# 0
```

## Paso 8: Los *namespaces* son distintos

**Por qué**: el aislamiento de procesos es un *namespace* de PID. Dos procesos con el
mismo identificador en `/proc/PID/ns/pid` comparten vista; el contenedor tiene la suya.

**Comando**:

```bash
echo "anfitrion: $(readlink /proc/self/ns/pid)"
echo "contenedor: $(docker exec ubuntu-lab readlink /proc/self/ns/pid)"
docker exec ubuntu-lab ls /proc/self/ns
```

**Verifica**:

```bash
[ "$(readlink /proc/self/ns/pid)" != "$(docker exec ubuntu-lab readlink /proc/self/ns/pid)" ] && echo distintos
# distintos
docker exec ubuntu-lab ls /proc/self/ns | wc -l
# 10
```

## Paso 9: Lanzar un contenedor endurecido

**Por qué**: es el contrapunto del laboratorio. Las banderas del archivo 08 cierran
lo que `ubuntu-lab` deja abierto. Se publica solo en `127.0.0.1` y se le pone tope
de memoria y de procesos.

**Comando**:

```bash
docker run -d --rm --name wk19-p04 -p 127.0.0.1:18081:80 \
  --user 1000 --read-only --cap-drop ALL --security-opt no-new-privileges \
  --memory 64m --pids-limit 50 ubuntu:24.04 sleep 120
docker port wk19-p04
```

**Verifica**:

```bash
docker port wk19-p04
# 80/tcp -> 127.0.0.1:18081
docker exec wk19-p04 sh -c 'id -u; touch /x 2>&1; grep CapEff /proc/self/status'
# 1000
# touch: cannot touch '/x': Read-only file system
# CapEff:	0000000000000000
```

## Paso 10: Auditar los dos con `harden container` y limpiar

**Por qué**: `harden container` lee un archivo con la salida de `docker inspect`.
Como `ubuntu-lab` no tiene `docker`, guardas la salida en el anfitrión y la copias
dentro. El laboratorio debe dar riesgos; el endurecido, ninguno.

**Comando**:

```bash
docker inspect wk19-p04 > /tmp/p04.json
docker cp /tmp/p04.json ubuntu-lab:/tmp/p04.json
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/p04.json; echo "rc=$?"
docker inspect ubuntu-lab | docker exec -i ubuntu-lab sh -c 'cat > /tmp/p04b.json'
docker exec ubuntu-lab /root/bin/toolkit.sh harden container /tmp/p04b.json --quiet; echo "rc=$?"
# --- limpieza ---
docker stop wk19-p04
docker exec ubuntu-lab rm -f /tmp/p04.json /tmp/p04b.json
rm -f /tmp/p04.json
```

**Verifica**:

```bash
# El endurecido:
#   ok Privileged / ok User / ok ReadonlyRootfs / ok NetworkMode / ok Ports
#   hallazgos: 0
#   rc=0
# El del laboratorio (con --quiet solo salen los riesgos):
#   riesgo User: corre como root (User vacio o root)
#   riesgo ReadonlyRootfs: el sistema de archivos raiz es escribible
#   hallazgos: 2
#   rc=2
sleep 2; docker ps -a --filter name=wk19-p04 -q | wc -l
# 0
```

## ✅ Resultado

- [ ] Listé los contenedores del laboratorio con `--format`
- [ ] Probé que el PID 1 del contenedor es un proceso del anfitrión
- [ ] Medí consumo con `stats --no-stream`
- [ ] Leí `Privileged`, `User` y `ReadonlyRootfs` con `inspect --format`
- [ ] Vi un mensaje en `docker logs` escribiendo en el PID 1
- [ ] Entré como el usuario 1000 y comprobé la diferencia con root
- [ ] Observé que los *namespaces* de PID son distintos
- [ ] Lancé un contenedor endurecido, publicado solo en `127.0.0.1`
- [ ] `harden container` dio 2 riesgos en el laboratorio y 0 en el endurecido
- [ ] Borré el contenedor temporal

```bash
bash scripts/verificar-semana.sh 19
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `docker: command not found` dentro de `ubuntu-lab` | La CLI vive en el anfitrión | Sal del contenedor (`exit`) y ejecuta en tu máquina |
| `permission denied` al hablar con el demonio | Tu usuario no está en el grupo `docker` | `sudo usermod -aG docker <tu-usuario>` y vuelve a entrar en sesión |
| `port is already allocated` | El 18081 está ocupado | Cambia el puerto de la izquierda (`127.0.0.1:18082:80`) |
| `Conflict. The container name "/wk19-p04" is already in use` | Quedó uno de un intento anterior | `docker rm -f wk19-p04` |
| `template parsing error` | Usaste `!=` en una plantilla | Usa `ne`: `{{ne .State.Pid 0}}` |
| `harden container`: `no parece la salida de docker inspect` | El archivo no contiene `"HostConfig"` | Revisa que `docker inspect NOMBRE > archivo` terminó bien |

---

[← Práctica 03: Seguridad básica y SSH](03-seguridad-basica-y-ssh.md) · [Práctica 05: `harden` a mano →](05-harden-a-mano.md)
