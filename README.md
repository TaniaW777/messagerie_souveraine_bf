# Messagerie Souveraine BF
**Prototype officiel de messagerie instantanée souveraine pour l'administration publique du Burkina Faso.**  
*Projet développé dans le cadre du Hackathon 226 — Édition 2026 (MTDPCE / DGTD)*  
*Niveau d'engagement open source : « Étendre et adapter » (Matrix Synapse & Element Web)*  

[![Licence](https://img.shields.io/badge/Licence-Apache%202.0-blue.svg)](LICENSE)
[![Sécurité](https://img.shields.io/badge/Chiffrement-Megolm%20E2EE-green.svg)](docs/SECURITY_AUDIT.md)
[![Authentification](https://img.shields.io/badge/MFA-OIDC%20%2B%20TOTP-orange.svg)](tests/mfa/README.md)
[![Innovation](https://img.shields.io/badge/Innovation-FasoVoice%20Multilingue-red.svg)](demo/fasovoice/)

---

## 1. Problème et Solution

### Le problème
Les agents publics de l'État burkinabè recourent quotidiennement à des applications grand public commerciales (WhatsApp, Telegram) hébergées à l'étranger. Cette pratique crée une vulnérabilité stratégique : dépendance d'infrastructures extraterritoriales, risques d'interception et impossibilité de révoquer centralement les accès lors du départ d'un agent.

### La solution
**Messagerie Souveraine BF** est une solution de communication instantanée étatique complète, autonome et déployable sur l'infrastructure souveraine de l'État burkinabè :
- **Chiffrement de bout en bout inviolable :** Olm/Megolm v1 AES-SHA2 appliqué par défaut à tous les salons.
- **Identité forte et vérifiée :** Inscription publique fermée ; délégation OIDC vers l'IdP Authentik avec double facteur TOTP (RFC 6238) obligatoire.
- **Révocation immédiate :** Coupure réseau instantanée côté serveur lors de l'exclusion d'un agent ou de la désactivation d'un compte (HTTP 403 `M_FORBIDDEN`).
- **Autonomie territoriale :** Fédération désactivée (`federation_domain_whitelist: []`), aucune fuite de métadonnées hors du périmètre national.
- **Innovation FASOVOICE :** Console de crise multilingue avec diffusion d'alertes en **Français**, **Mooré** et **Dioula** et synthèse vocale locale sans API externe.

---

## 2. Architecture et Technologies

```
┌─────────────────────────────────────────────────────────────┐
│                 UTILISATEUR (Navigateur Web)                │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS (TLS 1.3 / messagerie.local)
                    ┌──────▼──────┐
                    │ Nginx Proxy │  Terminaison TLS locale & reverse proxy
                    │ (msb-proxy) │  https://messagerie.local (Port 443)
                    └──────┬──────┘
             ┌─────────────┴─────────────┐
             │                           │
      ┌──────▼──────┐             ┌──────▼──────┐
      │ Element Web │             │   Synapse   │  Serveur Matrix v1.164.1
      │  (Client)   │             │ (msb-synapse│  Fédération coupée
      └─────────────┘             └──────┬──────┘  Chiffrement forcé
                                  ┌──────┴─────────────┐
                           ┌──────▼──────┐      ┌──────▼──────┐
                           │ PostgreSQL  │      │  Authentik  │ IdP OIDC + MFA
                           │(msb-postgres│      │ (Port 9000) │ (msb-auth-bridge)
                           └─────────────┘      └─────────────┘
                             (interne)
```

| Composant | Version | Licence OSI | Rôle opérationnel |
|---|---|---|---|
| **Matrix Synapse** | `v1.164.1` | Apache 2.0 | Homeserver souverain, gestion des salons et clés cryptographiques. |
| **Element Web** | `v1.11.109` | Apache 2.0 | Interface web sécurisée, déchiffrement Megolm local dans le navigateur. |
| **Authentik** | `2026.8.5` | MIT | Fournisseur d'identité étatique OIDC avec second facteur TOTP obligatoire. |
| **PostgreSQL** | `16-alpine` | PostgreSQL Lic. | Base relationnelle persistante isolée (seuls des ciphertexts sont stockés). |
| **Nginx** | `1.27-alpine` | 2-clause BSD | Reverse proxy frontal durci (liaison stricte `127.0.0.1`). |
| **FasoVoice** | `v1.0` | Apache 2.0 | Console de crise multilingue (Mooré, Dioula, Français) & lecture vocale. |

---

## 3. Installation et Démarrage Reproductible (Une Seule Commande)

### Prérequis
- Linux (Ubuntu 22.04 / 24.04 ou Debian 12 recommandé)
- Docker Engine ≥ 24 et plugin Docker Compose v2
- OpenSSL et Python 3
- 4 à 8 Go de mémoire RAM disponible

### 1. Cloner le dépôt et entrer dans le répertoire
```bash
git clone https://github.com/TaniaW777/messagerie_souveraine_bf.git
cd messagerie_souveraine_bf
git checkout develop
```

### 2. Configurer la résolution DNS locale (`/etc/hosts`)
Ajouter dans `/etc/hosts` sur la machine hôte :
```text
127.0.0.1   messagerie.local auth.messagerie.local
```

### 3. Lancer l'installation automatisée
```bash
./scripts/install.sh
```
Ce script vérifie les dépendances, génère les secrets locaux (`.env`), crée le réseau inter-projets `msb-auth-bridge`, génère les certificats TLS (`certs/`), initialise Authentik, démarre Synapse, Element et Nginx, et valide l'ensemble par un contrôle de santé.

---

## 4. Points d'Accès et Comptes de Démonstration

### URLs de la plateforme
| Service | URL locale | Rôle |
|---|---|---|
| **Element Web** | `https://messagerie.local` | Messagerie sécurisée chiffrée |
| **Console FasoVoice** | `https://messagerie.local/fasovoice/` | Diffusion multilingue & mode crise |
| **Authentik SSO** | `https://auth.messagerie.local` | Gestion d'identité & validation TOTP |
| **API Matrix** | `https://messagerie.local/_matrix/client/versions` | Sondes et intégrations |

### Comptes pré-configurés
Les identifiants et secrets TOTP sont stockés localement sur la machine hôte dans `.credentials_demo.local` (`chmod 600`, exclu de Git) :
- **`alice_demo`** (Responsable cellule de crise) : Connexion OIDC + TOTP dynamique.
- **`bob_demo`** (Agent d'intervention) : Connexion OIDC + TOTP dynamique.
- **`charlie_demo`** (Collaborateur cellule) : Connexion OIDC + TOTP dynamique.
- **`admin`** (Administrateur système d'urgence) : Compte d'API local de secours.

---

## 5. Innovation : FASOVOICE (Multilingue & Vocal)

En situation de crise nationale, la clarté et la rapidité des ordres sont vitales. La console **FasoVoice** (`https://messagerie.local/fasovoice/` ou `python3 scripts/fasovoice_alert.py demo`) permet à un coordinateur de :
1. Diffuser instantanément des alertes certifiées en **Français**, **Mooré** et **Dioula**.
2. Écouter vocalement l'instruction grâce au moteur audio souverain local (Web Speech / Web Audio, sans aucune API cloud payante).
3. Suivre en temps réel les accusés de réception horodatés des agents sur le terrain.

---

## 6. Vérification et Suite de Tests de Sécurité

Exécuter le banc de test automatisé couvrant l'épreuve Intrus et le chiffrement des fichiers :
```bash
python3 tests/test_matrix_security.py
```
*Couverture :*
- Rejet inscription publique (`HTTP 403 M_FORBIDDEN`)
- Rejet attaquant non enrôlé (`HTTP 403 M_FORBIDDEN`)
- Coupure stricte de la fédération (`HTTP 404 M_UNRECOGNIZED`)
- Chiffrement client AES-256-CTR, upload media store opaque, déchiffrement vérifié
- Rejet d'accès et d'envoi dans les salons privés non invités

---

## 7. Limites Connues et Transparence Technique

1. **Cache local des navigateurs (IndexedDB) :** La révocation d'un agent coupe instantanément tout flux réseau, mais ne peut pas effacer rétroactivement les anciens messages déjà déchiffrés stockés dans le navigateur du client sans agent MDM.
2. **Certificats de développement :** Les certificats fournis reposent sur une autorité locale de démonstration (mkcert / OpenSSL) ; un déploiement national nécessitera la PKI d'État (ANSSI-BF).
3. **Résolution DNS :** Utilise `/etc/hosts` en local.

---

## 8. Documents Officiels du Dossier de Candidature

- [`NOTE_PRE_PROJET.md`](NOTE_PRE_PROJET.md) : Note de concept, architecture, stack et rôles (2 pages).
- [`docs/SECURITY_AUDIT.md`](docs/SECURITY_AUDIT.md) : Note de sécurité détaillée et métadonnées (2 pages).
- [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) : Inventaire complet des licences tierces OSI.
- [`docs/SCENARIO_VIDEO_DEMO.md`](docs/SCENARIO_VIDEO_DEMO.md) : Conducteur vidéo chronométré (3 minutes max).
- [`demo/scenario.md`](demo/scenario.md) : Guide détaillé des manipulations pour le jury.
