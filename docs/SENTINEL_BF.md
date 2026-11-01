# SENTINEL BF — Documentation de Sécurité

## Présentation

**SENTINEL BF** est le module de cybersécurité intégré à Messagerie Souveraine BF.
Il détecte en temps réel les comportements d'authentification suspects et notifie
les administrateurs via un salon Matrix privé dédié.

## Architecture

```
Authentik PostgreSQL ──[poll 10s]──► Sentinel BF ──► Matrix (salon alertes)
                                          │
                                     Webhook HTTP
                                     (POST /api/v1/event)
                                     [Authentik → Sentinel]
```

### Composants

| Composant | Rôle |
|-----------|------|
| `sentinel.py` | Daemon principal Python |
| `sentinel/Dockerfile` | Image Docker Alpine Python 3.11 |
| `data/sentinel/sentinel.db` | Base SQLite locale (alertes, état) |
| `data/sentinel/sentinel.log` | Journal d'exécution |

### Réseaux Docker utilisés

| Réseau | Raison |
|--------|--------|
| `authentik_default` | Accès en lecture à `authentik-postgresql-1` |
| `msb-auth-bridge` | Accès à Synapse pour les notifications Matrix |

## Règles de Détection

### Règle 1 — Brute Force
- **Déclencheur :** ≥ 5 échecs de connexion (`login_failed`) en 5 minutes depuis la même IP
- **Gravité :** ÉLEVÉE
- **Cooldown anti-doublon :** 10 minutes

### Règle 2 — Password Spraying
- **Déclencheur :** 1 IP ciblant ≥ 3 comptes distincts en 10 minutes
- **Gravité :** CRITIQUE
- **Cooldown anti-doublon :** 10 minutes

### Règle 3 — Compromission Probable
- **Déclencheur :** Connexion réussie (`login`) après ≥ 3 échecs sur le même compte
- **Gravité :** ALERTE
- **Cooldown anti-doublon :** 10 minutes

## Format des Alertes Matrix

```
🚨 SENTINEL BF — ALERTE DE SÉCURITÉ

Type : Tentatives répétées (Brute Force)
Compte ciblé : utilisateur@messagerie.local
IP source : 192.168.1.15
Tentatives : 7
Gravité : ÉLEVÉE

Détails : 7 échecs en 5 min depuis 192.168.1.15

Action recommandée : Vérification de l'activité en cours.
```

## Ingestion des Événements

### Méthode principale : Polling PostgreSQL (automatique)
Sentinel interroge directement la table `authentik_events_event` de la base Authentik
toutes les 10 secondes. Aucune configuration Authentik supplémentaire n'est requise.

### Méthode secondaire : Webhook HTTP (optionnel)
```
POST http://sentinel:8088/api/v1/event
Authorization: Bearer <SENTINEL_WEBHOOK_SECRET>
Content-Type: application/json

{
  "action": "login_failed",
  "client_ip": "1.2.3.4",
  "username": "alice"
}
```

## Variables d'Environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `AUTHENTIK_PG_HOST` | `authentik-postgresql-1` | Hôte PostgreSQL Authentik |
| `AUTHENTIK_PG_USER` | `authentik` | Utilisateur PostgreSQL |
| `AUTHENTIK_PG_PASS` | *requis* | Mot de passe PostgreSQL |
| `AUTHENTIK_PG_DB` | `authentik` | Base de données |
| `SYNAPSE_URL` | `http://synapse:8008` | URL interne de Synapse |
| `SYNAPSE_REGISTRATION_SHARED_SECRET` | *requis* | Secret partagé Synapse |
| `SENTINEL_MATRIX_PASSWORD` | *requis* | Mot de passe `@sentinel_bf` |
| `SENTINEL_WEBHOOK_SECRET` | *requis* | Secret d'auth webhook |
| `BRUTE_FORCE_THRESHOLD` | `5` | Seuil brute force |
| `BRUTE_FORCE_WINDOW` | `300` | Fenêtre brute force (secondes) |
| `SPRAY_ACCOUNTS` | `3` | Seuil password spray |
| `SPRAY_WINDOW` | `600` | Fenêtre spray (secondes) |
| `POST_FAIL_THRESHOLD` | `3` | Seuil compromission |
| `ALERT_COOLDOWN` | `600` | Cooldown anti-doublon (secondes) |
| `POLL_INTERVAL_SEC` | `10` | Intervalle de polling |

## Compte Matrix Technique

- **Identifiant :** `@sentinel_bf:messagerie.local`
- **Salon d'alertes :** `#sentinel-alertes:messagerie.local`
- **Membres invités :** `@admin:messagerie.local`, `@alice_demo:messagerie.local`
- Le compte est créé automatiquement au premier démarrage via le `SYNAPSE_REGISTRATION_SHARED_SECRET`
- Les identifiants ne sont jamais stockés dans le code ou le dépôt Git

## Sécurité

- ✅ Service non exposé sur l'hôte (port 8088 interne uniquement)
- ✅ Webhook protégé par `Authorization: Bearer` avec comparaison HMAC
- ✅ Connexion PostgreSQL en lecture seule des événements
- ✅ Aucun secret dans le code source
- ✅ Utilisateur non-root dans le conteneur (`sentinel`)
- ✅ Déduplication des alertes (cooldown configurable)
- ✅ Pas de blocage automatique des comptes

## Démarrage

```bash
# Premier démarrage (build inclus)
docker compose up --build -d sentinel

# Vérifier le statut
docker ps | grep sentinel
docker logs msb-sentinel --tail 50

# Exécuter les tests d'intégration
python3 tests/test_sentinel_bf.py

# Voir les alertes enregistrées
sqlite3 data/sentinel/sentinel.db "SELECT * FROM alerts ORDER BY id DESC LIMIT 10;"
```

## Tests

Le fichier `tests/test_sentinel_bf.py` couvre les 6 cas obligatoires :

| # | Test | Méthode |
|---|------|---------|
| 1 | Connexion normale → aucune alerte | Webhook POST |
| 2 | 5 échecs même IP → Brute Force | Webhook POST ×5 |
| 3 | Succès après 3 échecs → Compromission | Webhook POST ×4 |
| 4 | 1 IP, 3 comptes → Password Spray | Webhook POST ×6 |
| 5 | Webhook sans auth → HTTP 401 | Webhook sans token |
| 6 | Alerte Matrix reçue | API Matrix |

## Limites et Points d'Attention

- Les alertes en mémoire sont réinitialisées au redémarrage du conteneur
  (les alertes enregistrées en SQLite sont persistantes)
- La détection ne couvre que les authentifications Authentik
  (pas les connexions directes Synapse avec `m.login.password`)
- Pas de blocage automatique des comptes (décision humaine requise)
