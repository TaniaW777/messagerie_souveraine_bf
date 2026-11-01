# Note de Pré-Projet — Messagerie Souveraine BF
**Challenge national :** « La messagerie souveraine de l'administration »  
**Compétition :** Sprint Technique Pré-Hackathon 226 — Édition 2026  
**Organisateur :** Ministère de la Transition Digitale, des Postes et des Communications Électroniques (MTDPCE) — DGTD  
**Niveau d'engagement open source :** « Étendre et adapter » (Matrix Synapse, Element Web, Authentik)  
**Date :** 1er Novembre 2026  

---

## 1. Contexte, Problème et Concept

Les agents de l'administration publique du Burkina Faso recourent fréquemment à des plateformes grand public étrangères (WhatsApp, Telegram) pour coordonner leurs missions de service. Cette pratique expose l'État à des risques majeurs : interception de données sensibles, dépendance à des infrastructures extraterritoriales, indisponibilité en cas de rupture de connectivité internationale et incapacité de révoquer un accès de manière unifiée.

**Le concept :** **Messagerie Souveraine BF** est une plateforme complète de messagerie instantanée étatique, hébergeable sur l'infrastructure souveraine de l'État burkinabè, sans aucune dépendance à des services tiers extérieurs. Elle associe une interface web ergonomique, un chiffrement de bout en bout inviolable mathématiquement, une fédération d'identité centralisée avec second facteur obligatoire (MFA TOTP) et une innovation majeure adaptée au contexte national : **FasoVoice**, un système d'alerte de crise multilingue (Français, Mooré, Dioula) avec synthèse vocale locale.

---

## 2. Architecture Technique et Hébergement Souverain

L'architecture est entièrement conteneurisée (Docker Compose) et segmentée en réseaux étanches :

```
┌─────────────────────────────────────────────────────────────┐
│               UTILISATEUR / NAVIGATEUR WEB                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS (TLS 1.3 / messagerie.local)
                    ┌──────▼──────┐
                    │ Nginx Proxy │  Reverse proxy frontal durci
                    │ (msb-proxy) │  Terminaison TLS locale & isolation 127.0.0.1
                    └──────┬──────┘
             ┌─────────────┴─────────────┐
             │                           │
      ┌──────▼──────┐             ┌──────▼──────┐
      │ Element Web │             │   Synapse   │  Serveur Matrix v1.164.1
      │ (Interface) │             │ (msb-synapse│  Fédération désactivée
      └─────────────┘             └──────┬──────┘  Chiffrement Megolm forcé
                                  ┌──────┴─────────────┐
                           ┌──────▼──────┐      ┌──────▼──────┐
                           │ PostgreSQL  │      │  Authentik  │ IdP OIDC + MFA
                           │(msb-postgres│      │ (IdP État)  │ Port 9000
                           └─────────────┘      └─────────────┘
                             (interne)           (msb-auth-bridge)
```

- **Hébergement autonome :** Déploiement en une seule commande via `scripts/install.sh`. Aucun appel à des API tierces ou cloud public.
- **Segmentation réseau stricte :** La base PostgreSQL est confinée sur un réseau Docker interne sans publication de port sur l'hôte. Tous les ports exposés sont strictement restreints à `127.0.0.1`.
- **Fédération désactivée :** Coupure totale des communications inter-serveurs (`federation_domain_whitelist: []`) pour garantir la souveraineté territoriale des données.

---

## 3. Protocole de Chiffrement et Sécurité Cryptographique

- **Protocole retenu :** **Matrix Olm/Megolm (v1 AES-SHA2)**, standard international ouvert audité par le NCC Group.
- **Chiffrement des messages :** Chaque salon applique l'algorithme Megolm. Les clés de chiffrement de session sont partagées uniquement entre les terminaux autorisés des agents présents.
- **Chiffrement des fichiers :** Tout fichier joint est chiffré côté client en AES-256-CTR avant son téléversement vers le serveur. Le serveur Synapse ne stocke que du ciphertext opaque ; les clés de déchiffrement transitent uniquement dans le message Megolm chiffré.
- **Preuve en base de données :** L'inspection SQL de PostgreSQL prouve que la colonne `ciphertext` ne contient que des blocs indéchiffrables en base64. Le corps du texte en clair n'existe nulle part sur le serveur.
- **Révocation immédiate :** L'exclusion d'un agent (`leave`/`kick`) ou la désactivation administrative d'un compte invalide instantanément sa session. Le serveur rejette immédiatement tout nouvel envoi avec le code d'erreur `HTTP 403 M_FORBIDDEN`.

---

## 4. Composants Open Source et Licences (Niveau « Étendre et adapter »)

Tous les composants sont sous licences approuvées par l'OSI :
- **Matrix Synapse v1.164.1** (Apache 2.0) : Homeserver souverain durci.
- **Element Web v1.11.109** (Apache 2.0) : Client web personnalisé aux armoiries nationales.
- **Authentik 2026.8.5** (MIT) : Gestionnaire d'identité centralisé OIDC + TOTP (RFC 6238).
- **PostgreSQL 16** (PostgreSQL License) : Persistance relationnelle sécurisée.
- **Nginx 1.27** (2-clause BSD) : Reverse proxy et passerelle TLS locale.

---

## 5. Fonctionnalités Innovantes : FASOVOICE

Conformément à l'espace d'innovation du hackathon, l'équipe propose **FASOVOICE**, une console d'assistance à la coordination et de diffusion d'alertes en langues nationales :
1. **Diffusion trilingue simultanée :** Émission d'instructions officielles en **Français**, **Mooré** et **Dioula** vers les salons d'urgence Matrix.
2. **Corpus validé de crise :** Messages certifiés couvrant les incidents sécuritaires, ordres d'évacuation, alertes météo et fin de confinement.
3. **Fonction vocale souveraine locale :** Lecture audio directe dans le navigateur via l'API Web Speech / Web Audio locale, garantissant l'accessibilité aux agents sur le terrain sans dépendance à un moteur cloud payant.
4. **Traçabilité des accusés de réception :** Suivi horodaté en direct de la prise en compte de l'ordre de mission par chaque agent opérationnel.

---

## 6. Répartition des Rôles au Sein de l'Équipe

| Membre | Rôle opérationnel | Responsabilités techniques |
|---|---|---|
| **Jonathan OUEDRAOGO** | Architecte Système & Intégrateur | Orchestration Docker Compose, intégration Synapse-PostgreSQL, Nginx HTTPS, automatisation `install.sh` et reproductibilité sur machine neuve. |
| **Membre 2 (Sécurité)** | Responsable Cybersécurité & Identité | Intégration OIDC Authentik, politique MFA TOTP, tests de pénétration intrus, vérification E2EE Megolm et note de sécurité. |
| **Membre 3 (Usage & Démo)** | Ingénieur Interface & Innovation | Personnalisation Element Web, développement de la console FasoVoice (Mooré/Dioula/Vocal), scénario de test et vidéo de démonstration. |

---

## 7. Résultats Attendus et Perspectives

Le prototype démontre formellement qu'une messagerie d'État hautement sécurisée, ergonomique, respectueuse des langues du Burkina Faso et administrable de manière unifiée est réalisable sur des technologies open source souveraines. La suite de la compétition permettra d'étendre la solution vers les clients mobiles Android (Element X) et l'interconnexion avec l'annuaire d'État.
