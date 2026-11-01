# Audit de Sécurité de la Plateforme — Messagerie Souveraine BF
*Évaluation de la posture de sécurité, matrice des risques et recommandations*
*Date d'audit : 1er Novembre 2026*

---

## 1. Périmètre de l'Audit

L'audit couvre l'intégralité des briques logicielles composant la plateforme **Messagerie Souveraine BF** :
- **Serveur de messagerie :** Matrix Synapse v1.164.1
- **Client utilisateur :** Element Web v1.11.109
- **Base de données :** PostgreSQL 16-alpine
- **Fournisseur d'identité (IdP) :** Authentik 2026.8.5
- **Reverse Proxy / Terminaison TLS :** Nginx 1.27-alpine
- **Orchestration :** Docker & Docker Compose sur Linux Ubuntu 24.04

---

## 2. Synthèse de la Posture de Sécurité

| Domaine | Niveau de conformité | Observations principales |
|---|---|---|
| **Contrôle d'accès & Inscription** | **Conforme** | Inscriptions publiques désactivées (`enable_registration: false`), utilisateurs invités désactivés (`allow_guest_registration: false`). |
| **Authentification & MFA** | **Conforme** | Délégation OIDC vers Authentik avec MFA TOTP obligatoire (RFC 6238). Protection anti-rejeu des jetons temporels. |
| **Confidentialité des échanges** | **Conforme** | Chiffrement de bout en bout Megolm (`m.megolm.v1.aes-sha2`). Stockage exclusif de texte chiffré en base de données. |
| **Segmentation réseau** | **Conforme** | Tous les conteneurs sont isolés sur des réseaux Docker internes (`msb-internal`, `msb-auth-bridge`). Aucun port applicatif sensible n'est lié sur `0.0.0.0` (liaison stricte `127.0.0.1`). |
| **Protection des secrets** | **Conforme** | Fichiers d'environnement (`.env`) et identifiants de démonstration (`.credentials_demo.local`) exclus de Git via `.gitignore` et protégés en `chmod 600`. Sauvegardes stockées hors du dépôt (`~/backups_msb/`). |
| **Révocation et gouvernance** | **Conforme** | Révocation immédiate d'appareils via l'API Synapse, désactivation officielle des comptes sans suppression brute en base, rejet immédiat (HTTP 403 `M_FORBIDDEN`) des tentatives d'envoi après exclusion d'un salon. |

---

## 3. Matrice des Risques Résiduels

### A. Risques de Niveau Critique
*Aucun risque critique non maîtrisé n'a été détecté dans la configuration actuelle.*

---

### B. Risques de Niveau Élevé

#### R-01 : Clé de Signature Synapse locale (Environnement Prototype)
- **Description :** Le serveur Synapse utilise une clé locale générée pour signer les événements du homeserver (`messagerie.local.signing.key`).
- **Impact :** Si cette clé venait à être compromise, un attaquant pourrait forger des événements au nom du serveur local.
- **Mesure d'atténuation appliquée :** La clé réside dans le volume `data/` exclu de Git, avec permissions restreintes à l'utilisateur système Synapse (UID 991).
- **Recommandation pour la production :** Intégrer un HSM (Hardware Security Module) ou un coffre-fort de secrets (HashiCorp Vault) pour la gestion du cycle de vie des clés de signature.

#### R-02 : Certificats TLS de développement (mkcert)
- **Description :** Les certificats TLS utilisés sont émis par une autorité locale de développement (`mkcert development CA`).
- **Impact :** Ces certificats sont reconnus uniquement sur les postes de travail où l'autorité a été injectée dans la base NSS du navigateur.
- **Mesure d'atténuation appliquée :** Injection ciblée dans Firefox Snap (`cert9.db`) et création d'un bundle CA système pour les appels cURL/Python.
- **Recommandation pour la production :** Déployer une PKI institutionnelle d'État (ANSSI-BF ou PKI nationale souveraine) ou des certificats X.509 d'une autorité reconnue publiquement avec renouvellement automatique Let's Encrypt / ACME.

---

### C. Risques de Niveau Moyen

#### R-03 : Découplage de la révocation globale des sessions Authentik vers Synapse
- **Description :** La désactivation d'un compte dans Authentik empêche toute nouvelle authentification SSO/OIDC. Toutefois, les sessions Matrix déjà émises (access tokens actifs) conservent leur validité jusqu'à leur expiration ou leur révocation administrative explicite dans Synapse.
- **Impact :** Un agent révoqué dans Authentik pourrait théoriquement continuer à émettre des messages via sa session locale Matrix tant que son token n'est pas révoqué dans Synapse.
- **Mesure d'atténuation appliquée :** Procédure documentée de double révocation (désactivation du compte dans Authentik + appel de l'API Synapse `POST /_synapse/admin/v1/deactivate/<user_id>`).
- **Recommandation pour la production :** Activer et tester le protocole OIDC Backchannel Logout (RFC draft) pour notifier automatiquement Synapse lors de la clôture d'une session dans Authentik.

#### R-04 : Dépendance au bridge réseau entre Compose Authentik et Compose Messagerie
- **Description :** Authentik et Messagerie Souveraine BF fonctionnent dans deux projets Docker Compose distincts, reliés par un réseau externe `msb-auth-bridge`.
- **Impact :** Si le réseau bridge n'est pas initialisé avant le lancement des conteneurs, Synapse ne peut pas contacter Authentik (`OidcDiscoveryError`).
- **Mesure d'atténuation appliquée :** Les scripts de démarrage et de healthcheck contrôlent systématiquement la connectivité inter-conteneurs.
- **Recommandation pour la production :** Unifier les fichiers d'orchestration ou déployer l'architecture sous Kubernetes avec des NetworkPolicies adaptées.

---

### D. Risques de Niveau Faible

#### R-05 : Taux de limitation de requêtes assoupli pour démonstration locale
- **Description :** Les paramètres `rc_login` de Synapse ont été ajustés (`per_second: 10`, `burst_count: 100`) pour permettre l'enchaînement rapide des tests automatisés de démonstration sans déclencher de blocage intempestif.
- **Impact :** Résistance moindre aux attaques automatisées par force brute en cas d'exposition directe.
- **Mesure d'atténuation appliquée :** L'interface Synapse n'est accessible que sur `127.0.0.1` à travers Nginx.
- **Recommandation pour la production :** Réduire les limites `rc_login` à `per_second: 1` et `burst_count: 5`, et coupler avec un module Fail2ban ou un WAF frontal.

---

## 4. Recommandations Prioritaires pour le Passage en Production

1. **Intégration d'une PKI Nationale :** Remplacer les certificats mkcert par des certificats X.509 délivrés par l'autorité de certification souveraine du Burkina Faso.
2. **Synchronisation LDAP / Annuaire d'État :** Relier Authentik à l'annuaire d'État (OpenLDAP / Active Directory ministériel) pour automatiser le cycle de vie des agents (onboarding / offboarding).
3. **Journalisation Centralisée et SIEM :** Exporter les journaux d'audit Synapse, Nginx et Authentik vers un SIEM souverain (Wazuh / OpenSearch) pour la détection proactive des anomalies de sécurité.
4. **Sauvegardes Chiffrées Hors Site :** Automatiser la réplication chiffrée des dumps PostgreSQL vers un site de secours distant géographiquement distinct.
