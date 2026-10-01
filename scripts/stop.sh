#!/bin/bash
# =============================================================================
# stop.sh  —  Apaga el servidor Minecraft desde la Mac (ahorra costos de cómputo)
# =============================================================================
# Uso:   ./stop.sh
# Requisitos: aws CLI configurado (perfil default), OpenTofu inicializado en ../
#
# NOTA DE APRENDIZAJE:
#   `stop-instances` apaga la instancia SIN destruirla: el disco (y el mundo)
#   se conservan. Dejás de pagar cómputo, pero seguís pagando el almacenamiento
#   EBS. Para borrar todo de verdad se usa `tofu destroy` (otra cosa distinta).
# =============================================================================
set -euo pipefail

AWS_PROFILE="default"
AWS_REGION="us-east-1"

TF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

INSTANCE_ID="$(cd "$TF_DIR" && tofu output -raw instance_id)"
echo "Instancia: $INSTANCE_ID"

# NOTA [APAGADO LIMPIO]: idealmente, antes de apagar habría que detener el
# proceso de Minecraft con gracia (save-all + stop) para no corromper el mundo.
# Eso requiere SSH o SSM. TODO [APAGADO]: decidir si agregamos un paso de
# apagado ordenado del server antes del stop-instances.

aws ec2 stop-instances \
  --instance-ids "$INSTANCE_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION"

echo "Esperando a que la instancia esté 'stopped'..."
aws ec2 wait instance-stopped \
  --instance-ids "$INSTANCE_ID" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION"

echo "Servidor apagado. Dejás de pagar cómputo (seguís pagando el disco EBS)."
