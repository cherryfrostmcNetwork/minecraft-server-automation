# Actualizar el servidor CherryFrost MC manualmente (vía SSM)

Guía para administrar el servidor conectándose por **AWS Systems Manager (SSM)**:
agregar/actualizar mods, editar configs, y prender/apagar. Pensada para **CachyOS**
(Arch Linux). No necesitás clonar el repo ni usar OpenTofu.

> **Datos de referencia**
> - Instance ID: `i-013ed0aaafd8acbb3`
> - Región: `us-east-1`
> - Bucket de configs (privado): `cherryfrost-mc-config-32b79dcf`
> - Carpeta del server en la instancia: `/opt/minecraft`

---

## 0. Requisitos (una sola vez en tu CachyOS)

CachyOS es Arch Linux, así que se usa `pacman` y AUR (`yay`).

```bash
# AWS CLI v2
sudo pacman -S aws-cli-v2

# Plugin de Session Manager (desde AUR)
yay -S aws-session-manager-plugin
# (alternativa: paru -S aws-session-manager-plugin)
```

Configurar tus credenciales (TE LAS PASA EL ADMIN):

```bash
aws configure --profile TU_PERFIL
# AWS Access Key ID:     <TU_ACCESS_KEY>
# AWS Secret Access Key: <TU_SECRET_KEY>
# Default region name:   us-east-1
# Default output format:  json
```

> Reemplazá `TU_PERFIL` por el nombre que quieras (ej. `cherryfrost`). Usá ese
> mismo nombre en todos los comandos de abajo donde dice `--profile TU_PERFIL`.

Verificar que las credenciales funcionan:

```bash
aws sts get-caller-identity --profile TU_PERFIL
```

---

## 1. Prender la instancia (la máquina en AWS)

> Esto requiere permisos de EC2. Si tu usuario NO los tiene, pedile al admin que
> prenda la instancia, y saltá al paso 2.

```bash
aws ec2 start-instances --instance-ids i-013ed0aaafd8acbb3 \
  --profile TU_PERFIL --region us-east-1

# esperar a que este "running"
aws ec2 wait instance-running --instance-ids i-013ed0aaafd8acbb3 \
  --profile TU_PERFIL --region us-east-1

echo "Instancia encendida. Esperá ~1-2 min a que SSM registre la instancia."
```

---

## 2. Conectarse por SSM (shell dentro de la instancia)

```bash
aws ssm start-session --target i-013ed0aaafd8acbb3 \
  --profile TU_PERFIL --region us-east-1
```

Vas a entrar como `ssm-user`. Para administrar el server, pasá a root:

```bash
sudo su -
cd /opt/minecraft
```

> Si `start-session` falla justo después de prender, esperá 1-2 min (SSM tarda en
> registrar la instancia) y reintentá.

---

## 3. Prender / apagar / reiniciar el SERVICIO Minecraft

El server corre como servicio systemd llamado `minecraft`. Dentro de la instancia (como root):

```bash
systemctl status minecraft     # ver si esta corriendo
systemctl stop minecraft       # apagar el server (NO la maquina)
systemctl start minecraft      # prender el server
systemctl restart minecraft    # reiniciar (tras cambios de mods/config)
```

---

## 4. Agregar o actualizar MODS (manual)

Los mods viven en `/opt/minecraft/mods/`. **Siempre pará el server antes de tocar mods.**

```bash
# 1) parar el server
systemctl stop minecraft

# 2) ver los mods actuales
ls -la /opt/minecraft/mods/

# 3a) AGREGAR un mod nuevo desde una URL (ej. Modrinth):
cd /opt/minecraft/mods/
curl -fsSL -O "https://cdn.modrinth.com/data/XXXX/versions/YYYY/mimod-1.21.1.jar"

# 3b) QUITAR un mod:
rm /opt/minecraft/mods/nombre-del-mod.jar

# 3c) ACTUALIZAR un mod (quitar el viejo, bajar el nuevo):
rm /opt/minecraft/mods/mimod-viejo.jar
curl -fsSL -O "https://.../mimod-nuevo-1.21.1.jar"

# 4) corregir dueño de los archivos nuevos
chown -R minecraft:minecraft /opt/minecraft/mods/

# 5) reiniciar
systemctl start minecraft
```

> **IMPORTANTE sobre compatibilidad:** el server es **Fabric 1.21.1**. Todo mod
> que agregues debe ser para **Fabric** y **1.21.1**, y server-side. NO pongas
> mods de solo-cliente (iris, sodium, shaders) o el server no arranca.

---

## 5. Editar CONFIGS de mods (manual)

Las configs están en `/opt/minecraft/config/`.

```bash
systemctl stop minecraft
nano /opt/minecraft/config/elconfig.toml   # editar lo que necesites
chown -R minecraft:minecraft /opt/minecraft/config/
systemctl start minecraft
```

> (Si `nano` no está: `dnf install -y nano`, o usá `vi`.)

---

## 6. Mandar comandos al juego sin entrar (RCON local)

Hay `mcrcon` instalado. Permite ejecutar comandos del juego (op, gamerule,
setworldspawn, etc.) sin consola interactiva. La password está en el
`server.properties`.

```bash
# como root, dentro de la instancia:
RP=$(grep rcon.password /opt/minecraft/server.properties | cut -d= -f2)

# un comando puntual:
mcrcon -H localhost -P 25575 -p "$RP" "list"

# modo interactivo (tipeás comandos seguidos, sin la barra "/"):
mcrcon -H localhost -P 25575 -p "$RP" -t
#   > list
#   > op SrRivers777
#   > say Hola
#   (salir: Ctrl+D)
```

---

## 7. Ver logs (diagnóstico)

```bash
# log del juego en vivo
tail -f /opt/minecraft/logs/latest.log

# ultimas 50 lineas
tail -50 /opt/minecraft/logs/latest.log

# log del arranque de la maquina (si algo fallo al bootear)
cat /var/log/cloud-init-output.log
```

Buscá la línea `Done (XX.XXXs)!` → significa que el server arrancó bien.

---

## 8. Apagar la instancia al terminar (ahorra costo)

> Requiere permisos EC2. Si no los tenés, avisale al admin.

```bash
# primero parar el server limpio
# (desde dentro, por SSM:  systemctl stop minecraft  ; luego salir con exit)

# apagar la maquina desde tu CachyOS:
aws ec2 stop-instances --instance-ids i-013ed0aaafd8acbb3 \
  --profile TU_PERFIL --region us-east-1
```

Apagar la instancia **deja de cobrar cómputo**. El disco (y el mundo) se conservan.

---

## Advertencias importantes

- **Los cambios manuales NO sobreviven a una recreación de la instancia.** Si el
  admin corre `tofu destroy`/recrea con OpenTofu, los mods/configs que agregaste a
  mano se pierden (se reconstruye desde el código + S3). Coordiná con el admin:
  vos editás en vivo, el admin maneja la infraestructura. Para cambios permanentes,
  hay que meterlos al repo de OpenTofu.
- **Siempre `systemctl stop minecraft` antes de tocar mods/configs**, y
  `chown minecraft:minecraft` después, o el server no levanta.
- **Compatibilidad:** solo mods Fabric 1.21.1 server-side.
- Si la IP del server cambió (pasa al prender/apagar la instancia), el DNS
  `smp3.mcserver01.xyz` lo actualiza el admin con su script; vos conectás por ese
  nombre, no por IP.
