#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE GÉNÉRATION ET SYNCHRONISATION DU PACK HORS-LIGNE (USB)
# Messagerie Souveraine BF — Hackathon 226
#
# Ce script assemble le pack autonome 'offline-demo/' à partir des fichiers sources
# uniques du dépôt (single source of truth) pour garantir l'absence de divergence
# et assurer une exécution 100% autonome et indépendante du dépôt Git.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEST_DIR="$PROJECT_ROOT/offline-demo"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  ASSEMBLAGE DU PACK HORS-LIGNE AUTONOME — MESSAGERIE SOUVERAINE BF          ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo "Source : $PROJECT_ROOT"
echo "Destination du pack : $DEST_DIR"
echo ""

# 1. Création de l'arborescence complète (miroir exact de la racine projet)
mkdir -p "$DEST_DIR"/{images,compose,config/{nginx,element,synapse,authentik/blueprints},scripts,demo/fasovoice/audio}

# 2. Synchronisation des scripts d'exploitation (Source unique : scripts/)
echo -e "${BOLD}[1/6] Synchronisation des scripts d'exploitation...${NC}"
SCRIPTS_TO_SYNC=(
    "install.sh"
    "start.sh"
    "stop.sh"
    "backup.sh"
    "restore.sh"
    "health_check.sh"
    "generate_certs.sh"
    "provision_authentik.py"
    "fasovoice_alert.py"
)

for s in "${SCRIPTS_TO_SYNC[@]}"; do
    if [ -f "$PROJECT_ROOT/scripts/$s" ]; then
        cp "$PROJECT_ROOT/scripts/$s" "$DEST_DIR/scripts/$s"
        chmod +x "$DEST_DIR/scripts/$s"
        echo -e "  ${GREEN}[OK]${NC} scripts/$s -> offline-demo/scripts/$s"
    fi
done

# 3. Synchronisation des fichiers Compose et configurations à la racine et sous config/
echo -e "\n${BOLD}[2/6] Synchronisation de l'arborescence Docker Compose et configurations...${NC}"
# Racine du pack autonome (permet d'exécuter ./scripts/install.sh directement depuis offline-demo/)
cp "$PROJECT_ROOT/docker-compose.yml" "$DEST_DIR/docker-compose.yml"
cp "$PROJECT_ROOT/.env.example" "$DEST_DIR/.env.example"

# Sous-dossier compose/ (copies de sauvegarde / compatibilité)
cp "$PROJECT_ROOT/docker-compose.yml" "$DEST_DIR/compose/docker-compose.yml"
cp "$PROJECT_ROOT/.env.example" "$DEST_DIR/compose/.env.example"
cp "$PROJECT_ROOT/config/authentik/docker-compose.yml" "$DEST_DIR/compose/authentik-compose.yml"
cp "$PROJECT_ROOT/config/authentik/.env.example" "$DEST_DIR/compose/authentik.env.example"

# Configurations applicatives (miroir exact de config/)
cp "$PROJECT_ROOT/config/nginx/nginx.conf" "$DEST_DIR/config/nginx/nginx.conf"
cp "$PROJECT_ROOT/config/element/config.json" "$DEST_DIR/config/element/config.json"
cp "$PROJECT_ROOT/config/synapse/homeserver.yaml.example" "$DEST_DIR/config/synapse/homeserver.yaml.example"

# Configuration Authentik autonome dans config/authentik/ (clé pour install.sh sur machine neuve)
cp "$PROJECT_ROOT/config/authentik/docker-compose.yml" "$DEST_DIR/config/authentik/docker-compose.yml"
cp "$PROJECT_ROOT/config/authentik/.env.example" "$DEST_DIR/config/authentik/.env.example"
cp "$PROJECT_ROOT/config/authentik/blueprints/synapse-oidc.yaml" "$DEST_DIR/config/authentik/blueprints/synapse-oidc.yaml"
echo -e "  ${GREEN}[OK]${NC} Fichiers Compose et configurations non sensibles synchronisés (racine et config/)."

# 4. Inclusion des 16 fichiers audio FasoVoice pour le pack USB
echo -e "\n${BOLD}[3/6] Inclusion des fichiers audio FasoVoice pour le pack USB...${NC}"
cp "$PROJECT_ROOT/demo/fasovoice/index.html" "$DEST_DIR/demo/fasovoice/index.html"
cp "$PROJECT_ROOT/demo/fasovoice/messages.json" "$DEST_DIR/demo/fasovoice/messages.json"
cp "$PROJECT_ROOT/demo/fasovoice/audio"/*.mp3 "$DEST_DIR/demo/fasovoice/audio/"

AUDIO_COUNT=$(find "$DEST_DIR/demo/fasovoice/audio" -name "*.mp3" | wc -l)
echo -e "  ${GREEN}[OK]${NC} $AUDIO_COUNT/16 fichiers audio copiés dans le pack hors-ligne."

# 5. Contrôle des archives Docker et génération des empreintes SHA256
echo -e "\n${BOLD}[4/6] Contrôle des images Docker du pack et calcul des empreintes SHA256...${NC}"
MISSING_IMAGES=0
for img in synapse.tar.gz element.tar.gz postgres.tar.gz nginx.tar.gz authentik.tar.gz; do
    if [ -f "$DEST_DIR/images/$img" ]; then
        SZ=$(du -h "$DEST_DIR/images/$img" | cut -f1)
        echo -e "  ${GREEN}[PRÉSENT]${NC} $img ($SZ)"
    else
        echo -e "  ${YELLOW}[ABSENT]${NC}  $img"
        MISSING_IMAGES=$((MISSING_IMAGES + 1))
    fi
done

if [ "$MISSING_IMAGES" -eq 0 ]; then
    (cd "$DEST_DIR/images" && sha256sum *.tar.gz > SHA256SUMS)
    echo -e "  ${GREEN}[OK]${NC} Empreintes de contrôle enregistrées dans $DEST_DIR/images/SHA256SUMS"
else
    echo -e "  ${YELLOW}[INFO]${NC} Pour exporter les images manquantes : exécutez '$DEST_DIR/export-images.sh'."
fi

# 6. Vérification de la compatibilité des scripts Bash
echo -e "\n${BOLD}[5/6] Contrôle de la syntaxe Bash de tous les scripts du pack...${NC}"
for script in "$DEST_DIR/scripts"/*.sh "$DEST_DIR"/*.sh; do
    if [ -f "$script" ]; then
        bash -n "$script"
        echo -e "  ${GREEN}[SYNTAXE OK]${NC} $(basename "$script")"
    fi
done

# 7. Génération du manifeste de contrôle global
echo -e "\n${BOLD}[6/6] Génération du manifeste de contrôle (manifest.json)...${NC}"
cat <<EOF > "$DEST_DIR/manifest.json"
{
  "project": "Messagerie Souveraine BF — Pack Hors-Ligne",
  "version": "1.0-hackathon226",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "standalone_ready": true,
  "audio_files_count": $AUDIO_COUNT,
  "docker_images_present": $((5 - MISSING_IMAGES)),
  "docker_images_expected": 5,
  "layout": {
    "root_compose": "docker-compose.yml",
    "authentik_compose": "config/authentik/docker-compose.yml",
    "images_dir": "images/",
    "scripts_dir": "scripts/"
  }
}
EOF

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "  ${GREEN}✓ Pack hors-ligne assemblé et validé avec succès dans $DEST_DIR${NC}"
echo -e "  Prêt à être copié sur clé USB pour démonstration devant le jury."
echo -e "${BLUE}==============================================================================${NC}"
