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
dnf -y install java-21-amazon-corretto-headless

# -----------------------------------------------------------------------------
# 3) Usuario y directorio del servidor.
# -----------------------------------------------------------------------------
useradd -r -m -d /opt/minecraft minecraft || true
mkdir -p /opt/minecraft/mods
cd /opt/minecraft

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

# server.properties mínimo (puerto default 25565).
cat > server.properties <<'PROPS'
server-port=25565
motd=CherryFrost SMP3 (Fabric 1.21.1)
online-mode=true
max-players=20
PROPS

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

echo "user_data completado: Fabric ${mc_version}/${fabric_loader_version}, 16 mods, systemd activo."
