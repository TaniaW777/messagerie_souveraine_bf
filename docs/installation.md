# Guide d'installation — Messagerie Souveraine BF

## Prérequis

- Docker Engine ≥ 24 et Docker Compose v2 (plugin)
- 7,5 Go de RAM (Synapse + PostgreSQL + Element + Authentik)
- Ports disponibles : **8008** (Synapse) et **8081** (Element)
- Git, Python 3 (pour la génération de secrets)

> **Authentik** est installé séparément dans `~/authentik` et tourne
> sur les ports 9000 (HTTP) et 9443 (HTTPS).
> Ne pas lancer tous les services simultanément si la RAM est limitée.

---

## 1. Récupérer le projet

```bash
git clone https://github.com/TaniaW777/messagerie_souveraine_bf.git
cd messagerie_souveraine_bf
git checkout develop
```

---

## 2. Configurer le fichier `.env`

```bash
cp .env.example .env
```

Éditer `.env` et remplacer **chaque** valeur `CHANGE_ME` :

| Variable | Description | Comment générer |
|---|---|---|
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | 20 caractères aléatoires |
| `SYNAPSE_REGISTRATION_SHARED_SECRET` | Secret d'enregistrement | `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` |
| `SYNAPSE_MACAROON_SECRET_KEY` | Clé des tokens | Même commande |
| `SYNAPSE_FORM_SECRET` | Secret des formulaires | Même commande |
| `AUTHENTIK_OIDC_CLIENT_ID` | ID client OIDC | Depuis Authentik (étape 5) |
| `AUTHENTIK_OIDC_CLIENT_SECRET` | Secret client OIDC | Depuis Authentik (étape 5) |

> ⚠️ Le fichier `.env` est ignoré par Git. Ne jamais le committer.

---

## 3. Résolution DNS locale

Ajouter dans `/etc/hosts` (Linux/macOS) :

```
127.0.0.1   messagerie.local
127.0.0.1   auth.messagerie.local
```

---

## 4. Créer les dossiers de données

```bash
mkdir -p data/synapse data/postgres
```

---

## 5. Générer la configuration Synapse (première fois uniquement)

```bash
docker run --rm \
  -v "$(pwd)/data/synapse:/data" \
  -e SYNAPSE_SERVER_NAME=messagerie.local \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:v1.164.1 generate
```

Trois fichiers apparaissent dans `data/synapse/` :
- `homeserver.yaml` (configuration principale — **contient des secrets**)
- `messagerie.local.log.config`
- `messagerie.local.signing.key` (**clé de signature — ne jamais partager**)

---

## 6. Adapter `data/synapse/homeserver.yaml`

Le fichier généré utilise SQLite par défaut. Remplacer le bloc `database:` :

```yaml
database:
  name: psycopg2
  args:
    user: synapse
    password: VOTRE_POSTGRES_PASSWORD_DU_DOT_ENV
    database: synapse
    host: db
    port: 5432
    cp_min: 5
    cp_max: 10
```

S'assurer également que :
```yaml
enable_registration: false
x_forwarded: false    # false sans proxy nginx
report_stats: false
```

Le modèle complet est dans `config/synapse/homeserver.yaml.example`.

---

## 7. Démarrer les services

```bash
docker compose up -d
```

Vérifier l'état :
```bash
docker compose ps
```

Les trois services (`msb-postgres`, `msb-synapse`, `msb-element`)
doivent être **Up** et **healthy** après 30-60 secondes.

---

## 8. Créer les comptes

```bash
# Compte administrateur
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u admin -a \
  http://localhost:8008

# Comptes utilisateurs
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u alice --no-admin \
  http://localhost:8008
```

---

## 9. Vérification de l'installation

```bash
# API Synapse
curl http://localhost:8008/_matrix/client/versions

# Tables PostgreSQL
docker exec msb-postgres psql -U synapse -d synapse -c "\dt"

# Interface Element
# Ouvrir http://localhost:8081 dans le navigateur
```

---

## Intégration OIDC / Authentik (configuration avancée)

> Cette section décrit la configuration à réaliser **après** que
> l'installation de base est validée.

### Prérequis OIDC

L'intégration OIDC nécessite :
1. Un certificat TLS valide (ou auto-signé ajouté à la chaîne de confiance)
2. Authentik accessible en HTTPS depuis le réseau Docker
3. Un nom de domaine résolu entre les conteneurs

### Configurer Authentik

1. Se connecter à `http://localhost:9000`
2. Aller dans **Applications** → **Fournisseurs** → **Créer**
3. Choisir **OAuth2/OIDC**
4. Paramètres :
   - **Nom** : `Synapse`
   - **Type d'autorisation** : Authorization Code
   - **Redirect URI** : `https://messagerie.local/_synapse/client/oidc/callback`
   - **Scopes** : `openid`, `profile`, `email`
5. Créer l'**application** associée au fournisseur
6. Copier le **Client ID** et le **Client Secret** dans `.env`

### Activer OIDC dans Synapse

Dans `data/synapse/homeserver.yaml`, décommenter et compléter :

```yaml
oidc_providers:
  - idp_id: authentik
    idp_name: "Authentik"
    discover: true
    issuer: "https://auth.messagerie.local/application/o/synapse/"
    client_id: "VOTRE_CLIENT_ID"
    client_secret: "VOTRE_CLIENT_SECRET"
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        localpart_template: "{{ user.preferred_username }}"
        display_name_template: "{{ user.name }}"
    allow_existing_users: true
    backchannel_logout_enabled: true
```

> ⚠️ **Ne jamais committer le client_secret dans Git.**

### Problème de résolution réseau

Authentik tourne dans son propre réseau Docker (`~/authentik`).
Synapse tourne dans le réseau `msb-public`.

Options pour permettre la communication :
- **Option A (recommandée)** : Connecter les deux compositions au même
  réseau Docker externe nommé.
- **Option B** : Utiliser l'IP hôte (`host-gateway`) dans `extra_hosts`.

Option A (à valider avant déploiement) :
```bash
# Créer un réseau partagé
docker network create msb-auth-bridge

# Connecter Authentik au réseau partagé
docker network connect msb-auth-bridge authentik-server-1

# Ajouter au docker-compose.yml de Synapse
# networks: msb-auth-bridge (réseau externe)
```

---

## Arrêt

```bash
docker compose down          # Arrêt (données conservées)
```

> ⚠️ Ne jamais utiliser `docker compose down -v` : cela supprimerait
> les volumes et les données de base de données.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Synapse redémarre en boucle | Mot de passe différent entre `.env` et `homeserver.yaml` | Vérifier les deux fichiers |
| `pg_isready` échoue | PostgreSQL en cours de démarrage | Attendre 20 secondes, relancer |
| Element ne trouve pas Synapse | URL incorrecte dans `config.json` | Vérifier `base_url` |
| Erreur OIDC | Certificat TLS non reconnu | Ajouter le cert à la chaîne de confiance Synapse |
| Permission denied sur docker.sock | Utilisateur pas dans le groupe docker | `sudo usermod -aG docker $USER` puis se reconnecter |
