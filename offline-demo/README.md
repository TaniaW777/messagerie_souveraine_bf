# MESSAGERIE SOUVERAINE BF — PACK DE DÉMONSTRATION HORS-LIGNE
## Hackathon 226 — MTDPCE/DGTD Burkina Faso

Ce pack contient tout le nécessaire pour déployer et démontrer **Messagerie Souveraine BF** sur une machine Ubuntu équipée de Docker, **sans aucune connexion Internet**.

---

## Contenu du pack

```
offline-demo/
├── INSTALL.md              ← Ce guide d'installation
├── README.md               ← Ce fichier
├── load-images.sh          ← Chargement des images Docker hors-ligne
├── export-images.sh        ← (Source uniquement) Export des images
├── images/                 ← Archives Docker .tar.gz
│   ├── synapse.tar.gz      - Matrix Synapse v1.164.1
│   ├── element.tar.gz      - Element Web v1.11.109
│   ├── postgres.tar.gz     - PostgreSQL 16-alpine
│   ├── nginx.tar.gz        - Nginx 1.27-alpine
│   └── authentik.tar.gz    - Authentik 2026.8.5
├── compose/
│   ├── docker-compose.yml  - Composition principale (Synapse + Element + Nginx)
│   ├── authentik-compose.yml - Composition Authentik (SSO/OIDC)
│   ├── .env.example        - Variables d'environnement principales
│   └── authentik.env.example - Variables d'environnement Authentik
├── config/
│   ├── nginx/nginx.conf    - Configuration reverse proxy HTTPS
│   ├── element/config.json - Configuration Element Web
│   ├── synapse/homeserver.yaml.example - Configuration Synapse
│   └── authentik/blueprints/synapse-oidc.yaml - Provisionnement OIDC
├── scripts/                ← Scripts de gestion
│   ├── install.sh          - Installation initiale
│   ├── start.sh            - Démarrage autonome hors-ligne
│   ├── stop.sh             - Arrêt sécurisé
│   ├── health_check.sh     - Contrôle de santé
│   ├── backup.sh           - Sauvegarde souveraine
│   ├── generate_certs.sh   - Génération certificats TLS locaux
│   └── provision_authentik.py - Provisionnement comptes de démo
└── demo/fasovoice/
    ├── index.html          - Console de gestion de crise FasoVoice
    ├── messages.json       - Corpus trilingue (FR/Mooré/Dioula)
    └── audio/              - Clips vocaux préenregistrés (MP3, hors-ligne)
        ├── alert-sec-01-fr.mp3
        ├── alert-sec-01-mo.mp3
        ├── alert-sec-01-di.mp3
        ├── alert-sec-01-trilingue.mp3
        └── ... (16 fichiers audio)
```

---

## Démarrage rapide (3 étapes)

```bash
# 1. Charger les images
./load-images.sh

# 2. Installer (1ère fois)
./scripts/install.sh

# 3. Accéder à la messagerie
# https://messagerie.local
```

→ Voir [INSTALL.md](INSTALL.md) pour les instructions détaillées.

---

## Architecture technique

```
[Navigateur Jury]
       |
  [Nginx 1.27] (HTTPS :443 — TLS local)
   /        |              \
[Element] [Synapse]    [FasoVoice]
  Web    Matrix v1.164.1  Console
           |                 
      [PostgreSQL 16]     [Audio MP3]
           |              Hors-ligne
     [Authentik 2026]
      SSO/OIDC/TOTP
```

Tous les composants tournent dans des conteneurs Docker isolés sur une même machine. **Zéro dépendance externe.**

---

## Comptes de démonstration

| Utilisateur | Rôle | Auth |
|-------------|------|------|
| alice_demo | Administratrice de crise | OIDC + TOTP |
| bob_demo | Agent d'intervention | OIDC + TOTP |
| charlie_demo | Observateur | OIDC + TOTP |
| admin | Administrateur secours | Mot de passe local |

---

## Fonctionnalités démontrables hors-ligne

- ✅ Messagerie chiffrée de bout en bout (Megolm / AES-256)
- ✅ Authentification OIDC + TOTP (sans dépendance cloud)
- ✅ Salons privés avec contrôle d'accès
- ✅ Transfert de fichiers chiffrés
- ✅ Rejet des utilisateurs non autorisés
- ✅ Fédération désactivée (souveraineté totale)
- ✅ Console FasoVoice multilingue (FR/Mooré/Dioula)
- ✅ Audio préenregistré — 16 clips vocaux de crise
- ✅ Diffusion d'alertes Matrix + Audio via API souveraine
