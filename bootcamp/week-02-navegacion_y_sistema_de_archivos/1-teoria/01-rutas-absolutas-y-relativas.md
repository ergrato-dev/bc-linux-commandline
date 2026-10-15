# Rutas absolutas y relativas

> "¿Dónde estoy?" es la pregunta que más vas a hacerte en una terminal. Esta
> sección te da las herramientas para contestarla sin adivinar.

## 🎯 Objetivos

- Distinguir ruta absoluta de ruta relativa y saber cuándo usar cada una
- Navegar con `cd`, `pwd` y los atajos `~`, `.`, `..`, `-`
- Explicar por qué un comando "funciona en una carpeta y no en otra"

## 1. Qué problema resuelve

Casi todo error de "no encuentra el archivo" en la línea de comandos viene de
una confusión entre ruta absoluta y relativa: el comando buscó donde
*creíste* que estabas parado, no donde realmente estabas. Sin un modelo claro
de cómo bash interpreta una ruta, cada error de este tipo se resuelve a
prueba y error. Con el modelo, se resuelve mirando dos cosas: tu directorio
actual, y si la ruta que escribiste empieza con `/`.

## 2. Cómo funciona

### 2.1 Ruta absoluta: desde la raíz, siempre igual

Una ruta absoluta empieza con `/` (la raíz del sistema de archivos) y
describe una ubicación exacta, sin importar desde dónde la escribas:

```bash
/etc/hostname
/home/student/bin/toolkit.sh
/
```

No importa en qué directorio estés parado: `/etc/hostname` siempre se
refiere al mismo archivo.

### 2.2 Ruta relativa: desde donde estás parado

Una ruta relativa **no** empieza con `/`, y se interpreta siempre respecto a
tu directorio actual (el valor de `pwd`):

```bash
cd /etc
cat hostname          # relativa: busca /etc/hostname
cd /home/student
cat hostname          # la MISMA ruta relativa, otro archivo distinto
```

El mismo texto, `hostname`, apunta a un archivo distinto según dónde estés
parado. Esta es la fuente del error más común: copiar un comando de un lugar
y pegarlo en otro sin ajustar si la ruta era relativa.

### 2.3 Tu directorio actual: `pwd` y la variable `$PWD`

Bash mantiene tu directorio actual en la variable de entorno `$PWD`, y el
builtin `pwd` la imprime:

```bash
pwd
# /home/student

echo "$PWD"
# /home/student
```

`pwd` y `echo $PWD` casi siempre coinciden — la diferencia aparece solo con
enlaces simbólicos (ver `pwd -P` más abajo), caso raro en el día a día.

### 2.4 Los atajos de ruta

| Atajo | Significa |
|---|---|
| `~` | Tu directorio home (`/home/tu-usuario`) |
| `~usuario` | El home de otro usuario (`/home/usuario`) |
| `.` | El directorio actual |
| `..` | El directorio padre (uno arriba) |
| `-` | Solo con `cd`: el directorio anterior, antes del último `cd` |

```bash
cd /var/log
cd ..
pwd
# /var

cd -
pwd
# /var/log      (volviste adonde estabas antes del cd ..)
```

`cd -` es el atajo más subestimado: alterna entre los dos últimos
directorios sin tener que recordar ninguna ruta.

### 2.5 Encadenar `..` para subir varios niveles

```bash
cd /home/student/proyectos/bootcamp/semana-02
cd ../../..
pwd
# /home/student
```

Cada `../` sube un nivel; encadenarlos con `/` entre cada uno sube tantos
niveles como `..` hayas puesto.

### 2.6 `cd` sin argumentos

```bash
cd /var/log
cd
pwd
# /home/student
```

`cd` sin argumentos siempre te lleva a tu home — equivalente a `cd ~`, y el
comportamiento por defecto si escribiste `cd` por reflejo sin pensar adónde
ibas.

### 2.7 Rutas relativas dentro de un script: el error que solo aparece en producción

Un script que usa rutas relativas a archivos propios (`source ./config.sh`,
`cat ./datos.txt`) funciona perfecto cuando lo pruebas desde su propia
carpeta, y falla en silencio (o con un error confuso) apenas alguien lo
ejecuta desde otro directorio o lo llama desde un cron job — porque la ruta
relativa se resuelve contra el directorio *desde donde se invocó*, no contra
la carpeta donde vive el script.

```bash
#!/usr/bin/env bash
# mal: asume que siempre se ejecuta parado en su propia carpeta
source ./config.sh
```

```bash
#!/usr/bin/env bash
# bien: resuelve su propia ubicacion primero, sin importar desde donde se llame
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/config.sh"
```

Este patrón (`$(dirname "${BASH_SOURCE[0]}")` seguido de `cd ... && pwd`) es
tan común en scripts reales que ya lo viste, sin que se explicara todavía, en
los `scripts/*.sh` de este mismo repositorio — vuelves a encontrarlo recién en
la Semana 13, cuando empieces a escribir tus propios scripts con esta misma
necesidad.

## 3. Cómo se usa

```bash
# Moverte a una ruta absoluta, sin importar donde estes parado
cd /etc/systemd/system

# Moverte a una ruta relativa al directorio actual
cd ../network

# Combinar atajos: tu home, mas una subcarpeta
cd ~/bin

# Confirmar donde quedaste, siempre
pwd
```

```bash
# pwd -P resuelve enlaces simbolicos; pwd a secas (o -L) no
mkdir -p /tmp/real
ln -s /tmp/real /tmp/enlace
cd /tmp/enlace
pwd
# /tmp/enlace
pwd -P
# /tmp/real
```

Esta diferencia entre `pwd` y `pwd -P` solo importa cuando tu ruta pasa por
un enlace simbólico — el resto del tiempo son idénticos. Los enlaces se
tratan a fondo en el archivo 04 de esta semana.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Copiar un comando con ruta relativa de un tutorial sin revisar desde dónde se escribió | La misma ruta relativa apunta a un archivo distinto (o a ninguno) según tu directorio actual | Antes de pegar un comando con rutas relativas, correr `pwd` y confirmar que estás en el directorio que el tutorial asume |
| Usar `cd ../../../../..` a ciegas, contando mal los niveles | Termina en un directorio que no es el esperado, y el siguiente comando falla en un lugar inesperado | Confirmar con `pwd` después de cada `cd` con varios `..`, o preferir la ruta absoluta si la conoces |
| Asumir que `pwd` y `$PWD` pueden diferir en el uso normal | Genera dudas innecesarias; en el 99% de los casos son idénticos | Solo investigar la diferencia si hay un enlace simbólico de por medio |

## 5. Trucos

- `cd -` dos veces seguidas te deja exactamente donde estabas antes de la
  primera vez — útil para "ir y volver" sin memorizar ninguna ruta.
- `cd` sin argumentos es el atajo más rápido para "llevame a mi home", más
  corto que `cd ~` o `cd $HOME`.
- `cd ~usuario` (sin barra) funciona igual que `cd /home/usuario` en la
  mayoría de los sistemas, sin tener que escribir la ruta completa.

## 📚 Recursos Adicionales

- `help cd` — `cd` es builtin (visto en la Semana 01), así que su ayuda vive ahí, no en `man`.
- [Bash Reference Manual — Bourne Shell Builtins](https://www.gnu.org/software/bash/manual/bash.html#Bourne-Shell-Builtins) — comportamiento completo de `cd`, incluidas sus variables `CDPATH` y `OLDPWD` (esta última se retoma en el archivo 06).

## ✅ Checklist de Verificación

- [ ] Distinguiste una ruta absoluta de una relativa en al menos tres ejemplos propios
- [ ] Usaste `cd -` para alternar entre dos directorios sin escribir ninguna ruta
- [ ] Reprodujiste la diferencia entre `pwd` y `pwd -P` con un enlace simbólico propio

---

[← Semana 02](../README.md) · [02 — El estándar FHS →](02-el-estandar-fhs.md)
