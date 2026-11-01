#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE DÉMARRAGE AUTONOME & HORS-LIGNE — MESSAGERIE SOUVERAINE BF
# Démarre l'ensemble des composants dans le bon ordre sans appel externe.
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
echo -e "${BLUE}  DÉMARRAGE DE LA MESSAGERIE SOUVERAINE BF (MODE AUTONOME HORS-LIGNE)         ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Date : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Racine du projet : $PROJECT_ROOT"
echo "Répertoire Authentik détecté : $AUTH_DIR (compose: $(basename "$AUTH_COMPOSE_FILE"))"
echo ""

# 1. Vérification Docker et Docker Compose
echo -e "${BOLD}[1/10] Vérification du moteur Docker...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "  ${RED}[ERREUR] Le démon Docker n'est pas actif ou inaccessible.${NC}"
    exit 1
fi
echo -e "  ${GREEN}[OK] Moteur Docker opérationnel.${NC}"

# 2. Vérification de la présence des images Docker requises (Hors-Ligne)
echo -e "\n${BOLD}[2/10] Contrôle des images Docker locales (aucun téléchargement externe)...${NC}"
REQUIRED_IMAGES=(
    "postgres:16-alpine"
    "matrixdotorg/synapse:v1.164.1"
    "vectorim/element-web:v1.11.109"
    "nginx:1.27-alpine"
    "ghcr.io/goauthentik/server:2026.8.5"
)

MISSING_IMAGES=0
for img in "${REQUIRED_IMAGES[@]}"; do
    if docker image inspect "$img" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${NC} Image présente : $img"
    else
        echo -e "  ${RED}[MANQUANTE]${NC} Image absente du cache local : $img"
        MISSING_IMAGES=$((MISSING_IMAGES + 1))
    fi
done

if [ $MISSING_IMAGES -gt 0 ]; then
    echo -e "  ${RED}[ERREUR] Des images requises sont absentes.${NC}"
    echo -e "  Veuillez exécuter '${YELLOW}./offline-demo/load-images.sh${NC}' pour charger le pack hors-ligne."
    exit 1
fi

# 3. Vérification des fichiers d'environnement et de configuration
echo -e "\n${BOLD}[3/10] Vérification des configurations locales...${NC}"
if [ ! -f .env ]; then
    echo -e "  ${RED}[ERREUR] Fichier .env manquant dans $PROJECT_ROOT.${NC}"
    echo "  Veuillez exécuter ./scripts/install.sh pour initialiser l'environnement."
    exit 1
fi

if [ ! -f "$AUTH_DIR/.env" ] || [ ! -f "$AUTH_COMPOSE_FILE" ]; then
    echo -e "  ${RED}[ERREUR] Authentik non initialisé dans $AUTH_DIR.${NC}"
    echo "  Veuillez exécuter ./scripts/install.sh pour initialiser l'environnement."
    exit 1
fi
echo -e "  ${GREEN}[OK] Fichiers d'environnement confirmés.${NC}"

# 4. Création du réseau Docker partagé (Bridge)
echo -e "\n${BOLD}[4/10] Vérification du réseau Docker partagé msb-auth-bridge...${NC}"
if ! docker network inspect msb-auth-bridge >/dev/null 2>&1; then
    echo "  -> Création du réseau partagé 'msb-auth-bridge'..."
    docker network create msb-auth-bridge
    echo -e "  ${GREEN}[OK] Réseau msb-auth-bridge créé.${NC}"
else
    echo -e "  ${GREEN}[OK] Réseau msb-auth-bridge déjà existant.${NC}"
fi

# 5. Contrôle des certificats TLS locaux
echo -e "\n${BOLD}[5/10] Contrôle des certificats TLS locaux...${NC}"
if [ ! -f certs/messagerie.local+3.pem ] || [ ! -f certs/messagerie.local+3-key.pem ]; then
    echo "  -> Génération des certificats TLS locaux..."
    bash scripts/generate_certs.sh
else
    echo -e "  ${GREEN}[OK] Certificats TLS présents dans certs/.${NC}"
fi

# 6. Démarrage de la pile Authentik (IdP Souverain)
echo -e "\n${BOLD}[6/10] Démarrage de la pile Authentik (SSO / OIDC)...${NC}"
(cd "$AUTH_DIR" && docker compose -f "$AUTH_COMPOSE_FILE" up -d)

echo "  -> Attente de l'état sain d'Authentik..."
MAX_WAIT=90
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    SRV_STATUS=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' authentik-server-1 2>/dev/null || echo "none")
    if [ "$SRV_STATUS" = "healthy" ]; then
        echo -e "  ${GREEN}[OK] Authentik Server est opérationnel et sain.${NC}"
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    echo -n "."
done
echo ""

# 7. Démarrage de la pile Messagerie Souveraine BF (Synapse, Postgres, Element, Nginx)
echo -e "\n${BOLD}[7/10] Démarrage des conteneurs de la messagerie...${NC}"
docker compose up -d

# 8. Attente de la disponibilité de tous les services
echo -e "\n${BOLD}[8/10] Attente de la stabilisation des services...${NC}"
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    SYN_STATUS=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' msb-synapse 2>/dev/null || echo "none")
    ELE_STATUS=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' msb-element 2>/dev/null || echo "none")
    if [ "$SYN_STATUS" = "healthy" ] && [ "$ELE_STATUS" = "healthy" ]; then
        echo -e "  ${GREEN}[OK] Matrix Synapse et Element Web sont opérationnels et sains.${NC}"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done
echo ""

# 9. Exécution du contrôle de santé
echo -e "\n${BOLD}[9/10] Exécution du contrôle de santé complet...${NC}"
bash "$PROJECT_ROOT/scripts/health_check.sh"

# 10. Affichage des points d'accès pour le jury
echo -e "\n${BOLD}[10/10] ADRESSES D'ACCÈS DU JURY (100% SOUVERAIN & HORS-LIGNE)${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "  💬 ${BOLD}Element Web (Messagerie Sécurisée)${NC} : https://messagerie.local"
echo -e "  🔑 ${BOLD}Portail SSO Authentik (IdP & MFA)${NC} : https://auth.messagerie.local"
echo -e "  🎙️ ${BOLD}Console FasoVoice (Gestion de Crise)${NC} : https://messagerie.local/fasovoice/"
echo -e "  ⚡ ${BOLD}Serveur Matrix Synapse API${NC}       : https://messagerie.local/_matrix/client/versions"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "  ${GREEN}✓ L'application est entièrement active et prête pour la démonstration.${NC}"
echo -e "${BLUE}==============================================================================${NC}"
