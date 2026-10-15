# Práctica 01: Primer contacto con ubuntu-lab

Esta práctica te mete directo en el contenedor del laboratorio, confirma que
sabes identificar dónde estás parado, y deja tu primer alias configurado.

## Paso 1: Entrar al contenedor

**Por qué**: todo el trabajo de este bootcamp ocurre dentro de `ubuntu-lab`,
nunca en tu máquina host. Si algo sale mal ahí adentro, se destruye y se
recrea sin ningún riesgo real.

**Comando**:

```bash
# Si todavia no levantaste el laboratorio:
./scripts/start.sh

# Entrar a una sesion interactiva dentro de ubuntu-lab
docker exec -it ubuntu-lab bash
```

**Verifica**:

```bash
whoami
# root (o el usuario que configure la imagen)

cat /etc/os-release | grep PRETTY_NAME
# PRETTY_NAME="Ubuntu 24.04 LTS"
```

## Paso 2: Identificar las cuatro capas que viste en la teoría

**Por qué**: distinguir TTY, shell y kernel desde el primer día evita que
confundas "mi terminal se ve rara" con "mi shell está mal configurado" más
adelante.

**Comando**:

```bash
tty
ps -o pid,ppid,tty,comm
echo "soy el shell: $(ps -p $$ -o comm=)"
```

**Verifica**:

```
/dev/pts/0
  PID  PPID TT       COMMAND
    1     0 pts/0    bash
   47     1 pts/0    ps
soy el shell: bash
```

## Paso 3: Leer tu `$PS1` tal cual está, sin tocarlo todavía

**Por qué**: antes de modificar el prompt, conviene ver qué secuencias ya
trae por defecto en esta imagen — así notas la diferencia después.

**Comando**:

```bash
echo "$PS1"
```

**Verifica**: el resultado contiene al menos una de las secuencias `\u`,
`\h`, `\w` o `\$` vistas en la teoría. Si no aparece ninguna, es que la
imagen base no trae prompt configurado — normal en bases mínimas, y motivo
suficiente para el paso 4.

## Paso 4: Agregar el código de salida al prompt

**Por qué**: es la señal más barata que existe para saber, de un vistazo, si
el comando anterior falló — y la vas a usar todo el bootcamp.

**Comando**:

```bash
cat >> ~/.bashrc << 'EOF'

# Muestra el codigo de salida del comando anterior si fue distinto de 0
PS1='$(ec=$?; [ $ec -ne 0 ] && echo "[✗$ec] ")'"$PS1"
EOF

source ~/.bashrc
```

**Verifica**:

```bash
false
# el prompt siguiente deberia mostrar [✗1] antes del resto

true
# el prompt siguiente vuelve a verse normal, sin marca de error
```

## Paso 5: Subir el historial a un tamaño razonable

**Por qué**: el valor por defecto (1000 líneas) se queda corto en una sesión
de trabajo real, y perder comandos de hace una hora es una fricción
innecesaria y evitable.

**Comando**:

```bash
cat >> ~/.bashrc << 'EOF'

export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:ignorespace
EOF

source ~/.bashrc
```

**Verifica**:

```bash
echo "HISTSIZE=$HISTSIZE HISTFILESIZE=$HISTFILESIZE"
# HISTSIZE=10000 HISTFILESIZE=20000
```

## Paso 6: Tu primer alias

**Por qué**: `ls -la` es uno de los comandos que más vas a repetir en este
bootcamp. Un alias corto ahorra tecleo real, todos los días, para siempre.

**Comando**:

```bash
cat >> ~/.bashrc << 'EOF'

alias ll='ls -la --color=auto'
EOF

source ~/.bashrc
```

**Verifica**:

```bash
type ll
# ll es un alias para 'ls -la --color=auto'

ll /etc | head -3
```

## ✅ Resultado

- [ ] Entraste a `ubuntu-lab` y confirmaste que es Ubuntu 24.04 LTS
- [ ] Identificaste tu PTY, tu shell y la cadena de procesos con `ps`
- [ ] Tu prompt ahora muestra el código de salida cuando un comando falla
- [ ] `HISTSIZE`/`HISTFILESIZE` quedaron configurados en `~/.bashrc`
- [ ] El alias `ll` existe y funciona

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `docker exec` dice "No such container" | El laboratorio no está levantado | Correr `./scripts/start.sh` desde la raíz del repositorio, en tu máquina host, no dentro del contenedor |
| El prompt no muestra `[✗N]` tras un `false` | `source ~/.bashrc` no se ejecutó, o hay un error de sintaxis en el bloque agregado | Revisar `tail -20 ~/.bashrc` buscando algo mal cerrado; volver a correr `source ~/.bashrc` y mirar si tira error |
| `type ll` dice "not found" | El `cat >> ~/.bashrc` se escribió en una sesión y estás verificando en otra que no hizo `source` | Correr `source ~/.bashrc` en la sesión donde estás verificando |

---

[← 06 — Historial y edición de línea](../1-teoria/06-historial-y-edicion-de-linea.md) · [Práctica 02 →](02-navegar-la-ayuda-y-el-manual.md)
