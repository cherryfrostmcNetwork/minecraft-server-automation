# =============================================================================
# downloads.tf  —  Bucket S3 PÚBLICO para descarga de modpacks (jugadores)
# =============================================================================
# Separado del bucket de configs (que es privado). Este sirve los 3 formatos
# de modpack del CLIENTE para que los 5 jugadores los descarguen desde el sitio.
# Acceso público de SOLO LECTURA, limitado a los objetos de este bucket.
# =============================================================================

resource "aws_s3_bucket" "downloads" {
  bucket = "cherryfrost-mc-downloads-${random_id.bucket_suffix.hex}"
  tags = {
    Project = "cherryFrostMC"
    Name    = "cherryfrost-mc-downloads"
  }
}

# Permitir políticas públicas en ESTE bucket (a diferencia del privado).
resource "aws_s3_bucket_public_access_block" "downloads" {
  bucket                  = aws_s3_bucket.downloads.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# Policy: cualquiera puede LEER (GetObject) los objetos de este bucket.
data "aws_iam_policy_document" "downloads_public" {
  statement {
    sid       = "PublicRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.downloads.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "downloads" {
  bucket     = aws_s3_bucket.downloads.id
  policy     = data.aws_iam_policy_document.downloads_public.json
  depends_on = [aws_s3_bucket_public_access_block.downloads]
}

# --- Los 3 modpacks del cliente ---
resource "aws_s3_object" "pack_mrpack" {
  bucket       = aws_s3_bucket.downloads.id
  key          = "CherryFrostMC.mrpack"
  source       = var.pack_mrpack_path
  etag         = filemd5(var.pack_mrpack_path)
  content_type = "application/octet-stream"
}

resource "aws_s3_object" "pack_zip" {
  bucket       = aws_s3_bucket.downloads.id
  key          = "CherryFrostMC.zip"
  source       = var.pack_zip_path
  content_type = "application/zip"
  # Archivo grande: S3 usa etag multiparte (no es MD5 simple), lo que causaba
  # drift perpetuo con `etag = filemd5(...)`. source_hash evita ese problema:
  # solo re-sube si el contenido local realmente cambia.
  source_hash = filemd5(var.pack_zip_path)
}

resource "aws_s3_object" "pack_curseforge" {
  bucket       = aws_s3_bucket.downloads.id
  key          = "CherryFrostMC-CurseForge.zip"
  source       = var.pack_curseforge_path
  etag         = filemd5(var.pack_curseforge_path)
  content_type = "application/zip"
}

# --- URLs públicas (para pegar en el HTML) ---
output "download_url_mrpack" {
  value = "https://${aws_s3_bucket.downloads.bucket_regional_domain_name}/${aws_s3_object.pack_mrpack.key}"
}
output "download_url_zip" {
  value = "https://${aws_s3_bucket.downloads.bucket_regional_domain_name}/${aws_s3_object.pack_zip.key}"
}
output "download_url_curseforge" {
  value = "https://${aws_s3_bucket.downloads.bucket_regional_domain_name}/${aws_s3_object.pack_curseforge.key}"
}
