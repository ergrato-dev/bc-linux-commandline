# Webgrafía — Semana 19

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html) | Cada directiva de aislamiento del archivo 06 (`ProtectSystem`, `PrivateTmp`, `NoNewPrivileges`…) con su efecto exacto | 2026-10-25 |
| [systemd.service(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) | Referencia de `Type=`, `ExecStart=` y `Restart=`: el archivo 03 | 2026-10-25 |
| [systemd-analyze(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html) | `verify`, `security`, `calendar`, `timespan`, `blame` y `critical-chain` en un solo manual | 2026-10-25 |
| [journalctl(1)](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html) | Filtros por unidad, arranque y prioridad del archivo 04 | 2026-10-25 |
| [sshd_config(5) (OpenBSD)](https://man.openbsd.org/sshd_config) | Manual oficial de OpenSSH: confirma que la primera aparición gana y documenta `Match` | 2026-10-25 |
| [Mozilla: OpenSSH guidelines](https://infosec.mozilla.org/guidelines/openssh) | Configuración recomendada de SSH con justificación de cada ajuste | 2026-10-25 |
| [sudoers(5)](https://www.sudo.ws/docs/man/sudoers.man/) | Sintaxis de las reglas del archivo 05, con los avisos sobre comandos que abren una shell | 2026-10-25 |
| [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) | Qué poderes de root existen por separado; base de `--cap-drop` y `CapabilityBoundingSet=` | 2026-10-25 |
| [namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html) y [cgroups(7)](https://man7.org/linux/man-pages/man7/cgroups.7.html) | Lo que hay detrás de un contenedor (archivo 07) | 2026-10-25 |
| [Docker: seguridad del motor](https://docs.docker.com/engine/security/) | Modelo de seguridad de Docker: qué aísla y qué no | 2026-10-25 |
| [`docker container run`](https://docs.docker.com/reference/cli/docker/container/run/) | Referencia de `--read-only`, `--user`, `--cap-drop`, `--init` y `-p` | 2026-10-25 |
| [ShellCheck](https://www.shellcheck.net/) | El analizador que debe dejar limpio `toolkit.sh` con la capa `harden` | 2026-10-25 |

---

[← Videografía](../videografia/README.md) · [Glosario →](../../5-glosario/README.md)
