# Inventaire des Licences des Composants Tiers (Third-Party Licenses)
## Projet : Messagerie Souveraine BF — Hackathon 226 (Édition 2026)

Conformément à l'Obligation Open Source (Section ❷ du règlement du Hackathon 226), l'ensemble de la plateforme repose exclusivement sur des technologies open source reconnues par l'Open Source Initiative (OSI). Aucune API propriétaire ni aucun service tiers externe n'est indispensable au fonctionnement de la solution.

---

## 1. Niveau d'Engagement Open Source Déclaré

- **Niveau d'engagement :** **« Étendre et adapter »**
- **Justification :** Le projet réutilise et orchestre des composants éprouvés de l'écosystème international Matrix et Authentik (Synapse, Element Web, Authentik IdP, Nginx, PostgreSQL), durcis pour la souveraineté nationale du Burkina Faso, étendus avec une console d'innovation multilingue de crise (**FasoVoice** en Français, Mooré et Dioula) et orchestrés pour un déploiement autonome reproductible.

---

## 2. Inventaire des Technologies et Composants Tiers

| Composant | Version retenue | Licence OSI | Rôle dans l'architecture | Dépôt officiel / Référence |
|---|---|---|---|---|
| **Matrix Synapse** | `v1.164.1` | **Apache License 2.0** | Serveur de messagerie souverain (Homeserver), gestion des salons, clés cryptographiques et contrôle d'accès. | [github.com/element-hq/synapse](https://github.com/element-hq/synapse) |
| **Element Web** | `v1.11.109` | **Apache License 2.0** | Interface utilisateur web moderne, déchiffrement local Megolm dans le navigateur. | [github.com/element-hq/element-web](https://github.com/element-hq/element-web) |
| **Authentik** | `2026.8.5` | **MIT License** | Fournisseur d'identité centralisé (IdP), OpenID Connect (OIDC) et second facteur obligatoire (MFA TOTP RFC 6238). | [github.com/goauthentik/authentik](https://github.com/goauthentik/authentik) |
| **PostgreSQL** | `16-alpine` | **PostgreSQL License** (compatible BSD/MIT) | Base de données relationnelle persistante pour Synapse et Authentik. Stockage exclusif de données chiffrées. | [postgresql.org](https://www.postgresql.org/about/licence/) |
| **Nginx** | `1.27-alpine` | **2-clause BSD License** | Reverse proxy frontal, terminaison TLS 1.3 locale et routage interne sécurisé. | [nginx.org](https://nginx.org/LICENSE) |
| **Docker Engine & Compose** | `≥ 24 / Compose v2` | **Apache License 2.0** | Orchestration, conteneurisation et segmentation réseau interne. | [github.com/docker/compose](https://github.com/docker/compose) |
| **Cryptography (Python)** | `≥ 42.0` | **Apache License 2.0 / BSD** | Primitives cryptographiques pour la suite de validation de sécurité et simulation client. | [github.com/pyca/cryptography](https://github.com/pyca/cryptography) |
| **gTTS (Google Text-to-Speech)** | `2.5.4` | **MIT License** | Outil d'ingénierie préliminaire pour la synthèse des 16 fichiers audio hors-ligne. Non requis à l'exécution en démonstration. | [github.com/pndurette/gTTS](https://github.com/pndurette/gTTS) |

---

## 3. Analyse des Obligations de Licence

1. **Licence Apache 2.0 (Synapse, Element Web, Docker Compose) :**
   - Autorise l'utilisation commerciale, la modification et la distribution sans redevance.
   - Obligation de conserver les mentions de copyright, la notice de licence et d'indiquer les modifications apportées.

2. **Licence MIT (Authentik) :**
   - Licence permissive autorisant la copie, modification, fusion et publication sous réserve d'inclure la notice de copyright d'origine.

3. **Licence PostgreSQL (PostgreSQL) :**
   - Licence libérale similaire à MIT/BSD autorisant toute utilisation sans restriction sous réserve de citation du copyright.

4. **Licence 2-clause BSD (Nginx) :**
   - Autorise la redistribution et l'utilisation sous forme source et binaire sous condition de maintien de la notice de copyright.

5. **Licence MIT (gTTS - Pierre Nicolas Durette) :**
   - Licence permissive autorisant l'utilisation pour la génération des fichiers audio préenregistrés sans restriction de distribution.

---

## 4. Licence du Projet Messagerie Souveraine BF

Le code original produit par l'équipe (scripts de déploiement, bancs de tests automatisés, configurations durcies, module d'alerte multilingue FasoVoice et documentation) est publié sous licence libre **Apache License 2.0** (fichier `LICENSE` à la racine du dépôt).

---

## 5. Propriété Intellectuelle et Licence des Ressources FasoVoice

1. **Corpus textuel de crise multilingue (`demo/fasovoice/messages.json`) :**
   - **Auteurs :** Équipe de développement Messagerie Souveraine BF (Hackathon 226).
   - **Contenu :** Textes d'alertes institutionnelles rédigés et traduits en langues Français, Mooré et Dioula.
   - **Droits :** L'équipe détient la pleine propriété intellectuelle originelle de ces formulations.
   - **Licence accordée :** Publié sous licence **Apache License 2.0** (Open Source), garantissant la libre réutilisation par les services publics du Burkina Faso.

2. **Enregistrements audio préenregistrés (`demo/fasovoice/audio/*.mp3`) :**
   - **Nature des données :** 16 fichiers audio MP3 matérialisant les alertes en Français, Mooré, Dioula et en version Trilingue complète.
   - **Processus de production :** Synthétisés localement à partir du corpus officiel de l'équipe sans dépendance runtime.
   - **Licence accordée :** Distribués sous licence libre **Creative Commons Attribution 4.0 International (CC-BY 4.0)** et **Apache License 2.0**. Aucune redevance ni restriction d'usage hors-ligne ne s'applique.
