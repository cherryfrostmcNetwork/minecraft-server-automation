#!/bin/bash
# Monta el volumen EBS en /opt/minecraft/world, migra el mundo actual, instala backup.
# Se ejecuta UNA vez en la instancia (vía SSM). Idempotente y seguro.
set -e

BK="$1"   # bucket de backups, pasado como argumento

systemctl stop minecraft || true

# Localizar el device del volumen adjunto.
DEV=""
for d in /dev/sdf /dev/xvdf /dev/nvme1n1; do
  [ -b "$d" ] && DEV="$d" && break
done
if [ -z "$DEV" ]; then echo "NO_DEVICE"; exit 1; fi
echo "DEV=$DEV"

# Formatear SOLO si está vacío (sin filesystem).
if ! blkid "$DEV" >/dev/null 2>&1; then
  mkfs -t ext4 "$DEV"
  echo "formateado"
else
  echo "ya-tiene-fs (no se reformatea)"
fi

# Copiar el mundo actual al volumen (sin destruir el original hasta confirmar).
mkdir -p /mnt/world-new
mount "$DEV" /mnt/world-new
if [ -d /opt/minecraft/world ] && [ -z "$(ls -A /mnt/world-new 2>/dev/null | grep -v lost+found)" ]; then
  cp -a /opt/minecraft/world/. /mnt/world-new/
  echo "mundo-copiado-al-volumen"
fi
umount /mnt/world-new

# Reemplazar el directorio por el punto de montaje.
[ -d /opt/minecraft/world ] && mv /opt/minecraft/world /opt/minecraft/world.bak || true
mkdir -p /opt/minecraft/world
mount "$DEV" /opt/minecraft/world

# Persistir en fstab por UUID.
UUID=$(blkid -s UUID -o value "$DEV")
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /opt/minecraft/world ext4 defaults,nofail 0 2" >> /etc/fstab

chown -R minecraft:minecraft /opt/minecraft/world

# Instalar script de backup manual a S3.
cat > /usr/local/bin/backup-world.sh <<BKP
#!/bin/bash
set -eo pipefail
TS=\$(date +%Y%m%d-%H%M%S)
OUT=/tmp/world-\$TS.tar.gz
tar -czf \$OUT -C /opt/minecraft world
aws s3 cp \$OUT s3://$BK/world-\$TS.tar.gz --region us-east-1
rm -f \$OUT
echo "Backup: s3://$BK/world-\$TS.tar.gz"
BKP
chmod +x /usr/local/bin/backup-world.sh

systemctl start minecraft

echo "=== RESULTADO ==="
df -h /opt/minecraft/world
grep world /etc/fstab
ls -la /usr/local/bin/backup-world.sh
echo "=== OK ==="
