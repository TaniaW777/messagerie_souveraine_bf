#!/usr/bin/env bash
# ==============================================================================
# EXPORT DES IMAGES DOCKER — GÉNÉRATION DU PACK HORS-LIGNE
# À exécuter UNE FOIS sur la machine source (avec internet ou images présentes).
# Génère des archives .tar.gz dans offline-demo/images/
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  EXPORT DES IMAGES DOCKER — PACK HORS-LIGNE MESSAGERIE SOUVERAINE BF         ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Dossier de destination : $IMAGES_DIR"
echo "ATTENTION : Opération longue (~3-4 GB compressés). Veuillez patienter."
echo ""

mkdir -p "$IMAGES_DIR"

declare -A EXPORTS=(
    ["synapse.tar.gz"]="matrixdotorg/synapse:v1.164.1"
    ["element.tar.gz"]="vectorim/element-web:v1.11.109"
    ["postgres.tar.gz"]="postgres:16-alpine"
    ["nginx.tar.gz"]="nginx:1.27-alpine"
    ["authentik.tar.gz"]="ghcr.io/goauthentik/server:2026.8.5"
)

for filename in "${!EXPORTS[@]}"; do
    image="${EXPORTS[$filename]}"
    filepath="$IMAGES_DIR/$filename"

    if [ -f "$filepath" ]; then
        echo -e "  ${BLUE}[EXISTANT]${NC} $filepath déjà présent, ignoré."
        continue
    fi

    echo -e "  ${BLUE}[EXPORT]${NC} $image -> $filename ..."
    docker save "$image" | gzip > "$filepath"
    SIZE=$(du -h "$filepath" | cut -f1)
    echo -e "  ${GREEN}[OK]${NC} $filename créé ($SIZE)."
done

echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "  ${GREEN}✓ Pack hors-ligne généré dans $IMAGES_DIR${NC}"
echo -e "  Copiez tout le dossier 'offline-demo/' sur une clé USB ou disque externe."
echo -e "  Sur la machine cible : exécutez '${BOLD}offline-demo/load-images.sh${NC}'"
echo -e "${BLUE}==============================================================================${NC}"
