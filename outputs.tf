# =============================================================================
# outputs.tf  —  Valores que OpenTofu imprime tras el apply
# =============================================================================
# NOTA DE APRENDIZAJE (IaC):
#   Los outputs exponen datos del estado para usarlos fuera de OpenTofu.
#   Acá los scripts start/stop leen el instance_id, y vos usás la IP pública
#   para conectarte al servidor desde el cliente de Minecraft.
#   Se leen con:  tofu output <nombre>   (o  tofu output -raw <nombre>)
# =============================================================================

output "instance_id" {
  description = "ID de la instancia EC2. Lo usan los scripts start/stop."
  value       = aws_instance.mc.id
}

output "public_ip" {
  description = "IP pública actual. OJO: cambia en cada stop/start salvo EIP."
  value       = aws_instance.mc.public_ip
}

output "minecraft_address" {
  description = "Dirección para pegar en el cliente de Minecraft."
  value       = "${aws_instance.mc.public_ip}:25565"
}

# NOTA [IP DINÁMICA]: sin Elastic IP, la IP pública CAMBIA cada vez que
# apagás y prendés la instancia. Para los scripts de prender/apagar esto
# importa: tras cada start hay que releer la IP (tofu refresh + output, o
# aws ec2 describe-instances). Una Elastic IP la fija, pero cuesta si la
# instancia está apagada. TODO [RED]: decidir si querés EIP.
