# GUIDE D'INSTALLATION HORS-LIGNE — MESSAGERIE SOUVERAINE BF
## Déploiement Autonome Sans Internet

**Version :** 1.0 — Hackathon 226  
**Cible :** Ordinateur Ubuntu 20.04+ avec Docker

---

## Pré-requis

### Système
```bash
# Vérifier Ubuntu
lsb_release -a

# Vérifier Docker
docker version
docker compose version  # v2 requis

# Vérifier Python 3
python3 --version

# Vérifier OpenSSL
openssl version
```

### Espace disque
- Images Docker : ~645 Mo (compressées) / ~3,2 Go (décompressées)
- Données applicatives : ~500 Mo minimum recommandé
- Total minimal : **4 Go libres**

---

## Étape 1 — Obtenir le pack hors-ligne

Copiez le dossier `offline-demo/` depuis une clé USB ou un disque externe :

```bash
# Depuis la clé USB (adapter le chemin)
cp -r /media/usb/offline-demo ~/messagerie-demo

# Ou depuis le projet source
cd ~/messagerie_souveraine_bf
```

---

## Étape 2 — Configurer les entrées DNS locales

### Sur l'ordinateur hôte (obligatoire)
```bash
sudo nano /etc/hosts
```

Ajouter la ligne :
```
127.0.0.1  messagerie.local  auth.messagerie.local
```

### Sur les appareils du jury (Mode B — Réseau local)

Remplacer `127.0.0.1` par l'IP de l'ordinateur hôte :
```bash
# Trouver l'IP locale de l'hôte
ip addr show | grep "inet " | grep -v 127.0.0.1
# Exemple : 192.168.1.42
```

Sur chaque appareil client, ajouter dans `/etc/hosts` (ou équivalent) :
```
192.168.1.42  messagerie.local  auth.messagerie.local
```

---

## Étape 3 — Charger les images Docker

```bash
cd ~/messagerie-demo  # ou ~/messagerie_souveraine_bf

# Charger toutes les images depuis les archives locales
./offline-demo/load-images.sh
```

Résultat attendu : 5 images chargées, aucune connexion Internet utilisée.

---

## Étape 4 — Créer le réseau Docker partagé

```bash
docker network create msb-auth-bridge
```

---

## Étape 5 — Configurer les variables d'environnement

### Pour la pile principale
```bash
cp .env.example .env

# Générer des secrets aléatoires et éditer
python3 -c "import secrets; print('POSTGRES_PASSWORD=' + secrets.token_urlsafe(24))"
python3 -c "import secrets; print('SYNAPSE_REGISTRATION_SHARED_SECRET=' + secrets.token_urlsafe(48))"
nano .env
```

### Pour Authentik
```bash
mkdir -p ~/authentik
cp offline-demo/compose/authentik-compose.yml ~/authentik/compose.yml
cp offline-demo/compose/authentik.env.example ~/authentik/.env

python3 -c "import secrets; print('AUTHENTIK_SECRET_KEY=' + secrets.token_urlsafe(50))"
python3 -c "import secrets; print('PG_PASS=' + secrets.token_urlsafe(24))"
nano ~/authentik/.env
```

---

## Étape 6 — Générer les certificats TLS locaux

```bash
bash scripts/generate_certs.sh
```

Les certificats seront créés dans `certs/`.

### Installer l'autorité de certification sur l'ordinateur hôte

```bash
# Ubuntu / Debian
sudo cp certs/rootCA.pem /usr/local/share/ca-certificates/msb-local-ca.crt
sudo update-ca-certificates

# Redémarrer les navigateurs pour prendre en compte le nouveau CA
```

### Installer le CA sur les appareils du jury

Voir `offline-demo/INSTALL.md` pour les instructions par système (Android, iOS, Windows, Firefox).

---

## Étape 7 — Démarrer les services

```bash
# Option A : Installation complète automatisée
bash scripts/install.sh

# Option B : Démarrage simple (si déjà configuré)
bash scripts/start.sh
```

---

## Étape 8 — Vérifier l'installation

```bash
bash scripts/health_check.sh
```

Résultat attendu : **TOUS LES CONTRÔLES RÉUSSIS** ✅

---

## Étape 9 — Premier accès et comptes

Ouvrir **https://messagerie.local** dans un navigateur.

Si c'est la première installation sur une machine vierge, provisionner les comptes de démonstration :

```bash
python3 scripts/provision_authentik.py
```

---

## Accès réseau local (Mode B)

Pour que le jury accède depuis un autre appareil Wi-Fi :

```bash
# 1. Modifier .env
MSB_BIND_ADDRESS=0.0.0.0

# 2. Redémarrer le proxy
docker compose restart proxy

# 3. Vérifier le firewall (si actif)
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
```

---

## Commandes de maintenance

```bash
# Arrêt propre (sans perte de données)
bash scripts/stop.sh

# Sauvegarde
bash scripts/backup.sh

# Restauration
bash scripts/restore.sh ~/backups_msb/backup_YYYYMMDD_HHMMSS

# Contrôle de santé
bash scripts/health_check.sh
```

---

## Résolution des problèmes

| Problème | Solution |
|---------|---------|
| "cannot connect" | Vérifier `/etc/hosts` et `docker ps` |
| Certificat rejeté | Importer `certs/rootCA.pem` dans le navigateur |
| Service non démarré | `docker logs msb-synapse` pour les détails |
| Image manquante | `./offline-demo/load-images.sh` |
| Réseau manquant | `docker network create msb-auth-bridge` |
