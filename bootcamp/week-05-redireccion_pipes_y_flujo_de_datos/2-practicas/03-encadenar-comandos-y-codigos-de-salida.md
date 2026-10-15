# Práctica 03: Encadenar comandos y códigos de salida

Esta práctica combina `&&`/`||`/`;` con códigos de salida propios,
incluidos los casos límite que `ls -l` de un archivo sin permiso de
ejecución y una señal real producen.

## Paso 1: Confirmar los códigos que genera bash mismo

**Por qué**: distinguir 126 y 127, generados por bash, de los códigos que
define cada programa.

**Comando**:

```bash
cd /tmp
echo "echo hola" > sin-permiso.sh
chmod 644 sin-permiso.sh
./sin-permiso.sh
echo "codigo: $?"

./no-existe.sh
echo "codigo: $?"
```

**Verifica**: el primero da `126` (existe pero no se puede ejecutar); el
segundo da `127` (no existe).

## Paso 2: Calcular un código de señal

**Por qué**: confirmar el cálculo `128+N` con un caso real.

**Comando**:

```bash
sleep 100 &
pid=$!
kill -9 "$pid"
wait "$pid"
echo "codigo: $?"
```

**Verifica**: el código es `137` (`128 + 9`, la señal `SIGKILL`).

## Paso 3: Guardar `$?` antes de que se pise

**Por qué**: reproducir el error más común al trabajar con códigos de
salida.

**Comando**:

```bash
grep "root" /etc/passwd > /dev/null
echo "paso intermedio"
echo "codigo incorrecto: $?"
```

```bash
grep "root" /etc/passwd > /dev/null
codigo=$?
echo "paso intermedio"
echo "codigo correcto: $codigo"
```

**Verifica**: el primer bloque muestra el código de `echo`, no de `grep`;
el segundo, guardado a tiempo, muestra el código real de `grep`.

## Paso 4: Encadenar con `&&`/`||` e intención

**Por qué**: practicar el patrón real de "crear y entrar, o fallar con
aviso".

**Comando**:

```bash
mkdir -p /tmp/proyecto-wk05 && cd /tmp/proyecto-wk05 || { echo "no se pudo preparar" >&2; exit 1; }
pwd
```

**Verifica**: termina parado en `/tmp/proyecto-wk05`, sin ningún mensaje
de error.

## Paso 5: Reproducir el riesgo de `&&`/`||` sin agrupar

**Por qué**: ver el caso límite antes de preferir `if` cuando importa de
verdad.

**Comando**:

```bash
true && echo "ok" | false || echo "esto se imprime aunque 'true' funciono"
```

**Verifica**: el `|| echo` se dispara aunque el primer comando (`true`)
haya sido exitoso — porque el `|| ` está evaluando el resultado de todo el
pipeline `echo "ok" | false`, no solo el `true` inicial. Explicá con tus
palabras por qué este caso confirma la recomendación de usar `if`/`else`
cuando la lógica es crítica.

## ✅ Resultado

- [ ] Reprodujiste los códigos 126 y 127
- [ ] Calculaste un código de señal real (137 = 128+9)
- [ ] Guardaste `$?` antes de que un comando intermedio lo pisara
- [ ] Encadenaste `&&`/`||` con un bloque `{ }` para manejo de error
- [ ] Reprodujiste el caso límite de `&&`/`||` sin agrupar y lo explicaste

```bash
./scripts/verificar-semana.sh 05
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El paso 1 no da 126 | Puede que el sistema interprete el archivo de otra forma; confirmar que no tiene `x` con `ls -l` | Revisar `ls -l sin-permiso.sh` antes de ejecutar |
| El paso 2 da un código distinto de 137 | El proceso pudo haber terminado antes de que `kill -9` llegara a aplicarse | Repetir con un `sleep` de duración mayor |
| El paso 5 no muestra el mensaje | Se escribió sin el pipe intermedio, cambiando la condición real que se evalúa | Copiar la línea exacta del paso, con el `| false` incluido |

---

[← Práctica 02](02-pipes-y-tee.md) · [Práctica 04 →](04-logreport-con-pipes-reales.md)
