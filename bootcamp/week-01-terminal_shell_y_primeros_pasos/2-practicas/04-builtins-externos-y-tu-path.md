# Práctica 04: Builtins, externos y tu `$PATH`

Esta práctica te hace instalar tu primer script propio en `~/bin`, agregarlo
al `$PATH`, y diagnosticar con `type` qué es cada comando que usas.

## Paso 1: Clasificar comandos con `type`

**Por qué**: distinguir builtin de externo de alias es el diagnóstico más
rápido que existe para "¿por qué este comando se comporta distinto de lo que
esperaba?".

**Comando**:

```bash
type cd
type ll
type grep
type echo
```

**Verifica**: cuatro respuestas distintas — builtin, alias (si ya hiciste la
Práctica 01), archivo en `/usr/bin`, y builtin de nuevo (`echo` existe tanto
como builtin como en `/usr/bin/echo`; bash usa el builtin por defecto, más
rápido por no lanzar un proceso nuevo).

## Paso 2: Crear `~/bin` y agregarlo al `$PATH`

**Por qué**: es donde va a vivir `toolkit.sh`, el proyecto que vas a hacer
crecer las próximas veinte semanas.

**Comando**:

```bash
mkdir -p ~/bin

cat >> ~/.bashrc << 'EOF'

export PATH="$HOME/bin:$PATH"
EOF

source ~/.bashrc
```

**Verifica**:

```bash
echo "$PATH" | tr ':' '\n' | head -3
# /root/bin        (o /home/tu-usuario/bin)
# /usr/local/sbin
# /usr/local/bin
```

Tu carpeta nueva aparece **primero**, antes que las del sistema.

## Paso 3: Confirmar por qué el directorio actual no cuenta

**Por qué**: es el error más común de quien recién empieza — "lo creé pero
dice command not found".

**Comando**:

```bash
cd /tmp
cat > hola.sh << 'EOF'
#!/usr/bin/env bash
echo "hola desde /tmp"
EOF
chmod +x hola.sh

hola.sh
```

**Verifica**: falla con `command not found`, aunque `ls` muestre el archivo
ahí mismo. Corregí con:

```bash
./hola.sh
# hola desde /tmp
```

## Paso 4: Mover el script a `~/bin` y confirmar que ahí sí funciona por nombre

**Por qué**: esta es la diferencia real entre "un script que existe" y "un
comando que puedes usar desde cualquier carpeta".

**Comando**:

```bash
mv /tmp/hola.sh ~/bin/hola.sh
cd /
hola.sh
```

**Verifica**:

```bash
hola.sh
# hola desde /tmp
```

(El mensaje quedó igual porque no editaste el contenido del script, solo lo
moviste — lo importante es que ahora corre sin `./` ni ruta completa, desde
cualquier directorio.)

## Paso 5: Provocar y entender un fallo de la tabla hash

**Por qué**: es el síntoma "lo instalé pero bash dice que no existe" —
confuso la primera vez, trivial una vez que sabes qué mirar.

**Comando**:

```bash
cp ~/bin/hola.sh ~/bin/chau.sh
sed -i 's/hola/chau/' ~/bin/chau.sh

chau.sh
# funciona directo, por ser la primera vez que se busca

rm ~/bin/chau.sh
cp ~/bin/hola.sh ~/bin/chau.sh   # lo recreamos identico

chau.sh
```

**Verifica**: si en algún punto bash "recuerda" una ruta vieja que ya no
corresponde (más fácil de reproducir moviendo binarios reales del sistema,
no scripts propios), `hash -r` fuerza a recalcular:

```bash
hash chau.sh
hash -r
hash chau.sh
```

## ✅ Resultado

- [ ] Clasificaste al menos cuatro comandos distintos con `type`
- [ ] `~/bin` existe y está al principio de tu `$PATH`
- [ ] Reprodujiste el error de "directorio actual no está en PATH" y lo corregiste con `./`
- [ ] Tienes un script propio corriendo por nombre desde cualquier carpeta

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `hola.sh` sigue sin encontrarse después de moverlo a `~/bin` | `~/bin` no quedó en `$PATH` de esta sesión | Repetir `source ~/.bashrc`, o confirmar con `echo $PATH` que la carpeta aparece |
| `chmod +x` no alcanza y el script sigue sin ejecutarse | El shebang de la primera línea tiene un error de tipeo o un espacio extra | `head -1 archivo.sh | cat -A` para ver caracteres invisibles |
| `$PATH` quedó vacío o roto después de editar `.bashrc` | Se sobrescribió `PATH=` en vez de extenderlo con `$PATH` al final | Revisar la línea agregada: siempre `export PATH="algo:$PATH"`, nunca `export PATH="algo"` |

---

[← Práctica 03](03-dominar-historial-y-atajos.md) · [Proyecto: Capa 1 de toolkit →](../3-proyecto/README.md)
