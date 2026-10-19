#!/bin/bash
# =============================================================================
# add-mods.sh  —  Instala mods en el server CherryFrost MC (NeoForge 1.21.1)
# =============================================================================
# Estrategia HÍBRIDA:
#   1. Intenta instalar cada mod con ferium (perfil neoforge).
#   2. Si ferium falla en descargar un mod (su problema conocido de
#      "could not get compatible version"), cae a descarga DIRECTA por la
#      API de Modrinth, filtrando por NeoForge + 1.21.1.
#
# Correr EN EL SERVER (por SSM), como root:
#   sudo /opt/minecraft/scripts/add-mods.sh accessories fzzy-config waystones
#   sudo /opt/minecraft/scripts/add-mods.sh --api sable          # forzar API
#
# Argumentos: uno o más SLUGS de Modrinth (ej. "accessories", "fzzy-config").
# =============================================================================
set -uo pipefail

MC="1.21.1"
LOADER="neoforge"
MODS_DIR="/opt/minecraft/mods"
OWNER="minecraft:minecraft"
UA="cherryfrost-add-mods"
FORCE_API=0

# --- parsear flags ---
ARGS=()
for a in "$@"; do
  case "$a" in
    --api) FORCE_API=1 ;;
    -*) echo "Flag desconocido: $a"; exit 1 ;;
    *) ARGS+=("$a") ;;
  esac
done

if [ "${#ARGS[@]}" -eq 0 ]; then
  echo "Uso: $0 [--api] <slug-mod> [slug-mod ...]"
  echo "Ejemplo: $0 accessories fzzy-config"
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "Falta jq. Instalando..."; dnf -y install jq >/dev/null 2>&1 || true; }

download_via_api() {
  # $1 = slug. Baja la versión NeoForge 1.21.1 del mod a MODS_DIR.
  local slug="$1"
  echo "  [API] resolviendo $slug en Modrinth (NeoForge $MC)..."
  local url fname
  local resp
  resp=$(curl -fsSL -H "User-Agent: $UA" \
    "https://api.modrinth.com/v2/project/$slug/version?loaders=%5B%22$LOADER%22%5D&game_versions=%5B%22$MC%22%5D" 2>/dev/null)
  if [ -z "$resp" ] || [ "$resp" = "[]" ]; then
    echo "  [API] ✗ $slug: no hay versión $LOADER $MC en Modrinth"
    return 1
  fi
  url=$(echo "$resp" | jq -r '.[0].files[0].url')
  fname=$(echo "$resp" | jq -r '.[0].files[0].filename')
  if [ -z "$url" ] || [ "$url" = "null" ]; then
    echo "  [API] ✗ $slug: no se pudo extraer la URL"
    return 1
  fi
  curl -fsSL -o "$MODS_DIR/$fname" "$url" || { echo "  [API] ✗ descarga falló"; return 1; }
  chown "$OWNER" "$MODS_DIR/$fname"
  echo "  [API] ✓ $slug -> $fname"
  return 0
}

install_via_ferium() {
  # $1 = slug. Devuelve 0 si quedó el jar; 1 si ferium no pudo.
  local slug="$1"
  export HOME=/root
  ferium profile switch neoforge >/dev/null 2>&1
  ferium add "$slug" >/dev/null 2>&1 || true
  local before after
  before=$(ls -1 "$MODS_DIR"/*.jar 2>/dev/null | wc -l)
  ferium upgrade >/dev/null 2>&1
  after=$(ls -1 "$MODS_DIR"/*.jar 2>/dev/null | wc -l)
  # Heurística: si aumentó el número de jars, ferium bajó algo.
  [ "$after" -gt "$before" ] && return 0 || return 1
}

echo "Instalando ${#ARGS[@]} mod(s) en $MODS_DIR (NeoForge $MC)"
systemctl stop minecraft 2>/dev/null || true

FAILED=()
for slug in "${ARGS[@]}"; do
  echo "- $slug"
  if [ "$FORCE_API" -eq 1 ]; then
    download_via_api "$slug" || FAILED+=("$slug")
    continue
  fi
  if install_via_ferium "$slug"; then
    echo "  [ferium] ✓ $slug"
  else
    echo "  [ferium] no pudo, probando API..."
    download_via_api "$slug" || FAILED+=("$slug")
  fi
done

chown -R "$OWNER" "$MODS_DIR"
systemctl start minecraft

echo ""
echo "=== Resumen ==="
echo "mods en $MODS_DIR: $(ls -1 "$MODS_DIR"/*.jar 2>/dev/null | wc -l)"
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "FALLARON (ni ferium ni API): ${FAILED[*]}"
  echo "  -> revisá que el slug sea correcto y que exista para NeoForge $MC"
  exit 1
fi
echo "OK. Reiniciá/verificá el server: systemctl status minecraft"
