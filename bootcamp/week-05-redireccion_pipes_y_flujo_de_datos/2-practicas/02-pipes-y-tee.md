# Práctica 02: Pipes y `tee`

Esta práctica construye pipelines paso a paso y usa `tee` para ver y
guardar al mismo tiempo, incluido el caso de escritura con privilegios.

## Paso 1: Construir un pipeline agregando un comando a la vez

**Por qué**: entrenar el hábito de probar cada eslabón antes de agregar el
siguiente.

**Comando**:

```bash
cd /tmp
ps -eo user > usuarios.txt
cat usuarios.txt | head -5

cat usuarios.txt | sort | head -5

cat usuarios.txt | sort | uniq -c | head -5

cat usuarios.txt | sort | uniq -c | sort -rn | head -5
```

**Verifica**: en cada paso, la salida tiene sentido antes de agregar el
siguiente comando a la cadena.

## Paso 2: Reproducir por qué `$?` sin `pipefail` no detecta un fallo temprano

**Por qué**: ver el problema real antes de la solución.

**Comando**:

```bash
comando-que-no-existe | wc -l
echo "codigo sin pipefail: $?"

set -o pipefail
comando-que-no-existe | wc -l
echo "codigo con pipefail: $?"
```

**Verifica**: el primer `$?` es `0` (el de `wc -l`, que sí corrió);
el segundo es distinto de `0` — `pipefail` propagó el fallo real.

## Paso 3: Usar `PIPESTATUS` para ver cada código por separado

**Por qué**: confirmar el detalle que `pipefail` por sí solo no da.

**Comando**:

```bash
false | true | false
echo "${PIPESTATUS[@]}"
```

**Verifica**: la salida es `1 0 1` — un código por cada comando de la
cadena, en orden.

## Paso 4: `tee` para ver y guardar al mismo tiempo

**Por qué**: practicar el caso de uso central de `tee`.

**Comando**:

```bash
ps -eo user,pid | tee procesos.log | head -3
wc -l procesos.log
```

**Verifica**: ves las primeras tres líneas en pantalla, y `procesos.log`
contiene el listado completo, no solo esas tres líneas.

## Paso 5: `sudo tee` para escribir en un archivo protegido

**Por qué**: reproducir el caso real donde `sudo comando >` no alcanza.

**Comando**:

```bash
apt-get update -qq && apt-get install -y sudo
useradd -m -s /bin/bash operador 2>/dev/null
echo 'operador ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/operador
chmod 440 /etc/sudoers.d/operador

touch /etc/archivo-protegido.conf
chmod 600 /etc/archivo-protegido.conf

su operador -c 'echo "linea nueva" > /etc/archivo-protegido.conf' 2>&1
su operador -c 'echo "linea nueva" | sudo tee /etc/archivo-protegido.conf'
cat /etc/archivo-protegido.conf
```

**Verifica**: el primer intento (`>` con `sudo` implícito por el usuario)
falla con "Permission denied"; el segundo (`sudo tee`) funciona.

## ✅ Resultado

- [ ] Construiste un pipeline de cuatro comandos, probándolo paso a paso
- [ ] Reprodujiste la diferencia de `$?` con y sin `pipefail`
- [ ] Usaste `PIPESTATUS` para ver el código de cada comando por separado
- [ ] Usaste `tee` para ver y guardar al mismo tiempo
- [ ] Reprodujiste por qué `sudo tee` funciona donde `sudo comando >` no

```bash
./scripts/verificar-semana.sh 05
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El paso 5 funciona igual con `>` sin `tee` | El comando se corrió como `root`, sin pasar por `su operador` | Confirmar que todo el comando está dentro de `su operador -c '...'` |
| `PIPESTATUS` muestra solo un número | Se consultó `$PIPESTATUS` (sin `[@]`) en vez del array completo | Usar `${PIPESTATUS[@]}`, con los corchetes y el arroba |
| `apt-get install sudo` falla por falta de red | El contenedor necesita acceso a internet para instalar paquetes | Confirmar conectividad del host; si persiste, reportarlo como bloqueo de infraestructura, no de la práctica |

---

[← Práctica 01](01-redirecciones-de-entrada-y-salida.md) · [Práctica 03 →](03-encadenar-comandos-y-codigos-de-salida.md)
