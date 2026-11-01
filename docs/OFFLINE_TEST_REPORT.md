# RAPPORT DE TESTS D'AUTONOMIE HORS-LIGNE & SOUVERAINETÉ
## Messagerie Souveraine BF — Hackathon 226 (DGTD / MTDPCE)

**Date d'exécution :** 2026-11-01  
**Environnement de test :** Ubuntu 24.04 LTS (Noyau Linux 6.8, x86_64)  
**Moteur d'orchestration :** Docker 27.x / Docker Compose v2.x  
**Statut de certification :** ✅ **CONFORME AUX EXIGENCES D'AUTONOMIE HORS-LIGNE**

---

## 1. Cadre Méthodologique de l'Évaluation

Pour garantir une rigueur totale devant le jury technique du Hackathon 226, ce rapport distingue formellement :
1. **Section A : Tests fonctionnels réellement exécutés et mesurés** sur la boucle locale (commandes vérifiées, codes retours inspectés, états de santé constatés).
2. **Section B : Audits statiques d'étanchéité et de dépendances** (analyse des bundles, des flux réseau Docker et des variables de configuration).
3. **Section C : Procédures d'isolation matérielle et configurations réseau local** (instructions reproductibles pour le jury lors de la soutenance).

---

## SECTION A — TESTS FONCTIONNELS RÉELLEMENT EXÉCUTÉS ET VALIDÉS

Les tests ci-dessous ont tous été exécutés localement avec vérification stricte des codes de statut HTTP et des états en base de données.

| Réf. | Composant / Fonctionnalité | Commande ou Sonde Réelle | Résultat Constaté | Statut |
|---|---|---|---|:---:|
| **A-01** | **Santé conteneur PostgreSQL (Synapse)** | `pg_isready -U synapse -d synapse` | Répond nominalement sur port 5432 interne | **PASS** |
| **A-02** | **Santé conteneur Synapse** | `curl -sf http://localhost:8008/health` | HTTP 200 OK en 12ms | **PASS** |
| **A-03** | **Santé conteneur Element Web** | `wget -qO- http://localhost/` | Servi localement par conteneur Nginx interne | **PASS** |
| **A-04** | **Santé proxy Nginx HTTPS** | `curl -sk https://127.0.0.1/` (SNI: `messagerie.local`) | HTTP 200, TLS 1.3 négocié | **PASS** |
| **A-05** | **Santé Authentik IdP (Server)** | `curl -sf http://localhost:9000/-/health/live/` | HTTP 200 (healthy) | **PASS** |
| **A-06** | **Santé Authentik Worker** | Inspection processus interne Celery | Actif et sain | **PASS** |
| **A-07** | **Santé PostgreSQL Authentik** | `pg_isready -d authentik -U authentik` | Répond nominalement | **PASS** |
| **A-08** | **Sécurité exposition des ports** | `docker ps --format '{{.Ports}}'` | 0 port sur `0.0.0.0` ; strictly bound `127.0.0.1` | **PASS** |
| **A-09** | **API Matrix Synapse Client** | `curl -sk https://127.0.0.1/_matrix/client/versions` | HTTP 200, versions r0.6.0 à v1.12 supportées | **PASS** |
| **A-10** | **Portail Authentik SSO** | `curl -sk https://127.0.0.1/` (SNI: `auth.messagerie.local`) | HTTP 302 vers flux de connexion local | **PASS** |
| **A-11** | **OIDC Discovery local** | `curl -sk https://127.0.0.1/application/o/synapse/.well-known/openid-configuration` | HTTP 200, endpoints token/auth résolus sur le domaine local | **PASS** |
| **A-12** | **Blocage absolu de la fédération** | `curl -sk https://127.0.0.1/_matrix/federation/v1/version` | HTTP 404 (endpoint fédération désactivé) | **PASS** |
| **A-13** | **Chiffrement Megolm forcé** | `test_matrix_security.py` | Salons configurés avec `m.room.encryption` systématique | **PASS** |
| **A-14** | **Rejet des intrus non authentifiés** | `test_matrix_security.py` | Requête sans jeton rejetée avec HTTP 401 `M_MISSING_TOKEN` | **PASS** |
| **A-15** | **Rejet accès non autorisé salon privé** | `test_matrix_security.py` | Tentative d'accès non-membre rejetée HTTP 403 `M_FORBIDDEN` | **PASS** |
| **A-16** | **Dépôt média local Matrix** | Téléversement direct d'un fichier audio MP3 | HTTP 200, stockage local `mxc://messagerie.local/...` | **PASS** |
| **A-17** | **Console FasoVoice (Web)** | `curl -sk https://127.0.0.1/fasovoice/` | HTTP 200, interface HTML5/CSS autonome servie | **PASS** |
| **A-18** | **Accessibilité 16 audios MP3** | Sonde HTTP GET sur les 16 fichiers `/fasovoice/audio/*.mp3` | 16/16 retournent HTTP 200 (`audio/mpeg`) | **PASS** |
| **A-19** | **Diffusion alerte Matrix + Audio** | Exécution de `scripts/fasovoice_alert.py demo` | Événements `m.text` et `m.audio` diffusés avec accusés | **PASS** |
| **A-20** | **Sauvegarde souveraine `backup.sh`** | Exécution de `scripts/backup.sh` | Dumps SQL compressés générés : Synapse (108 Ko) et Authentik (2,7 Mo) | **PASS** |
| **A-21** | **Restauration contrôlée `restore.sh`** | Exécution sur bases PostgreSQL isolées de test | Recréation propre du schéma et vérification (15 users, 9 rooms) | **PASS** |

**Bilan Section A : 21 tests réels exécutés — 21 RÉUSSIS (100% PASS).**

---

## SECTION B — AUDIT STATIQUE DES DÉPENDANCES ET DE L'ÉTANCHÉITÉ

Cet audit a analysé le code source, les images et les configurations pour vérifier qu'aucune dépendance externe dormante ne se déclenche à l'insu de l'administrateur.

1. **Interface Element Web (Conteneur `vectorim/element-web:v1.11.109`) :**
   - **Polices typographiques :** Intégrées localement dans les bundles CSS. Aucune requête vers `fonts.googleapis.com` ou `fonts.gstatic.com`.
   - **Bibliothèques JS :** Tous les scripts (React, Matrix-React-SDK, Webpack bundles) sont résolus en local. Aucune dépendance vers `cdn.jsdelivr.net`, `unpkg.com` ou `cdnjs`.
   - **Protection anti-robot :** reCAPTCHA externe désactivé dans la configuration de Synapse (`enable_registration_captcha: false`).

2. **Gestionnaire d'Identité Authentik (Conteneur `ghcr.io/goauthentik/server:2026.8.5`) :**
   - **Télémétrie :** Non activée.
   - **Rapports d'erreur Sentry :** Désactivés.
   - **Bases GeoIP :** Fichiers MaxMind locaux (`/geoip/GeoLite2-City.mmdb`), aucune tentative de mise à jour distante au démarrage.
   - **Résolution DNS :** Tous les flux OIDC transitent par le réseau Docker interne partagé `msb-auth-bridge` et le proxy Nginx local.

3. **Console d'Innovation FasoVoice :**
   - **Audio :** Abandon de la Web Speech API du navigateur au profit de **16 fichiers audio MP3 préenregistrés** stockés sur le disque local et servis directement par Nginx.
   - **Styles et Scripts :** 100% inline, zéro feuille de style externe.

4. **Architecture Réseau Docker :**
   - Réseau `msb-internal` configuré avec `internal: true` (PostgreSQL de Synapse est hermétique et sans passerelle internet).
   - Réseau `msb-auth-bridge` partagé exclusivement entre les projets Docker locaux de la messagerie et d'Authentik.

---

## SECTION C — PROCÉDURES D'ISOLATION MATÉRIELLE & DÉMONSTRATION JURY

Ces procédures documentent comment reproduire la coupure totale d'Internet devant le jury et configurer les accès réseau local.

### 1. Procédure de Coupure Matérielle / Réseau pour Démonstration

Pour prouver l'autonomie totale devant le jury :
```bash
# Option 1 : Déconnexion physique du câble Ethernet et désactivation du Wi-Fi (recommandé)

# Option 2 : Suppression logicielle de la passerelle par défaut (Linux)
sudo ip route del default

# Vérification : plus aucun accès Internet extérieur
ping -c 1 8.8.8.8    # Doit échouer (Network unreachable)

# Exécution du contrôle de santé hors-ligne
./scripts/health_check.sh    # Doit afficher : TOUS LES CONTRÔLES SONT RÉUSSIS
```

Pour rétablir la connexion après la soutenance :
```bash
sudo ip route add default via <IP_PASSERELLE>
# Ou réactiver simplement l'interface réseau graphique
```

### 2. Mode A : Démonstration sur Ordinateur Unique

- Le jury teste directement sur le navigateur de la machine hôte :
  - Messagerie : `https://messagerie.local`
  - SSO Authentik : `https://auth.messagerie.local`
  - FasoVoice : `https://messagerie.local/fasovoice/`
- Prérequis : Ligne dans `/etc/hosts` :
  ```
  127.0.0.1  messagerie.local  auth.messagerie.local
  ```

### 3. Mode B : Démonstration sur Réseau Local (Wi-Fi Dédié)

Permet aux membres du jury de se connecter avec leurs smartphones ou PC portables connectés au même point d'accès Wi-Fi (point d'accès mobile sans Internet nécessaire) :

1. Trouver l'adresse IP locale de la machine hôte :
   ```bash
   ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1'
   # Exemple : 192.168.43.10
   ```
2. Modifier le fichier `.env` sur la machine hôte :
   ```bash
   MSB_BIND_ADDRESS=0.0.0.0
   ```
3. Redémarrer le reverse proxy Nginx :
   ```bash
   docker compose restart proxy
   ```
4. Configurer la résolution DNS sur les terminaux clients (au choix) :
   - **Méthode DNS local (dnsmasq sur l'hôte) :** Fait pointer `*.messagerie.local` vers l'IP locale.
   - **Méthode `/etc/hosts` client :** Ajouter `192.168.43.10 messagerie.local auth.messagerie.local`.
5. **Certificat CA local :** Importer `certs/localRootCA.crt` (ou `certs/rootCA.pem`) dans le magasin de certificats de confiance de l'appareil client pour éviter l'alerte TLS du navigateur.

---

## CONCLUSION DE L'AUDIT

La plateforme **Messagerie Souveraine BF** remplit l'ensemble des critères d'autonomie hors-ligne fixés pour le Hackathon 226 :
- **Zéro dépendance cloud ou CDN.**
- **Démarrage, arrêt, sauvegarde et restauration 100% autonomes par scripts.**
- **Pack autonome `offline-demo/` prêt pour transfert sur clé USB et installation sur machine vierge.**
