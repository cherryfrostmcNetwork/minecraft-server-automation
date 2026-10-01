#!/bin/bash
# =============================================================================
# start.sh  —  Prende el servidor Minecraft desde la Mac (sin entrar a la consola)
# =============================================================================
# Uso:   ./start.sh
# Requisitos: aws CLI configurado (perfil default), OpenTofu inicializado en ../
#
# NOTA DE APRENDIZAJE:
#   El instance_id se lee del output de OpenTofu, así el script no depende de
#   IDs hardcodeados. Tras prender, la IP pública puede haber cambiado, por eso
#   la volvemos a consultar y la mostramos.
# =============================================================================
set -euo pipefail

AWS_PROFILE="default"
AWS_REGION="us-east-1"

# Carpeta del proyecto OpenTofu (un nivel arriba de scripts/).
TF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1) Obtener el instance_id desde el estado de OpenTofu.
INSTANCE_ID="$(cd "$TF_DIR" && tofu output -raw instance_id)"
echo "Instancia: $INSTANCE_ID"

# 2) Prender.
aws ec2 start-instances \
  --instance-ids "$INSTANCE_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION"

# 3) Esperar a que esté running.
echo "Esperando a que la instancia esté 'running'..."
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION"

# 4) Mostrar la IP pública actual (puede haber cambiado desde el último arranque).
PUBLIC_IP="$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)"

# 5) Actualizar el DNS (smp3.mcserver01.xyz) con la IP nueva.
#    Sin Elastic IP, la IP cambia en cada encendido. `tofu apply` detecta la IP
#    nueva en aws_instance.mc.public_ip y reescribe el registro A en Route 53.
#    El TTL de 60s hace que la propagación sea rápida.
echo "Actualizando DNS smp3.mcserver01.xyz con la IP nueva..."
(cd "$TF_DIR" && tofu apply -auto-approve)

echo "Servidor encendido."
echo "Conectate en Minecraft a:  smp3.mcserver01.xyz   (o  $PUBLIC_IP:25565)"
echo "NOTA: Minecraft puede tardar ~1-2 min extra en levantar tras el boot."
echo "NOTA: el DNS puede tardar hasta ~60s (TTL) en reflejar la IP nueva."
