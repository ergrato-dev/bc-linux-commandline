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
# cerrá sesión y volvé a entrar para que el grupo tome efecto
```

Verificá:

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
`arch-lab`). Verificá que `ubuntu-lab` responde:

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

## 5. Diagnóstico rápido

```bash
./scripts/verificar-semana.sh --doctor
```

---

[← Volver al índice de documentación](README.md)
