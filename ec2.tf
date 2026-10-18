# =============================================================================
# ec2.tf  —  Instancia EC2 del servidor Minecraft
# =============================================================================
# NOTA DE APRENDIZAJE (IaC):
#   - `data aws_ami` resuelve la AMI más reciente de Amazon Linux 2023 por
#     filtro, en vez de hardcodear un ID que cambia por región y con el tiempo.
#   - `user_data` es un script que la instancia ejecuta UNA sola vez al primer
#     arranque: ahí creamos el swap, instalamos Java 21 y preparamos Fabric.
#   - `templatefile()` inyecta nuestras variables al script .tpl.
# =============================================================================

# AMI FIJADA al ID actual de la instancia. Antes se usaba `most_recent = true`,
# pero eso forzaba recrear la instancia (y perder el mundo) cada vez que Amazon
# publicaba una AMI nueva de AL2023. Fijar el ID evita ese drift destructivo.
# Para actualizar la AMI a propósito en el futuro: cambiar este valor conscientemente.
#   AMI anterior dinámica: al2023-ami-2023.*-x86_64 (most_recent)
locals {
  al2023_ami_id = "ami-03714e87ed2cafc78" # AL2023 x86_64 us-east-1 (en uso)
}

# -----------------------------------------------------------------------------
# Instancia EC2.
# -----------------------------------------------------------------------------
resource "aws_instance" "mc" {
  ami                    = local.al2023_ami_id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.mc.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.mc.name

  # Disco raíz. 20GB da espacio para SO + Java + mods + mundo inicial.
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true # TODO [PERSISTENCIA]: ver nota abajo.
  }

  # Script de arranque: swap + Java 21 + Fabric 1.21.1.
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    swap_size_gb          = var.swap_size_gb
    mc_version            = var.mc_version
    fabric_loader_version = var.fabric_loader_version
    mc_ram_mb             = var.mc_ram_mb
    modpack_source        = var.modpack_source
    config_bucket         = aws_s3_bucket.config.id
    rcon_password         = random_password.rcon.result
    zone_id               = data.aws_route53_zone.main.zone_id
    backups_bucket        = aws_s3_bucket.backups.id
  })

  tags = {
    Project = "cherryFrostMC"
    Name    = "cherryfrost-mc-server"
  }

  # ---------------------------------------------------------------------------
  # TODO [PERSISTENCIA]: pendiente de confirmación del usuario.
  #   - Con delete_on_termination=true, destruir la instancia borra el mundo.
  #     El stop/start (prender/apagar) SÍ conserva los datos del disco raíz.
  #   - Si querés que el mundo sobreviva incluso a `tofu destroy`, se agrega
  #     un volumen EBS separado (aws_ebs_volume + aws_volume_attachment) con
  #     el mundo montado ahí. Eso es un cambio de diseño a decidir.
  # ---------------------------------------------------------------------------
}
