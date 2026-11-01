# Messagerie Souveraine BF

**Prototype de messagerie instantanée souveraine pour l'administration publique du Burkina Faso.**

Basée sur Matrix (Synapse + Element Web), avec chiffrement de bout en bout et authentification forte via Authentik, déployable avec Docker Compose.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UTILISATEUR                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP (local)
                    ┌──────▼──────┐
                    │ Element Web │  http://localhost:8081
                    │  (port 80)  │
                    └──────┬──────┘
                           │ Matrix Client API
                    ┌──────▼──────┐
                    │   Synapse   │  http://localhost:8008
                    │  (port 8008)│
                    └──────┬──────┘
             ┌─────────────┼─────────────┐
             │             │             │
    ┌────────▼──────┐  ┌───▼────┐  ┌────▼────────┐
    │  PostgreSQL   │  │Authentik│  │  Olm/Megolm │
    │  (interne)    │  │(OIDC)  │  │ (E2EE natif)│
    └───────────────┘  └────────┘  └─────────────┘
                        port 9000
                        (existant)
```

## Technologies

| Composant | Version | Rôle |
|-----------|---------|------|
| Matrix Synapse | 1.164.1 | Serveur de messagerie |
| Element Web | 1.11.109 | Interface utilisateur |
| PostgreSQL | 16-alpine | Base de données |
| Authentik | 2026.8.5 | Authentification centralisée + MFA TOTP |
| Docker Compose | v2 | Orchestration |

## Fonctionnalités

| Fonctionnalité | État |
|----------------|------|
| Messagerie avec chiffrement E2EE (Olm/Megolm) | ✅ Disponible |
| Inscriptions publiques désactivées | ✅ Configuré |
| Création de comptes par l'administrateur | ✅ Opérationnel (testé) |
| Désactivation d'un compte | ✅ Testé (API Synapse) |
| MFA TOTP via Authentik | ✅ Testé (Authentik seul) |
| Intégration OIDC Authentik → Synapse | 🔶 Configuré, non testé |
| Révocation d'appareil/session | ⏳ Scénario préparé |

## Prérequis

- Docker Engine ≥ 24 + Docker Compose v2
- RAM disponible : ~4 Go minimum (Synapse + PostgreSQL + Element)
- Ports libres : 8008, 8081
- Git

> **Note RAM** : Authentik (installé séparément) consomme ~2-3 Go.
> Ne pas lancer tous les services simultanément si la RAM < 7,5 Go.

## Installation

### 1. Cloner le projet

```bash
git clone https://github.com/TaniaW777/messagerie_souveraine_bf.git
cd messagerie_souveraine_bf
git checkout develop
```

### 2. Configurer l'environnement

```bash
cp .env.example .env
```

Éditer `.env` et remplacer **toutes** les valeurs `CHANGE_ME` par des valeurs sécurisées.

Pour générer des secrets aléatoires :
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

### 3. Créer les dossiers de données

```bash
mkdir -p data/synapse data/postgres
```

### 4. Générer la configuration Synapse (première fois uniquement)

```bash
docker run --rm \
  -v "$(pwd)/data/synapse:/data" \
  -e SYNAPSE_SERVER_NAME=messagerie.local \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:v1.164.1 generate
```

Cela crée `data/synapse/homeserver.yaml`, `messagerie.local.log.config` et `messagerie.local.signing.key`.

### 5. Configurer Synapse

Copier le modèle comme référence et adapter `data/synapse/homeserver.yaml` :

```bash
# Vérifier la configuration de référence
cat config/synapse/homeserver.yaml.example
```

Points clés à vérifier dans `data/synapse/homeserver.yaml` :
- `database` : bloc PostgreSQL avec le mot de passe du `.env`
- `enable_registration: false`
- `x_forwarded: false` (sauf si proxy nginx configuré)

### 6. Résolution DNS locale

Ajouter dans `/etc/hosts` :
```
127.0.0.1   messagerie.local
```

### 7. Démarrer les services

```bash
docker compose up -d
docker compose ps
```

### 8. Créer les comptes

```bash
# Compte administrateur
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u admin -a \
  http://localhost:8008

# Compte utilisateur standard
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u alice --no-admin \
  http://localhost:8008
```

### 9. Vérification

| Vérification | Commande | Résultat attendu |
|---|---|---|
| API Synapse | `curl http://localhost:8008/_matrix/client/versions` | JSON versions Matrix |
| Tables PostgreSQL | `docker exec msb-postgres psql -U synapse -d synapse -c "\dt"` | Liste des tables |
| Interface Element | `http://localhost:8081` | Page "Messagerie Souveraine BF" |

## Administration

### Désactiver un compte

```bash
# Obtenir un token admin (authentification locale)
TOKEN=$(curl -s -X POST http://localhost:8008/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"admin","password":"MOT_DE_PASSE"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Désactiver alice
curl -X POST \
  "http://localhost:8008/_synapse/admin/v1/deactivate/@alice:messagerie.local" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"erase": false}'
```

### Lister les utilisateurs

```bash
curl "http://localhost:8008/_synapse/admin/v2/users?limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

## Sécurité

- Les inscriptions publiques sont désactivées.
- PostgreSQL n'est pas exposé sur l'hôte (réseau interne Docker).
- Synapse et Element n'écoutent que sur `127.0.0.1` (pas `0.0.0.0`).
- Les secrets ne doivent jamais être commités dans Git.
- Voir `docs/security/README.md` pour la politique de sécurité complète.

## Limites connues

1. **Intégration OIDC** : configurée mais non testée (prérequis TLS manquants).
2. **Révocation E2EE** : la révocation ne supprime pas les messages déjà déchiffrés.
3. **Pas de fédération** : désactivée intentionnellement (`default_federate: false`).
4. **HTTPS local** : l'intégration Authentik nécessite un certificat TLS local.

## Structure du projet

```
messagerie_souveraine_bf/
├── docker-compose.yml          # Orchestration des services
├── .env.example                # Modèle de configuration (sans secrets)
├── config/
│   ├── element/config.json     # Configuration Element Web
│   ├── synapse/
│   │   └── homeserver.yaml.example  # Modèle Synapse (sans secrets)
│   └── nginx/                  # Réservé au reverse proxy (futur)
├── data/                       # Données persistantes (gitignored)
│   ├── synapse/                # homeserver.yaml réel, clés, médias
│   └── postgres/               # Données PostgreSQL
├── docs/
│   ├── installation.md         # Guide d'installation détaillé
│   └── security/README.md      # Politique de sécurité
├── tests/
│   ├── mfa/README.md           # Scénarios tests MFA/TOTP
│   ├── e2ee/README.md          # Scénarios tests chiffrement
│   └── revocation/README.md    # Scénarios tests révocation
└── demo/scenario.md            # Scénario de démonstration hackathon
```
