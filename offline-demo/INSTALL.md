# INSTALLATION HORS-LIGNE — MESSAGERIE SOUVERAINE BF
## Guide de déploiement autonome sans Internet

> **Ce pack permet de déployer Messagerie Souveraine BF sur une machine Ubuntu équipée de Docker, sans aucune connexion Internet.**

---

## Pré-requis sur la machine cible

| Composant | Version minimale |
|-----------|-----------------|
| Ubuntu | 20.04 LTS ou supérieur |
| Docker Engine | 24.0+ |
| Docker Compose v2 | intégré à Docker |
| Espace disque libre | 8 Go minimum |
| RAM | 4 Go minimum (8 Go recommandés) |
| Python 3 | 3.8+ (pour les scripts de provisionnement) |
| OpenSSL | 3.0+ (pour les certificats TLS locaux) |

---

## Étape 1 — Configurer /etc/hosts

Ajoutez les entrées DNS locales sur **chaque machine participant à la démo** (ordinateur hôte ET appareils jury en mode réseau local) :

```
127.0.0.1  messagerie.local  auth.messagerie.local
```

Pour l'accès réseau local (Mode B — depuis un téléphone ou second ordinateur), remplacez `127.0.0.1` par l'**IP locale** de l'ordinateur hôte (ex: `192.168.1.42`) :

```
192.168.1.42  messagerie.local  auth.messagerie.local
```

---

## Étape 2 — Charger les images Docker

```bash
# Depuis le dossier offline-demo/
./load-images.sh
```

Ce script charge toutes les images depuis les archives locales (aucun téléchargement).

---

## Étape 3 — Configurer les variables d'environnement

```bash
# Pile principale (Synapse + Element + Nginx)
cp compose/.env.example .env
# Éditez .env et renseignez les secrets

# Pile Authentik
cp compose/authentik.env.example ~/authentik/.env
# Éditez ~/authentik/.env et renseignez les secrets
```

> **Sécurité** : Générez des mots de passe longs et aléatoires avec :
> ```bash
> python3 -c "import secrets; print(secrets.token_urlsafe(32))"
> ```

---

## Étape 4 — Installer et démarrer

```bash
# Option A : Installation complète (1ère fois)
./scripts/install.sh

# Option B : Démarrage rapide (si déjà installé)
./scripts/start.sh
```

---

## Étape 5 — Accéder à l'application

| Service | URL |
|---------|-----|
| 💬 Messagerie Element | https://messagerie.local |
| 🔑 Portail SSO Authentik | https://auth.messagerie.local |
| 🎙️ Console FasoVoice | https://messagerie.local/fasovoice/ |
| ⚡ API Matrix Synapse | https://messagerie.local/_matrix/client/versions |

---

## Installation du certificat CA local (pour le jury)

Le certificat `certs/rootCA.pem` (ou `certs/messagerie.local+3.pem`) doit être importé sur chaque appareil du jury :

### Ubuntu / Linux (Firefox)
```bash
# Firefox : Paramètres > Vie privée > Afficher les certificats > Importer
```

### Ubuntu / Linux (Chrome/Chromium)
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "MSB-LocalCA" -i certs/rootCA.pem
```

### Android
1. Copiez `rootCA.pem` sur le téléphone
2. Paramètres > Sécurité > Chiffrement > Installer un certificat

### iOS / iPhone
1. Envoyez `rootCA.pem` par AirDrop ou e-mail
2. Ouvrez le fichier → Installer le profil → Paramètres > Général > Certificats

### Windows
1. Double-cliquez sur `rootCA.pem`
2. Installer → Ordinateur local → Autorités de certification racines

---

## Mode réseau local (accès jury depuis un téléphone/autre PC)

Pour que le jury puisse accéder depuis un autre appareil sur le même réseau Wi-Fi :

1. Trouvez l'IP locale de l'ordinateur hôte :
   ```bash
   ip addr show | grep "inet " | grep -v 127.0.0.1
   ```

2. Modifiez `.env` pour exposer sur le réseau local :
   ```
   MSB_BIND_ADDRESS=0.0.0.0
   ```

3. Ajoutez dans `/etc/hosts` **sur chaque appareil client** :
   ```
   192.168.X.X  messagerie.local  auth.messagerie.local
   ```

4. Relancez Nginx :
   ```bash
   docker compose restart proxy
   ```

---

## Contrôle de santé

```bash
./scripts/health_check.sh
```

---

## Sauvegarde et restauration

```bash
# Sauvegarde complète
./scripts/backup.sh

# Restauration depuis une sauvegarde
./scripts/restore.sh ~/backups_msb/backup_YYYYMMDD_HHMMSS
```

---

## Arrêt propre

```bash
./scripts/stop.sh
```

> ⚠️ **Ne jamais** utiliser `docker compose down -v` — cela supprime toutes les données.
