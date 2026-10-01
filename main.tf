# =============================================================================
# main.tf  —  Servidor Minecraft Fabric 1.21.1 en AWS EC2
# =============================================================================
# Objetivo: instancia EC2 (~2GB RAM) con swap, que se prende/apaga por comandos
#           desde la Mac, corriendo Fabric 1.21.1 (Java 21) + modpack de Modrinth.
#
# NOTA DE APRENDIZAJE (IaC):
#   - El bloque `terraform` fija las versiones del CLI y de los providers.
#     Esto hace el despliegue reproducible: cualquiera que corra `tofu init`
#     obtiene exactamente el mismo provider.
#   - El bloque `provider` configura CÓMO hablar con AWS (región, credenciales).
#     Los argumentos de versión NO van aquí; van en required_providers.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # serie actual del provider AWS (NO 2.x, que es obsoleta)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # para generar el sufijo aleatorio del bucket S3
    }
  }
}

provider "aws" {
  region  = var.aws_region  # us-east-1 (confirmado) — definido en variables.tf
  profile = var.aws_profile # perfil "default" (confirmado)

  # ---------------------------------------------------------------------------
  # TODO [AUTH]: Confirmar el método de autenticación del perfil "default".
  #   - Si es ACCESS KEYS (aws configure): este bloque funciona tal cual.
  #   - Si es SSO (aws sso login): necesitás una sesión SSO activa antes de
  #     correr `tofu plan/apply`, y el perfil debe tener config sso_* en
  #     ~/.aws/config. El bloque no cambia, pero el flujo de trabajo sí.
  # ---------------------------------------------------------------------------
}
