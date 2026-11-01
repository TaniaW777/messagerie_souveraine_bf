#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE SAUVEGARDE SOUVERAINE — MESSAGERIE SOUVERAINE BF
# Sauvegarde cohérente des bases PostgreSQL (Synapse & Authentik) et configurations.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$HOME/backups_msb}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TARGET_DIR="$BACKUP_BASE_DIR/backup_$TIMESTAMP"

# Détection cohérente de l'emplacement d'Authentik
if [ -n "${AUTHENTIK_DIR:-}" ] && [ -d "$AUTHENTIK_DIR" ]; then
    AUTH_DIR="$AUTHENTIK_DIR"
elif [ -d "$HOME/authentik" ] && [ -f "$HOME/authentik/compose.yml" ]; then
    AUTH_DIR="$HOME/authentik"
elif [ -d "$PROJECT_ROOT/config/authentik" ]; then
    AUTH_DIR="$PROJECT_ROOT/config/authentik"
else
    AUTH_DIR="$HOME/authentik"
fi

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  SAUVEGARDE SOUVERAINE — MESSAGERIE SOUVERAINE BF                            ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Horodatage : $TIMESTAMP"
echo "Dossier cible : $TARGET_DIR"

mkdir -p "$TARGET_DIR"
chmod 700 "$TARGET_DIR"

# 1. Sauvegarde de la base de données Synapse (PostgreSQL)
echo -e "\n${BOLD}[1/4] Sauvegarde de la base PostgreSQL Synapse (msb-postgres)...${NC}"
if docker ps --format '{{.Names}}' | grep -q '^msb-postgres$'; then
    docker exec msb-postgres pg_dump -U synapse -d synapse | gzip > "$TARGET_DIR/synapse_db.sql.gz"
    SYN_SIZE=$(du -h "$TARGET_DIR/synapse_db.sql.gz" | cut -f1)
    echo -e "  ${GREEN}[OK]${NC} Base Synapse sauvegardée avec succès ($SYN_SIZE)."
else
    echo -e "  ${RED}[ERREUR]${NC} Conteneur msb-postgres non actif."
    exit 1
fi

# 2. Sauvegarde de la base de données Authentik (PostgreSQL)
echo -e "\n${BOLD}[2/4] Sauvegarde de la base PostgreSQL Authentik (authentik-postgresql-1)...${NC}"
if docker ps --format '{{.Names}}' | grep -q '^authentik-postgresql-1$'; then
    docker exec authentik-postgresql-1 pg_dump -U authentik -d authentik | gzip > "$TARGET_DIR/authentik_db.sql.gz"
    AUTH_SIZE=$(du -h "$TARGET_DIR/authentik_db.sql.gz" | cut -f1)
    echo -e "  ${GREEN}[OK]${NC} Base Authentik sauvegardée avec succès ($AUTH_SIZE)."
else
    echo -e "  ${RED}[AVERTISSEMENT]${NC} Conteneur authentik-postgresql-1 non détecté."
fi

# 3. Sauvegarde des configurations non sensibles et des certificats
echo -e "\n${BOLD}[3/4] Sauvegarde des fichiers de configuration et certificats...${NC}"
mkdir -p "$TARGET_DIR/config" "$TARGET_DIR/certs"
cp -r "$PROJECT_ROOT/config" "$TARGET_DIR/"
if [ -d "$PROJECT_ROOT/certs" ]; then
    cp -r "$PROJECT_ROOT/certs" "$TARGET_DIR/"
    chmod 700 "$TARGET_DIR/certs"
fi
echo -e "  ${GREEN}[OK]${NC} Configurations archivées."

# 4. Génération du manifeste de sauvegarde
echo -e "\n${BOLD}[4/4] Génération du manifeste de métadonnées...${NC}"
cat <<EOF > "$TARGET_DIR/manifest.json"
{
  "project": "Messagerie Souveraine BF",
  "timestamp": "$TIMESTAMP",
  "synapse_version": "v1.164.1",
  "authentik_version": "2026.8.5",
  "files": [
    "synapse_db.sql.gz",
    "authentik_db.sql.gz",
    "config/",
    "certs/"
  ]
}
EOF
chmod 600 "$TARGET_DIR/manifest.json"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "  ${GREEN}✓ Sauvegarde souveraine terminée avec succès !${NC}"
echo -e "  Emplacement : ${BOLD}$TARGET_DIR${NC}"
echo -e "${BLUE}==============================================================================${NC}"
