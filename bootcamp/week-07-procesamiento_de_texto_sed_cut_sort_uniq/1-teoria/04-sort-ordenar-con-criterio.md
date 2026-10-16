# sort: ordenar con criterio

> `sort` sin banderas ordena como diccionario, carácter por carácter — y
> eso hace que `10` quede antes que `2`. La mitad de esta semana es saber
> *qué* bandera corrige eso según el dato; la otra mitad es `sort -k`,
> necesario en casi todo pipeline real donde el criterio de orden no es
> la línea completa, sino una columna de ella.

## 🎯 Objetivos

- Explicar por qué el orden alfabético por defecto rompe con números
- Ordenar numéricamente, al revés, y por una columna específica
- Combinar varias claves de orden, con el orden de desempate correcto
- Verificar si un archivo ya está ordenado, sin ordenarlo de nuevo

## 1. Qué problema resuelve

Una lista de archivos con tamaños (`10`, `9`, `2`, `1`) ordenada "como
diccionario" da `1, 10, 2, 9` — correcto como texto, inútil como números.
`sort` necesita que se le diga **qué tipo de dato** está ordenando; sin
esa indicación, asume que todo es texto plano.

## 2. Cómo funciona

### 2.1 Orden por defecto: lexicográfico, no numérico

```bash
printf '10\n9\n2\n1\n' | sort
# 1
# 10
# 2
# 9
```

Carácter por carácter: `"1"` es menor que `"2"` antes de mirar el
segundo carácter de `"10"` — el resultado es correcto como comparación de
texto, pero no es el orden numérico esperado.

### 2.2 `-n`: orden numérico

```bash
printf '10\n9\n2\n1\n' | sort -n
# 1
# 2
# 9
# 10
```

### 2.3 `-h`: orden "humano" con sufijos (K, M, G)

```bash
printf '1K\n2M\n500\n1G\n' | sort -h
# 500
# 1K
# 2M
# 1G
```

`-h` entiende sufijos de tamaño (como los que imprime `du -h` o `ls -lh`)
y ordena por el valor real que representan, no por el texto del sufijo.

### 2.4 `-r`: invertir el orden

```bash
printf 'a\nc\nb\n' | sort -r
# c
# b
# a
```

Combinable con cualquier otro criterio: `sort -rn` ordena numérico, de
mayor a menor.

### 2.5 `-k`: ordenar por una columna, no por la línea completa

```bash
printf 'juan 30\nana 25\ncarlos 40\n' | sort -k2,2n
# ana 25
# juan 30
# carlos 40
```

`-k2,2` indica "la clave de orden es del campo 2 al campo 2" (es decir,
solo el campo 2); `n` al final aplica orden numérico a esa clave. Sin el
`,2` de cierre, `-k2` ordenaría por "desde el campo 2 hasta el final de
la línea", que puede dar un resultado distinto cuando hay más de dos
columnas.

### 2.6 `-t`: delimitador de columnas distinto a espacios

```bash
printf 'root:0\nadmin:1000\nguest:500\n' | sort -t: -k2,2n
# root:0
# guest:500
# admin:1000
```

Por defecto, `sort -k` separa columnas por espacios en blanco — `-t`
cambia ese delimitador, igual que `-d` en `cut`.

### 2.7 Varias claves: desempate en orden

```bash
printf 'juan 30 a\njuan 25 b\nana 30 c\n' | sort -k1,1 -k2,2n
# ana 30 c
# juan 25 b
# juan 30 a
```

Varios `-k` se aplican en el orden en que se escriben: primero ordena por
la primera clave (`-k1,1`, el nombre); donde hay empate, usa la segunda
clave (`-k2,2n`, la edad) para decidir entre ellos.

### 2.8 `-u`: eliminar duplicados como parte del ordenamiento

```bash
printf 'b\na\nb\na\n' | sort -u
# a
# b
```

Equivalente a `sort | uniq` (archivo 05 de esta semana), en un solo paso
— útil cuando solo interesa la lista de valores únicos, no además
contarlos.

### 2.9 `-c`: verificar si ya está ordenado, sin ordenar

```bash
printf 'a\nb\nc\n' | sort -c; echo $?
# 0

printf 'b\na\n' | sort -c
# sort: -:2: disorder: a
```

`-c` no produce salida ordenada — solo confirma (con el código de salida
y, si falla, un mensaje señalando dónde) si la entrada ya cumple el
orden. Útil para validar una precondición (por ejemplo, antes de `uniq`,
que necesita entrada ordenada) sin gastar el trabajo de reordenar algo
que ya podría estarlo.

### 2.10 `-f`: ignorar mayúsculas/minúsculas al ordenar

```bash
printf 'banana\nApple\ncereza\n' | sort -f
# Apple
# banana
# cereza
```

Sin `-f`, las mayúsculas ordenan antes que las minúsculas en la mayoría
de los `locale` (`"Apple"` quedaría primero por casualidad de tabla
ASCII, no por intención) — `-f` hace que el orden no distinga caso,
tratando `"Apple"` y `"apple"` como equivalentes para decidir la posición.

## 3. Cómo se usa

```bash
# Los 5 procesos que mas memoria usan
ps aux | sort -k4,4rn | head -5

# Lista de IPs unicas de un log de acceso, ordenadas
cut -d' ' -f1 acceso.log | sort -u

# Verificar que un archivo de datos esta ordenado antes de confiar en uniq
sort -c datos.txt && uniq -c datos.txt

# Ordenar un /etc/passwd por UID numerico (campo 3, delimitado por :)
sort -t: -k3,3n /etc/passwd
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Ordenar números sin `-n` | `sort` por defecto compara texto: `10` queda antes de `2` | `sort -n` (o `-h` para tamaños con sufijo) para cualquier columna numérica |
| Usar `-k2` sin cerrar el rango (`-k2,2`) cuando hay más columnas | `-k2` solo ordena "desde el campo 2 hasta el final", no por el campo 2 aislado — con más columnas, el resultado cambia | Cerrar siempre el rango de la clave: `-k2,2` para ordenar solo por esa columna |
| Correr `uniq` sobre datos sin verificar que están ordenados | `uniq` solo detecta duplicados **adyacentes** — sin ordenar antes, duplicados no consecutivos pasan desapercibidos | `sort -c` para confirmar, o simplemente `sort` antes de `uniq` cuando no hay certeza |
| Asumir que el orden de varios `-k` no importa | El primer `-k` decide el orden principal; los siguientes solo desempatan — invertir el orden de los `-k` puede cambiar el resultado completo | Poner primero la clave que debe dominar el orden, y las de desempate después, en ese orden |

## 5. Trucos

- `sort -R` da un orden **aleatorio**, no alfabético ni numérico — útil
  para elegir una muestra al azar de un archivo (combinado con `head`).
- `sort -k1,1 -u` elimina duplicados considerando solo la primera
  columna, no la línea completa — distinto de `sort -u` sin `-k`, que
  compara la línea entera.
- `LC_ALL=C sort archivo.txt` fuerza un orden puramente por valor de
  byte, ignorando reglas de idioma del `locale` — más rápido, y
  consistente entre sistemas con distinto `locale` configurado.

## Resumen

`sort` por defecto compara texto, no números — `-n` (o `-h` para
sufijos) corrige eso. `-r` invierte el orden. `-k inicio,fin` ordena por
una columna específica (cerrar el rango importa); `-t` cambia el
delimitador de columna. Varios `-k` desempatan en el orden en que se
escriben. `-u` deduplica como parte del ordenamiento; `-c` verifica si
ya está ordenado sin reordenar; `-f` ignora mayúsculas/minúsculas.

## 📚 Recursos Adicionales

- [GNU Coreutils Manual — sort invocation](https://www.gnu.org/software/coreutils/manual/coreutils.html#sort-invocation) — referencia completa de banderas, incluido `-k` con todos sus modificadores.
- `man sort` — disponible sin conexión en cualquier distro.

## ✅ Checklist de Verificación

- [ ] Reprodujiste por qué el orden por defecto rompe con números, y lo corregiste con `-n`
- [ ] Ordenaste por una columna específica con `-k inicio,fin`, cerrando el rango
- [ ] Combinaste dos claves de orden (`-k1,1 -k2,2n`) y confirmaste cuál desempata a cuál
- [ ] Usaste `-c` para verificar si un archivo ya está ordenado, sin reordenarlo
- [ ] Usaste `-u` para deduplicar como parte de un `sort`, sin un `uniq` separado

---

[← 03 — cut: extraer campos y caracteres](03-cut-extraer-campos-y-caracteres.md) · [05 — uniq: duplicados adyacentes →](05-uniq-duplicados-adyacentes.md)
