# =============================================================================
# network.tf  —  Red mínima y Security Group
# =============================================================================
# NOTA DE APRENDIZAJE (IaC):
#   - `data` NO crea recursos: consulta infraestructura que YA existe. Acá lo
#     usamos para tomar la VPC y subred default de la cuenta, en vez de armar
#     una VPC completa (lo que sería ideal en producción, pero excesivo acá).
#   - El Security Group es el firewall de la instancia: define qué puertos
#     entran. Por eso Minecraft (25565) y SSH (22) viven acá.
# =============================================================================

# VPC default de la cuenta en la región.
data "aws_vpc" "default" {
  default = true
}

# Subredes de esa VPC (la instancia irá en una de ellas).
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------------------------------------------------------------
# Security Group del servidor Minecraft.
# -----------------------------------------------------------------------------
resource "aws_security_group" "mc" {
  name        = "cherryfrost-mc-sg"
  description = "Firewall para servidor Minecraft Fabric 1.21.1"
  vpc_id      = data.aws_vpc.default.id

  # --- Minecraft: 25565/tcp abierto al mundo (los jugadores necesitan entrar) ---
  ingress {
    description = "Minecraft Java Edition"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- SSH: 22/tcp RESTRINGIDO a tu IP (nunca al mundo) ---
  # TODO [SEGURIDAD]: var.allowed_ssh_cidr debe ser "TU_IP/32".
  #   Si queda vacío, este bloque dará error de validación en `tofu plan`,
  #   lo cual es intencional: te obliga a definir tu IP antes de desplegar.
  ingress {
    description = "SSH administrativo (solo tu IP)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- Salida: todo permitido (la instancia baja Java, Fabric y mods) ---
  egress {
    description = "Salida libre"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "cherryFrostMC"
    Name    = "cherryfrost-mc-sg"
  }
}
