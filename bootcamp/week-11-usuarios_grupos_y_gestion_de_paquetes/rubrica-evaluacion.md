# Rúbrica de Evaluación — Semana 11

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

1. ¿Qué dos cuentas con distinto nombre son, para el kernel, la misma persona?

<details>
<summary>Ver respuesta</summary>

Las que comparten **UID**. El kernel solo guarda el número; el nombre es
una traducción que viene de `/etc/passwd`. Una cuenta `toor` con UID `0`
tiene exactamente los mismos privilegios que `root`, por eso `acctaudit`
la marca como hallazgo aunque el nombre sea otro.

</details>

2. ¿Por qué la contraseña no está en `/etc/passwd` y dónde está?

<details>
<summary>Ver respuesta</summary>

`/etc/passwd` tiene que poder leerlo cualquier programa (por ejemplo,
`ls -l` lo usa para traducir UID a nombre), así que es legible por todos.
El hash vive en `/etc/shadow` (modo `640`, `root:shadow`) y el campo 2 de
`passwd` solo lleva una `x` que remite allí.

</details>

3. ¿Qué diferencia hay entre `usermod -G devs ana` y `usermod -aG devs ana`?

<details>
<summary>Ver respuesta</summary>

Sin `-a`, `-G` **reemplaza** toda la lista de grupos suplementarios de
`ana` por `devs`, borrando los que tuviera (`sudo`, `adm`…). Con `-a`
(*append*) se **añade** `devs` y se conservan los demás. Es el error más
caro de `usermod`: se reproduce en la Práctica 01.

</details>

4. ¿Qué queda en el disco si das de baja una cuenta con `userdel` sin `-r`, y por qué es un riesgo?

<details>
<summary>Ver respuesta</summary>

El home y sus archivos permanecen, con el UID/GID **numérico** como
dueño (`ls -ln` muestra números, no nombres). El riesgo: el siguiente
`useradd` puede reutilizar ese UID y el usuario nuevo **hereda el home y
los archivos de otra persona**. `find / -nouser` los localiza.

</details>

5. ¿Qué diferencia hay entre `su luis` y `su - luis`?

<details>
<summary>Ver respuesta</summary>

`su - luis` simula un inicio de sesión completo: limpia el entorno,
carga los perfiles de `luis` y entra en **su** home. `su luis` conserva
el entorno y el directorio actuales del usuario anterior, una mezcla
que provoca errores de tipo "funciona con mi usuario y falla con el
otro".

</details>

6. ¿Por qué se valida con `visudo -cf` en `/tmp` antes de instalar una regla en `/etc/sudoers.d`?

<details>
<summary>Ver respuesta</summary>

Un archivo con sintaxis rota en `sudoers.d` puede dejar sin `sudo` a
toda la máquina, y sin `sudo` ni contraseña de `root` es difícil de
reparar. Validar primero en `/tmp` hace que un error nunca llegue al
sitio definitivo; `install -m 0440 -o root -g root` lo copia luego con
el modo y dueño correctos en un solo paso.

</details>

7. ¿Por qué `usuario ALL=(ALL) NOPASSWD: ALL` es un antipatrón y qué se hace en su lugar?

<details>
<summary>Ver respuesta</summary>

Equivale a `root` sin contraseña: quien tome la sesión de ese usuario es
`root`. El mínimo privilegio da **solo** la orden necesaria, con ruta
absoluta (`NOPASSWD: /usr/bin/id`), y deja el resto protegido por
contraseña, además de dejar un registro de cada uso.

</details>

8. ¿Qué dos capas tiene un gestor como `apt` y qué hace cada una?

<details>
<summary>Ver respuesta</summary>

El **frontend** (`apt`, `dnf`) habla con los repositorios, resuelve
dependencias y decide el orden. El **backend** (`dpkg`, `rpm`) instala
**un archivo local** y actualiza la base de datos, sin saber nada de
repositorios. `dpkg -i` de un `.deb` con dependencias sin resolver deja
el paquete a medias (`iU`). Arch, con `pacman`, hace las dos cosas en un
solo binario.

</details>

9. ¿Por qué `pkgcheck` pregunta por el estado del paquete y no solo por su versión?

<details>
<summary>Ver respuesta</summary>

Un paquete quitado con `apt remove` (no `purge`) queda en estado `rc`
(*config-files*): `dpkg-query -W` **sigue devolviendo su versión** aunque
el programa ya no esté. Solo `${db:Status-Status}` igual a `installed`
distingue "instalado" de "con restos de configuración".

</details>

10. ¿Qué diferencia de confianza hay entre un `.deb` y un `.rpm` descargados de internet?

<details>
<summary>Ver respuesta</summary>

Un `.rpm` va **firmado individualmente** y `rpm -K` lo valida en
cualquier archivo (da `NOT OK` si se modifica un byte). Un `.deb` no
lleva firma propia: la confianza viene del **índice firmado** del
repositorio (`InRelease`, con su `Signed-By` y los hashes SHA-256).
Descargado fuera de `apt`, nadie garantiza el `.deb`: `dpkg-deb -I` abre
sin quejarse uno al que se le añadió un byte.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — usuarios y grupos reales | Crea un usuario completo, reproduce la trampa de `-G`, localiza un home huérfano y prueba un directorio SGID | 10 |
| 02 — sudo con criterio | Valida una regla con `visudo -cf` antes de instalarla, comprueba lo permitido y lo prohibido, reproduce `world writable` | 10 |
| 03 — paquetes en cuatro familias | Repite el ciclo instalar/consultar/quitar en `apt`, `dnf` y `pacman`, y verifica firma y hash | 10 |
| 04 — acctaudit y pkgcheck a mano | Provoca cada regla por separado, monta `auditar` con códigos `0`/`2`, y distingue `rc` de `installed` | 10 |

## 📦 Producto (30%)

### Autograding (`checks.json`)

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable y regresión de las capas anteriores (3 checks) | 3 |
| `acctaudit`: validación de entrada y casos limpios (3 checks) | 3 |
| `acctaudit`: detección de las cuatro reglas (4 checks) | 8 |
| `acctaudit`: código de salida con hallazgos (1 check) | 2 |
| `pkgcheck`: validación de entrada y gestor (2 checks) | 2 |
| `pkgcheck`: instalado, versión y no instalado (3 checks) | 4 |

**Total autograding: 22 puntos** de 30 del Producto.

### Calidad manual

| Criterio | Puntos |
|---|:--:|
| `shellcheck` limpio sobre el starter completo | 3 |
| Compara contra `/etc/shells` (no contra `nologin`) y lo documenta | 2 |
| Decide "instalado" por el estado, no por la versión, y lo documenta | 2 |
| Cuenta con `grep -c . \|\| true`, sin `wc -l` sobre variables posiblemente vacías | 1 |

**Total calidad manual: 8 puntos** (22 + 8 = 30).

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Crear cuentas con UID 0 u otros usuarios peligrosos de verdad en el laboratorio para probar `acctaudit` | Grave |
| `sudo su -`/`sudo bash` o `NOPASSWD: ALL` en cualquier ejemplo, sin marcarlo como antipatrón | Grave |
| `userdel -r`, `autoremove` u otro comando destructivo sin aviso ni respaldo/simulación previa | Grave |
| Secreto comiteado (clave, hash o token con formato real) | Grave |
| `curl \| sudo bash` o `--allow-unauthenticated` sin marcarlo como antipatrón | Grave |
| `shellcheck` con hallazgos sin justificar | Moderada |

---

[← Proyecto: Capa 11 de toolkit](3-proyecto/README.md) · [Recursos: Ebooks →](4-recursos/ebooks-free/README.md)
