#!/usr/bin/env bash
# ==============================================================================
# SCRIPT D'INSTALLATION & INITIALISATION COMPLÈTE — MESSAGERIE SOUVERAINE BF
# Déploiement reproductible et autonome pour machine neuve (Hackathon 226)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\133[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  INSTALLATION AUTOMATISÉE — MESSAGERIE SOUVERAINE BF                        ${NC}"
echo -e "${BLUE}  Hackathon 226 — Prototype Souverain de Messagerie Sécurisée                 ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Date de lancement : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Répertoire racine : $PROJECT_ROOT"
echo ""

# 1. Vérification des dépendances système
echo -e "${BOLD}[1/8] Contrôle des dépendances système...${NC}"

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${NC} Commande '$1' détectée ($(command -v "$1"))."
    else
        echo -e "  ${RED}[ERREUR]${NC} Commande obligatoire '$1' introuvable. Veuillez l'installer."
        exit 1
    fi
}

check_cmd docker
check_cmd openssl
check_cmd python3

if ! docker compose version >/dev/null 2>&1; then
    echo -e "  ${RED}[ERREUR]${NC} Le plugin Docker Compose v2 n'est pas disponible."
    exit 1
else
    echo -e "  ${GREEN}[OK]${NC} Docker Compose v2 disponible ($(docker compose version --short))."
fi

# Vérification des images Docker requises pour le mode hors-ligne
echo "  -> Contrôle de l'autonomie hors-ligne des images Docker..."
REQUIRED_IMAGES=("postgres:16-alpine" "matrixdotorg/synapse:v1.164.1" "vectorim/element-web:v1.11.109" "nginx:1.27-alpine" "ghcr.io/goauthentik/server:2026.8.5" "msb-sentinel-bf:1.0")
for img in "${REQUIRED_IMAGES[@]}"; do
    if ! docker image inspect "$img" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[INFO]${NC} Image '$img' non trouvée localement."
        if [ -f "offline-demo/load-images.sh" ]; then
            echo "  -> Chargement automatique depuis le pack hors-ligne 'offline-demo'..."
            bash offline-demo/load-images.sh
            break
        fi
    fi
done

# 2. Préparation des variables d'environnement (.env)
echo -e "\n${BOLD}[2/8] Configuration des variables d'environnement (.env)...${NC}"
if [ ! -f .env ]; then
    echo "  -> Création de .env à partir de .env.example..."
    cp .env.example .env
    
    # Génération automatique de secrets aléatoires sécurisés
    PG_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
    REG_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
    MAC_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
    FORM_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
    
    sed -i "s/CHANGE_ME_mot_de_passe_postgresql_long_et_aleatoire/$PG_PASS/g" .env
    sed -i "s/CHANGE_ME_secret_registration_aleatoire_64_caracteres/$REG_SECRET/g" .env
    sed -i "s/CHANGE_ME_secret_macaroon_aleatoire_64_caracteres/$MAC_SECRET/g" .env
    sed -i "s/CHANGE_ME_secret_form_aleatoire_64_caracteres/$FORM_SECRET/g" .env
    chmod 600 .env
    echo -e "  ${GREEN}[OK]${NC} Fichier .env initialisé avec des secrets cryptographiques générés localement."
else
    echo -e "  ${GREEN}[OK]${NC} Fichier .env existant détecté."
    chmod 600 .env 2>/dev/null || true
fi

# 3. Création des répertoires de données persistantes
echo -e "\n${BOLD}[3/8] Création des volumes de données et certificats...${NC}"
mkdir -p data/synapse data/postgres certs demo/fasovoice
chmod 700 data/synapse data/postgres 2>/dev/null || true
echo -e "  ${GREEN}[OK]${NC} Dossiers de persistance vérifiés."

# 4. Création des réseaux Docker
echo -e "\n${BOLD}[4/8] Initialisation du réseau partagé inter-projets (msb-auth-bridge)...${NC}"
if ! docker network inspect msb-auth-bridge >/dev/null 2>&1; then
    docker network create msb-auth-bridge
    echo -e "  ${GREEN}[OK]${NC} Réseau Docker 'msb-auth-bridge' créé avec succès."
else
    echo -e "  ${GREEN}[OK]${NC} Réseau Docker 'msb-auth-bridge' déjà présent."
fi

# 5. Génération des certificats TLS
echo -e "\n${BOLD}[5/8] Génération et validation des certificats TLS (HTTPS)...${NC}"
./scripts/generate_certs.sh

# Détection cohérente de l'emplacement et du fichier Compose d'Authentik
if [ -n "${AUTHENTIK_DIR:-}" ] && [ -d "$AUTHENTIK_DIR" ]; then
    AUTH_DIR="$AUTHENTIK_DIR"
elif [ -d "$HOME/authentik" ] && [ -f "$HOME/authentik/compose.yml" ]; then
    AUTH_DIR="$HOME/authentik"
elif [ -d "$PROJECT_ROOT/config/authentik" ] && [ -f "$PROJECT_ROOT/config/authentik/docker-compose.yml" ]; then
    AUTH_DIR="$PROJECT_ROOT/config/authentik"
else
    AUTH_DIR="$PROJECT_ROOT/config/authentik"
fi

if [ -f "$AUTH_DIR/compose.yml" ]; then
    AUTH_COMPOSE_FILE="$AUTH_DIR/compose.yml"
elif [ -f "$AUTH_DIR/docker-compose.yml" ]; then
    AUTH_COMPOSE_FILE="$AUTH_DIR/docker-compose.yml"
else
    AUTH_COMPOSE_FILE="$AUTH_DIR/docker-compose.yml"
fi

# 6. Démarrage et initialisation d'Authentik (IdP OIDC)
echo -e "\n${BOLD}[6/8] Démarrage du gestionnaire d'identité Authentik ($AUTH_DIR)...${NC}"
if docker inspect authentik-server-1 >/dev/null 2>&1; then
    echo "  -> Conteneur Authentik existant détecté. Vérification de l'état..."
    if [ "$(docker inspect --format '{{.State.Status}}' authentik-server-1)" != "running" ]; then
        docker compose -f "$AUTH_COMPOSE_FILE" up -d
    fi
else
    echo "  -> Initialisation d'Authentik depuis $AUTH_DIR..."
    if [ ! -f "$AUTH_DIR/.env" ]; then
        if [ -f "$AUTH_DIR/.env.example" ]; then
            cp "$AUTH_DIR/.env.example" "$AUTH_DIR/.env"
        else
            cp config/authentik/.env.example "$AUTH_DIR/.env"
        fi
        AUTH_PG_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
        AUTH_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
        sed -i "s/CHANGE_ME_authentik_postgres_password_24_chars/$AUTH_PG_PASS/g" "$AUTH_DIR/.env"
        sed -i "s/CHANGE_ME_authentik_secret_key_64_chars/$AUTH_KEY/g" "$AUTH_DIR/.env"
        chmod 600 "$AUTH_DIR/.env"
    fi
    docker compose -f "$AUTH_COMPOSE_FILE" up -d
fi

# Attente de disponibilité d'Authentik
echo "  -> Attente de l'état nominal d'Authentik (jusqu'à 60s)..."
for i in {1..30}; do
    if docker inspect authentik-server-1 >/dev/null 2>&1 && \
       [ "$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}' authentik-server-1 2>/dev/null)" = "healthy" ]; then
        echo -e "  ${GREEN}[OK]${NC} Authentik est opérationnel et sain."
        break
    fi
    sleep 2
done

# Provisionnement des applications et comptes de démo dans Authentik
echo "  -> Provisionnement reproductible du provider OIDC Synapse..."
docker cp scripts/provision_authentik.py authentik-server-1:/tmp/provision_authentik.py 2>/dev/null || true
docker exec authentik-server-1 python3 /tmp/provision_authentik.py 2>/dev/null || true

# 7. Démarrage de la pile Messagerie Souveraine BF (PostgreSQL, Synapse, Element, Nginx)
echo -e "\n${BOLD}[7/8] Démarrage des conteneurs applicatifs (docker compose up -d)...${NC}"

# Configuration Synapse initiale si absente
if [ ! -f data/synapse/homeserver.yaml ]; then
    echo "  -> Première exécution : initialisation de la configuration Synapse..."
    cp config/synapse/homeserver.yaml.example data/synapse/homeserver.yaml
    PG_PASS=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)
    sed -i "s/CHANGE_ME_mot_de_passe_postgresql_long_et_aleatoire/$PG_PASS/g" data/synapse/homeserver.yaml
    # Génération d'une clé de signature si absente
    docker run --rm -v "$(pwd)/data/synapse:/data" \
        -e SYNAPSE_SERVER_NAME=messagerie.local \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:v1.164.1 generate 2>/dev/null || true
fi

docker compose up -d

echo "  -> Attente de la convergence des sondes de santé..."
sleep 5

# 8. Contrôle de santé global
echo -e "\n${BOLD}[8/8] Exécution du contrôle de santé de l'infrastructure...${NC}"
./scripts/health_check.sh

echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}  INSTALLATION RÉUSSIE AVEC SUCCÈS !                                          ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "  Points d'accès locaux sécurisés :"
echo -e "    - Element Web :     ${BOLD}https://messagerie.local${NC} (Port 443)"
echo -e "    - Console FasoVoice: ${BOLD}https://messagerie.local/fasovoice/${NC}"
echo -e "    - Authentik SSO :    ${BOLD}https://auth.messagerie.local${NC} (Port 443 / 9000)"
echo -e "    - Matrix API :       ${BOLD}https://messagerie.local/_matrix/client/versions${NC}"
echo ""
echo -e "  Comptes de démonstration pré-configurés :"
echo -e "    - Alice Demo :      @alice_demo:messagerie.local (OIDC + TOTP)"
echo -e "    - Bob Demo :        @bob_demo:messagerie.local (OIDC + TOTP)"
echo -e "    - Charlie Demo :    @charlie_demo:messagerie.local (OIDC + TOTP)"
echo -e "    - Admin Secours :   @admin:messagerie.local (Authentification locale)"
echo ""
echo -e "  Note DNS locale (/etc/hosts) :"
echo -e "    Assurez-vous que la ligne suivante figure dans /etc/hosts :"
echo -e "    ${BOLD}127.0.0.1 messagerie.local auth.messagerie.local${NC}"
echo -e "${BLUE}==============================================================================${NC}"
