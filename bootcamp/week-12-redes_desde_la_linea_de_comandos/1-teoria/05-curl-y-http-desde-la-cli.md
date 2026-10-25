# curl y HTTP desde la CLI

> Los cuatro archivos anteriores comprueban que **llegas** al servidor.
> `curl` comprueba que el servidor **responde bien**: es la última capa, la
> de la aplicación, y la que más se automatiza.

## 🎯 Objetivos

- Leer una petición y una respuesta HTTP con `curl -v`
- Elegir entre `-s`, `-S`, `-f`, `-I`, `-i`, `-o` y `-w` según lo que necesites
- Reconocer los códigos de salida de `curl` (`6`, `7`, `22`, `28`) y qué capa señalan
- Medir dónde se va el tiempo de una petición (DNS, conexión, total)

## 1. Qué problema resuelve

Puedes tener interfaz, ruta, DNS y un puerto abierto, y que la aplicación
siga mal: responde un `500`, un `404`, o tarda treinta segundos. `ping` y
`nc -z` no lo ven, porque solo comprueban que algo acepta la conexión.
`curl` habla el protocolo HTTP de verdad y devuelve **dos cosas
independientes**: el contenido de la respuesta y un **código de salida** que
dice en qué capa falló. Con esas dos cosas, un script decide solo.

## 2. Cómo funciona

### 2.1 Un servidor para practicar

El laboratorio no trae servidores web. `rhel-lab` tiene `python3`, que
incluye uno mínimo; se arranca **desde tu máquina** y queda en segundo plano
dentro del contenedor:

```bash
docker exec rhel-lab bash -c 'mkdir -p /srv/www && echo "hola desde rhel-lab" > /srv/www/index.html'
docker exec -d rhel-lab bash -c 'echo $$ > /tmp/http.pid; cd /srv/www && exec python3 -m http.server 8000 --bind 0.0.0.0'
```

`echo $$ > /tmp/http.pid` guarda el PID (que `exec` conserva) porque `rhel-lab`
no trae `pkill`: así podrás apagarlo con `kill "$(cat /tmp/http.pid)"`.
`--bind 0.0.0.0` lo hace visible para los otros contenedores (archivo 04).
Es un servidor de **juguete**, sin cifrado ni autenticación: solo vive
dentro de la red interna del laboratorio.

```bash
# Desde ubuntu-lab:
curl http://rhel-lab:8000/
# hola desde rhel-lab
```

### 2.2 Lo que `curl` envía y recibe: `-v`

```bash
curl -sv http://rhel-lab:8000/ 2>&1 | grep -E '^[*<>]'
# * Host rhel-lab:8000 was resolved.
# * IPv4: 172.27.0.4
# *   Trying 172.27.0.4:8000...
# * Connected to rhel-lab (172.27.0.4) port 8000
# > GET / HTTP/1.1
# > Host: rhel-lab:8000
# > User-Agent: curl/8.5.0
# > Accept: */*
# < HTTP/1.0 200 OK
# < Server: SimpleHTTP/0.6 Python/3.9.18
# < Content-type: text/html
# < Content-Length: 20
```

Las líneas con `*` son el trabajo de `curl` (**resolvió el nombre**, **se
conectó**: capas 3 y 4 que ya conoces); las `>` es lo que **envía**; las `<`
es lo que **recibe**. Una petición HTTP es una línea (`GET / HTTP/1.1`),
cabeceras y, a veces, un cuerpo; la respuesta es una línea de estado
(`HTTP/1.0 200 OK`), cabeceras y el cuerpo.

### 2.3 Los códigos de estado

El primer dígito de `200`, `301`, `404`, `500` es la familia:

| Familia | Significa | Ejemplos |
|:--:|---|---|
| `2xx` | Todo bien | `200 OK` |
| `3xx` | Mira en otro sitio | `301 Moved Permanently`, `302 Found` |
| `4xx` | Error **tuyo** (petición mala) | `401` sin credenciales, `404` no existe |
| `5xx` | Error **del servidor** | `500` fallo interno, `503` no disponible |

## 3. Cómo se usa

### 3.1 Las opciones que definen el comportamiento

| Opción | Qué hace |
|:--:|---|
| `-s` (*silent*) | Sin barra de progreso ni mensajes: la salida es solo el contenido |
| `-S` | Con `-s`, **vuelve a mostrar los errores** (`-sS`) |
| `-f` (*fail*) | Con un `4xx`/`5xx`, no imprime el cuerpo de error y sale con código `22` |
| `-I` | Pide solo las **cabeceras** (petición `HEAD`) |
| `-i` | Incluye las cabeceras de la respuesta antes del cuerpo |
| `-o archivo` | Guarda el cuerpo en un archivo (`-o /dev/null` lo descarta) |
| `-L` | Sigue redirecciones `3xx` |
| `--max-time N` | Aborta si **toda** la operación pasa de N segundos |
| `--connect-timeout N` | Aborta si **conectar** pasa de N segundos |

La combinación de scripts es `-sSf`: sin ruido, con el error visible si algo
sale mal, y con código de salida distinto de cero ante un `4xx`/`5xx`.

```bash
curl -sSf http://rhel-lab:8000/nada
# curl: (22) The requested URL returned error: 404
```

Sin `-f`, `curl` sale con `0` aunque el servidor responda `404`: para él, la
petición **funcionó** (recibió una respuesta). Es la causa de más scripts
rotos con `curl`.

### 3.2 El código de salida cuenta en qué capa falló

```bash
for u in http://rhel-lab:8000/ http://rhel-lab:8000/nada http://rhel-lab:9999/ http://no-existe.invalid/; do
  curl -sf --max-time 3 -o /dev/null "$u"; echo "$u -> $?"
done
# http://rhel-lab:8000/ -> 0
# http://rhel-lab:8000/nada -> 22
# http://rhel-lab:9999/ -> 7
# http://no-existe.invalid/ -> 6
curl -sf --max-time 2 -o /dev/null http://10.255.255.1/; echo "10.255.255.1 -> $?"
# 10.255.255.1 -> 28
```

| Código | Mensaje | Capa que señala |
|:--:|---|---|
| `6` | `Could not resolve host` | **DNS** (archivo 03) |
| `7` | `Failed to connect` / `Connection refused` | **TCP**: nadie escucha (archivo 04) |
| `28` | `Operation timed out` | **Ruta o cortafuegos**: nadie contestó (archivo 02/04) |
| `22` | `The requested URL returned error` | **Aplicación**: respondió con `4xx`/`5xx` (solo con `-f`) |
| `0` | — | Todo bien |

Los códigos de `curl` son el mismo diagnóstico por capas de la semana,
empaquetado en un número.

### 3.3 Medir con `-w`

`-w` imprime variables de la petición tras terminar. Con `-o /dev/null`
solo ves la medición:

```bash
curl -s -o /dev/null -w 'code=%{http_code} ip=%{remote_ip} port=%{remote_port} dns=%{time_namelookup} connect=%{time_connect} total=%{time_total}\n' http://rhel-lab:8000/
# code=200 ip=172.27.0.4 port=8000 dns=0.000896 connect=0.001155 total=0.002308
```

Tiempos **acumulados**, en segundos: `dns` es el instante en que terminó la
resolución; `connect` el de la conexión TCP; `total` el de toda la petición.
Si `dns` es grande, el DNS es lento; si `connect - dns` es grande, la red
lo es; si `total - connect` es grande, lo es la aplicación. Para un script,
la forma más corta de obtener solo el código:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://rhel-lab:8000/index.html
# 200
```

### 3.4 Redirecciones

```bash
curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://rhel-lab:8000/docs
# 301 -> http://rhel-lab:8000/docs/
curl -sL -o /dev/null -w '%{http_code} final=%{url_effective}\n' http://rhel-lab:8000/docs
# 200 final=http://rhel-lab:8000/docs/
```

Sin `-L`, `curl` se queda en el `301` y no sigue. `%{url_effective}` dice
dónde terminó.

### 3.5 Probar un servidor sin tocar el DNS

```bash
# --resolve nombre:puerto:IP: solo para esta llamada, "nombre" va a esa IP.
curl -s --resolve prueba.test:8000:172.27.0.4 http://prueba.test:8000/
# hola desde rhel-lab
```

Es la forma de probar un servidor antes de cambiar el DNS, o de comprobar
un sitio concreto detrás de un balanceador, sin editar `/etc/hosts`.

### 3.6 Reintentos y cabeceras

```bash
# Reintenta 2 veces, incluso ante "refused"; 1 s entre intentos.
curl -s --retry 2 --retry-connrefused --retry-delay 1 --max-time 2 http://rhel-lab:9999/; echo "codigo: $?"
# codigo: 7
```

Una cabecera propia se manda con `-H`:

```bash
curl -s -H "Authorization: Bearer $API_TOKEN" https://api.ejemplo.test/datos
```

> 🔐 **Seguridad**: lo que escribes en la línea de comandos es **visible**
> en `ps` para otros usuarios de la máquina y queda en el historial. Un
> token real no va en `-H` en una máquina compartida. Dos alternativas,
> ambas verificadas en el laboratorio: `curl -H @archivo` (las cabeceras se
> leen de un archivo con permisos `600`) y `curl -K -` (la configuración,
> incluida una línea `header = "..."`, llega por la entrada estándar). En
> este bootcamp, los ejemplos usan `$API_TOKEN` o `<TOKEN>`, nunca una
> credencial real.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `curl url` sin `-f` en un script | Un `404` o `500` sale con `0` y el script sigue como si fuera bien | `curl -sSf` |
| `curl -s` sin `-S` | `-s` silencia también los errores: el script falla sin decir por qué | `-sS` |
| Sin `--max-time` | Una petición que se cuelga bloquea el script para siempre | `--max-time 10` y, si repites, `--retry` |
| `curl ... \| sudo bash` | Ejecuta como `root` lo que baje, sin que lo hayas visto | Descargar a un archivo (`-o`), **leerlo** y luego ejecutarlo |
| Pegar un token en `-H` en una máquina compartida | Queda en `ps` y en el historial | `-H @archivo`, `-K` o la variable de entorno dentro del script |
| Medir con `time curl` | Incluye el arranque del proceso | `-w '%{time_total}'` |

## 5. Trucos

- `curl -w '%{json}' -o /dev/null url` imprime **todas** las variables de
  `-w` como JSON: la forma de ver qué más se puede medir.
- `curl -I -L url` muestra las cabeceras de **toda** la cadena de
  redirecciones, no solo de la última.
- `curl -H 'Host: otro.test' http://IP/` cambia la cabecera `Host` sin tocar
  el DNS: así se prueba qué sitio sirve un servidor con varios (*virtual
  hosts*). Con el servidor de juguete del laboratorio no se nota (sirve lo
  mismo para cualquier `Host`).
- `python3 -m http.server` sirve el directorio actual en cualquier máquina
  con Python: para pasar un archivo a otra máquina de tu red en un minuto
  (y apagarlo después con `Ctrl+C`).

## 📚 Recursos Adicionales

- `man curl`: la lista completa de opciones y de códigos de salida (sección *EXIT CODES*)
- [Everything curl](https://everything.curl.dev/): el libro oficial, gratuito

## ✅ Checklist de Verificación

- [ ] `curl -s http://rhel-lab:8000/` desde `ubuntu-lab` imprime `hola desde rhel-lab`
- [ ] `curl -sf http://rhel-lab:8000/nada; echo $?` imprime `22`
- [ ] Reproduces los códigos `6`, `7` y `28` y sabes qué capa señala cada uno
- [ ] Con `-w` obtienes el código HTTP y el tiempo total de una petición

---

[← Puertos, sockets y ss](04-puertos-sockets-y-ss.md) · [Diagnóstico por capas →](06-diagnostico-por-capas.md)
