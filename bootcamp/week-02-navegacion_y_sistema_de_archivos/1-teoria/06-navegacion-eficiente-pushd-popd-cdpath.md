# Navegación eficiente: pushd, popd y CDPATH

> `cd` sirve para moverte una vez. Cuando necesitas ir y volver entre varios
> directorios todo el tiempo, hay herramientas mejores que recordar rutas de
> memoria.

## 🎯 Objetivos

- Usar una pila de directorios con `pushd`/`popd`/`dirs` para moverte entre varios lugares
- Configurar `CDPATH` para navegar sin rutas completas
- Aprovechar el autocompletado de `cd` con Tab
- Cerrar la Semana 02 con un modelo completo de cómo bash resuelve dónde estás parado y adónde te mueve

## 1. Qué problema resuelve

`cd -` (visto en el primer archivo de esta semana) resuelve "ir y volver"
entre **dos** lugares. Pero cuando estás trabajando activamente entre tres o
cuatro carpetas distintas — el código, los logs, la configuración, un
directorio temporal — ni `cd -` ni memorizar rutas completas escala bien.
Bash trae una pila de directorios pensada exactamente para esto, y casi
nadie la usa porque nunca se topó con ella.

## 2. Cómo funciona

### 2.1 La pila de directorios

`pushd` apila un directorio nuevo (y te mueve ahí); `popd` saca el de arriba
de la pila (y te devuelve al anterior); `dirs` muestra la pila completa.

```bash
pwd
# /home/student

pushd /etc
# /etc /home/student          <- pila: arriba el actual, abajo lo anterior
pwd
# /etc

pushd /var/log
# /var/log /etc /home/student
pwd
# /var/log

popd
# /etc /home/student
pwd
# /etc

popd
# /home/student
pwd
# /home/student
```

Cada `pushd` agrega una entrada arriba de la pila y te mueve ahí; cada
`popd` saca la de arriba y te mueve al nuevo tope. Es un modelo de "ir
apilando lugares" en vez de "recordar de memoria dónde estaba antes".

### 2.2 `dirs`: ver la pila sin moverte

```bash
dirs -v
# 0  /etc
# 1  /home/student
```

El número de cada entrada sirve para saltar directo a cualquier posición de
la pila sin hacer `popd` varias veces:

```bash
pushd +1
# te mueve a la entrada 1 de la pila, rotandola hacia arriba
```

### 2.3 `pushd` sin argumentos: alternar el tope con el siguiente

```bash
pushd
# intercambia las dos entradas de arriba de la pila entre si
```

Es similar a `cd -`, pero operando sobre la pila en vez de sobre un único
"directorio anterior".

### 2.4 `CDPATH`: `cd` que busca en más de un lugar

Por defecto, `cd nombre` (sin `/` inicial) busca `nombre` como subcarpeta del
directorio actual. `CDPATH` extiende dónde busca, igual que `$PATH` extiende
dónde bash busca comandos (visto en la Semana 01):

```bash
export CDPATH=".:~/proyectos:~/bin"

cd bootcamp
# aunque no estuvieras parado en ~/proyectos, cd la encuentra ahi
# si existe ~/proyectos/bootcamp
```

Con `CDPATH` configurado, `cd nombre-de-carpeta` funciona como un atajo
global a cualquier carpeta que vivas visitando seguido, sin tener que
escribir la ruta completa ni estar parado en el lugar correcto.

```bash
cd bootcamp
# /home/student/proyectos/bootcamp     <- cd imprime la ruta cuando la
#                                          encuentra via CDPATH, para que
#                                          sepas que no te quedaste donde
#                                          pensabas
```

Ese comportamiento (imprimir la ruta resultante) es deliberado: sin aviso,
`CDPATH` podría llevarte a un lugar inesperado sin que lo notes.

### 2.5 Autocompletado de `cd` con Tab

Esto no es exclusivo de `cd`, pero vale la pena nombrarlo acá: escribir las
primeras letras de una carpeta y apretar `Tab` completa el nombre si hay una
sola coincidencia, o lo expande hasta donde sea ambiguo y muestra las
opciones si aprietas `Tab` dos veces:

```bash
cd doc<Tab>
# completa a "documentos/" si es la unica carpeta que empieza asi

cd d<Tab><Tab>
# muestra: documentos/  descargas/  (ambas, si ambas empiezan con "d")
```

Combinado con `CDPATH`, el autocompletado también busca en las carpetas de
`CDPATH`, no solo en la actual.

## 3. Cómo se usa

```bash
# Flujo tipico: trabajar entre configuracion y logs de un servicio
pushd /etc/nginx
# editar algo
pushd /var/log/nginx
# revisar logs
popd
# de vuelta en /etc/nginx
popd
# de vuelta en el directorio original
```

```bash
# Hacer CDPATH persistente
cat >> ~/.bashrc << 'EOF'
export CDPATH=".:~/proyectos:~/bin"
EOF
source ~/.bashrc
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Usar `pushd`/`popd` dentro de un script pensando que es como `cd` | Dentro de un script, `pushd` imprime la pila por defecto (ruido en la salida) y el comportamiento puede confundir a quien lea el script | Usar `pushd ruta > /dev/null` dentro de scripts, o preferir `cd` simple si no hace falta volver |
| Configurar `CDPATH` con demasiadas carpetas parecidas | Aumenta la chance de que `cd nombre` te lleve a un lugar distinto del esperado | Mantener `CDPATH` corto, con solo las carpetas que visitas todos los días |
| Perder la cuenta de cuántos `pushd` hiciste y no saber cuántos `popd` hacen falta para volver al inicio | La pila crece sin que lo notes, y `popd` de más puede sacarte de donde no esperabas | Revisar `dirs -v` antes de asumir cuántos `popd` necesitas |
| Activar `autocd` sin avisar a quien comparte la máquina | Un nombre de carpeta escrito solo, sin `cd`, ahora navega en vez de dar error — sorprende a cualquiera acostumbrado al comportamiento estándar | Mantenerlo como preferencia personal documentada, no asumirlo en sesiones compartidas |

## 5. Trucos

- `dirs -c` vacía la pila sin moverte de donde estás — útil para "empezar de
  cero" sin cerrar la terminal.
- `cd -- -nombre-raro` (con `--` antes) navega a una carpeta cuyo nombre
  empieza con guión, que de otra forma `cd` interpretaría como un flag.
- Si solo necesitas ir y volver **una vez**, `cd -` (de la Semana 02, archivo
  01) sigue siendo más simple que armar una pila para un solo salto.
- `shopt -s autocd` (si tu bash lo soporta) te deja escribir solo el nombre
  de una carpeta, sin `cd` adelante, y te mueve ahí igual — cómodo para
  sesiones muy interactivas, menos recomendable en scripts por la ambigüedad
  que introduce.

## Resumen

`pushd`/`popd`/`dirs` reemplazan "memorizar rutas" por una pila explícita
cuando trabajas entre varios directorios a la vez; `CDPATH` extiende dónde
`cd` busca, igual que `$PATH` extiende dónde bash busca comandos. Ninguna de
las dos reemplaza a `cd -` para el caso simple de ir y volver una sola vez —
son herramientas para cuando el patrón de movimiento es más complejo que eso.

## 📚 Recursos Adicionales

- [Bash Reference Manual — The Directory Stack](https://www.gnu.org/software/bash/manual/bash.html#The-Directory-Stack) — referencia completa de `pushd`/`popd`/`dirs`.
- `help pushd`, `help popd`, `help dirs` — son builtins, su ayuda vive ahí.
- `man bash`, sección `SHELL BUILTIN COMMANDS` — la misma referencia de `CDPATH`, offline.

## ✅ Checklist de Verificación

- [ ] Usaste `pushd`/`popd` para moverte entre al menos tres directorios y volver al inicio
- [ ] Configuraste `CDPATH` de forma persistente y navegaste a una carpeta sin escribir su ruta completa
- [ ] Usaste `dirs -v` para revisar la pila antes de decidir cuántos `popd` hacer
- [ ] Probaste `pushd +1` para saltar directo a una entrada de la pila sin hacer `popd` repetido
- [ ] Explicaste la diferencia entre `pushd ruta` (agrega a la pila) y `pushd` sin argumentos (intercambia el tope)

---

[← 05 — Globbing y expansión de patrones](05-globbing-y-expansion-de-patrones.md) · [Práctica 01 →](../2-practicas/01-rutas-absolutas-y-relativas.md)
