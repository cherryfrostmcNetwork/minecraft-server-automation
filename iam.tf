# =============================================================================
# iam.tf  —  Rol e instance profile para que la EC2 lea el bucket de configs
# =============================================================================
# La instancia necesita permiso para bajar overrides.tar.gz de S3. En vez de
# poner credenciales en la instancia, se le adjunta un ROL IAM (instance
# profile) con acceso de SOLO LECTURA, limitado a ESTE bucket.
# =============================================================================

# Trust policy: permite que el servicio EC2 asuma este rol.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mc" {
  name               = "cherryfrost-mc-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Project = "cherryFrostMC"
  }
}

# Permiso mínimo: leer objetos y listar SOLO el bucket de configs.
data "aws_iam_policy_document" "s3_read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.config.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.config.arn]
  }
}

resource "aws_iam_role_policy" "s3_read" {
  name   = "cherryfrost-mc-s3-read"
  role   = aws_iam_role.mc.id
  policy = data.aws_iam_policy_document.s3_read.json
}

# -----------------------------------------------------------------------------
# SSM Session Manager: administrar la instancia por HTTPS (443), sin SSH.
# Necesario porque la red de la universidad bloquea el puerto 22 (SSH).
# El SSM Agent ya viene preinstalado en Amazon Linux 2023; esta policy
# administrada por AWS es lo único que falta para habilitarlo.
# Conexión desde la Mac:  aws ssm start-session --target <instance-id>
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.mc.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile: el envoltorio que conecta el rol a la instancia EC2.
resource "aws_iam_instance_profile" "mc" {
  name = "cherryfrost-mc-profile"
  role = aws_iam_role.mc.name
}
