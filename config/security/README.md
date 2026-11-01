# Sécurité des configurations — Messagerie Souveraine BF

Ce répertoire contient la documentation des règles de configuration
sécurisée pour les services du projet.

---

## Règles de sécurité par service

### Synapse

| Paramètre | Valeur requise | Raison |
|-----------|---------------|--------|
| `enable_registration` | `false` | Pas d'inscription publique |
| `x_forwarded` | `false` (sans proxy) | Évite l'usurpation IP |
| `bind_addresses` | `['0.0.0.0']` (conteneur) | Accès hôte limité via `ports:` |
| Mot de passe DB | Variable `.env` | Ne jamais hardcoder |
| Secrets | Valeurs aléatoires 64+ chars | Sécurité des tokens |

### PostgreSQL

| Paramètre | Valeur requise | Raison |
|-----------|---------------|--------|
| Réseau | `msb-internal` uniquement | Isolation réseau |
| Port exposé | Aucun | Pas d'accès externe |
| `POSTGRES_INITDB_ARGS` | `--encoding=UTF8 --lc-collate=C` | Compatibilité Synapse |

### Docker

| Pratique | Raison |
|----------|--------|
| Images épinglées (pas `latest`) | Reproductibilité, pas de surprise |
| `ports: 127.0.0.1:PORT:PORT` | Écoute locale seulement |
| Réseaux séparés internal/public | Isolation PostgreSQL |
| Healthchecks configurés | Démarrage ordonné fiable |

---

## Fichiers à ne jamais committer

```
.env
data/synapse/homeserver.yaml
data/synapse/*.signing.key
data/postgres/
*.pem
*.key
*.crt
```

## Fichiers sûrs à committer (exemples uniquement)

```
.env.example
config/synapse/homeserver.yaml.example
config/element/config.json
```

---

## Procédure de génération des secrets

```bash
# Un secret par ligne de commande (ne pas réutiliser)
python3 -c "import secrets; print(secrets.token_urlsafe(64))"

# Permissions du .env
chmod 600 .env
```

---

## Vérification avant commit

```bash
# Vérifier que .env n'est pas tracké
git status .env

# Scanner pour des patterns de secrets
git diff --cached | grep -E "(password|secret|key)\s*[:=]\s*[^CHANGE]"
```
