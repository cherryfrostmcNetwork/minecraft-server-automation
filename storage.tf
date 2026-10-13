# =============================================================================
# storage.tf  —  Volumen EBS persistente para el mundo de Minecraft
# =============================================================================
# El mundo vive en un volumen SEPARADO del disco raíz, con
# delete_on_termination implícito en false (los aws_ebs_volume NO se borran al
# terminar la instancia). Así, aunque la instancia se recree o se destruya, el
# mundo SOBREVIVE en este volumen.
#
# Backups manuales: a S3 vía script (ver scripts/backup-world.sh). No hay
# backups automáticos por decisión del usuario.
# =============================================================================

# Volumen de 5 GB para /opt/minecraft/world. Debe estar en la MISMA AZ que la
# instancia (un volumen EBS solo se adjunta a instancias de su zona).
resource "aws_ebs_volume" "world" {
  availability_zone = aws_instance.mc.availability_zone
  size              = 5 # GB (límite pedido por el usuario)
  type              = "gp3"

  tags = {
    Project = "cherryFrostMC"
    Name    = "cherryfrost-mc-world"
  }

  # Evita que un cambio de tamaño/tipo recree (y borre) el volumen por error.
  lifecycle {
    prevent_destroy = true
  }
}

# Adjuntar el volumen a la instancia como /dev/sdf.
resource "aws_volume_attachment" "world" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.world.id
  instance_id = aws_instance.mc.id

  # Al recrear la instancia, permití desconectar el volumen para re-adjuntarlo
  # (sin borrarlo). stop_instance_before_detaching evita corromper datos.
  stop_instance_before_detaching = true
}

# Bucket para los backups manuales del mundo (privado).
resource "aws_s3_bucket" "backups" {
  bucket = "cherryfrost-mc-backups-${random_id.bucket_suffix.hex}"
  tags   = { Project = "cherryFrostMC", Name = "cherryfrost-mc-backups" }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "backups_bucket" {
  value = aws_s3_bucket.backups.id
}
