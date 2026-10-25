# Capa 12 de `toolkit`: el subcomando `netcheck`

## 🎯 Objetivo

Añadir a `toolkit.sh` el subcomando `netcheck <host> [puerto]`, que
diagnostica la conectividad hacia un destino **capa por capa** (interfaz,
ruta por defecto, DNS y puerto TCP), imprime un veredicto por capa y sale con
un código que un script o `cron` puede usar.

## 📦 Qué añade esta capa

`doctor`, `inventory`, `organize`, `audit`, `logreport`, `logscan`,
`topcount`, `sumfield`, `finddupes`, `procwatch`, `acctaudit` y `pkgcheck`
siguen intactos y **vienen completos** en el starter de esta semana:
`acctaudit` y `pkgcheck` los terminaste en la Semana 11. Esta capa cierra
la Fase 3 del bootcamp (Semanas 09-12): `finddupes` miró el sistema de
archivos, `procwatch` los procesos, `acctaudit` y `pkgcheck` las cuentas y
el software, y `netcheck` la red. Las capas 10 a 12 forman el `sys-snapshot`
del hilo conductor: **qué corre, quién hay, qué hay instalado y a qué se
llega**.

La Semana 13 abre la Fase 4 (automatización) con bash desde cero. Esta capa
deja a `toolkit` listo para ello: los tres códigos de salida (`0`, `1`, `2`)
son el contrato que un script programado necesitará para decidir si alertar.

Esta capa reutiliza, de forma explícita, varios patrones ya vistos:

- **Tres códigos de salida con significado** (`0` todo bien, `1` uso inválido,
  `2` hallazgo): el mismo patrón de toda la fase.
- **Validación con regex antes de comparar** (el `^[0-9]+$` de la Semana 06):
  un `[[ $p -ge 1 ]]` sin validar evalúa su contenido como aritmética y
  ejecuta código.
- **`|| true` ante un comando que puede fallar a propósito** (Semanas 07-11):
  aquí tras `getent`, que sale con `2` si el nombre no resuelve.
- **Contar con asignación aritmética** (el `plan_count=$(( plan_count + 1 ))`
  de las Semanas 04-08): `fallos=$(( fallos + 1 ))` en lugar de
  `((fallos++))`, que con `set -e` mata el script en el primer fallo.
- **Leer del kernel en vez de depender de un paquete**: `/sys` y `/proc` en
  lugar de `ip`, igual que `procwatch` leía `ps`.

## ✅ Requisitos verificables

(Copiados literal de `checks.json`.)

1. toolkit.sh sigue existiendo y ejecutable
2. Los subcomandos doctor, inventory, organize, audit y logreport siguen funcionando (regresion de las Semanas 01-05)
3. Los subcomandos logscan, topcount, sumfield, finddupes y procwatch siguen funcionando (regresion de las Semanas 06-10)
4. Los subcomandos acctaudit y pkgcheck siguen funcionando (regresion de la Semana 11)
5. netcheck sale con codigo 1 si no se le pasa ningun host
6. netcheck sale con codigo 1 si el puerto no es un entero entre 1 y 65535
7. netcheck encuentra una interfaz activa aparte de lo
8. netcheck muestra la ruta por defecto con su gateway en notacion decimal
9. netcheck resuelve un nombre que existe (localhost) a una direccion IPv4
10. netcheck informa fallo de DNS para un nombre que no existe
11. netcheck no consulta DNS cuando el destino ya es una IP
12. netcheck detecta un puerto TCP que esta escuchando
13. netcheck detecta un puerto TCP donde no escucha nadie
14. netcheck omite la prueba TCP cuando el DNS ya fallo
15. netcheck sale con codigo 0 y confirma el puerto abierto cuando todas las capas responden
16. netcheck sale con codigo 2 si alguna capa falla

## 🎨 Criterios de calidad

- Cada capa usa una fuente que **existe en la imagen mínima**: `/sys`,
  `/proc`, `getent` y `/dev/tcp`; ni `ip`, ni `ss`, ni `nc`, ni `curl`
- El puerto se valida con una **regex antes** de compararlo con `-ge`/`-le`
- `getent` lleva `|| true`, y el resultado vacío se trata como "no resuelve"
- La prueba TCP lleva `timeout` y reutiliza la IP que ya resolvió la capa 3
- Las capas se ejecutan **todas** y se cuentan los fallos; solo la prueba TCP
  se omite cuando no hay IP, porque depende de la capa de abajo
- El contador usa `fallos=$(( fallos + 1 ))`, no `((fallos++))`
- `shellcheck` limpio sobre el script completo

## 💡 Adaptación a tu dominio

| Tu situación | Qué podrías priorizar en tu propio `netcheck` (no evaluado esta semana) |
|---|---|
| Administras servidores web | Añadir una quinta capa con `curl -sf --max-time 5` que compruebe el código HTTP del servicio |
| Tienes varios destinos que vigilar | Aceptar varios `host:puerto` y devolver `2` si **alguno** falla, con un resumen al final |
| Trabajas desde una red inestable | Medir y mostrar el tiempo de la conexión TCP, y avisar si pasa de un umbral |
| Vas a lanzarlo desde `cron` (Semana 16) | Una opción `--silencioso` que imprima solo los fallos, para que `cron` no te escriba cuando todo va bien |

## 🚦 Cómo entregarlo

```bash
docker exec ubuntu-lab mkdir -p /root/bin
docker cp bootcamp/week-12-redes_desde_la_linea_de_comandos/3-proyecto/starter/toolkit.sh ubuntu-lab:/root/bin/toolkit.sh
docker exec ubuntu-lab chmod +x /root/bin/toolkit.sh
# completa los TODO de cmd_netcheck en tu editor,
# y vuelve a ejecutar el docker cp tras cada cambio
./scripts/verificar-semana.sh 12
```

## 🧯 Errores comunes

- Comparar el puerto con `-ge`/`-le` **antes** de validar que es un número:
  un valor como `a[$(comando)]` se evalúa como aritmética y ejecuta el comando.
- Usar `((fallos++))` con `set -e`: la primera vez vale `0`, sale con `1` y el
  script aborta en el primer fallo, justo cuando querías seguir contando.
- Olvidar el `|| true` tras `getent`: con un nombre que no resuelve, `getent`
  sale con `2` y `set -e` corta el script antes de escribir `fallo dns`.
- Probar el puerto sin `timeout`: una IP que descarta paquetes deja el script
  colgado hasta que el kernel se rinde.
- Probar el puerto con el **nombre** en lugar de la IP ya resuelta: vuelve a
  resolver y puede dar otra dirección.
- Contar dos fallos cuando el DNS falla (DNS y TCP): sin IP, la prueba TCP se
  omite; no es un segundo fallo.
- Llamar `1` a un fallo de red: `1` es "me usaste mal" y `2` es "encontré un
  problema"; mezclarlos hace inútil el código de salida.

## 🔗 Navegación

[← Práctica 04](../2-practicas/04-netcheck-a-mano.md) · [Rúbrica de evaluación →](../rubrica-evaluacion.md)
