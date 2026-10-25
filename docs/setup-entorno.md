# Preparar el entorno

## Prerrequisitos

- Linux, macOS o **WSL2** en Windows. En PowerShell nativo faltan `ps`, `grep`
  real, permisos Unix: trabaja dentro de WSL2.
- Docker Engine + Compose v2.
- No se requiere saber programar. El bash se aprende durante el bootcamp.

## 1. Instalar Docker

```bash
# Ubuntu 24.04
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker "$USER"
# cierra sesión y vuelve a entrar para que el grupo tome efecto
```

Verifica:

```bash
docker --version
docker compose version
```

## 2. Instalar shellcheck

```bash
sudo apt install -y shellcheck
```

Lo vas a usar desde la Semana 13 en adelante para auditar tus propios scripts.

## 3. Clonar el repositorio y levantar el laboratorio

```bash
git clone https://github.com/ergrato-dev/bc-linux-commandline.git
cd bc-linux-commandline
./scripts/start.sh
```

Esto levanta cuatro contenedores (`ubuntu-lab`, `debian-lab`, `rhel-lab`,
`arch-lab`). Verifica que `ubuntu-lab` responde:

```bash
docker exec -it ubuntu-lab cat /etc/os-release | grep VERSION_ID
# VERSION_ID="24.04"
```

## 4. Entrar al laboratorio

```bash
docker exec -it ubuntu-lab bash
```

Todo lo que practiques en `1-teoria/` y `2-practicas/` se ejecuta **dentro**
de este contenedor, no en tu máquina host. Si algo sale mal adentro, se borra
y se levanta de nuevo sin arriesgar tu sistema real:

```bash
./scripts/stop.sh --limpiar
./scripts/start.sh
```

## 5. Entregar `toolkit` al laboratorio

`verificar-semana.sh` ejecuta cada comprobación **dentro de `ubuntu-lab`**,
así que `toolkit.sh` tiene que estar en el `~/bin` **del contenedor** (para
`root`, `/root/bin`), no solo en tu máquina. El repositorio no se monta en el
contenedor: se copia el archivo con `docker cp`.

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-NN-tema/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
```

Edita el archivo en tu editor, en tu máquina, y **vuelve a ejecutar el
`docker cp`** tras cada cambio. Dos avisos:

- Si recreas el laboratorio (`./scripts/stop.sh` y luego `./scripts/start.sh`),
  `/root/bin` desaparece con el contenedor: vuelve a copiar.
- Cada semana trae su propio `starter/toolkit.sh` con todas las capas
  anteriores ya completas; cópialo encima del anterior.

## 6. Diagnóstico rápido

```bash
./scripts/verificar-semana.sh --doctor
```

---

[← Volver al índice de documentación](README.md)
