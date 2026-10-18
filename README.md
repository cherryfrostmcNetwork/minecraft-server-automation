# CherryFrost MC — Backend (Infraestructura y Automatización)

Infraestructura como código y automatización para la red de servidores de
Minecraft **CherryFrost MC**, desplegada en AWS con **OpenTofu**.

## Visión

El proyecto está pensado para operar **múltiples servidores** de Minecraft bajo
el dominio `mcserver01.xyz`. Por ahora corre **uno** (por costo), pero la
arquitectura y el código apuntan a escalar a varios. Este repositorio concentra
todo lo relacionado con la infraestructura, la automatización del servidor y las
aplicaciones de soporte, organizado por módulos.

## Qué hay aquí

- **OpenTofu (`*.tf`)** — define toda la infraestructura en AWS:
  - EC2 efímera (se prende/apaga por comando) con Fabric/NeoForge 1.21.1.
  - Volumen EBS separado para el mundo (persiste a recreaciones) + backups a S3.
  - Auto-DNS: la instancia actualiza su registro Route 53 al arrancar (sin Elastic IP).
  - Sitio web estático con HTTPS (S3 + CloudFront + ACM).
  - Buckets S3 para configs, descargas de modpacks y backups.
  - Usuarios IAM con acceso acotado (SSM, start/stop, gestión de modpacks).
- **Scripts (`scripts/`)** — prender/apagar, montar el volumen, backups.
- **`user_data.sh.tpl`** — aprovisionamiento de la instancia al arrancar.

## Despliegue

```bash
cd backend
cp terraform.tfvars.example terraform.tfvars   # completá tus valores
tofu init
tofu plan
tofu apply
```

## Administración

- Prender/apagar: `./scripts/start.sh` / `./scripts/stop.sh`
- Administrar por SSM (sin SSH): `aws ssm start-session --target <instance-id>`

## Seguridad

`terraform.tfstate`, `terraform.tfvars`, `*.pem` y credenciales están en
`.gitignore` y **no se versionan**. Nunca subas secretos a este repositorio.
