# =============================================================================
# s3.tf  —  Bucket S3 para las configs (overrides/) del modpack
# =============================================================================
# El servidor baja overrides.tar.gz desde este bucket en el arranque (user_data)
# y lo descomprime sobre /opt/minecraft. Así las configs vitales (claims, etc.)
# quedan aplicadas sin SSH manual.
#
# NOTA: nombre con sufijo RANDOM para unicidad global. El bucket PERSISTE
#   (no es efímero); "temporal" se refería solo al nombre autogenerado.
# =============================================================================

# Sufijo aleatorio para el nombre del bucket (los nombres S3 son globales).
resource "random_id" "bucket_suffix" {
  byte_length = 4 # 8 caracteres hex
}

resource "aws_s3_bucket" "config" {
  bucket = "cherryfrost-mc-config-${random_id.bucket_suffix.hex}"

  tags = {
    Project = "cherryFrostMC"
    Name    = "cherryfrost-mc-config"
  }
}

# Bloquear todo acceso público: la instancia lee vía rol IAM, no públicamente.
resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Subir el paquete de configs. etag detecta cambios para re-subir si editás.
resource "aws_s3_object" "overrides" {
  bucket = aws_s3_bucket.config.id
  key    = "overrides.tar.gz"
  source = "${path.module}/overrides.tar.gz"
  etag   = filemd5("${path.module}/overrides.tar.gz")
}
