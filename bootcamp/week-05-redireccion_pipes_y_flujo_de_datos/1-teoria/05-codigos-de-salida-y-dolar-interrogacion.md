# Códigos de salida y `$?`

> Cada comando que corres termina con un número entre 0 y 255, y ese
> número tiene significado. La Semana 01 ya te presentó `$?` de pasada —
> esta sección lo explica completo: qué significan los valores, no solo
> que "0 es bueno".

## 🎯 Objetivos

- Interpretar un código de salida más allá de "0 funcionó, otra cosa no"
- Usar códigos de salida propios para comunicar distintos resultados
- Combinar código de salida con las estructuras `&&`/`||` del archivo siguiente
- Calcular qué señal terminó un proceso a partir de un código 128+N

## 1. Qué problema resuelve

"El script falló" sin más detalle obliga a leer logs para entender qué
pasó. Un código de salida bien pensado (distinto según el tipo de
problema) permite que quien llama al script — otro script, un sistema de
monitoreo, una persona revisando `echo $?` — sepa *qué clase* de fallo
ocurrió sin leer una sola línea de log. `toolkit.sh audit` (Semana 04) y
`logreport` (esta semana) ya usan este patrón: 0, 1, 2 significan cosas
distintas, no solo "bien" o "mal".

## 2. Cómo funciona

### 2.1 El rango: 0 a 255, nada más

```bash
exit 300
echo $?
# 44
```

Un código de salida es un solo byte: valores por encima de 255 se
truncan (`300 mod 256 = 44`). Esto rara vez importa en la práctica, pero
explica por qué un script con un cálculo de código de salida mal pensado
puede devolver un número que no esperabas.

### 2.2 La convención: 0 es éxito, cualquier otro es algún tipo de fallo

No hay una regla universal más allá de "0 es éxito" — pero existen
convenciones ampliamente usadas:

| Rango | Convención común |
|---|---|
| `0` | Éxito |
| `1` | Error genérico |
| `2` | Uso incorrecto del comando (argumentos inválidos) |
| `64-78` | Reservados por convención BSD (`sysexits.h`) para categorías específicas, poco usados en Linux pero citados en documentación antigua |
| `126` | El comando existe pero no se puede ejecutar (ej. sin permiso de `x`) |
| `127` | Comando no encontrado |
| `128+N` | Terminado por la señal número `N` (ej. `130` = `128+2`, terminado por `Ctrl+C`/`SIGINT`) |

Estas últimas (126, 127, 128+N) las genera **bash mismo**, no el programa
que intentaste correr — por eso son consistentes entre comandos distintos.
Los códigos 1-125 quedan a criterio de cada programa.

```bash
./no-ejecutable.sh
echo $?
# 126

comando-que-no-existe
echo $?
# 127
```

### 2.3 `$?` se sobrescribe con cada comando — guárdalo si lo necesitas después

Ya lo viste de pasada en la Semana 01, pero vale la pena repetirlo con
precisión: `$?` refleja **siempre** el comando inmediatamente anterior.

```bash
grep "patron" archivo.txt
echo "resultado anterior"    # este comando pisa el $? de grep
echo $?
# 0        <- el exit code de "echo resultado anterior", no de grep
```

```bash
grep "patron" archivo.txt
codigo=$?                     # guardarlo ANTES de correr nada mas
echo "resultado anterior"
echo "codigo real de grep: $codigo"
```

### 2.4 Diseñar tus propios códigos de salida con intención

```bash
#!/usr/bin/env bash
#
# Codigos de salida: 0 limpio, 1 archivo invalido, 2 se encontraron errores.
set -euo pipefail

if [[ ! -f "$1" ]]; then
  echo "archivo no encontrado" >&2
  exit 1
fi

if grep -q "ERROR" "$1"; then
  echo "se encontraron errores" >&2
  exit 2
fi

exit 0
```

Esto es exactamente el patrón de `toolkit.sh logreport`: tres resultados
posibles (archivo inválido, riesgo encontrado, todo limpio), tres códigos
distintos — quien llame al script puede reaccionar diferente a cada caso
sin parsear ningún texto.

### 2.5 `exit` sin argumento: propaga el último código visto

```bash
grep "patron" archivo.txt
exit
```

`exit` sin número usa el código del último comando ejecutado — útil al
final de un script cuando simplemente quieres "terminar con lo que sea que
haya pasado", sin calcular nada nuevo.

## 3. Cómo se usa

```bash
# Chequeo rapido e interactivo del ultimo comando
comando-dudoso
echo $?

# Guardar el codigo para usarlo mas adelante en el mismo bloque
resultado=$(comando-dudoso)
codigo=$?
if [[ "$codigo" -ne 0 ]]; then
  echo "fallo con codigo $codigo"
fi
```

```bash
# Interpretar un codigo de señal
comando-que-se-cuelga &
pid=$!
kill -9 "$pid"
wait "$pid"
echo $?
# 137 = 128 + 9 (SIGKILL)
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Leer `$?` después de un `echo` o cualquier comando intermedio | `$?` ya no refleja lo que piensas que refleja | Guardar `$?` en una variable inmediatamente después del comando que te interesa |
| Usar siempre `exit 1` para cualquier tipo de fallo en un script propio | Quien llama al script no puede distinguir un tipo de error de otro sin leer texto | Asignar códigos distintos a condiciones de fallo distintas, documentados en el uso del script |
| Asumir que un código de salida alto (ej. 137, 255) es "un error cualquiera" | Códigos en el rango 128+N son señales específicas — ignorarlos pierde información real sobre qué pasó (ej. `kill -9`, memoria agotada) | Reconocer el rango 128-255 como "terminado por señal" y calcular cuál con `N = código - 128` |
| Copiar el `exit 1` de otro script sin pensar si el número ya significa algo distinto en ese contexto | Puede chocar con una convención ya establecida en el resto del sistema o del proyecto | Revisar si el proyecto ya tiene una convención de códigos antes de inventar una propia |

## 5. Trucos

- `echo $?` inmediatamente después de cualquier comando dudoso es el
  reflejo más barato para entender qué pasó, antes de recurrir a logs.
- `command; echo "salida: $?"` en una sola línea evita el riesgo de que
  algo se interponga entre el comando y la lectura de `$?`.
- Documentar los códigos de salida de un script propio en un comentario al
  principio del archivo (como hace `toolkit.sh`) ahorra tener que leer
  todo el script para saber qué significa cada número.
- `type -t false` y `type -t true` confirman que ambos son comandos reales
  que solo existen para devolver un código de salida fijo (1 y 0
  respectivamente) — útiles para probar lógica de `$?` sin ningún efecto
  secundario.

## Resumen

Un código de salida es un byte (0-255) con convenciones, no reglas
rígidas: `0` siempre éxito, `126`/`127` los genera bash mismo (sin
permiso de ejecución, comando no encontrado), `128+N` significa
terminado por la señal `N`. `$?` se pisa con cada comando — guardarlo
antes de que algo más se ejecute es la única forma confiable de usarlo
después. Diseñar los propios códigos de salida con intención (como hace
`toolkit.sh`) es lo que permite que un script comunique *qué clase* de
resultado tuvo, sin que quien lo llama tenga que leer texto.

## 📚 Recursos Adicionales

- [Advanced Bash-Scripting Guide — Exit Codes](https://tldp.org/LDP/abs/html/exitcodes.html) — tabla extendida de convenciones de códigos de salida.
- `man sysexits` (si está disponible en el sistema) — el origen histórico de los códigos 64-78.
- `man bash`, sección `EXIT STATUS` — la documentación oficial de cómo bash calcula y trunca códigos de salida.
- `man 7 signal` — la lista completa de señales y sus números, necesaria para calcular `128+N`.

## ✅ Checklist de Verificación

- [ ] Guardaste `$?` en una variable antes de que otro comando lo pisara
- [ ] Reprodujiste los códigos 126 y 127 con tus propios ejemplos
- [ ] Calculaste qué señal corresponde a un código de salida del rango 128-255
- [ ] Diseñaste un script propio con al menos tres códigos de salida distintos, con intención
- [ ] Usaste `exit` sin argumento para propagar el código del último comando ejecutado

---

[← 04 — tee: ver y guardar al mismo tiempo](04-tee-ver-y-guardar-al-mismo-tiempo.md) · [06 — Encadenar comandos: &&, ||, ; →](06-encadenar-comandos-and-or-punto-y-coma.md)
