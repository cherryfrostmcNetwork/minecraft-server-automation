# =============================================================================
# iam-vettigo.tf  —  Usuario IAM "vettigo" en el grupo Admin
# =============================================================================
# ADVERTENCIA: el grupo "Admin" tiene AdministratorAccess => control TOTAL de la
# cuenta AWS (no solo el server). Decisión explícita del dueño de la cuenta.
# =============================================================================

resource "aws_iam_user" "vettigo" {
  name = "vettigo"
  tags = { Project = "cherryFrostMC" }
}

# Membresía al grupo Admin existente (el grupo NO lo gestiona este proyecto;
# solo agregamos a vettigo como miembro).
resource "aws_iam_user_group_membership" "vettigo" {
  user   = aws_iam_user.vettigo.name
  groups = ["Admin"]
}

resource "aws_iam_access_key" "vettigo" {
  user = aws_iam_user.vettigo.name
}

output "vettigo_access_key_id" {
  value     = aws_iam_access_key.vettigo.id
  sensitive = true
}
output "vettigo_secret_access_key" {
  value     = aws_iam_access_key.vettigo.secret
  sensitive = true
}
