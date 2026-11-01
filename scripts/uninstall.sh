#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE DÉSINSTALLATION PRUDENTE — MESSAGERIE SOUVERAINE BF
# Arrête les conteneurs sans JAMAIS supprimer automatiquement les volumes ni données
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${YELLOW}==============================================================================${NC}"
echo -e "${YELLOW}  PROCÉDURE D'ARRÊT & DÉSINSTALLATION — MESSAGERIE SOUVERAINE BF              ${NC}"
echo -e "${YELLOW}==============================================================================${NC}"
echo ""

echo -e "${BOLD}[1/2] Arrêt des conteneurs applicatifs Messagerie Souveraine BF...${NC}"
docker compose down

echo -e "\n${BOLD}[2/2] Arrêt d'Authentik (si déployé via le projet)...${NC}"
if [ -f config/authentik/docker-compose.yml ]; then
    docker compose -f config/authentik/docker-compose.yml down 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}[INFO DE SÉCURITÉ CONCERNANT LES VOLUMES ET DONNÉES PERSISTANTES]${NC}"
echo -e "Les conteneurs sont arrêtés et retirés du réseau."
echo -e "${BOLD}AUCUN volume, AUCUNE base de données ni AUCUN fichier de configuration n'a été supprimé.${NC}"
echo ""
echo "Vos données restent conservées dans :"
echo "  - ./data/synapse/ (Configuration et historique de chiffrement)"
echo "  - ./data/postgres/ (Base de données PostgreSQL)"
echo "  - ./certs/ (Certificats et clés TLS)"
echo "  - ./.env (Secrets et variables d'environnement)"
echo ""
echo "Pour redémarrer ultérieurement l'application en conservant vos données :"
echo "  ./scripts/install.sh"
echo ""
echo "Si et seulement si vous souhaitez effectuer une réinitialisation totale manuelle :"
echo -e "  ${RED}rm -rf data/synapse data/postgres certs .env${NC}"
echo -e "${GREEN}==============================================================================${NC}"
