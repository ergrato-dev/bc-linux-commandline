# Webgrafía — Semana 15

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [BashFAQ 105: por qué `set -e` no hace lo que esperas](https://mywiki.wooledge.org/BashFAQ/105) | La referencia sobre las excepciones de `set -e`, con ejemplos y una recomendación honesta: el archivo 01 y la práctica 01 con más casos límite | 2026-10-24 |
| [Bash Strict Mode (redsymbol)](http://redsymbol.net/articles/unofficial-bash-strict-mode/) | El artículo que popularizó `set -euo pipefail`; léelo **junto** a la BashFAQ 105 para ver el argumento a favor y sus límites | 2026-10-24 |
| [BashFAQ 062: archivos temporales](https://mywiki.wooledge.org/BashFAQ/062) | Cómo crear temporales de forma segura con `mktemp` y qué falla con nombres predecibles: el archivo 04 ampliado | 2026-10-24 |
| [BashFAQ 045: evitar ejecuciones simultáneas](https://mywiki.wooledge.org/BashFAQ/045) | Compara `flock`, `mkdir` y archivos de PID, y por qué algunos fallan: la base del archivo 06 | 2026-10-24 |
| [SignalTrap (Greg's Wiki)](https://mywiki.wooledge.org/SignalTrap) | `trap` explicado con cuidado, con sus señales y el uso de `EXIT` para la limpieza: contrasta con el archivo 03 | 2026-10-24 |
| [BashFAQ 035: procesar argumentos](https://mywiki.wooledge.org/BashFAQ/035) | `getopts`, opciones largas a mano y sus trampas: el archivo 07 ampliado | 2026-10-24 |
| [man 1 flock (man7.org)](https://man7.org/linux/man-pages/man1/flock.1.html) | El manpage de `flock` con `-n`, `-w`, `-E` y el modo con descriptor: el truco del README sale de aquí | 2026-10-24 |
| [timeout (GNU coreutils)](https://www.gnu.org/software/coreutils/manual/html_node/timeout-invocation.html) | Los códigos `124`, `125`, `137` y la opción `-k`, que el `--help` resume en una línea | 2026-10-24 |
| [mktemp (GNU coreutils)](https://www.gnu.org/software/coreutils/manual/html_node/mktemp-invocation.html) | Plantillas, `-d`, `-p` y por qué `-u` es inseguro | 2026-10-24 |
| [signal(7) (man7.org)](https://man7.org/linux/man-pages/man7/signal.7.html) | La lista oficial de señales, cuáles se pueden atrapar y qué hace cada una por defecto | 2026-10-24 |
| [ShellCheck SC2181](https://www.shellcheck.net/wiki/SC2181) | El aviso de `cmd; if [ $? -ne 0 ]`: por qué comprobar el comando directamente en el `if` | 2026-10-24 |

---

[← Videografía](../videografia/README.md) · [Glosario →](../../5-glosario/README.md)
