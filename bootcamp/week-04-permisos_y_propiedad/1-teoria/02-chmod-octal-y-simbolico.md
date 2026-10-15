# `chmod`: octal y simbólico

> `chmod 755` es una secuencia de tres dígitos que la mayoría memoriza sin
> entender. Esta sección da el cálculo real detrás, para que puedas
> construir cualquier combinación sin adivinar ni buscarla en internet.

## 🎯 Objetivos

- Calcular cualquier permiso octal a partir de `rwx`, sin memorizar tablas
- Usar la notación simbólica de `chmod` para cambios puntuales
- Elegir cuándo conviene octal y cuándo simbólico
- Reconocer el cuarto dígito octal como una capa aparte, antes de verla a fondo

## 1. Qué problema resuelve

`chmod 755` funciona, pero copiarlo sin entender el cálculo significa que
no puedes construir `640`, o `2770`, o cualquier combinación que no hayas
visto antes copiada de algún lado. El sistema octal es, literalmente, un
cálculo de tres bits por grupo — una vez que lo entiendes, cualquier
combinación se construye en segundos, sin tabla de referencia.

## 2. Cómo funciona

### 2.1 El cálculo: cada letra vale una potencia de 2

```
r = 4
w = 2
x = 1
```

Cada dígito octal es la **suma** de las letras presentes en ese ámbito:

```
rwx = 4+2+1 = 7
rw- = 4+2+0 = 6
r-x = 4+0+1 = 5
r-- = 4+0+0 = 4
-wx = 0+2+1 = 3
--x = 0+0+1 = 1
--- = 0+0+0 = 0
```

`chmod 755` es, entonces: dueño `7` (rwx), grupo `5` (r-x), otros `5`
(r-x). No hay ninguna tabla que memorizar — es una suma de tres números
fijos, repetida tres veces.

### 2.2 Combinaciones típicas, ya calculadas

| Octal | Simbólico | Uso típico |
|---|---|---|
| `755` | `rwxr-xr-x` | Scripts y binarios ejecutables por cualquiera, editables solo por el dueño |
| `644` | `rw-r--r--` | Archivos de datos/configuración legibles por todos, editables solo por el dueño |
| `700` | `rwx------` | Scripts o carpetas privadas, solo el dueño accede |
| `600` | `rw-------` | Archivos sensibles (claves, credenciales): solo el dueño lee y escribe |
| `750` | `rwxr-x---` | Carpetas compartidas con un grupo específico, cerradas a "otros" |
| `664` | `rw-rw-r--` | Archivos editables en colaboración por dueño y grupo, solo lectura para el resto |

### 2.3 `chmod` octal: aplicar el cálculo

```bash
chmod 755 script.sh
chmod 600 clave-privada.pem
chmod 700 script-privado.sh
chmod 644 datos.csv
chmod 664 notas-compartidas.md
```

### 2.4 Notación simbólica: cambios relativos, no absolutos

La notación simbólica no reemplaza todos los permisos — **modifica** sobre
lo que ya hay, usando `u` (usuario/dueño), `g` (grupo), `o` (otros), `a`
(todos), combinados con `+`, `-`, `=`:

```bash
chmod u+x script.sh        # agrega x solo al dueño, sin tocar el resto
chmod go-w archivo.txt      # quita w a grupo y otros, sin tocar el dueño
chmod a+r archivo.txt       # agrega r a los tres ambitos
chmod u=rwx,g=rx,o= archivo # fija exactamente 750, de forma simbolica
```

La diferencia clave con octal: `chmod 700 archivo` **fija** los permisos
exactos sin importar cómo estaban antes; `chmod u+x archivo` solo agrega
`x` al dueño, dejando el resto intacto. Para un cambio puntual sin pisar
todo lo demás, simbólico es más seguro; para fijar un estado exacto
conocido, octal es más directo.

### 2.5 `chmod` recursivo, con cuidado

```bash
chmod -R 755 carpeta/
```

`-R` aplica el cambio a todo el contenido, recursivamente — pero aplica
**el mismo** permiso a archivos y directorios por igual, lo cual casi
nunca es lo correcto: un archivo de datos no debería tener `x`, pero un
directorio sí lo necesita para poder entrar (visto en el archivo
anterior). La forma correcta de aplicar esto en bloque usa `find` (que se
profundiza en la Semana 09):

```bash
find carpeta/ -type d -exec chmod 755 {} \;   # directorios: con x
find carpeta/ -type f -exec chmod 644 {} \;   # archivos: sin x
```

### 2.6 El cuarto dígito, adelantado

El octal de tres dígitos (`755`) cubre dueño/grupo/otros. Existe un **cuarto
dígito opcional**, al principio (`4755`, `2755`, `1755`), para los bits
especiales SUID/SGID/sticky — se explican a fondo en el archivo 05 de esta
semana. Por ahora alcanza con reconocer que, si ves un octal de cuatro
cifras, el primero no es parte del cálculo de `rwx` que acabas de aprender:
es una capa aparte.

### 2.7 `chmod` sobre un enlace simbólico

```bash
ln -s archivo-real.txt enlace.txt
chmod 600 enlace.txt
ls -l archivo-real.txt
# el permiso que cambio fue el de archivo-real.txt, no el del enlace
```

Por defecto, `chmod` sigue los enlaces simbólicos: el cambio de permiso se
aplica al **destino**, no al enlace en sí (los enlaces simbólicos no tienen
permisos propios relevantes — siempre muestran `rwxrwxrwx`, pero eso no se
usa para nada, el sistema consulta los permisos del destino real). Esto es
consistente con lo que ya viste con `cp` y `stat` en la Semana 03: seguir
el enlace es el comportamiento por defecto, no seguirlo requiere un flag
explícito (`chmod -h` para enlaces simbólicos puntuales, donde el sistema
operativo lo soporta).

## 3. Cómo se usa

```bash
# Hacer un script ejecutable, sin tocar nada mas
chmod +x deploy.sh

# Restringir una clave privada al minimo necesario
chmod 600 id_rsa

# Compartir una carpeta con el grupo, cerrada a otros
chmod 770 proyecto-equipo/

# Ver el cambio reflejado
ls -l deploy.sh id_rsa
ls -ld proyecto-equipo/
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `chmod 777` sin calcular qué hace falta de verdad | Da permiso total a cualquier usuario del sistema — casi nunca es lo necesario | Calcular el permiso exacto letra por letra, ámbito por ámbito |
| Aplicar `chmod -R 755` a una carpeta con archivos de datos | Le da `x` (ejecución) a archivos que nunca deberían tenerlo | Separar el `chmod` de directorios (con `x`) del de archivos (sin `x`), vía `find` |
| Confundir `644` con "ejecutable para el dueño" | `644` no tiene ningún bit `x` — un script con ese permiso no corre para nadie, ni siquiera el dueño | Recordar: `644` es lectura/escritura para el dueño, solo lectura para el resto, sin ejecución para nadie |
| Usar `=` simbólico pensando que "agrega" | `u=rwx` fija exactamente esos permisos, borrando cualquier otro bit que hubiera antes en ese ámbito | Usar `+`/`-` para modificar, `=` solo cuando quieres fijar un estado exacto |
| Copiar un octal de cuatro cifras sin saber qué hace el primero | El cuarto dígito activa bits especiales (SUID/SGID/sticky), no permisos adicionales de `rwx` | Separar mentalmente el cálculo de tres dígitos del cuarto, y revisar el archivo 05 antes de usarlo |

## 5. Trucos

- `chmod +x` (sin especificar ámbito) agrega ejecución a los tres ámbitos
  que ya tenían algún permiso de lectura — el atajo más común para "hacer
  ejecutable" sin pensar en el cálculo completo.
- `chmod --reference=otro-archivo archivo` copia los permisos exactos de
  otro archivo, sin tener que calcular ni escribir el número.
- `stat -c '%a'` imprime el permiso en formato octal puro — útil para
  comparar permisos de dos archivos con un solo número, sin descifrar
  letras.
- `chmod -v` muestra qué cambió exactamente en cada archivo afectado,
  incluido el valor anterior — útil al aplicar un cambio en lote para
  confirmar que tocó lo esperado.

## Resumen

El octal de `chmod` es una suma fija (`r=4, w=2, x=1`) repetida tres veces,
no una tabla para memorizar. Simbólico modifica sobre lo existente
(`+`/`-`), octal fija un estado exacto (o `=` simbólico, equivalente). El
cuarto dígito opcional y el comportamiento sobre enlaces simbólicos quedan
como anticipos de lo que viene en los próximos archivos de esta semana.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — chmod invocation](https://www.gnu.org/software/coreutils/manual/html_node/chmod-invocation.html) — la referencia completa, incluida toda la notación simbólica.
- `man chmod` — la misma referencia, offline.
- `man 2 chmod` — la syscall real detrás del comando, para quien quiera el detalle de kernel.
- `info coreutils 'chmod invocation'` — el manual extendido de GNU, con ejemplos adicionales a los de la página de `man`.

## ✅ Checklist de Verificación

- [ ] Calculaste al menos cinco combinaciones octales a mano, sin tabla de referencia
- [ ] Usaste notación simbólica para un cambio puntual sin pisar el resto de los permisos
- [ ] Reprodujiste por qué `chmod -R` aplica el mismo permiso a archivos y directorios, y por qué eso casi nunca es correcto
- [ ] Explicaste la diferencia entre `chmod 700` y `chmod u=rwx` (mismo resultado, mecanismos distintos)
- [ ] Confirmaste que `chmod` sobre un enlace simbólico cambia los permisos del destino, no del enlace
- [ ] Usaste `chmod --reference` para copiar permisos exactos de un archivo a otro

---

[← 01 — Modelo de permisos: rwx](01-modelo-de-permisos-rwx.md) · [03 — chown y chgrp →](03-chown-y-chgrp.md)
