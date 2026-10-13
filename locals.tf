# =============================================================================
# locals.tf  —  Valores parametrizados (para que el repo sea público sin exponer
#               datos específicos de la cuenta).
# =============================================================================
# El account-id se obtiene dinámicamente (no se hardcodea). El dominio y la
# región vienen de variables cuyos valores reales viven en terraform.tfvars
# (que está en .gitignore y NO se sube al repo público).
# =============================================================================

# Account-id actual, resuelto en runtime (no queda escrito en el código).
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# Dominio base (ej. "mcserver01.xyz"). Valor real en terraform.tfvars.
variable "domain" {
  description = "Dominio base gestionado en Route 53 (sin punto final)."
  type        = string
  # Sin default: obliga a definirlo en terraform.tfvars (fuera del repo público).
}

# Subdominio del servidor de juego (ej. "smp3").
variable "game_subdomain" {
  description = "Subdominio para el servidor Minecraft."
  type        = string
  default     = "smp3"
}

# Subdominio del sitio web (ej. "play").
variable "web_subdomain" {
  description = "Subdominio para el sitio web."
  type        = string
  default     = "play"
}
