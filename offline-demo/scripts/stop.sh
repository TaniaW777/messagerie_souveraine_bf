#!/usr/bin/env bash
# ==============================================================================
# SCRIPT D'ARRÊT SÉCURISÉ — MESSAGERIE SOUVERAINE BF
# Arrête les services proprement sans suppression de volumes ni perte de données.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Détection cohérente de l'emplacement et du fichier Compose d'Authentik
if [ -n "${AUTHENTIK_DIR:-}" ] && [ -d "$AUTHENTIK_DIR" ]; then
    AUTH_DIR="$AUTHENTIK_DIR"
elif [ -d "$HOME/authentik" ] && [ -f "$HOME/authentik/compose.yml" ]; then
    AUTH_DIR="$HOME/authentik"
elif [ -d "$PROJECT_ROOT/config/authentik" ] && [ -f "$PROJECT_ROOT/config/authentik/docker-compose.yml" ]; then
    AUTH_DIR="$PROJECT_ROOT/config/authentik"
else
    AUTH_DIR="$HOME/authentik"
fi

if [ -f "$AUTH_DIR/compose.yml" ]; then
    AUTH_COMPOSE_FILE="$AUTH_DIR/compose.yml"
elif [ -f "$AUTH_DIR/docker-compose.yml" ]; then
    AUTH_COMPOSE_FILE="$AUTH_DIR/docker-compose.yml"
else
    AUTH_COMPOSE_FILE="$AUTH_DIR/compose.yml"
fi

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  ARRÊT SÉCURISÉ DES SERVICES — MESSAGERIE SOUVERAINE BF                      ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Garantie : AUCUN volume ni aucune donnée de base n'est supprimé."
echo ""

# 1. Arrêt de la pile principale (Element, Synapse, Nginx, Postgres)
echo -e "${BOLD}[1/2] Arrêt ordonné des conteneurs de messagerie (Synapse/Element/Nginx)...${NC}"
docker compose down

echo -e "  ${GREEN}[OK] Pile principale arrêtée.${NC}"

# 2. Arrêt de la pile Authentik
if [ -d "$AUTH_DIR" ] && [ -f "$AUTH_COMPOSE_FILE" ]; then
    echo -e "\n${BOLD}[2/2] Arrêt ordonné des conteneurs Authentik ($AUTH_DIR)...${NC}"
    (cd "$AUTH_DIR" && docker compose -f "$AUTH_COMPOSE_FILE" down)
    echo -e "  ${GREEN}[OK] Pile Authentik arrêtée.${NC}"
else
    echo -e "\n[2/2] Configuration Authentik non détectée dans $AUTH_DIR, ignoré."
fi

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "  ${GREEN}✓ Tous les conteneurs sont arrêtés en toute sécurité.${NC}"
echo -e "  ${GREEN}✓ Les données PostgreSQL, Synapse et Authentik sont intactes.${NC}"
echo -e "${BLUE}==============================================================================${NC}"
