# Rúbrica de Evaluación — Semana 04

## 📊 Distribución de Evidencias

| Evidencia | Peso |
|---|:--:|
| 🧠 Conocimiento | 30% |
| 💪 Desempeño | 40% |
| 📦 Producto | 30% |

**Mínimo 70% en cada evidencia**, no en el promedio.

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | ¿Por qué `x` en un directorio significa "tránsito" y no "ejecución", y qué pasa si falta? |
| 2 | ¿De qué depende realmente poder borrar un archivo: sus propios permisos, o algo más? |
| 3 | Calculá, sin tabla, el octal de `rwxr-x---` y explicá cada dígito. |
| 4 | ¿Por qué `chown` casi siempre requiere privilegios elevados mientras `chgrp` no, siempre que sea a un grupo propio? |
| 5 | ¿Qué permisos recibe un archivo nuevo bajo `umask 027`, y por qué nunca recibe `x` sin importar el `umask`? |
| 6 | ¿Qué hace SUID en un binario, y por qué el kernel lo ignora en scripts interpretados? |
| 7 | ¿Qué problema resuelve el sticky bit, y en qué se diferencia de SGID? |
| 8 | ¿Qué puede expresar una ACL que el modelo clásico de dueño/grupo/otros no puede? |
| 9 | ¿Qué es el `mask` de una ACL, y por qué un permiso puede "estar" en `getfacl` sin aplicarse de verdad? |
| 10 | ¿Por qué `sudo` se considera más seguro que compartir la contraseña de `root`, y qué hace `visudo` distinto de editar `/etc/sudoers` con cualquier editor? |

<details>
<summary><strong>Respuestas</strong></summary>

1. Porque en un directorio, `x` no ejecuta nada — permite *entrar* (`cd`) y
   acceder a archivos conocidos por nombre dentro. Sin `x`, ni siquiera se
   puede entrar al directorio, aunque haya permiso de lectura (`r`) para
   listar sus nombres.

2. Depende del permiso de escritura sobre el **directorio que lo
   contiene**, no de los permisos del archivo mismo. Un archivo protegido
   contra escritura igual se puede borrar si el directorio es escribible
   para quien lo intenta.

3. `rwxr-x---` = dueño `7` (4+2+1), grupo `5` (4+0+1), otros `0` (sin
   ningún permiso) → octal `750`.

4. Porque cambiar el dueño podría usarse para evadir cuotas de disco
   (transferir archivos grandes a otro usuario para que cuenten contra su
   cupo) — por eso requiere `root`. `chgrp` a un grupo del que ya se es
   miembro no tiene ese riesgo: solo reasigna algo que ya te pertenece
   dentro de un conjunto al que ya tenías acceso.

5. Bajo `umask 027`: directorios `777-027=750`, archivos `666-027=640`. Un
   archivo nunca recibe `x` porque su máximo teórico (`666`) no incluye ese
   bit — ponerle ejecución es una decisión explícita posterior, no algo que
   el sistema asuma al crearlo.

6. SUID hace que el proceso corra con los privilegios del **dueño del
   archivo**, no de quien lo ejecuta. El kernel lo ignora en archivos que
   empiezan con un shebang (`#!`) porque los scripts interpretados tienen
   múltiples formas conocidas de explotar ese mecanismo de forma insegura.

7. El sticky bit restringe quién puede **borrar o renombrar** dentro de un
   directorio escribible por todos: solo el dueño del archivo (o `root`)
   puede hacerlo, aunque cualquiera pueda crear archivos ahí. SGID, en
   cambio, hace que los archivos *nuevos* hereden el grupo del directorio —
   resuelve un problema distinto (de qué grupo nace algo, no quién puede
   borrarlo).

8. Puede dar permiso a un usuario o grupo **puntual**, más allá del único
   dueño y el único grupo que el modelo clásico permite nombrar — sin tener
   que crear un grupo nuevo solo para esa persona.

9. El `mask` es el límite máximo efectivo para cualquier entrada de ACL de
   usuario o grupo (no para el dueño ni "otros"). Una entrada puede decir
   `rw-` en `getfacl`, pero si el `mask` es `r--`, el permiso real aplicado
   es solo lectura — `getfacl` muestra esa limitación con `#effective:`.

10. Porque `sudo` registra y audita comandos puntuales ejecutados con
    privilegios, sin que nadie necesite conocer la contraseña real de
    `root` — se puede revocar o limitar por persona. `visudo` valida la
    sintaxis de `/etc/sudoers` antes de guardar; un editor cualquiera
    podría guardar un archivo con un error que deje el sistema sin forma
    de usar `sudo` para corregirlo.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Modelo de permisos y chmod | Reprodujo la diferencia root/usuario normal; calculó octales a mano | 10 |
| 02 — chown, chgrp y umask | Confirmó restricciones reales de chown/chgrp; configuró SGID y umask | 10 |
| 03 — Bits especiales | Auditó SUID real; confirmó que scripts lo ignoran; configuró sticky bit | 10 |
| 04 — ACLs y sudo | Resolvió un caso real con ACL; configuró regla de sudo de menor privilegio | 10 |

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit.sh` ejecutable, `doctor`/`inventory`/`organize` sin regresión | 15 |
| `audit` reporta `umask` correctamente | 10 |
| `audit` detecta escribibles-por-otros y SUID, sale con código 2 | 20 |
| `audit` sale con 0 si está limpio, con 1 si la ruta no existe | 15 |

### Calidad — 40 puntos

| Criterio | Puntos |
|---|:--:|
| Usa `find -perm` para detectar riesgos, no parseo manual de `ls -l` | 10 |
| Los tres códigos de salida (0/1/2) están documentados en el uso del comando | 10 |
| Mensajes de riesgo van a stderr | 10 |
| No requiere privilegios de root para auditar | 10 |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Romper `doctor`/`inventory`/`organize` de semanas anteriores | -30 pts (regresión) |
| Usar el mismo código de salida para "ruta inválida" y "riesgo encontrado" | -20 pts |
| `set -euo pipefail` eliminado o comentado "para que ande" | -30 pts |

## 🔗 Navegación

[← Proyecto: Capa 4 de toolkit](3-proyecto/README.md) · [Ebooks gratuitos →](4-recursos/ebooks-free/README.md)
