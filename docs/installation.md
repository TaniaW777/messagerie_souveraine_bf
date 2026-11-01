# Guide d'Installation Complet — Messagerie Souveraine BF
## Procédure Reproductible pour Déploiement sur Machine Neuve
*Hackathon 226 — Édition 2026 (MTDPCE / DGTD)*

---

## 1. Prérequis Système

| Ressource | Exigence minimale | Recommandé |
|---|---|---|
| **Système d'exploitation** | Linux (Ubuntu 22.04 / 24.04, Debian 12) | Ubuntu 24.04 LTS |
| **Mémoire vive (RAM)** | 4 Go (Messagerie seule) | 8 Go (Messagerie + Authentik) |
| **Espace disque** | 10 Go d'espace libre | 20 Go SSD |
| **Logiciels requis** | Docker Engine ≥ 24, Docker Compose v2, OpenSSL, Python 3, Git | `docker compose version` fonctionnel |
| **Ports libres (hôte)** | 80, 443, 8008, 8081, 9000, 9443 (liés sur `127.0.0.1`) | Aucun conflit sur ces ports |

---

## 2. Configuration Préalable du Système Hôte

### A. Déclaration des noms de domaine locaux (`/etc/hosts`)
Ajouter les domaines de la plateforme dans le fichier `/etc/hosts` de la machine exécutant le navigateur :
```bash
echo "127.0.0.1 messagerie.local auth.messagerie.local" | sudo tee -a /etc/hosts
```

*Vérification :*
```bash
ping -c 1 messagerie.local
ping -c 1 auth.messagerie.local
```

---

## 3. Installation Automatisée en Une Seule Commande

Le projet inclut un script d'installation clé en main idempotent :

```bash
# 1. Cloner le projet et se positionner sur la branche develop
git clone https://github.com/TaniaW777/messagerie_souveraine_bf.git
cd messagerie_souveraine_bf
git checkout develop

# 2. Exécuter le script d'installation
./scripts/install.sh
```

### Ce que réalise automatiquement `scripts/install.sh` :
1. **Contrôle des dépendances :** Vérifie la présence de Docker, Compose v2, OpenSSL et Python 3.
2. **Génération des secrets locaux :** Si le fichier `.env` est absent, il est créé à partir de `.env.example` avec des clés aléatoires sécurisées (PostgreSQL, secrets Synapse). Les permissions sont fixées à `chmod 600`.
3. **Création des volumes persistants :** Prépare `data/synapse/`, `data/postgres/` et `certs/`.
4. **Création du réseau partagé :** Initialise le bridge Docker inter-projets `msb-auth-bridge`.
5. **Génération des certificats TLS :** Exécute `scripts/generate_certs.sh` pour créer la PKI locale avec SAN (`messagerie.local`, `auth.messagerie.local`), les certificats serveurs et le trust bundle CA pour Synapse.
6. **Démarrage d'Authentik :** Lance les conteneurs Authentik et provisionne le provider OIDC Synapse et les comptes de test via `scripts/provision_authentik.py`.
7. **Démarrage de la pile Messagerie :** Lance PostgreSQL, Matrix Synapse, Element Web et le proxy Nginx via `docker compose up -d`.
8. **Contrôle de santé :** Exécute `scripts/health_check.sh` pour vérifier l'état nominal de chaque service et affiche les URL d'accès.

---

## 4. Procédure Manuelle Détaillée (Étape par Étape)

Si vous préférez installer chaque composant manuellement :

### Étape 1 : Préparation de l'environnement
```bash
cp .env.example .env
# Générer des secrets forts :
sed -i "s/CHANGE_ME_mot_de_passe_postgresql_long_et_aleatoire/$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')/g" .env
chmod 600 .env
```

### Étape 2 : Réseau et Certificats
```bash
docker network create msb-auth-bridge || true
./scripts/generate_certs.sh
```

### Étape 3 : Démarrage d'Authentik
```bash
# Si Authentik est déployé via config/authentik :
cp config/authentik/.env.example config/authentik/.env
docker compose -f config/authentik/docker-compose.yml up -d
```

### Étape 4 : Démarrage de Messagerie Souveraine BF
```bash
docker compose up -d
```

### Étape 5 : Vérification
```bash
./scripts/health_check.sh
```

---

## 5. Points d'Accès et Vérifications

| Service | URL locale | Code HTTP attendu |
|---|---|---|
| **Element Web** | `https://messagerie.local/` | HTTP 200 |
| **Console FasoVoice** | `https://messagerie.local/fasovoice/` | HTTP 200 |
| **Authentik SSO** | `https://auth.messagerie.local/` | HTTP 200 / 302 |
| **Synapse Versions API** | `https://messagerie.local/_matrix/client/versions` | HTTP 200 (JSON) |

---

## 6. Comptes de Démonstration

Les identifiants générés localement sont consignés dans le fichier sécurisé :  
`~/messagerie_souveraine_bf/.credentials_demo.local` (permissions `chmod 600`) :
- `alice_demo` : Rôle Responsable ministériel (OIDC + TOTP)
- `bob_demo` : Rôle Agent de terrain (OIDC + TOTP)
- `charlie_demo` : Rôle Collaborateur cellule (OIDC + TOTP)
- `admin` : Compte d'administration locale d'urgence

---

## 7. Arrêt et Désinstallation Sécurisée

Pour arrêter l'ensemble des conteneurs sans perdre vos données ni volumes :
```bash
./scripts/uninstall.sh
```
Ce script garantit la préservation intégrale des bases de données PostgreSQL, des historiques chiffrés et des configurations.
