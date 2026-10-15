# Práctica 01: Redirecciones de entrada y salida

Esta práctica reproduce, dentro de `ubuntu-lab`, la separación real entre
stdin/stdout/stderr y los errores clásicos de redirección.

## Paso 1: Confirmar que stdout y stderr son independientes

**Por qué**: verlo con tus propios ojos fija la separación mejor que
leerla.

**Comando**:

```bash
docker exec -it ubuntu-lab bash
ls /etc /no-existe 1>/dev/null
ls /etc /no-existe 2>/dev/null
```

**Verifica**: el primer comando solo muestra el error; el segundo solo
muestra el listado de `/etc`.

## Paso 2: Leer desde un archivo vía stdin, no como argumento

**Por qué**: distinguir el mecanismo, no solo el resultado visible.

**Comando**:

```bash
cat /etc/hostname
cat < /etc/hostname
```

**Verifica**: ambos muestran lo mismo, pero por caminos distintos — el
segundo usa redirección de entrada, el primero pasa la ruta como
argumento.

## Paso 3: Reproducir el error clásico de truncar lo que lees

**Por qué**: ver la pérdida de datos en carne propia es más convincente
que la advertencia en teoría.

**Comando**:

```bash
printf "3\n1\n2\n" > numeros.txt
cat numeros.txt
sort numeros.txt > numeros.txt
cat numeros.txt
```

**Verifica**: el archivo queda vacío o incompleto — `>` truncó antes de
que `sort` pudiera leer el contenido original.

## Paso 4: Corregir con un archivo intermedio

**Por qué**: aplicar la solución real al problema que acabas de
reproducir.

**Comando**:

```bash
printf "3\n1\n2\n" > numeros.txt
sort numeros.txt > numeros.ordenados.txt && mv numeros.ordenados.txt numeros.txt
cat numeros.txt
```

**Verifica**: ahora el archivo contiene `1 2 3`, ordenado correctamente.

## Paso 5: El orden de `2>&1` importa

**Por qué**: confirmar con un caso real por qué el orden de las
redirecciones no es cosmético.

**Comando**:

```bash
ls /etc /no-existe 2>&1 > salida-mal.log
cat salida-mal.log

ls /etc /no-existe > salida-bien.log 2>&1
cat salida-bien.log
```

**Verifica**: `salida-mal.log` no contiene el mensaje de error (fue a la
terminal); `salida-bien.log` contiene tanto el listado como el error.

## ✅ Resultado

- [ ] Confirmaste que stdout y stderr son canales independientes
- [ ] Usaste `cat <` para leer vía stdin, no como argumento
- [ ] Reprodujiste y corregiste el error de truncar un archivo que también leías
- [ ] Reprodujiste por qué el orden de `2>&1` y `>archivo` cambia el resultado

```bash
./scripts/verificar-semana.sh 05
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El paso 3 no pierde datos | El sistema de archivos o el shell hicieron algo distinto de lo esperado (muy raro) | Confirmar con `cat numeros.txt` inmediatamente después del `sort > numeros.txt`, sin pasos de por medio |
| `salida-mal.log` y `salida-bien.log` tienen el mismo contenido | Se escribieron en el orden equivocado, o uno de los dos comandos se copió mal | Comparar carácter por carácter la posición de `2>&1` respecto a `>` en cada línea |
| `cat < archivo` da el mismo error que `cat archivo` | Normal si el archivo no existe — ambos mecanismos fallan igual ante un archivo inexistente | Confirmar primero que el archivo existe con `ls` |

---

[← 06 — Encadenar comandos](../1-teoria/06-encadenar-comandos-and-or-punto-y-coma.md) · [Práctica 02 →](02-pipes-y-tee.md)
