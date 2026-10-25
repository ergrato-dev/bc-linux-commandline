# Webgrafía — Semana 18

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [tar(1) (man7.org)](https://man7.org/linux/man-pages/man1/tar.1.html) | Referencia de `-C`, `--exclude`, `--strip-components`, `-T` y `--listed-incremental`: las opciones del archivo 01 | 2026-10-25 |
| [sha256sum(1) (man7.org)](https://man7.org/linux/man-pages/man1/sha256sum.1.html) | Los modos de `-c`, `--status` e `--ignore-missing` y qué código devuelve cada fallo (práctica 02) | 2026-10-25 |
| [mktemp(1) (man7.org)](https://man7.org/linux/man-pages/man1/mktemp.1.html) | Por qué `backup create` escribe en un temporal con permisos `600` | 2026-10-25 |
| [logger(1) (man7.org)](https://man7.org/linux/man-pages/man1/logger.1.html) | `-t`, `-p`, `-s`, `-f` y `-u`: el archivo 07 entero | 2026-10-25 |
| [journalctl (freedesktop.org)](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html) | El manual oficial con todos los filtros y formatos de salida del archivo 05 | 2026-10-25 |
| [journald.conf (freedesktop.org)](https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html) | `Storage=`, `SystemMaxUse=` y `MaxRetentionSec=`: qué controla el tamaño y la persistencia del diario | 2026-10-25 |
| [logrotate(8) (man7.org)](https://man7.org/linux/man-pages/man8/logrotate.8.html) | La lista completa de directivas (`create`, `copytruncate`, `postrotate`, `su`) del archivo 06 | 2026-10-25 |
| [logrotate (GitHub)](https://github.com/logrotate/logrotate) | Código y notas de versiones del proyecto; útil para saber qué directivas existen en tu versión | 2026-10-25 |
| [RFC 5424: protocolo syslog](https://www.rfc-editor.org/rfc/rfc5424) | Origen de las *facilities* y las ocho severidades (`emerg`…`debug`) que usan `logger -p` y `journalctl -p` | 2026-10-25 |
| [rsyslog: documentación](https://rsyslog.com/doc/) | Cómo se escriben las reglas de `/etc/rsyslog.d/` que mandan `auth` a `auth.log` | 2026-10-25 |
| [Zstandard](https://facebook.github.io/zstd/) | Comparativas oficiales de velocidad y ratio frente a `gzip` y `xz` (archivo 02); son del propio proyecto, contrástalas con tus datos | 2026-10-25 |
| [Arch Wiki: tar](https://wiki.archlinux.org/title/Tar) | Resumen claro de formatos y compresores; ojo, se refiere a Arch (marca sus divergencias al leerla) | 2026-10-25 |
| [Arch Wiki: systemd/Journal](https://wiki.archlinux.org/title/Systemd/Journal) | Persistencia y límites del diario con ejemplos, útil para el apartado de `Storage=` del archivo 05 | 2026-10-25 |
| [ShellCheck](https://www.shellcheck.net/) | El analizador que debe dejar limpio `toolkit.sh` con la capa `backup` | 2026-10-25 |

---

[← Videografía](../videografia/README.md) · [Glosario →](../../5-glosario/README.md)
