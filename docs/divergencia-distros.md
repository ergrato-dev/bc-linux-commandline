# Divergencia entre distribuciones

Ubuntu 24.04 LTS es el entorno canónico de este bootcamp: todas las prácticas
y todo el autograding corren contra `ubuntu-lab`. Pero el objetivo es que
operes **cualquier** distro mayor, así que donde un comando cambia de familia
a familia, el material lo dice explícito acá — no solo en prosa suelta dentro
de cada semana.

Esta tabla crece semana a semana. Cada fila enlaza a la semana donde se
explica en profundidad.

| Área | Ubuntu/Debian (`apt`) | RHEL/Fedora (`dnf`) | Arch (`pacman`) | Semana |
|---|---|---|---|:--:|
| Gestor de paquetes | `apt install` / `apt remove` | `dnf install` / `dnf remove` | `pacman -S` / `pacman -R` | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Buscar paquete | `apt search` | `dnf search` | `pacman -Ss` | [11](../bootcamp/week-11-usuarios_grupos_y_gestion_de_paquetes/) |
| Firewall por defecto | `ufw` | `firewalld` | ninguno preinstalado | [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |
| Init / service manager | systemd | systemd | systemd (base mínima, menos unidades preinstaladas) | [16](../bootcamp/week-16-automatizacion_y_tareas_programadas/), [19](../bootcamp/week-19-systemd_seguridad_y_contenedores_desde_cli/) |
| Seguridad obligatoria | AppArmor (activo por defecto) | SELinux (activo por defecto) | ninguno por defecto | [04](../bootcamp/week-04-permisos_y_propiedad/) |
| ACLs | `acl` paquete aparte en bases mínimas | preinstalado en la mayoría | paquete `acl` aparte | [04](../bootcamp/week-04-permisos_y_propiedad/) |

## Por qué esto y no una semana por distro

Enseñar `apt`, `dnf` y `pacman` como tres cursos paralelos triplicaría el
contenido sin triplicar el aprendizaje: el *modelo mental* de "gestor de
paquetes" es el mismo, cambia la sintaxis. Este bootcamp enseña el modelo una
vez y la sintaxis comparada donde diverge, usando los contenedores de
exploración (`debian-lab`, `rhel-lab`, `arch-lab`) para que lo veas correr, no
solo lo leas.

## Cómo practicar la divergencia

```bash
# el mismo objetivo, tres gestores
docker exec -it ubuntu-lab apt search htop
docker exec -it rhel-lab   dnf search htop
docker exec -it arch-lab   pacman -Ss htop
```

---

[← Volver al índice de documentación](README.md)
