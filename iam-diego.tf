# =============================================================================
# iam-diego.tf  —  Usuario IAM "diego" con acceso SOLO por SSM a la instancia
# =============================================================================
# Mínimo privilegio: diego puede iniciar una sesión SSM ÚNICAMENTE contra la
# instancia del server (no otras), y NO puede prender/apagar la instancia EC2.
#
# ADVERTENCIA: dentro de la sesión SSM diego puede hacer `sudo su -` y tiene
# control total del server (es root de facto en la máquina). Acceso admin.
# =============================================================================

resource "aws_iam_user" "diego" {
  name = "diego"
  tags = { Project = "cherryFrostMC" }
}

# Access keys (quedan en el estado de tofu, que está en .gitignore).
# Se leen con:  tofu output -raw diego_access_key_id
#               tofu output -raw diego_secret_access_key
resource "aws_iam_access_key" "diego" {
  user = aws_iam_user.diego.name
}

# --- Permisos de SSM Session Manager, acotados ---
data "aws_iam_policy_document" "diego_ssm" {
  # Iniciar sesión SOLO contra la instancia del server + los documentos de sesión.
  statement {
    sid     = "StartSessionOnServerOnly"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/${aws_instance.mc.id}",
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:document/SSM-SessionManagerRunShell",
      "arn:aws:ssm:*:*:document/AWS-StartInteractiveCommand",
      "arn:aws:ssm:*:*:document/AWS-StartSSHSession"
    ]
  }

  # Gestionar/terminar SUS propias sesiones. Estas acciones no admiten ARN de
  # instancia; se limitan al propio usuario donde AWS lo permite.
  statement {
    sid = "ManageOwnSessions"
    actions = [
      "ssm:TerminateSession",
      "ssm:ResumeSession"
    ]
    resources = ["arn:aws:ssm:*:*:session/$${aws:username}-*"]
  }

  # Canales de mensajería de Session Manager: por diseño de AWS no soportan
  # recurso específico (deben ir con "*").
  statement {
    sid = "SsmMessagingChannels"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  # Prender / apagar SOLO la instancia del server (no otras).
  statement {
    sid = "StartStopServerInstance"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]
    resources = ["arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/${aws_instance.mc.id}"]
  }

  # Gestionar modpacks (bucket downloads) y el sitio web (bucket site):
  # subir nuevos, borrar viejos, listar. Para actualizar la pagina de descargas.
  statement {
    sid = "ManageModpacksAndSite"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.downloads.arn,
      "${aws_s3_bucket.downloads.arn}/*",
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*"
    ]
  }

  # Invalidar la cache de CloudFront para que el sitio sirva el HTML nuevo.
  statement {
    sid       = "InvalidateCdn"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_user_policy" "diego_ssm" {
  name   = "diego-ssm-access"
  user   = aws_iam_user.diego.name
  policy = data.aws_iam_policy_document.diego_ssm.json
}

# --- Outputs con las credenciales (sensibles) ---
output "diego_access_key_id" {
  value     = aws_iam_access_key.diego.id
  sensitive = true
}
output "diego_secret_access_key" {
  value     = aws_iam_access_key.diego.secret
  sensitive = true
}
