#!/usr/bin/env bash
# ==============================================================================
# CHARGEMENT DES IMAGES DOCKER — PACK HORS-LIGNE MESSAGERIE SOUVERAINE BF
# Ce script charge toutes les images Docker depuis les archives locales.
# Aucune connexion Internet requise.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  CHARGEMENT DES IMAGES DOCKER HORS-LIGNE — MESSAGERIE SOUVERAINE BF          ${NC}"
echo -e "${BLUE}==============================================================================${NC}"

IMAGES=(
    "synapse.tar.gz|matrixdotorg/synapse:v1.164.1"
    "element.tar.gz|vectorim/element-web:v1.11.109"
    "postgres.tar.gz|postgres:16-alpine"
    "nginx.tar.gz|nginx:1.27-alpine"
    "authentik.tar.gz|ghcr.io/goauthentik/server:2026.8.5"
)

LOADED=0
SKIPPED=0
ERRORS=0

for entry in "${IMAGES[@]}"; do
    filename="${entry%%|*}"
    image="${entry##*|}"
    filepath="$IMAGES_DIR/$filename"

    if docker image inspect "$image" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[IGNORÉ]${NC} $image déjà présent dans le cache Docker local."
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ ! -f "$filepath" ]; then
        echo -e "  ${RED}[MANQUANT]${NC} Fichier introuvable : $filepath"
        echo "  -> Générez le pack hors-ligne sur la machine source avec :"
        echo "     offline-demo/export-images.sh"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    echo -e "  ${BLUE}[CHARGEMENT]${NC} Chargement de $image depuis $filename..."
    gunzip -c "$filepath" | docker load
    echo -e "  ${GREEN}[OK]${NC} $image chargé avec succès."
    LOADED=$((LOADED + 1))
done

echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "  Résultat : ${GREEN}$LOADED chargé(s)${NC} | ${YELLOW}$SKIPPED ignoré(s)${NC} | ${RED}$ERRORS erreur(s)${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}✓ Toutes les images sont prêtes. Lancez : ./scripts/start.sh${NC}"
else
    echo -e "  ${RED}Des images sont manquantes. Consultez les instructions ci-dessus.${NC}"
fi
echo -e "${BLUE}==============================================================================${NC}"
