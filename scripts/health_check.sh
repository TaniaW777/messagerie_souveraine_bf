#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE CONTRÔLE DE SANTÉ DE L'INFRASTRUCTURE — MESSAGERIE SOUVERAINE BF
# Idempotent, non destructif, sans exposition de secrets
# ==============================================================================

set -euo pipefail

# Couleurs pour lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  CONTRÔLE DE SANTÉ GLOBAL — MESSAGERIE SOUVERAINE BF                         ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Date d'exécution : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 1. Vérification Docker
echo -e "${BLUE}[1/6] Vérification du démon Docker...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "  ${RED}[ÉCHEC] Le démon Docker n'est pas accessible sans privilèges ou est arrêté.${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "  ${GREEN}[OK] Démon Docker opérationnel.${NC}"
fi

# 2. Vérification de l'état des conteneurs
echo -e "\n${BLUE}[2/6] Contrôle de l'état des conteneurs applicatifs...${NC}"
EXPECTED_CONTAINERS=(
    "msb-postgres:healthy"
    "msb-synapse:healthy"
    "msb-element:healthy"
    "msb-proxy:running"
    "authentik-server-1:healthy"
    "authentik-worker-1:healthy"
    "authentik-postgresql-1:healthy"
)

for entry in "${EXPECTED_CONTAINERS[@]}"; do
    cname="${entry%%:*}"
    expected_status="${entry##*:}"

    if ! docker inspect "$cname" >/dev/null 2>&1; then
        echo -e "  ${RED}[MANQUANT] Conteneur $cname introuvable.${NC}"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    state=$(docker inspect --format '{{.State.Status}}' "$cname" 2>/dev/null || echo "unknown")
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cname" 2>/dev/null || echo "none")

    if [ "$expected_status" = "healthy" ]; then
        if [ "$health" = "healthy" ]; then
            echo -e "  ${GREEN}[OK] $cname : en cours d'exécution et sain ($health).${NC}"
        else
            echo -e "  ${RED}[ÉCHEC] $cname : état '$state', santé '$health' (attendu: healthy).${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        if [ "$state" = "running" ]; then
            echo -e "  ${GREEN}[OK] $cname : en cours d'exécution ($state).${NC}"
        else
            echo -e "  ${RED}[ÉCHEC] $cname : état '$state' (attendu: running).${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# 3. Vérification de la liaison locale stricte des ports (Sécurité)
echo -e "\n${BLUE}[3/6] Contrôle de la sécurisation des ports réseau (Liaison locale 127.0.0.1)...${NC}"
DOCKER_PORTS=$(docker ps --format '{{.Names}}: {{.Ports}}')

if echo "$DOCKER_PORTS" | grep -E "0\.0\.0\.0:(80|443|8008|8081|9000|9443|5432)" >/dev/null; then
    echo -e "  ${RED}[ALERTE SÉCURITÉ] Des ports sont exposés publiquement sur 0.0.0.0 :${NC}"
    echo "$DOCKER_PORTS" | grep -E "0\.0\.0\.0:(80|443|8008|8081|9000|9443|5432)"
    ERRORS=$((ERRORS + 1))
else
    echo -e "  ${GREEN}[OK] Aucun port sensible n'est exposé sur 0.0.0.0 (restreints à 127.0.0.1 ou internes).${NC}"
fi

# 4. Vérification de la base PostgreSQL
echo -e "\n${BLUE}[4/6] Contrôle de la connectivité et persistance PostgreSQL...${NC}"
if docker exec msb-postgres pg_isready -U synapse -d synapse >/dev/null 2>&1; then
    USER_COUNT=$(docker exec msb-postgres psql -U synapse -d synapse -tAc "SELECT count(*) FROM users WHERE deactivated = 0;")
    ROOM_COUNT=$(docker exec msb-postgres psql -U synapse -d synapse -tAc "SELECT count(*) FROM rooms;")
    echo -e "  ${GREEN}[OK] PostgreSQL répond aux requêtes.${NC}"
    echo -e "  ${GREEN}[INFO] Utilisateurs actifs: $USER_COUNT | Salons existants: $ROOM_COUNT${NC}"
else
    echo -e "  ${RED}[ÉCHEC] Impossible d'interroger msb-postgres via pg_isready/psql.${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 5. Vérification des points d'accès HTTP/HTTPS
echo -e "\n${BLUE}[5/6] Contrôle des sondes HTTP / HTTPS...${NC}"

# A. Synapse versions
SYNAPSE_CODE=$(curl -sk -o /dev/null -w "%{http_code}" https://127.0.0.1:443/_matrix/client/versions -H "Host: messagerie.local" || echo "000")
if [ "$SYNAPSE_CODE" = "200" ]; then
    echo -e "  ${GREEN}[OK] Synapse Client API (HTTPS:443) -> HTTP $SYNAPSE_CODE${NC}"
else
    echo -e "  ${RED}[ÉCHEC] Synapse Client API -> HTTP $SYNAPSE_CODE (attendu: 200)${NC}"
    ERRORS=$((ERRORS + 1))
fi

# B. Element Web
ELEMENT_CODE=$(curl -sk -o /dev/null -w "%{http_code}" https://127.0.0.1:443/ -H "Host: messagerie.local" || echo "000")
if [ "$ELEMENT_CODE" = "200" ]; then
    echo -e "  ${GREEN}[OK] Element Web (HTTPS:443) -> HTTP $ELEMENT_CODE${NC}"
else
    echo -e "  ${RED}[ÉCHEC] Element Web -> HTTP $ELEMENT_CODE (attendu: 200)${NC}"
    ERRORS=$((ERRORS + 1))
fi

# C. Authentik SSO
AUTH_CODE=$(curl -sk -o /dev/null -w "%{http_code}" https://127.0.0.1:443/ -H "Host: auth.messagerie.local" || echo "000")
if [ "$AUTH_CODE" = "200" ] || [ "$AUTH_CODE" = "302" ]; then
    echo -e "  ${GREEN}[OK] Authentik Web UI (HTTPS:443) -> HTTP $AUTH_CODE${NC}"
else
    echo -e "  ${RED}[ÉCHEC] Authentik Web UI -> HTTP $AUTH_CODE (attendu: 200 ou 302)${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 6. Bilan Global
echo -e "\n${BLUE}==============================================================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}RÉSULTAT GLOBAL : TOUS LES CONTRÔLES SONT RÉUSSIS (SANTÉ INFRASTRUCTURE OK)${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    exit 0
else
    echo -e "  ${RED}RÉSULTAT GLOBAL : $ERRORS ERREUR(S) DÉTECTÉE(S)${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    exit 1
fi
