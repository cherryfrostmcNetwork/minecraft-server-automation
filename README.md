# CherryFrost MC — Servidor Minecraft Fabric en AWS (OpenTofu)

Infraestructura como código (OpenTofu) para desplegar un servidor de Minecraft
**Fabric 1.21.1** con modpack en una instancia EC2 de ~2 GB de RAM, que se
**prende y apaga por comando** desde la Mac y actualiza su DNS automáticamente.

## Objetivo de diseño

- Servidor que se enciende solo cuando se juega (ahorro de costo: apagado = sin cobro de cómputo).
- **Sin Elastic IP** (para evitar costo): la IP pública cambia en cada encendido,
  y el registro DNS se actualiza solo vía `tofu apply`.
- Administración por **SSM Session Manager** (HTTPS/443), porque la red de la
  universidad bloquea SSH (puerto 22).

## Arquitectura

| Componente | Recurso | Detalle |
|---|---|---|
| Cómputo | `aws_instance.mc` | `t3.small` (2 GB) + swap 4 GB, Amazon Linux 2023 |
| Red | `aws_security_group.mc` | 25565 (juego) y 22 (SSH) abiertos; egress libre |
| Configs | `aws_s3_bucket.config` | bucket privado con `overrides.tar.gz` del modpack |
| Permisos | `aws_iam_role.mc` | lectura del bucket + `AmazonSSMManagedInstanceCore` |
| DNS | `aws_route53_record` | `smp3.mcserver01.xyz` (A + SRV, TTL 60) |

## Flujo completo

```
DESPLIEGUE (desde la Mac, por HTTPS/443 — funciona en la uni)
  tofu init → plan → apply
    ├─ S3: crea bucket + sube overrides.tar.gz (configs del modpack)
    ├─ IAM: rol + instance profile (lectura S3 + SSM)
    ├─ EC2: instancia con el user_data de arranque
    │    1. swap 4 GB      2. Java 21        3. usuario/dir
    │    4. Fabric 1.21.1/0.19.5 + EULA + server.properties
    │    5. 16 mods (Modrinth CDN)
    │    6. overrides desde S3 (configs de claims, etc.)
    │    7. systemd arranca el server
    └─ Route 53: registros A + SRV apuntando a la IP

USO DIARIO
  ./scripts/start.sh → enciende, espera running, tofu apply (actualiza DNS)
  ./scripts/stop.sh  → apaga (deja de cobrar cómputo)

JUGADORES → smp3.mcserver01.xyz  (puerto 25565 vía registro SRV)
ADMIN     → SSM (ver abajo)
```

## Requisitos (en la Mac)

- [OpenTofu](https://opentofu.org) y [AWS CLI v2](https://aws.amazon.com/cli/) instalados.
- Perfil AWS `default` autenticado, región `us-east-1`.
- Para administrar por SSM, instalar una vez el plugin (vía Homebrew):
  ```bash
  brew install --cask session-manager-plugin
  ```

## Despliegue

```bash
cd backend
tofu init          # descarga providers (aws, random)
tofu plan          # revisá qué se va a crear
tofu apply         # crea todo; el DNS se puebla solo
```

## Prender / Apagar

```bash
./scripts/start.sh   # enciende y actualiza el DNS con la IP nueva
./scripts/stop.sh    # apaga
```

## Administración por SSM (sin SSH — funciona en la red de la uni)

Con la instancia encendida:

```bash
aws ssm start-session \
  --target "$(tofu output -raw instance_id)" \
  --profile default
```

Dentro de la sesión, útiles:

```bash
sudo cat /var/log/cloud-init-output.log   # log del arranque (diagnóstico)
sudo systemctl status minecraft           # estado del server
ls /opt/minecraft/mods                     # mods instalados
```

> SSM tarda ~1-2 min tras el arranque en registrar la instancia. Si falla
> justo después de encender, esperá y reintentá.

## Modpack

- Fuente: `.mrpack` de Modrinth (Fabric 1.21.1, loader 0.19.5).
- **16 mods server-side** descargados en el arranque desde Modrinth CDN.
- Excluidos a propósito (client-only, romperían el server): iris, sodium, shaderpacks.
- Configs (`overrides/`) servidas desde S3. Incluye Open Parties and Claims con
  `maxPlayerClaimForceloads = 500` y la barrera de entrada de jugadores habilitada.

### Si editás las configs del modpack

Regenerá el paquete y reaplicá (el `etag` detecta el cambio y lo re-sube):

```bash
tar -czf overrides.tar.gz -C modpack overrides
tofu apply
```

## Seguridad y notas

- `master.pem` / `master.pub` y el estado de tofu están en `.gitignore`: NO se versionan.
- SSH (22) está abierto a `0.0.0.0/0` por decisión explícita. La administración
  real se hace por SSM; SSH queda como vía alternativa desde otras redes.
- `delete_on_termination = true`: un `tofu destroy` **borra el mundo**. El
  stop/start lo conserva. Para persistencia ante destroy, habría que agregar un
  volumen EBS separado (no implementado).

## Variables principales (`variables.tf`)

| Variable | Default | Descripción |
|---|---|---|
| `aws_region` | `us-east-1` | Región |
| `instance_type` | `t3.small` | ~2 GB RAM |
| `key_name` | `master` | Key pair SSH |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR SSH (abierto) |
| `mc_version` | `1.21.1` | Minecraft |
| `fabric_loader_version` | `0.19.5` | Fabric Loader |
| `mc_ram_mb` | `1536` | RAM de la JVM |
| `swap_size_gb` | `4` | Swap |
