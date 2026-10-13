#!/bin/bash
# =============================================================================
# user_data.sh.tpl  —  Arranque inicial de la instancia (se ejecuta 1 sola vez)
# =============================================================================
# Variables inyectadas por templatefile() desde ec2.tf:
#   swap_size_gb=${swap_size_gb}  mc_version=${mc_version}
#   fabric_loader_version=${fabric_loader_version}  mc_ram_mb=${mc_ram_mb}
#
# Logs del arranque: /var/log/cloud-init-output.log
# =============================================================================
set -euxo pipefail

# -----------------------------------------------------------------------------
# 1) SWAP — colchón de memoria para la construcción inicial en instancia de 2GB.
# -----------------------------------------------------------------------------
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=$((${swap_size_gb} * 1024))
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# -----------------------------------------------------------------------------
# 2) JAVA 21 — requerido por Minecraft 1.21.1.
# -----------------------------------------------------------------------------
dnf -y update
dnf -y install java-21-amazon-corretto-headless tar gzip

# --- mcrcon: cliente RCON para mandar comandos al server por localhost ---
# Se baja el binario estatico oficial (funciona en AL2023). Uso: ver nota final.
curl -fsSL -o /tmp/mcrcon.tar.gz \
  "https://github.com/Tiiffi/mcrcon/releases/download/v0.7.2/mcrcon-0.7.2-linux-x86-64.tar.gz" || true
tar -xzf /tmp/mcrcon.tar.gz -C /tmp 2>/dev/null || true
find /tmp -name mcrcon -type f -exec cp {} /usr/local/bin/mcrcon \; 2>/dev/null || true
chmod +x /usr/local/bin/mcrcon 2>/dev/null || true

# -----------------------------------------------------------------------------
# 3) Usuario y directorio del servidor.
# -----------------------------------------------------------------------------
useradd -r -m -d /opt/minecraft minecraft || true
mkdir -p /opt/minecraft/mods
cd /opt/minecraft

# -----------------------------------------------------------------------------
# 3.5) VOLUMEN EBS PERSISTENTE para el mundo (/opt/minecraft/world).
# -----------------------------------------------------------------------------
# El volumen se adjunta como /dev/sdf (puede aparecer como /dev/xvdf o nvme en
# AL2023). Se formatea SOLO si está vacío (sin filesystem). Si ya tiene un mundo
# de una vida anterior de la instancia, NO se reformatea -> el mundo SOBREVIVE.
WORLD_DEV=""
for d in /dev/sdf /dev/xvdf /dev/nvme1n1; do
  [ -b "$d" ] && WORLD_DEV="$d" && break
done
if [ -n "$WORLD_DEV" ]; then
  # Formatear SOLO si no tiene filesystem (volumen nuevo/vacío).
  if ! blkid "$WORLD_DEV" >/dev/null 2>&1; then
    mkfs -t ext4 "$WORLD_DEV"
  fi
  mkdir -p /opt/minecraft/world
  mount "$WORLD_DEV" /opt/minecraft/world
  # Persistir el montaje por UUID (robusto ante cambios de nombre de device).
  UUID=$(blkid -s UUID -o value "$WORLD_DEV")
  grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /opt/minecraft/world ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# -----------------------------------------------------------------------------
# 4) FABRIC SERVER ${mc_version} (loader ${fabric_loader_version})
# -----------------------------------------------------------------------------
# Se usa el endpoint de Fabric que genera un server-launcher jar directo:
#   /v2/versions/loader/<mc>/<loader>/<installer>/server/jar
FABRIC_INSTALLER="1.1.2"
curl -fsSL -o server.jar \
  "https://meta.fabricmc.net/v2/versions/loader/${mc_version}/${fabric_loader_version}/$${FABRIC_INSTALLER}/server/jar"

# EULA de Minecraft (obligatorio aceptarlo para arrancar).
echo "eula=true" > eula.txt

# server.properties: puerto 25565, seed fija, spawn lejano, MOTD con colores y RCON local.
cat > server.properties <<PROPS
server-port=25565
level-seed=-3224511046644684461
motd=\u00A7d\u00A7lCherryFrost MC \u00A7r\u00A77\u00BB \u00A7bFabric 1.21.1\n\u00A76Claims \u00A7r\u00A77| \u00A7aVoiceChat \u00A7r\u00A77| \u00A7eSMP
online-mode=true
max-players=20
spawn-protection=0
enable-rcon=true
rcon.port=25575
rcon.password=${rcon_password}
PROPS

# ops.json: SrRivers777 con OP permanente (nivel 4, sobrevive reinicios).
cat > ops.json <<'OPS'
[
  {
    "uuid": "34f65e95-c703-421e-9c6d-7944a1154a5a",
    "name": "SrRivers777",
    "level": 4,
    "bypassesPlayerLimit": true
  }
]
OPS

# -----------------------------------------------------------------------------
# 5) MODS del modpack (server-side) — descargados desde Modrinth CDN.
# -----------------------------------------------------------------------------
# Lista extraída de modrinth.index.json. EXCLUIDOS a propósito: iris y sodium
# (server: unsupported) y los shaderpacks (client-only). Instalarlos rompería
# el arranque del servidor.
cd /opt/minecraft/mods
MODS=(
  "https://cdn.modrinth.com/data/P7dR8mSH/versions/Mys3P7lK/fabric-api-0.116.17%2B1.21.1.jar"
  "https://cdn.modrinth.com/data/lfb5f3dN/versions/k4MkTWQi/TreeChopper-v1.0.0-mc1.21.1.jar"
  "https://cdn.modrinth.com/data/nPZr02ET/versions/9KrnphgC/netherportalfix-fabric-1.21.1-21.1.3.jar"
  "https://cdn.modrinth.com/data/OsZiaDHq/versions/v7fZmKvM/CreativeCore_FABRIC_v2.13.48_mc1.21.1.jar"
  "https://cdn.modrinth.com/data/ohNO6lps/versions/N5qzq0XV/ForgeConfigAPIPort-v21.1.6-1.21.1-Fabric.jar"
  "https://cdn.modrinth.com/data/OhduvhIc/versions/XJrQXP5u/veinminer-fabric-2.11.2%2B1.21.1.jar"
  "https://cdn.modrinth.com/data/u6dRKJwZ/versions/VKy3IS5s/jei-1.21.1-fabric-19.57.0.447.jar"
  "https://cdn.modrinth.com/data/7tEfOcA7/versions/DR2k9UK9/mezz_config-1.21.1-fabric-0.6.3.jar"
  "https://cdn.modrinth.com/data/6txNkua3/versions/wP4Wd1IW/immersive_paintings-fabric-1.21.1-0.7.9.jar"
  "https://cdn.modrinth.com/data/gF3BGWvG/versions/IGnNGC9H/open-parties-and-claims-fabric-1.21.1-0.31.6.jar"
  "https://cdn.modrinth.com/data/1bokaNcj/versions/ZD6hK4GV/xaerominimap-fabric-1.21.1-26.5.0.jar"
  "https://cdn.modrinth.com/data/Ha28R6CL/versions/eRRZzGMc/fabric-language-kotlin-1.14.1%2Bkotlin.2.4.20.jar"
  "https://cdn.modrinth.com/data/MBAkmtvl/versions/VynBiUHt/balm-fabric-1.21.1-21.0.65.jar"
  "https://cdn.modrinth.com/data/hYykXjDp/versions/zFccjYag/fzzy_config-0.7.7%2B1.21.jar"
  "https://cdn.modrinth.com/data/NcUtCpym/versions/txl9KURC/xaeroworldmap-fabric-1.21.1-1.46.0.jar"
  "https://cdn.modrinth.com/data/9eGKb6K1/versions/6PKCVne5/voicechat-fabric-1.21.1-2.6.24.jar"
)
for url in "$${MODS[@]}"; do
  curl -fsSL -O "$url"
done

# -----------------------------------------------------------------------------
# 6) overrides/ (configs del modpack) — descargadas desde S3.
# -----------------------------------------------------------------------------
# El bucket es privado; la instancia accede vía su rol IAM (instance profile).
# Incluye openpartiesandclaims-server.toml con maxPlayerClaimForceloads=500 y
# la barrera de entrada de jugadores habilitada.
dnf -y install awscli-2 || dnf -y install aws-cli || true
cd /opt/minecraft
aws s3 cp "s3://${config_bucket}/overrides.tar.gz" /tmp/overrides.tar.gz --region us-east-1
# Descomprime: el tar tiene overrides/ como raíz; se mueve su contenido a /opt/minecraft.
tar -xzf /tmp/overrides.tar.gz -C /tmp
cp -r /tmp/overrides/. /opt/minecraft/
rm -rf /tmp/overrides /tmp/overrides.tar.gz

# -----------------------------------------------------------------------------
# 7) Permisos y servicio systemd (autoarranque al prender la instancia).
# -----------------------------------------------------------------------------
chown -R minecraft:minecraft /opt/minecraft

cat > /etc/systemd/system/minecraft.service <<UNIT
[Unit]
Description=Minecraft Fabric Server (CherryFrost SMP3)
After=network.target

[Service]
User=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms${mc_ram_mb}M -Xmx${mc_ram_mb}M -jar server.jar nogui
Restart=on-failure
SuccessExitStatus=0 1

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable minecraft.service
systemctl start minecraft.service

# -----------------------------------------------------------------------------
# 8) AUTO-DNS: la instancia actualiza smp3.mcserver01.xyz con su IP al arrancar.
# -----------------------------------------------------------------------------
# Así nadie necesita correr `tofu apply` para refrescar el DNS: basta prender la
# instancia (aws ec2 start-instances) y ella misma se registra en Route 53.
cat > /usr/local/bin/update-dns.sh <<'DNSSCRIPT'
#!/bin/bash
set -eo pipefail
# IP pública vía IMDSv2.
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)
[ -z "$IP" ] && { echo "sin IP publica, aborto"; exit 0; }

cat > /tmp/dns-change.json <<JSON
{
  "Comment": "auto-update smp3 al arrancar",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "smp3.mcserver01.xyz",
      "Type": "A",
      "TTL": 60,
      "ResourceRecords": [{ "Value": "$IP" }]
    }
  }]
}
JSON

aws route53 change-resource-record-sets \
  --hosted-zone-id ${zone_id} \
  --change-batch file:///tmp/dns-change.json
echo "DNS smp3 -> $IP actualizado"
DNSSCRIPT
chmod +x /usr/local/bin/update-dns.sh

# Servicio que corre el update-dns en cada boot (tras la red).
cat > /etc/systemd/system/update-dns.service <<UNIT
[Unit]
Description=Actualiza smp3.mcserver01.xyz con la IP publica al arrancar
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-dns.sh

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable update-dns.service
systemctl start update-dns.service

# -----------------------------------------------------------------------------
# 9) Script de BACKUP MANUAL del mundo a S3 (lo ejecuta el admin cuando quiere).
# -----------------------------------------------------------------------------
# Uso (dentro de la instancia, como root):  /usr/local/bin/backup-world.sh
cat > /usr/local/bin/backup-world.sh <<'BKP'
#!/bin/bash
set -eo pipefail
TS=$(date +%Y%m%d-%H%M%S)
OUT="/tmp/world-$TS.tar.gz"
echo "Empaquetando el mundo..."
tar -czf "$OUT" -C /opt/minecraft world
echo "Subiendo a S3..."
aws s3 cp "$OUT" "s3://${backups_bucket}/world-$TS.tar.gz" --region us-east-1
rm -f "$OUT"
echo "Backup listo: s3://${backups_bucket}/world-$TS.tar.gz"
BKP
chmod +x /usr/local/bin/backup-world.sh

echo "user_data completado: Fabric ${mc_version}/${fabric_loader_version}, 16 mods, systemd + auto-DNS + volumen persistente + backup script."
