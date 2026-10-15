# Encadenar comandos: `&&`, `||`, `;`

> Esta semana cierra con tres símbolos que deciden **cuándo** corre el
> siguiente comando, basados exactamente en lo que acabas de aprender: el
> código de salida del anterior.

## 🎯 Objetivos

- Encadenar comandos con `&&`, `||` y `;`, entendiendo la condición exacta de cada uno
- Combinar los tres en una sola línea con intención, no por costumbre
- Reconocer el patrón `comando || { manejo de error; }` para control de errores compacto
- Cerrar la semana conectando código de salida, redirección y encadenamiento en un solo flujo

## 1. Qué problema resuelve

Sin estas tres herramientas, encadenar "hacé esto, y si funciona hacé lo
otro" requeriría un `if` completo para cada paso. `&&`, `||` y `;` resuelven
los tres casos más comunes de encadenamiento condicional en una sola línea,
reutilizando exactamente el código de salida visto en el archivo anterior.

## 2. Cómo funciona

### 2.1 `&&`: el siguiente corre solo si el anterior tuvo éxito

```bash
mkdir carpeta && cd carpeta
```

`cd carpeta` solo se ejecuta si `mkdir carpeta` salió con código `0`. Si
`mkdir` falla (la carpeta ya existe, falta permiso), `cd` ni se intenta.

### 2.2 `||`: el siguiente corre solo si el anterior falló

```bash
grep "patron" archivo.txt || echo "no se encontro el patron"
```

`echo` solo corre si `grep` salió con código distinto de `0` — es decir,
si no encontró coincidencias (o si hubo un error real, ver el archivo 01
de esta semana sobre esa distinción).

### 2.3 `;`: el siguiente corre siempre, sin importar el anterior

```bash
echo "primero"; echo "segundo"
```

`;` simplemente separa comandos en la misma línea, sin ninguna condición —
equivalente a escribirlos en líneas separadas.

### 2.4 Combinar los tres con intención

```bash
mkdir -p /tmp/proyecto && cd /tmp/proyecto || { echo "no se pudo preparar el directorio" >&2; exit 1; }
```

Leé esto de corrido: "creá el directorio y entrá; si cualquiera de los dos
falla, avisá y salí con error". El bloque `{ ... }` agrupa varios comandos
para que `||` los trate como una sola unidad — sin las llaves, el `exit 1`
correría siempre, no solo cuando algo falla.

### 2.5 El error clásico: `&&` seguido de `||` sin agrupar

```bash
comando && echo "exito" || echo "fallo"
```

Esto funciona para el caso simple, pero tiene una trampa: si `echo
"exito"` mismo fallara (muy raro, pero posible — por ejemplo, si
`stdout` está cerrado), el `|| echo "fallo"` se ejecutaría **también**,
aunque el `comando` original haya sido exitoso. Para la mayoría de los
casos esto nunca ocurre, pero el patrón más robusto cuando de verdad
importa es un `if` explícito:

```bash
if comando; then
  echo "exito"
else
  echo "fallo"
fi
```

(El `if`/`else` se profundiza en la Semana 13 — acá alcanza con reconocer
que existe una alternativa más robusta cuando `&&`/`||` encadenados se
vuelven ambiguos.)

### 2.6 `&&`/`||` evalúan de izquierda a derecha, con cortocircuito

```bash
false && echo "esto nunca se imprime"
true || echo "esto tampoco se imprime"
```

Bash no evalúa lo que ya sabe que no va a importar: si el primer operando
de `&&` es falso, el resultado ya está decidido (falso), así que el
segundo comando ni se ejecuta. Lo mismo al revés con `||` y un primer
operando verdadero. Esto se llama **evaluación de cortocircuito**, y es el
mismo principio que usan los operadores lógicos de casi cualquier lenguaje
de programación.

### 2.7 El mismo patrón detrás de `toolkit.sh`

El patrón de esta semana completa el ciclo que empezó con el archivo 05:
código de salida con significado (`0`/`1`/`2` en `audit` y `logreport`) +
`&&`/`||` para reaccionar a ese significado sin un `if` completo:

```bash
toolkit.sh logreport /var/log/app.log && echo "sin novedad" || echo "revisar el informe"
```

Acá `&&`/`||` reaccionan a los **tres** códigos posibles de `logreport` de
forma simplificada (éxito vs. cualquier no-éxito) — si necesitaras
distinguir el código `1` (archivo inválido) del `2` (errores encontrados)
de forma explícita, ahí sí hace falta un `if`/`case` completo, que se ve
recién en la Semana 13.

### 2.8 El cuarto separador: `&`, que no es `&&`

Vale la pena mencionarlo para no confundirlo con `&&`: un solo `&` al
final de un comando lo manda a **segundo plano** — bash no espera a que
termine para seguir con el siguiente:

```bash
comando-que-tarda &
echo "esto se imprime de inmediato, sin esperar a comando-que-tarda"
```

No es una condición de éxito/fallo como `&&`/`||`/`;` — es control de
ejecución en paralelo, tema completo de la Semana 10. Se nombra acá solo
para que no se confunda `&` suelto con el primer carácter de `&&`.

## 3. Cómo se usa

```bash
# Patron clasico: instalar solo si no esta instalado
which herramienta || apt install -y herramienta

# Patron clasico: crear respaldo antes de una operacion riesgosa
cp -a origen/ respaldo/ && rm -rf origen/viejo/

# Encadenar varios pasos independientes en una sola linea
actualizar_paquetes; limpiar_cache; reiniciar_servicio
```

```bash
# Patron de manejo de error compacto
comando-critico || { echo "fallo comando-critico" >&2; exit 1; }
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Encadenar pasos independientes con `&&` cuando en realidad no dependen entre sí | Si el primero falla por una razón menor, los siguientes (que podrían correr igual) quedan bloqueados | Usar `;` cuando los pasos son realmente independientes, `&&` solo cuando hay una dependencia real |
| Usar `comando && echo ok || echo fail` para lógica donde el `echo` mismo podría fallar | El `|| echo fail` puede dispararse aunque `comando` haya sido exitoso | Usar `if`/`else` cuando la lógica de éxito/fallo es crítica, no solo informativa |
| Olvidar las llaves `{ }` al agrupar varios comandos después de `||` | Solo el primer comando queda condicionado; el resto corre siempre | Agrupar explícitamente con `{ comando1; comando2; }` cuando el manejo de error necesita más de un paso |
| Encadenar demasiados pasos en una sola línea con `&&` | Una línea larga con cinco `&&` es difícil de leer y de depurar cuando algo falla | Dividir en varias líneas, o usar un script con pasos nombrados, cuando la cadena crece |

## 5. Trucos

- `comando && echo "OK" || echo "FALLO"` es perfecto como chequeo rápido
  interactivo — el riesgo de la sección 2.5 casi nunca aplica fuera de un
  script crítico.
- `which herramienta || apt install herramienta` es el patrón estándar de
  "instalar solo si hace falta", evitando una reinstalación innecesaria.
- Separar una cadena larga en varias líneas con `\` al final de cada una
  (continuación de línea) hace que una cadena de `&&` compleja se lea
  mucho mejor que apretada en una sola línea.
- `true` y `false` (vistos en el archivo anterior) son los comandos más
  simples para probar lógica de `&&`/`||` sin efectos secundarios, antes
  de aplicarla a un comando real.

## Resumen

`&&` corre el siguiente solo si el anterior tuvo éxito, `||` solo si
falló, `;` siempre — los tres reutilizan el mismo código de salida visto
en el archivo anterior, con evaluación de cortocircuito. Son perfectos
para chequeos rápidos y patrones cortos (`comando || manejo-de-error`);
cuando la lógica de éxito/fallo se vuelve crítica o necesita distinguir
más de dos casos, un `if`/`case` explícito (Semana 13) es más robusto que
encadenar `&&`/`||` indefinidamente.

## 📚 Recursos Adicionales

- [Bash Reference Manual — Lists of Commands](https://www.gnu.org/software/bash/manual/bash.html#Lists) — la referencia oficial de `&&`, `||`, `;` y `&`.
- `man bash`, sección `Lists` — la misma referencia, offline.
- `help jobs` — adelanto de cómo bash maneja lo que mandas a segundo plano con `&`, antes de verlo completo en la Semana 10.

## ✅ Checklist de Verificación

- [ ] Encadenaste `mkdir && cd` y confirmaste que el segundo no corre si el primero falla
- [ ] Usaste `||` con un bloque `{ }` para manejar un error con más de un paso
- [ ] Reprodujiste el error clásico de `&&`/`||` sin agrupar y por qué un `if` explícito lo evita
- [ ] Explicaste la evaluación de cortocircuito con tus propias palabras
- [ ] Usaste `&&`/`||` para reaccionar al código de salida de `toolkit.sh logreport`
- [ ] Distinguiste `&` (segundo plano) de `&&` (condición de éxito) en un ejemplo propio

---

[← 05 — Códigos de salida y $?](05-codigos-de-salida-y-dolar-interrogacion.md) · [Práctica 01 →](../2-practicas/01-redirecciones-de-entrada-y-salida.md)
