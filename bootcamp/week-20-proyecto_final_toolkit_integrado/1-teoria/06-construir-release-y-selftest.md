# Construir release y selftest

> Las cinco piezas anteriores se juntan aquí en dos subcomandos: `release` fabrica y comprueba el paquete, `selftest` prueba el conjunto.
> Este archivo explica **por qué** el código está escrito como está, para que lo reproduzcas en las prácticas y no lo copies.

## 🎯 Objetivos

- Explicar el flujo de `release build`: preparar, montar, construir, publicar la suma
- Justificar por qué se construye en un temporal y se mueve al destino con `mv`
- Mantener `SHA256SUMS` idempotente: reconstruir no duplica líneas
- Leer los seis chequeos de `release verify` y qué defecto detecta cada uno
- Reconocer el patrón «analizar, validar, ejecutar» que repiten las dos órdenes

## 1. Qué problema resuelve

Empaquetar a mano es una receta de diez pasos que se hace igual cada vez, y por eso
se hace mal una de cada diez. Convertirla en un subcomando la deja **repetible y
comprobable**: el mismo comando produce el mismo paquete y un segundo comando
confirma que cumple lo prometido.

![El toolkit en veinte capas](../0-assets/02-el-toolkit-en-veinte-capas.svg)

## 2. Cómo funciona

### 2.1 Tres fases, como en todas las capas anteriores

Igual que `harden` o `backup`, `release` separa el trabajo en funciones con un único cometido:

| Función | Hace | Falla con |
|---|---|---|
| `release_parse` | Lee las opciones y las guarda en variables globales | Código 1: opción desconocida, valor ausente, argumento sobrante |
| `release_prepare` | Valida **todo** antes de tocar el disco | Código 1: falta `--out`, versión inválida, directorio inexistente, falta `dpkg-deb` |
| `release_build` / `release_verify` | Hace el trabajo | Código 2 solo en `verify` |

Separar «analizar» de «validar» permite que los errores de uso salgan siempre con
el mismo formato (`toolkit release build: …`) y que **nada se escriba** si algo falla.
El orden de las comprobaciones también es contrato: `falta --out` aparece antes que
`version invalida`, y `falta dpkg-deb` va **el último**, para que un error del usuario
no se confunda con uno del entorno.

### 2.2 `release build`, paso a paso

```
mktemp -d                       →  directorio de montaje (stage)
mktemp en el destino            →  nombre temporal del .deb
release_stage                   →  copia, estampa, página de manual, control, md5sums
dpkg-deb --build                →  paquete temporal
mv temporal → toolkit_V_all.deb →  publicación atómica
sha256sum → SHA256SUMS          →  suma, también por temporal + mv
```

Cuatro decisiones merecen explicación.

**Se construye en un temporal y se publica con `mv`.** `mv` dentro del mismo sistema de
archivos es una operación atómica: otro proceso ve el paquete completo o no lo ve, nunca
a medias. Por eso el temporal se crea **en el directorio de destino** (`mktemp
"${RL_OUT}/.toolkit.XXXXXX"`) y no en `/tmp`: entre dos sistemas de archivos distintos
`mv` copia y borra, y ya no es atómico.

**El temporal se limpia con `trap`.** Si `dpkg-deb` falla, `trap 'rm -rf "${stage}" "${tmp}"' EXIT`
borra ambos. Cuando todo ha ido bien, `trap - EXIT` lo **desactiva** para no borrar
el trabajo, y el montaje se elimina a mano.

**`SHA256SUMS` se reescribe filtrando, no acumulando.** Construir dos veces la misma
versión no debe duplicar la línea:

```bash
awk -v f="$nombre" '$2 != f' SHA256SUMS > nuevo   # conserva las demás versiones
echo "${hash}  ${nombre}" >> nuevo                # añade la actual
mv nuevo SHA256SUMS
```

El archivo se lee con `awk` y no con `grep -v` porque `grep` tomaría `1.0.0` como
expresión regular (el punto casa con cualquier carácter) y borraría también `1x0y0`.
Con `$2 != f` la comparación es **exacta** de un campo completo.

**Formato de `SHA256SUMS`: dos espacios.** `hash␣␣nombre` es el formato que entiende
`sha256sum -c`; el segundo espacio indica «modo texto». El nombre va **sin ruta**, así
que `sha256sum -c` funciona desde el directorio del paquete, esté donde esté.

### 2.3 Montar el árbol (`release_stage`)

```bash
chmod 0755 "$dir"                       # mktemp -d da 0700 y dpkg-deb lo rechaza
install -d -m 0755 "$dir/DEBIAN" "$dir/usr/bin" "$dir/usr/share/man/man1"
install -m 0755 "$TK_SELF" "$dir/usr/bin/toolkit"
sed -i ... "$dir/usr/bin/toolkit"       # estampa la version
release_manpage | gzip -9n > ".../toolkit.1.gz"
```

`$TK_SELF` es `readlink -f "${BASH_SOURCE[0]}"`: la ruta **real** del propio script, de
modo que `release build` empaqueta **la misma herramienta que lo está ejecutando**,
aunque lo invoques por un enlace simbólico o desde otro directorio. Es una herramienta
que se empaqueta a sí misma.

El `md5sums` se genera con un patrón que ya conoces de la Semana 9:

```bash
(cd "$dir" && find usr -type f -print0 | LC_ALL=C sort -z | xargs -0 md5sum) > DEBIAN/md5sums
```

`-print0`/`-z`/`-0` son la cadena segura frente a nombres con espacios; `LC_ALL=C`
fija el orden de clasificación, para que dos construcciones den el mismo `md5sums`
sea cual sea el idioma del sistema. Y la ruta es `usr/bin/toolkit`, **relativa**: así
la entiende `dpkg --verify`.

### 2.4 `release verify`: seis preguntas independientes

Cada chequeo imprime `ok NOMBRE` o `falla NOMBRE: detalle`, y al final `fallos: N`.
Salir con `2` si hay alguno.

| Chequeo | Pregunta | Defecto que atrapa |
|---|---|---|
| `suma` | ¿El archivo coincide con `SHA256SUMS`? | Corrupción, edición posterior, paquete sustituido |
| `paquete` | ¿Es un `.deb` legible y se llama `toolkit`? | Un archivo cualquiera renombrado |
| `version` | ¿La versión del `control` es la del nombre del archivo? | Renombrar sin reconstruir |
| `ejecutable` | ¿`./usr/bin/toolkit` tiene modo `755`? | Un script que no arranca |
| `manual` | ¿Lleva la página de manual comprimida? | Documentación olvidada |
| `permisos` | ¿Hay algo escribible por grupo u otros? | Un fallo de seguridad en la instalación |

Dos matices de diseño:

- **Los chequeos no se cortan entre sí**: si `suma` falla, siguen los demás, porque
  quieres ver **todo** lo que está mal de una vez. Solo `paquete` corta cuando el
  archivo ni siquiera es un `.deb` (no hay nada más que mirar).
- **`permisos` lee la columna del listado**: de `-rwxr-xr-x`, los caracteres 6 y 9 son
  la escritura de grupo y de otros; basta `awk 'substr($1,6,1)=="w" || substr($1,9,1)=="w"'`.

Una limitación que debes conocer: la suma comprueba la **integridad**, no el **origen**.
Si alguien sustituye el paquete **y** el `SHA256SUMS`, `verify` no lo nota. Resolverlo
exige una firma (GPG) o una suma publicada por un canal aparte. La suma protege del
error; la firma, del adversario.

### 2.5 `selftest` encaja con el mismo patrón

`cmd_selftest` analiza `--quiet`, prepara el fixture (`selftest_fixture`), ejecuta los
cinco casos con `selftest_case` y resume. Los códigos son `0`, `1` y `2`, como todo el
resto del `toolkit`: **la misma interfaz para todo** es la razón de que una autoprueba
sea tan corta, porque cada caso es solo «¿qué código devolviste?».

## 3. Cómo se usa

```bash
toolkit selftest --quiet && \
  toolkit release build --out dist --version 1.0.0 && \
  toolkit release verify dist/toolkit_1.0.0_all.deb --quiet
# paquete: dist/toolkit_1.0.0_all.deb
# sha256: 3f2a...   (el hash real de tu archivo)
# fallos: 0
```

Si **cualquier** eslabón falla, la cadena `&&` se detiene y el código de salida del
conjunto es distinto de cero: el empaquetado está protegido por la autoprueba.
`--dry-run` ensaya sin escribir nada:

```bash
toolkit release build --out dist --dry-run
# [dry-run] paquete: dist/toolkit_1.0.0_all.deb
```

### 3.1 Divergencia de distro

`release` necesita `dpkg-deb`, presente en Debian y Ubuntu y también instalable en otras
(paquete `dpkg`), pero que **no tiene sentido** como estándar fuera de la familia Debian.
En `rhel-lab` o `arch-lab`, `toolkit release build` termina con `falta dpkg-deb` y código
1, que es justo lo previsto por `release_prepare`; el resto del `toolkit` funciona igual.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Escribir directamente el `.deb` final | Un fallo deja un paquete a medias | Temporal en el mismo directorio y `mv` |
| Temporal en `/tmp` y `mv` a otro disco | Deja de ser atómico | Crear el temporal junto al destino |
| `trap` sin desactivar tras el éxito | Borra el resultado bueno | `trap - EXIT` al terminar |
| `echo >> SHA256SUMS` sin filtrar | Líneas duplicadas con hashes viejos | `awk '$2 != f'` y añadir |
| `grep -v` con la versión como patrón | Borra líneas parecidas | Comparar el campo completo |
| Validar a mitad de la construcción | Ya se creó basura | Validar todo en `release_prepare` |
| Verificar solo la suma | Un paquete íntegro puede ser incorrecto | Los seis chequeos |
| Parar en el primer fallo de `verify` | Corriges de uno en uno | Informar de todos y salir con 2 |

## 5. Trucos

- **`sha256sum -c --status SHA256SUMS; echo $?`** da solo el código, sin imprimir
  nada: ideal en un `if`.
- **`sha256sum -c --ignore-missing SHA256SUMS`** comprueba solo los archivos que
  están presentes, útil cuando `dist/` guarda sumas de versiones ya borradas.
- **`dpkg-deb -c paquete | awk '{print $1, $NF}'`** da permisos y ruta en dos
  columnas: es la vista que usa `permisos` para buscar escritura de grupo u otros.

## 📚 Recursos Adicionales

- `man sha256sum`, `man dpkg-deb`, `man mktemp`

## ✅ Checklist de Verificación

- [ ] Describes el orden de `release build` y por qué el temporal está junto al destino
- [ ] Explicas la diferencia entre `trap … EXIT` y `trap - EXIT`
- [ ] Reconstruyes dos veces la misma versión y compruebas que `SHA256SUMS` tiene una línea
- [ ] Enumeras los seis chequeos de `release verify` y un defecto para cada uno
- [ ] Sabes qué no protege una suma (el origen)
- [ ] Explicas por qué `release` falla con código 1 en `rhel-lab`

---

[← Probar una herramienta](05-probar-una-herramienta.md) · [Repaso y siguientes pasos →](07-repaso-y-siguientes-pasos.md)
