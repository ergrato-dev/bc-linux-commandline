# Autograding

`scripts/verificar-semana.sh` te dice qué te falta antes de entregar. No sabe
nada de ninguna semana en concreto: lee `bootcamp/week-NN-*/checks.json` y
ejecuta cada comando **dentro de `ubuntu-lab`**.

---

## Uso

```bash
./scripts/verificar-semana.sh --doctor   # comprueba tu entorno
./scripts/verificar-semana.sh 04         # comprueba la Semana 04
```

Salida:

```
Semana 04 — Permisos y propiedad

  ✅ El directorio compartido tiene el bit SGID activo
  ✅ umask del usuario de practica es 027
  ❌ El script toolkit.sh no es ejecutable
     pista: 2-practicas/03-permisos-de-ejecucion.md, paso 2

  12/13 comprobaciones superadas.
```

Sale con 0 si pasan todas, con 1 si falla alguna. **Cada pista dice en qué
práctica y en qué paso se arregla**: si una pista no lleva ahí, es un fallo del
material y merece un issue.

---

## Formato de `checks.json`

Un archivo por semana, en la raíz de la carpeta de la semana.

```json
{
  "semana": "04",
  "titulo": "Permisos y propiedad",
  "checks": [
    {
      "id": "directorio-sgid",
      "descripcion": "El directorio compartido tiene el bit SGID activo",
      "cmd": "stat -c '%A' /srv/equipo | grep -q '^drwxrws'",
      "assert": "exit0",
      "pista": "2-practicas/02-sgid-en-directorio-compartido.md, paso 3"
    },
    {
      "id": "umask-practica",
      "descripcion": "umask del usuario de practica es 027",
      "cmd": "su - practica -c umask",
      "assert": "stdout~0027",
      "pista": "1-teoria/04-umask.md"
    }
  ]
}
```

### Campos

| Campo | Obligatorio | Qué es |
|---|:--:|---|
| `id` | sí | Identificador estable en kebab-case. **Nunca se renombra** |
| `descripcion` | sí | Qué se comprueba, en una línea. **Se copia literal** a `3-proyecto/README.md` |
| `cmd` | sí | Comando bash que se ejecuta **dentro de `ubuntu-lab`** vía `docker exec` |
| `assert` | sí | Qué tiene que cumplirse. Ver la tabla siguiente |
| `pista` | sí | Archivo y paso donde se arregla |

### Aserciones

| `assert` | Se cumple si |
|---|---|
| `exit0` | el comando sale con código 0 |
| `exit!=0` | el comando sale distinto de 0 |
| `exit=N` | el comando sale exactamente con el código `N` |
| `stdout~RE` | la salida casa con la expresión regular extendida `RE` |
| `stdout!~RE` | la salida **no** casa con `RE` |

### Reglas

- Se escribe **antes** que el contenido: define qué es entregable y qué
  tienen que enseñar las prácticas.
- Entre 6 y 18 comprobaciones, creciendo con la complejidad de la semana.
- Una comprobación, un hecho — nada de encadenar dos cosas con `&&` dentro del
  `cmd` salvo que ambas sean, en los hechos, un único requisito.
- Corre siempre contra `ubuntu-lab`. Si una comprobación necesita otra familia
  de distro, no va en `checks.json`: va a rúbrica manual, señalando qué
  contenedor de exploración usar.
- **Cero lógica bash por semana en `verificar-semana.sh`.** Si una
  comprobación necesita código imperativo, el entregable no es verificable y
  va a rúbrica manual.

---

[← Volver al índice de documentación](README.md)
