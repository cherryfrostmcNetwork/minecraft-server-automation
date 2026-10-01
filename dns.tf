# =============================================================================
# dns.tf  —  Registros DNS en Route 53 para smp3.mcserver01.xyz
# =============================================================================
# OBJETIVO: sin Elastic IP (para evitar costo), cada vez que la instancia se
#   prende obtiene una IP pública NUEVA. El registro A referencia esa IP vía
#   aws_instance.mc.public_ip, así que al correr `tofu apply` (lo hace start.sh
#   automáticamente tras encender) el DNS se actualiza solo.
#
# PATRÓN (replica el que ya usás en la zona para tus otros servidores):
#   - Registro A:   smp3.mcserver01.xyz            -> IP pública de la instancia
#   - Registro SRV: _minecraft._tcp.smp3...        -> puerto 25565 + target al A
#   El SRV permite conectarse como "smp3.mcserver01.xyz" sin escribir el puerto.
# =============================================================================

# Hosted zone existente (NO la crea; ya está registrada en tu cuenta).
data "aws_route53_zone" "main" {
  name         = "mcserver01.xyz."
  private_zone = false
}

# -----------------------------------------------------------------------------
# Registro A: smp3.mcserver01.xyz -> IP pública dinámica de la instancia.
# TTL 60s para que el cambio de IP (tras cada encendido) se propague rápido.
# -----------------------------------------------------------------------------
resource "aws_route53_record" "smp3_a" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "smp3.mcserver01.xyz"
  type    = "A"
  ttl     = 60
  records = [aws_instance.mc.public_ip]
}

# -----------------------------------------------------------------------------
# Registro SRV: _minecraft._tcp.smp3.mcserver01.xyz
# Formato del valor: "<prioridad> <peso> <puerto> <target>"
#   0 = prioridad, 5 = peso, 25565 = puerto, target = el registro A de arriba.
# -----------------------------------------------------------------------------
resource "aws_route53_record" "smp3_srv" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_minecraft._tcp.smp3.mcserver01.xyz"
  type    = "SRV"
  ttl     = 60
  records = ["0 5 25565 smp3.mcserver01.xyz"]
}
