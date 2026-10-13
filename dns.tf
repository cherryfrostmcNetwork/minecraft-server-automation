# =============================================================================
# dns.tf  —  Registros DNS en Route 53 para el servidor
# =============================================================================
# DISEÑO (auto-DNS desde la instancia):
#   El registro A del subdominio del juego lo gestiona la PROPIA INSTANCIA al
#   arrancar (ver user_data.sh.tpl): detecta su IP pública y actualiza Route 53
#   con su rol IAM. Por eso aquí NO definimos el registro A como recurso
#   OpenTofu — si lo hiciéramos, un `tofu apply` con la instancia apagada
#   fallaría (sin IP).
#
#   Solo gestionamos el SRV, que es estático (puerto 25565 + target al A).
# =============================================================================

locals {
  game_fqdn = "${var.game_subdomain}.${var.domain}" # ej. smp3.ejemplo.xyz
}

# Hosted zone existente (NO la crea; ya está registrada en tu cuenta).
data "aws_route53_zone" "main" {
  name         = "${var.domain}."
  private_zone = false
}

# -----------------------------------------------------------------------------
# Registro SRV: _minecraft._tcp.<game_subdomain>.<domain>
# Permite conectarse al FQDN sin escribir el puerto.
# Es estático (no depende de la IP), así que sí lo gestiona OpenTofu.
# -----------------------------------------------------------------------------
resource "aws_route53_record" "smp3_srv" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_minecraft._tcp.${local.game_fqdn}"
  type    = "SRV"
  ttl     = 60
  records = ["0 5 25565 ${local.game_fqdn}"]
}
