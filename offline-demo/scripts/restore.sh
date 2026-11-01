#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE RESTAURATION SOUVERAINE CONTRÔLÉE — MESSAGERIE SOUVERAINE BF
# Restaure proprement les bases PostgreSQL (Synapse & Authentik) avec contrôle
# strict des erreurs, sauvegarde préalable de sécurité obligatoire et vérification.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

if [ $# -lt 1 ]; then
    echo -e "${RED}[ERREUR] Usage : $0 <chemin_du_dossier_de_sauvegarde> [OPTIONS]${NC}"
    echo "Options :"
    echo "  --yes | -y                   Confirmation non-interactive"
    echo "  --only-synapse               Restaurer uniquement la base Synapse"
    echo "  --only-authentik             Restaurer uniquement la base Authentik"
    echo "  --test-db-synapse=<db>       Nom de la base Synapse cible (défaut: synapse)"
    echo "  --test-db-auth=<db>          Nom de la base Authentik cible (défaut: authentik)"
    echo "  --safety-dir=<dir>           Emplacement de la sauvegarde pré-restauration"
    echo ""
    echo "Exemple : $0 ~/backups_msb/backup_20261101_161059"
    exit 1
fi

BACKUP_DIR="$1"
shift || true

CONFIRM="no"
RESTORE_SYNAPSE="yes"
RESTORE_AUTHENTIK="yes"
TARGET_SYNAPSE_DB="synapse"
TARGET_AUTH_DB="authentik"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SAFETY_DIR="${HOME}/backups_msb/safety_pre_restore_${TIMESTAMP}"

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y)
            CONFIRM="yes"
            ;;
        --only-synapse)
            RESTORE_SYNAPSE="yes"
            RESTORE_AUTHENTIK="no"
            ;;
        --only-authentik)
            RESTORE_SYNAPSE="no"
            RESTORE_AUTHENTIK="yes"
            ;;
        --test-db-synapse=*)
            TARGET_SYNAPSE_DB="${1#*=}"
            ;;
        --test-db-auth=*)
            TARGET_AUTH_DB="${1#*=}"
            ;;
        --safety-dir=*)
            SAFETY_DIR="${1#*=}"
            ;;
        *)
            echo -e "${YELLOW}[AVERTISSEMENT] Option inconnue ignorée : $1${NC}"
            ;;
    esac
    shift
done

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}[ERREUR] Le dossier de sauvegarde $BACKUP_DIR n'existe pas.${NC}"
    exit 1
fi

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  RESTAURATION SOUVERAINE CONTRÔLÉE — MESSAGERIE SOUVERAINE BF                ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Dossier source        : $BACKUP_DIR"
echo "Composants cibles     : Synapse ($RESTORE_SYNAPSE) | Authentik ($RESTORE_AUTHENTIK)"
echo "Cible Synapse         : Base '$TARGET_SYNAPSE_DB' sur msb-postgres"
echo "Cible Authentik       : Base '$TARGET_AUTH_DB' sur authentik-postgresql-1"
echo "Dossier sécurité auto : $SAFETY_DIR"
echo ""

# Vérification de sécurité et confirmation explicite
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}==============================================================================${NC}"
    echo -e "${YELLOW}  ATTENTION : OPÉRATION DE RESTAURATION DE BASE DE DONNÉES                     ${NC}"
    echo -e "${YELLOW}  Les schémas actuels des bases cibles seront réinitialisés et remplacés.    ${NC}"
    echo -e "${YELLOW}  Une sauvegarde réflexe sera automatiquement créée dans :                    ${NC}"
    echo -e "${YELLOW}  $SAFETY_DIR                                                                 ${NC}"
    echo -e "${YELLOW}==============================================================================${NC}"
    read -r -p "Confirmez-vous la restauration ? Tapez 'OUI' en majuscules pour continuer : " choice
    if [ "$choice" != "OUI" ]; then
        echo -e "${BLUE}[ANNULÉ] Restauration interrompue par l'administrateur.${NC}"
        exit 0
    fi
fi

# Préparation du répertoire persistant et sécurisé pour la sauvegarde réflexe
mkdir -p "$SAFETY_DIR"
chmod 700 "$SAFETY_DIR"

# ==============================================================================
# 1. RESTAURATION SYNAPSE
# ==============================================================================
if [ "$RESTORE_SYNAPSE" = "yes" ]; then
    if [ -f "$BACKUP_DIR/synapse_db.sql.gz" ]; then
        echo -e "\n${BOLD}[1/2] Restauration contrôlée de Synapse (base: $TARGET_SYNAPSE_DB)...${NC}"
        if ! docker ps --format '{{.Names}}' | grep -q '^msb-postgres$'; then
            echo -e "  ${RED}[ERREUR] Le conteneur msb-postgres n'est pas actif.${NC}"
            exit 1
        fi

        # Sauvegarde réflexe préalable de sécurité obligatoire
        echo "  -> [SÉCURITÉ] Création de la sauvegarde réflexe pré-restauration..."
        SAFETY_SYN_FILE="$SAFETY_DIR/safety_synapse_${TARGET_SYNAPSE_DB}.sql.gz"
        if ! docker exec msb-postgres pg_dump -U synapse -d "$TARGET_SYNAPSE_DB" 2>/dev/null | gzip > "$SAFETY_SYN_FILE"; then
            echo -e "  ${RED}[ÉCHEC CRITIQUE] Impossible de créer la sauvegarde de sécurité de '$TARGET_SYNAPSE_DB'.${NC}"
            echo -e "  ${RED}-> Restauration ANNULÉE immédiatement pour protéger les données.${NC}"
            exit 1
        fi

        # Contrôle de validité de l'archive de sécurité
        if [ ! -s "$SAFETY_SYN_FILE" ] || ! gzip -t "$SAFETY_SYN_FILE" 2>/dev/null; then
            echo -e "  ${RED}[ÉCHEC CRITIQUE] L'archive de sécurité Synapse est vide ou corrompue.${NC}"
            echo -e "  ${RED}-> Restauration ANNULÉE immédiatement.${NC}"
            exit 1
        fi
        chmod 600 "$SAFETY_SYN_FILE"
        echo -e "  ${GREEN}[OK]${NC} Sauvegarde réflexe Synapse validée ($(du -h "$SAFETY_SYN_FILE" | cut -f1))."

        # Nettoyage contrôlé du schéma public
        echo "  -> Nettoyage préalable du schéma public sur '$TARGET_SYNAPSE_DB'..."
        docker exec -i msb-postgres psql -U synapse -d "$TARGET_SYNAPSE_DB" -v ON_ERROR_STOP=1 \
            -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO synapse;" >/dev/null

        # Décompression et réinjection
        echo "  -> Décompression et réinjection des données..."
        gunzip -c "$BACKUP_DIR/synapse_db.sql.gz" | \
            docker exec -i msb-postgres psql -U synapse -d "$TARGET_SYNAPSE_DB" -v ON_ERROR_STOP=1 >/dev/null

        # Contrôle d'intégrité post-restauration
        USER_COUNT=$(docker exec msb-postgres psql -U synapse -d "$TARGET_SYNAPSE_DB" -tAc "SELECT count(*) FROM users WHERE deactivated = 0;")
        ROOM_COUNT=$(docker exec msb-postgres psql -U synapse -d "$TARGET_SYNAPSE_DB" -tAc "SELECT count(*) FROM rooms;")

        if [ "$USER_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}[OK]${NC} Base Synapse restaurée et validée :"
            echo -e "       - Utilisateurs actifs : ${BOLD}$USER_COUNT${NC}"
            echo -e "       - Salons existants    : ${BOLD}$ROOM_COUNT${NC}"
        else
            echo -e "  ${RED}[ÉCHEC CRITIQUE]${NC} Aucune donnée utilisateur valide après restauration Synapse."
            exit 1
        fi
    else
        echo -e "\n${YELLOW}[INFO] synapse_db.sql.gz absent de $BACKUP_DIR, étape Synapse ignorée.${NC}"
    fi
else
    echo -e "\n${BLUE}[IGNORÉ] Étape Synapse désactivée (--only-authentik).${NC}"
fi

# ==============================================================================
# 2. RESTAURATION AUTHENTIK
# ==============================================================================
if [ "$RESTORE_AUTHENTIK" = "yes" ]; then
    if [ -f "$BACKUP_DIR/authentik_db.sql.gz" ]; then
        echo -e "\n${BOLD}[2/2] Restauration contrôlée d'Authentik (base: $TARGET_AUTH_DB)...${NC}"
        if ! docker ps --format '{{.Names}}' | grep -q '^authentik-postgresql-1$'; then
            echo -e "  ${RED}[ERREUR] Le conteneur authentik-postgresql-1 n'est pas actif.${NC}"
            exit 1
        fi

        # Sauvegarde réflexe préalable de sécurité obligatoire
        echo "  -> [SÉCURITÉ] Création de la sauvegarde réflexe pré-restauration..."
        SAFETY_AUTH_FILE="$SAFETY_DIR/safety_authentik_${TARGET_AUTH_DB}.sql.gz"
        if ! docker exec authentik-postgresql-1 pg_dump -U authentik -d "$TARGET_AUTH_DB" 2>/dev/null | gzip > "$SAFETY_AUTH_FILE"; then
            echo -e "  ${RED}[ÉCHEC CRITIQUE] Impossible de créer la sauvegarde de sécurité de '$TARGET_AUTH_DB'.${NC}"
            echo -e "  ${RED}-> Restauration ANNULÉE immédiatement pour protéger les données.${NC}"
            exit 1
        fi

        # Contrôle de validité de l'archive de sécurité
        if [ ! -s "$SAFETY_AUTH_FILE" ] || ! gzip -t "$SAFETY_AUTH_FILE" 2>/dev/null; then
            echo -e "  ${RED}[ÉCHEC CRITIQUE] L'archive de sécurité Authentik est vide ou corrompue.${NC}"
            echo -e "  ${RED}-> Restauration ANNULÉE immédiatement.${NC}"
            exit 1
        fi
        chmod 600 "$SAFETY_AUTH_FILE"
        echo -e "  ${GREEN}[OK]${NC} Sauvegarde réflexe Authentik validée ($(du -h "$SAFETY_AUTH_FILE" | cut -f1))."

        # Nettoyage contrôlé du schéma public
        echo "  -> Nettoyage préalable du schéma public sur '$TARGET_AUTH_DB'..."
        docker exec -i authentik-postgresql-1 psql -U authentik -d "$TARGET_AUTH_DB" -v ON_ERROR_STOP=1 \
            -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO authentik;" >/dev/null

        # Décompression et réinjection
        echo "  -> Décompression et réinjection des données Authentik..."
        gunzip -c "$BACKUP_DIR/authentik_db.sql.gz" | \
            docker exec -i authentik-postgresql-1 psql -U authentik -d "$TARGET_AUTH_DB" -v ON_ERROR_STOP=1 >/dev/null

        # Contrôle d'intégrité post-restauration
        AUTH_USER_COUNT=$(docker exec authentik-postgresql-1 psql -U authentik -d "$TARGET_AUTH_DB" -tAc "SELECT count(*) FROM authentik_core_user;")

        if [ "$AUTH_USER_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}[OK]${NC} Base Authentik restaurée et validée :"
            echo -e "       - Comptes utilisateurs : ${BOLD}$AUTH_USER_COUNT${NC}"
        else
            echo -e "  ${RED}[ÉCHEC CRITIQUE]${NC} Aucun compte utilisateur Authentik trouvé après restauration."
            exit 1
        fi
    else
        echo -e "\n${YELLOW}[INFO] authentik_db.sql.gz absent de $BACKUP_DIR, étape Authentik ignorée.${NC}"
    fi
else
    echo -e "\n${BLUE}[IGNORÉ] Étape Authentik désactivée (--only-synapse).${NC}"
fi

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "  ${GREEN}✓ Restauration terminée avec succès et intégrité vérifiée.${NC}"
echo -e "  Sauvegarde de sécurité conservée dans : ${BOLD}$SAFETY_DIR${NC}"
echo -e "  Conseil : Redémarrez les conteneurs applicatifs avec '${BOLD}./scripts/start.sh${NC}'."
echo -e "${BLUE}==============================================================================${NC}"
