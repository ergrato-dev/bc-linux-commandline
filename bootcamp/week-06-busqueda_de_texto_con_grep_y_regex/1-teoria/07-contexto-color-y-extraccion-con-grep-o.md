# Contexto, color y extracción con grep -o

> Encontrar la línea con el error casi nunca alcanza: también hace falta
> ver qué pasó justo antes, o extraer solo el valor exacto sin el resto de
> la línea alrededor. Este archivo cierra la semana con lo que convierte
> una coincidencia aislada en un diagnóstico completo — y con los
> antipatrones de regex que conviene reconocer de memoria.

## 🎯 Objetivos

- Mostrar líneas de contexto antes y después de una coincidencia con `-A`, `-B`, `-C`
- Extraer solo el texto que coincidió, no la línea completa, con `-o`
- Limitar cuántas coincidencias se procesan con `-m`
- Reconocer los antipatrones de regex más comunes antes de que aparezcan en un script real

## 1. Qué problema resuelve

```bash
grep "ERROR" app.log
# ERROR disco lleno
```

Una línea aislada rara vez cuenta toda la historia: ¿qué pasó inmediatamente
antes del error? ¿Cuántas veces ocurrió exactamente ese código de error en
todo el archivo, no solo en qué líneas? `grep` resuelve ambas preguntas sin
salir del comando, en vez de abrir el archivo en un editor para mirar
alrededor de cada coincidencia a mano.

## 2. Cómo funciona

### 2.1 Contexto: `-A`, `-B`, `-C`

```bash
grep -A2 "ERROR" app.log
# ERROR disco lleno          <- la coincidencia
# intentando liberar espacio  <- 2 lineas DESPUES
# liberado correctamente
```

```bash
grep -B2 "ERROR" app.log
# servicio respondiendo        <- 2 lineas ANTES
# carga alta detectada
# ERROR disco lleno            <- la coincidencia
```

```bash
grep -C1 "ERROR" app.log
# carga alta detectada    <- 1 linea antes
# ERROR disco lleno       <- la coincidencia
# intentando liberar espacio  <- 1 linea despues
```

`-A N` (*after*) muestra `N` líneas después de cada coincidencia; `-B N`
(*before*) las muestra antes; `-C N` (*context*) muestra `N` líneas de
ambos lados. Con varias coincidencias cercanas, `grep` fusiona los bloques
de contexto que se superponen en uno solo, separando bloques no contiguos
con una línea `--`.

### 2.2 `-o`: extraer solo la coincidencia, no la línea

```bash
printf 'precio 100 y 200\n' | grep -oE "[0-9]+"
# 100
# 200
```

Sin `-o`, `grep` siempre devuelve la línea completa que contiene la
coincidencia (visto desde el primer archivo de esta semana). `-o` cambia
eso: imprime **solo** el fragmento exacto que coincidió, una línea nueva
por cada coincidencia — incluso si varias aparecen en la misma línea
original, como en el ejemplo anterior.

Esto es lo que vuelve a `grep` útil para **extraer datos**, no solo
filtrar líneas: combinado con un patrón preciso (`[0-9]+`, una IP, un
correo), convierte texto desordenado en una lista limpia de valores.

### 2.3 `-m N`: detenerse después de N coincidencias

```bash
printf 'a\na\na\n' | grep -m2 "a"
# a
# a
```

`-m` corta la búsqueda apenas se alcanzan `N` coincidencias, sin seguir
leyendo el resto del archivo. En un archivo enorme donde solo interesa
confirmar que algo existe (o ver las primeras ocurrencias), `-m1` es más
rápido que dejar que `grep` procese el archivo completo para después
descartar casi todo con `head`.

### 2.4 Color: cuándo se ve y cuándo no

```bash
grep --color=auto "ERROR" app.log    # color solo si la salida va a una terminal
grep --color=always "ERROR" app.log | less -R   # fuerza color aun dentro de un pipe
grep --color=never "ERROR" app.log   # nunca, ni en terminal
```

Por defecto (`auto`), `grep` resalta la coincidencia en color solo cuando
la salida va directo a una terminal — dentro de un pipe, se desactiva
automáticamente, porque el siguiente comando de la cadena recibiría los
códigos de color como caracteres literales, no como color. `--color=always`
fuerza el resaltado incluso en un pipe, útil cuando el destino final (como
`less -R`) sabe interpretar esos códigos.

### 2.5 Antipatrones generales de regex

Más allá de lo específico de cada archivo anterior, estos son los errores
de regex que aparecen una y otra vez en scripts reales:

**Cuantificador voraz donde se necesitaba uno acotado.** `.*` coincide con
"cualquier cosa, tantas veces como sea posible" — en una línea con varios
delimitadores, puede extenderse mucho más allá de lo esperado.

```bash
printf '<a>texto<b>mas texto<c>\n' | grep -oE "<.*>"
# <a>texto<b>mas texto<c>    <- probablemente no era lo que se queria
printf '<a>texto<b>mas texto<c>\n' | grep -oE "<[^>]*>"
# <a>
# <b>
# <c>
```

`[^>]*` ("cualquier cosa que no sea `>`") es mucho más preciso que `.*`
cuando el límite real es "hasta el próximo carácter especial", no
"cualquier cosa".

**Olvidar anclas cuando el patrón debía cubrir la línea completa.** Sin
`^` y `$`, un patrón de validación puede dar falsos positivos si la línea
tiene texto extra antes o después de lo esperado.

```bash
printf '123\n123abc\n' | grep "[0-9]\+"
# 123
# 123abc     <- "paso" la validacion sin ser un numero puro
printf '123\n123abc\n' | grep "^[0-9]\+$"
# 123        <- solo la linea que es puramente numerica
```

## 3. Cómo se usa

```bash
# Ver el contexto completo alrededor de un crash en un log de systemd
journalctl -u mi-servicio | grep -B5 -A5 "Segmentation fault"

# Extraer todas las direcciones de correo de un archivo
grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" contactos.txt

# Confirmar rapido si algo existe, sin leer el archivo entero
grep -m1 -q "ERROR" archivo-enorme.log && echo "hay al menos un error"
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `.*` cuando el límite real es "hasta el próximo delimitador" | Voraz: se extiende más allá de lo esperado, capturando de más | Una clase negada (`[^delimitador]*`) acotada al delimitador real |
| Patrón de validación sin `^...$` | Coincide con líneas que solo contienen el patrón como parte de algo más grande, no toda la línea | Anclar ambos extremos cuando la línea completa debe cumplir el formato |
| Asumir que el color de `grep` siempre se ve en un script | `--color=auto` se desactiva fuera de una terminal — el script no "pierde" nada, pero confunde si se esperaba verlo en un log guardado | Usar `--color=always` solo cuando el destino final lo interpreta (como `less -R`), nunca al guardar en un archivo plano |
| Procesar un archivo completo con `grep` cuando solo interesan las primeras coincidencias | Lee de más sin necesidad | `-m N` para cortar la búsqueda apenas se alcanza lo que se necesita |

## 5. Trucos

- `grep -oE "[^>]*"` (o la clase negada equivalente al delimitador real)
  es casi siempre mejor que `.*` cuando se extrae contenido entre dos
  marcadores conocidos.
- `grep -m1 -q patron archivo && echo si` es más rápido que `grep -q` sin
  `-m` en un archivo donde ya se sabe que, si existe, aparece temprano.
- `grep -A0 -B0` (ambos en cero) es equivalente a no usar contexto —
  rara vez útil a propósito, pero explica qué pasa si un script calcula
  mal el valor de `N`.

## Resumen

`-A`, `-B`, `-C` agregan líneas de contexto alrededor de cada coincidencia;
`-o` extrae solo el fragmento coincidente, convirtiendo a `grep` en una
herramienta de extracción de datos, no solo de filtrado; `-m` limita
cuántas coincidencias procesar. El color se desactiva automáticamente
fuera de una terminal salvo que se fuerce con `--color=always`. Los dos
antipatrones de regex más frecuentes son un cuantificador voraz donde
hacía falta uno acotado, y una validación sin anclar ambos extremos de la
línea.

## 📚 Recursos Adicionales

- [GNU Grep Manual — Context Line Control](https://www.gnu.org/software/grep/manual/grep.html#Context-Line-Control) — documentación completa de `-A`, `-B`, `-C`.
- [GNU Grep Manual — Matching Control](https://www.gnu.org/software/grep/manual/grep.html#Matching-Control) — `-o`, `-m` y el resto de las banderas de control de coincidencias.
- `man grep` — sección `OUTPUT CONTROL`, con el detalle de `--color`.

## ✅ Checklist de Verificación

- [ ] Mostraste contexto antes y después de una coincidencia con `-A`, `-B` y `-C`
- [ ] Extrajiste solo el valor coincidente (no la línea completa) con `-o` y un patrón preciso
- [ ] Reprodujiste la diferencia entre `.*` voraz y una clase negada acotada
- [ ] Reprodujiste por qué una validación sin `^...$` deja pasar líneas con texto extra
- [ ] Confirmaste que `--color=auto` no aparece al redirigir la salida a un archivo

---

[← 06 — grep recursivo y por nombre de archivo](06-grep-recursivo-y-por-nombre-de-archivo.md) · [2-practicas/01 →](../2-practicas/01-grep-basico-y-anclas.md)
