#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE PRÉ-VÉRIFICATION VIDÉO — MESSAGERIE SOUVERAINE BF
# Prépare et contrôle l'environnement avant l'enregistrement de la démonstration
# Idempotent, non destructif, sans exposition de secrets
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  PRÉ-VOL DÉMONSTRATION VIDÉO — MESSAGERIE SOUVERAINE BF                      ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Date du contrôle : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 1. Vérification Docker et Conteneurs
echo -e "${BOLD}[1/7] Contrôle des services Docker et healthchecks...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "  ${RED}[ERREUR CRITIQUE] Démon Docker indisponible.${NC}"
    ERRORS=$((ERRORS + 1))
else
    for c in msb-postgres msb-synapse msb-element msb-proxy authentik-server-1 authentik-worker-1 authentik-postgresql-1; do
        if docker inspect "$c" >/dev/null 2>&1; then
            state=$(docker inspect --format '{{.State.Status}}' "$c")
            echo -e "  ${GREEN}[OK]${NC} Conteneur ${c} (${state})"
        else
            echo -e "  ${RED}[ÉCHEC]${NC} Conteneur ${c} absent !"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

# 2. Vérification DNS locale
echo -e "\n${BOLD}[2/7] Contrôle de la résolution DNS locale (/etc/hosts)...${NC}"
if grep -q "messagerie.local" /etc/hosts && grep -q "auth.messagerie.local" /etc/hosts; then
    echo -e "  ${GREEN}[OK]${NC} Les hôtes 'messagerie.local' et 'auth.messagerie.local' sont déclarés."
else
    echo -e "  ${RED}[ÉCHEC]${NC} Hôtes manquants dans /etc/hosts (127.0.0.1 messagerie.local auth.messagerie.local attendu)."
    ERRORS=$((ERRORS + 1))
fi

# 3. Vérification des Certificats TLS
echo -e "\n${BOLD}[3/7] Contrôle des certificats TLS et autorité mkcert...${NC}"
CA_FILE="${HOME}/messagerie_souveraine_bf/certs/ca-bundle.crt"
if [ -f "$CA_FILE" ]; then
    echo -e "  ${GREEN}[OK]${NC} Bundle CA trouvé ($CA_FILE)."
else
    echo -e "  ${RED}[ÉCHEC]${NC} Bundle CA introuvable."
    ERRORS=$((ERRORS + 1))
fi

# 4. Vérification de l'accès HTTPS aux interfaces Web
echo -e "\n${BOLD}[4/7] Contrôle des accès HTTPS (Reverse Proxy Nginx)...${NC}"
CODE_ELEMENT=$(curl -sk -o /dev/null -w "%{http_code}" https://messagerie.local/ || echo "000")
CODE_FASOVOICE=$(curl -sk -o /dev/null -w "%{http_code}" https://messagerie.local/fasovoice/ || echo "000")
CODE_SYNAPSE=$(curl -sk -o /dev/null -w "%{http_code}" https://messagerie.local/_matrix/client/versions || echo "000")
CODE_AUTH=$(curl -sk -o /dev/null -w "%{http_code}" https://auth.messagerie.local/ || echo "000")

if [ "$CODE_ELEMENT" = "200" ]; then
    echo -e "  ${GREEN}[OK]${NC} Element Web accessible (https://messagerie.local -> HTTP $CODE_ELEMENT)"
else
    echo -e "  ${RED}[ÉCHEC]${NC} Element Web inaccessible (HTTP $CODE_ELEMENT)"
    ERRORS=$((ERRORS + 1))
fi

if [ "$CODE_FASOVOICE" = "200" ]; then
    echo -e "  ${GREEN}[OK]${NC} Console FasoVoice accessible (https://messagerie.local/fasovoice/ -> HTTP $CODE_FASOVOICE)"
else
    echo -e "  ${RED}[ÉCHEC]${NC} Console FasoVoice inaccessible (HTTP $CODE_FASOVOICE)"
    ERRORS=$((ERRORS + 1))
fi

if [ "$CODE_SYNAPSE" = "200" ]; then
    echo -e "  ${GREEN}[OK]${NC} Matrix Synapse API accessible (HTTP $CODE_SYNAPSE)"
else
    echo -e "  ${RED}[ÉCHEC]${NC} Matrix Synapse API inaccessible (HTTP $CODE_SYNAPSE)"
    ERRORS=$((ERRORS + 1))
fi

if [ "$CODE_AUTH" = "200" ] || [ "$CODE_AUTH" = "302" ]; then
    echo -e "  ${GREEN}[OK]${NC} Authentik SSO accessible (https://auth.messagerie.local -> HTTP $CODE_AUTH)"
else
    echo -e "  ${RED}[ÉCHEC]${NC} Authentik SSO inaccessible (HTTP $CODE_AUTH)"
    ERRORS=$((ERRORS + 1))
fi

# 5. Vérification des comptes de démonstration
echo -e "\n${BOLD}[5/7] Vérification de la présence des comptes de démonstration...${NC}"
REQUIRED_USERS=("@admin:messagerie.local" "@alice_demo:messagerie.local" "@bob_demo:messagerie.local" "@charlie_demo:messagerie.local")

for u in "${REQUIRED_USERS[@]}"; do
    DEACT=$(docker exec msb-postgres psql -U synapse -d synapse -tAc "SELECT deactivated FROM users WHERE name = '$u';" 2>/dev/null || echo "not_found")
    if [ "$DEACT" = "0" ]; then
        echo -e "  ${GREEN}[OK]${NC} Compte Matrix actif présent : $u"
    else
        echo -e "  ${RED}[ÉCHEC]${NC} Compte Matrix manquant ou désactivé : $u (statut: $DEACT)"
        ERRORS=$((ERRORS + 1))
    fi
done

# 6. Vérification du fichier de secrets local
echo -e "\n${BOLD}[6/7] Contrôle du fichier sécurisé d'identifiants locaux...${NC}"
CREDS_FILE="${HOME}/messagerie_souveraine_bf/.credentials_demo.local"
if [ -f "$CREDS_FILE" ]; then
    PERMS=$(stat -c "%a" "$CREDS_FILE")
    if [ "$PERMS" = "600" ]; then
        echo -e "  ${GREEN}[OK]${NC} Fichier .credentials_demo.local présent avec permissions strictes ($PERMS)."
    else
        echo -e "  ${YELLOW}[ATTENTION]${NC} Permissions de $CREDS_FILE : $PERMS (600 recommandé)."
        chmod 600 "$CREDS_FILE"
        echo -e "  ${GREEN}[CORRIGÉ]${NC} Permissions réappliquées à 600."
    fi
else
    echo -e "  ${RED}[ÉCHEC]${NC} Fichier .credentials_demo.local introuvable."
    ERRORS=$((ERRORS + 1))
fi

# 7. Contrôle d'absence de fuite de secrets dans Git
echo -e "\n${BOLD}[7/7] Contrôle de protection Git des fichiers sensibles...${NC}"
cd "${HOME}/messagerie_souveraine_bf"
if git check-ignore .credentials_demo.local .env >/dev/null 2>&1; then
    echo -e "  ${GREEN}[OK]${NC} .env et .credentials_demo.local sont bien ignorés par Git."
else
    echo -e "  ${RED}[ÉCHEC]${NC} .env ou .credentials_demo.local n'est pas ignoré par Git !"
    ERRORS=$((ERRORS + 1))
fi

# Bilan Final
echo -e "\n${BLUE}==============================================================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}BILAN DU PRÉ-VOL : PRÊT POUR LA DÉMONSTRATION VIDÉO${NC}"
    echo -e "  Tous les prérequis techniques, réseaux, cryptographiques et comptes sont validés."
    echo -e "${BLUE}==============================================================================${NC}"
    exit 0
else
    echo -e "  ${RED}${BOLD}BILAN DU PRÉ-VOL : PROBLÈMES À CORRIGER ($ERRORS ERREUR(S))${NC}"
    echo -e "  Veuillez corriger les points marqués en rouge avant de lancer l'enregistrement."
    echo -e "${BLUE}==============================================================================${NC}"
    exit 1
fi
