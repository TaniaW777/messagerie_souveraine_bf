#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE GÉNÉRATION DES CERTIFICATS TLS — MESSAGERIE SOUVERAINE BF
# Supporte mkcert (si disponible) ou fallback autonome OpenSSL (avec Root CA locale)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="${PROJECT_ROOT}/certs"

mkdir -p "$CERTS_DIR"

echo "=== Génération des certificats TLS pour Messagerie Souveraine BF ==="
echo "Dossier cible : $CERTS_DIR"

DOMAINS=("messagerie.local" "auth.messagerie.local" "localhost" "127.0.0.1")

# Vérifier si des certificats valides existent déjà
if [ -f "$CERTS_DIR/messagerie.local+3.pem" ] && [ -f "$CERTS_DIR/messagerie.local+3-key.pem" ] && [ -f "$CERTS_DIR/ca-bundle.crt" ]; then
    echo "[INFO] Certificats existants détectés dans $CERTS_DIR."
    # Assurer les liens symboliques et permissions
    ln -sf "messagerie.local+3.pem" "$CERTS_DIR/server.crt" 2>/dev/null || true
    ln -sf "messagerie.local+3-key.pem" "$CERTS_DIR/server.key" 2>/dev/null || true
    chmod 600 "$CERTS_DIR"/*key*.pem "$CERTS_DIR"/*.key 2>/dev/null || true
    chmod 644 "$CERTS_DIR"/*.crt "$CERTS_DIR"/*.pem 2>/dev/null || true
    echo "[OK] Certificats existants validés."
    exit 0
fi

if command -v mkcert >/dev/null 2>&1; then
    echo "[INFO] mkcert détecté. Génération via mkcert..."
    mkcert -install
    CAROOT=$(mkcert -CAROOT)
    mkcert -cert-file "$CERTS_DIR/messagerie.local+3.pem" \
           -key-file "$CERTS_DIR/messagerie.local+3-key.pem" \
           "${DOMAINS[@]}"
    
    # Création du ca-bundle pour Synapse
    if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        cat "$CAROOT/rootCA.pem" /etc/ssl/certs/ca-certificates.crt > "$CERTS_DIR/ca-bundle.crt"
    else
        cp "$CAROOT/rootCA.pem" "$CERTS_DIR/ca-bundle.crt"
    fi
else
    echo "[INFO] mkcert absent. Génération autonome via OpenSSL (PKI locale de démo)..."
    
    ROOT_KEY="$CERTS_DIR/localRootCA.key"
    ROOT_CRT="$CERTS_DIR/localRootCA.crt"
    SERVER_KEY="$CERTS_DIR/messagerie.local+3-key.pem"
    SERVER_CSR="$CERTS_DIR/server.csr"
    SERVER_CRT="$CERTS_DIR/messagerie.local+3.pem"
    EXT_FILE="$CERTS_DIR/san.ext"

    # 1. Génération de l'Autorité Racine Locale
    if [ ! -f "$ROOT_KEY" ]; then
        openssl req -x509 -new -nodes -newkey rsa:4096 \
            -keyout "$ROOT_KEY" -out "$ROOT_CRT" -days 365 \
            -subj "/C=BF/O=Gouvernement Burkina Faso/OU=Messagerie Souveraine/CN=Messagerie Souveraine Root CA"
    fi

    # 2. Génération de la clé privée serveur et CSR
    openssl req -new -nodes -newkey rsa:2048 \
        -keyout "$SERVER_KEY" -out "$SERVER_CSR" \
        -subj "/C=BF/O=Gouvernement Burkina Faso/OU=Messagerie Souveraine/CN=messagerie.local"

    # 3. Fichier d'extension SAN (Subject Alternative Names)
    cat <<EOF > "$EXT_FILE"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = messagerie.local
DNS.2 = auth.messagerie.local
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

    # 4. Signature du certificat serveur par la Root CA locale
    openssl x509 -req -in "$SERVER_CSR" -CA "$ROOT_CRT" -CAkey "$ROOT_KEY" \
        -CAcreateserial -out "$SERVER_CRT" -days 365 -sha256 -extfile "$EXT_FILE"

    rm -f "$SERVER_CSR" "$EXT_FILE"

    # 5. Création du bundle CA (incluant la Root CA locale pour Synapse OIDC Discovery)
    if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        cat "$ROOT_CRT" /etc/ssl/certs/ca-certificates.crt > "$CERTS_DIR/ca-bundle.crt"
    else
        cp "$ROOT_CRT" "$CERTS_DIR/ca-bundle.crt"
    fi
fi

# Liens symboliques standard
ln -sf "messagerie.local+3.pem" "$CERTS_DIR/server.crt" 2>/dev/null || true
ln -sf "messagerie.local+3-key.pem" "$CERTS_DIR/server.key" 2>/dev/null || true

# Permissions restrictives
chmod 600 "$CERTS_DIR"/*.key "$CERTS_DIR"/*-key.pem 2>/dev/null || true
chmod 644 "$CERTS_DIR"/*.crt "$CERTS_DIR"/*.pem 2>/dev/null || true

echo "[OK] Certificats TLS et CA bundle générés avec succès dans $CERTS_DIR"
