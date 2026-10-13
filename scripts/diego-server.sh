#!/bin/bash
# =============================================================================
# diego-server.sh  —  Prender / apagar el server CherryFrost (sin OpenTofu)
# =============================================================================
# Para Diego (u otros con permisos EC2 start/stop). NO necesita el repo ni tofu.
# El DNS smp3.mcserver01.xyz se actualiza SOLO cuando la instancia arranca
# (la instancia se auto-registra en Route 53), así que este script solo
# prende/apaga la máquina.
#
# Uso:
#   ./diego-server.sh start   -> prende el server
#   ./diego-server.sh stop    -> apaga el server
#   ./diego-server.sh status  -> ver estado e IP
# =============================================================================
set -euo pipefail

PROFILE="${AWS_PROFILE:-diego}"   # exportá AWS_PROFILE o editá acá tu perfil
REGION="us-east-1"
INSTANCE_ID="i-013ed0aaafd8acbb3"

case "${1:-}" in
  start)
    echo "Prendiendo el server..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --profile "$PROFILE" --region "$REGION"
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --profile "$PROFILE" --region "$REGION"
    echo "Instancia encendida. El DNS smp3.mcserver01.xyz se actualiza solo (~1 min)."
    echo "Conectate en Minecraft a:  smp3.mcserver01.xyz"
    echo "El juego tarda ~1-2 min extra en levantar tras el boot."
    ;;
  stop)
    echo "Apagando el server..."
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --profile "$PROFILE" --region "$REGION"
    echo "Server apagado. Deja de cobrar computo."
    ;;
  status)
    aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --profile "$PROFILE" --region "$REGION" \
      --query 'Reservations[0].Instances[0].{Estado:State.Name,IP:PublicIpAddress}' --output table
    ;;
  *)
    echo "Uso: $0 {start|stop|status}"
    exit 1
    ;;
esac
