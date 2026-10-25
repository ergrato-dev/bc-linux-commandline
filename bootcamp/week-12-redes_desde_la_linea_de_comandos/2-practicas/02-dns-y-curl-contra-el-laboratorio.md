# Práctica 02: DNS y curl contra el laboratorio

Las capas 3 y 5 con las manos: ves por qué `getent` y `dig` pueden dar
respuestas distintas, y provocas cada código de salida de `curl` (`6`, `7`,
`22`, `28`) para reconocerlo después sin pensar.

Necesitas las herramientas de la Práctica 01 (paso 1) instaladas en
`ubuntu-lab`. Los bloques *"desde tu máquina"* van en tu terminal normal;
los *"en ubuntu-lab"*, dentro del contenedor:

```bash
docker exec -it ubuntu-lab bash
```

## Paso 1: Arrancar un servidor web de juguete en rhel-lab

**Por qué**: `curl` necesita algo con lo que hablar. `rhel-lab` incluye
`python3`, que trae un servidor HTTP mínimo (archivo 05). Se guarda el PID
porque `rhel-lab` no tiene `pkill`.

**Comando** (desde tu máquina):

```bash
docker exec rhel-lab bash -c 'mkdir -p /srv/www/docs && echo "hola desde rhel-lab" > /srv/www/index.html && echo "documento" > /srv/www/docs/a.txt'
docker exec -d rhel-lab bash -c 'echo $$ > /tmp/http.pid; cd /srv/www && exec python3 -m http.server 8000 --bind 0.0.0.0'
```

**Verifica** (en ubuntu-lab, tras uno o dos segundos):

```bash
curl -s http://rhel-lab:8000/
# hola desde rhel-lab
```

## Paso 2: Leer los tres archivos de resolución

**Por qué**: antes de comparar herramientas hay que saber **qué
configuración** usa el sistema (archivo 03).

**Comando** (en ubuntu-lab):

```bash
grep ^hosts /etc/nsswitch.conf
grep -v '^#' /etc/resolv.conf
tail -1 /etc/hosts
```

**Verifica**:

```bash
grep ^hosts /etc/nsswitch.conf
# hosts:          files dns
grep -v '^#' /etc/resolv.conf
# nameserver 127.0.0.11
# options ndots:0
tail -1 /etc/hosts
# 172.27.0.5	ubuntu-lab
```

Tres hechos para anotar: el orden es **primero `/etc/hosts`**, luego DNS; el
servidor DNS es `127.0.0.11` (el de Docker); y la última línea de
`/etc/hosts` es tu propio contenedor.

## Paso 3: `getent` y `dig`, la misma pregunta

**Por qué**: con un nombre normal los dos coinciden. Hay que verlo antes de
romper la igualdad en el paso siguiente.

**Comando**:

```bash
getent hosts rhel-lab
dig +short rhel-lab
dig rhel-lab | grep -E 'status|SERVER'
```

**Verifica**:

```bash
getent hosts rhel-lab
# 172.27.0.4      rhel-lab
dig +short rhel-lab
# 172.27.0.4
dig rhel-lab | grep -E 'status|SERVER'
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4852
# ;; SERVER: 127.0.0.11#53(127.0.0.11) (UDP)
```

El `id` cambia en cada consulta. Fíjate en `SERVER: 127.0.0.11`: es el
`nameserver` del paso 2, y `NOERROR` es la respuesta sana.

## Paso 4: Una entrada en `/etc/hosts` que `dig` no ve

**Por qué**: es el caso que explica por qué un nombre "no existe" para `dig`
pero sí para `curl` (archivo 03). Modificas un archivo del **contenedor**,
así que primero se hace la copia y al final se restaura.

> ⚠️ **Advertencia**: este paso edita `/etc/hosts` del contenedor. La
> copia en `/tmp/hosts.bak` es la vuelta atrás; **no la borres hasta
> terminar el paso**. Está dentro del laboratorio: tu `/etc/hosts` real no
> se toca.

> `/etc/hosts` es un archivo que **Docker monta** dentro del contenedor:
> `sed -i` falla sobre él (`sed: cannot rename ...: Device or resource
> busy`) porque intenta sustituir el archivo en lugar de escribir dentro.
> Por eso aquí se añade con `>>` y se restaura con `cp`, que escriben
> **dentro** del archivo.

**Comando** (en ubuntu-lab):

```bash
cp /etc/hosts /tmp/hosts.bak
echo '10.99.99.99 miservicio.test' >> /etc/hosts
getent hosts miservicio.test
dig +short miservicio.test
ping -c1 -W1 miservicio.test | head -1
```

**Verifica**:

```bash
getent hosts miservicio.test
# 10.99.99.99     miservicio.test
dig +short miservicio.test
#                                       <- vacío
ping -c1 -W1 miservicio.test | head -1
# PING miservicio.test (10.99.99.99) 56(84) bytes of data.
```

`getent` y `ping` ven la entrada; `dig` no. Y fíjate en que el código de
salida de `dig` es `0`:

```bash
dig +short miservicio.test; echo "codigo: $?"
# codigo: 0
```

Restaura y comprueba que la entrada desapareció:

```bash
cp /tmp/hosts.bak /etc/hosts
getent hosts miservicio.test; echo "codigo: $?"
# codigo: 2
```

## Paso 5: Un nombre que no existe y un servidor que no contesta

**Por qué**: reconocer cómo falla cada caso: `NXDOMAIN` frente a un
servidor DNS que no responde (archivo 03).

**Comando**:

```bash
dig no-existe.invalid | grep -E 'status'
getent hosts no-existe.invalid; echo "getent: $?"
dig +short A example.com
dig @8.8.8.8 +short A example.com
```

**Verifica**:

```bash
dig no-existe.invalid | grep -E 'status'
# ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 25830
getent hosts no-existe.invalid; echo "getent: $?"
# getent: 2
dig +short A example.com
# 104.20.23.154
# 172.66.147.243
dig @8.8.8.8 +short A example.com
# 104.20.23.154
# 172.66.147.243
```

Las dos IP de `example.com` pueden ser otras y en otro orden. Lo
importante es que **ambos servidores dan lo mismo**: así se descarta que el
problema sea tu resolvedor. (Si no hay salida a internet, estas dos
últimas líneas no responden; ver *Si algo sale mal*.)

## Paso 6: Provocar cada código de salida de `curl`

**Por qué**: el código de `curl` dice en qué capa falló (archivo 05). Si
lo has visto cuatro veces, lo reconoces a la quinta.

**Comando** (en ubuntu-lab):

```bash
for u in http://rhel-lab:8000/ http://rhel-lab:8000/nada http://rhel-lab:9999/ http://no-existe.invalid/; do
  curl -sf --max-time 3 -o /dev/null "$u"; echo "$u -> $?"
done
curl -sf --max-time 2 -o /dev/null http://10.255.255.1/; echo "http://10.255.255.1/ -> $?"
```

**Verifica**:

```bash
# http://rhel-lab:8000/ -> 0
# http://rhel-lab:8000/nada -> 22
# http://rhel-lab:9999/ -> 7
# http://no-existe.invalid/ -> 6
# http://10.255.255.1/ -> 28
```

La última tarda dos segundos (el `--max-time`): es la espera de un
*timeout*. Compara con `7`, que fue **instantáneo**. Y esa diferencia (un
rechazo inmediato frente a una espera) es la señal más útil de la semana.

Para ver **el mensaje** y no solo el código, `-S`:

```bash
curl -sS --max-time 3 http://rhel-lab:9999/
# curl: (7) Failed to connect to rhel-lab port 9999 after 0 ms: Couldn't connect to server
curl -sSf http://rhel-lab:8000/nada
# curl: (22) The requested URL returned error: 404
```

## Paso 7: Cabeceras, redirecciones y tiempos

**Por qué**: leer una respuesta HTTP y medir dónde se va el tiempo
(archivo 05).

**Comando**:

```bash
curl -sI http://rhel-lab:8000/ | head -3
curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://rhel-lab:8000/docs
curl -sL -o /dev/null -w '%{http_code} final=%{url_effective}\n' http://rhel-lab:8000/docs
curl -s -o /dev/null -w 'code=%{http_code} ip=%{remote_ip} total=%{time_total}\n' http://rhel-lab:8000/
```

**Verifica**:

```bash
curl -sI http://rhel-lab:8000/ | head -3
# HTTP/1.0 200 OK
# Server: SimpleHTTP/0.6 Python/3.9.18
# Date: Sun, 25 Oct 2026 02:41:01 GMT
curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://rhel-lab:8000/docs
# 301 -> http://rhel-lab:8000/docs/
curl -sL -o /dev/null -w '%{http_code} final=%{url_effective}\n' http://rhel-lab:8000/docs
# 200 final=http://rhel-lab:8000/docs/
curl -s -o /dev/null -w 'code=%{http_code} ip=%{remote_ip} total=%{time_total}\n' http://rhel-lab:8000/
# code=200 ip=172.27.0.4 total=0.002308
```

La fecha y el `total` (en segundos) variarán. Sin `-L`, `curl` se queda
en el `301`; con `-L`, llega al `200` final.

Y la prueba de `--resolve`, con un nombre que **no existe** en ningún DNS:

```bash
curl -s --resolve prueba.test:8000:172.27.0.4 http://prueba.test:8000/
# hola desde rhel-lab
```

## Paso 8: Diagnosticar un fallo por capas

**Por qué**: es el ejercicio central de la semana: provocas un fallo y lo
localizas siguiendo el método del archivo 06, sin saltarte capas.

**Comando** (desde tu máquina): apaga el servidor.

```bash
docker exec rhel-lab bash -c 'kill "$(cat /tmp/http.pid)"'
```

Y ahora, **en ubuntu-lab**, diagnostica sin mirar la causa:

```bash
cat /sys/class/net/eth0/operstate
ip route get 172.27.0.4
getent hosts rhel-lab
ping -c1 -W1 rhel-lab | grep received
nc -zv -w2 rhel-lab 8000
curl -sS --max-time 3 http://rhel-lab:8000/; echo "curl: $?"
```

**Verifica**:

```bash
# up
# 172.27.0.4 dev eth0 src 172.27.0.5 uid 0
#     cache
# 172.27.0.4      rhel-lab
# 1 packets transmitted, 1 received, 0% packet loss, time 0ms
# nc: connect to rhel-lab (172.27.0.4) port 8000 (tcp) failed: Connection refused
# curl: (7) Failed to connect to rhel-lab port 8000 after 0 ms: Couldn't connect to server
# curl: 7
```

El veredicto: capas 1 a 3 sanas, la máquina responde a `ping`, y el puerto
**rechaza**: el servicio no está arrancado. Arréglalo (desde tu máquina) y
confirma que el diagnóstico vuelve a verde:

```bash
docker exec -d rhel-lab bash -c 'echo $$ > /tmp/http.pid; cd /srv/www && exec python3 -m http.server 8000 --bind 0.0.0.0'
docker exec ubuntu-lab curl -s http://rhel-lab:8000/
# hola desde rhel-lab
```

## ✅ Resultado

- [ ] Viste que `getent` y `ping` usan `/etc/hosts` y `dig` no
- [ ] Restauraste `/etc/hosts` y `getent hosts miservicio.test` sale con `2`
- [ ] Provocaste los códigos `0`, `22`, `7`, `6` y `28` de `curl`
- [ ] Distingues un rechazo instantáneo (`7`) de una espera hasta el *timeout* (`28`)
- [ ] Diagnosticaste el servidor apagado capa por capa y lo volviste a arrancar

```bash
./scripts/verificar-semana.sh 12
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `curl: (7)` en el paso 1 | El servidor aún no había arrancado | Espera un segundo y repite; confirma con `nc -zv -w2 rhel-lab 8000` desde `ubuntu-lab` |
| `curl: (6)` para `rhel-lab` | Los contenedores no comparten red | `./scripts/start.sh` y repite |
| `dig @8.8.8.8` se queda esperando | El contenedor no tiene salida a internet (o está bloqueada) | Es un paso ilustrativo: salta ese comando |
| `getent hosts miservicio.test` sigue resolviendo tras restaurar | No ejecutaste el `cp /tmp/hosts.bak /etc/hosts` | Ejecútalo y vuelve a comprobar |
| `dig: command not found` | No se instaló `dnsutils` | Práctica 01, paso 1 |
| `kill: usage` al apagar el servidor | No existe `/tmp/http.pid` (se arrancó sin guardar el PID) | Repite el arranque del paso 1 tal como está escrito |

---

[← Práctica 01](01-interfaces-rutas-y-puertos.md) · [Práctica 03 →](03-ssh-entre-contenedores.md)
