# Note de Sécurité et Minimisation des Métadonnées
## Messagerie Souveraine BF — Hackathon 226 (Édition 2026)
*Conforme aux exigences de la Section ❸ du règlement officiel (Note de sécurité de 2 pages)*  
*Date d'audit & version : 1er Novembre 2026 — v2.0*

---

## 1. Périmètre du Système

La plateforme **Messagerie Souveraine BF** comprend l'intégralité des briques logicielles suivantes, hébergées en environnement clos sans aucune dépendance à des services cloud tiers :
- **Serveur de messagerie :** Matrix Synapse v1.164.1 durci.
- **Client utilisateur :** Element Web v1.11.109 personnalisé.
- **Fournisseur d'identité (IdP) :** Authentik 2026.8.5 avec flux OIDC PKCE.
- **Base de données persistante :** PostgreSQL 16 (réseau interne isolé).
- **Reverse proxy & terminaison TLS :** Nginx 1.27 (TLS 1.2/1.3, ports 127.0.0.1).
- **Module d'innovation multilingue :** Console de crise locale FasoVoice.

---

## 2. Actifs à Protéger

1. **Confidentialité des échanges :** Contenu textuel des conversations, notes de service et documents échangés entre agents de l'État.
2. **Intégrité des pièces jointes :** Fichiers confidentiels, ordres de mission, cartes d'intervention.
3. **Identité et habilitations des agents :** Annuaire d'État, identifiants, facteurs d'authentification (mots de passe hachés, secrets TOTP).
4. **Disponibilité opérationnelle :** Continuité de service de la messagerie en cas de crise ou d'incident réseau extérieur.
5. **Clés cryptographiques souveraines :** Clés privées de signature du homeserver (`*.signing.key`), clés d'identité des sessions.

---

## 3. Menaces Identifiées (Modèle de Menaces)

| Menace | Vecteur d'attaque | Niveau de risque |
|---|---|---|
| **Interception réseau (Man-in-the-Middle)** | Écoute passive ou active sur le réseau local ou étatique. | Élevé |
| **Compromission du serveur / Base de données** | Attaquant ou administrateur système indélicat accédant à PostgreSQL. | Critique |
| **Usurpation d'identité d'un agent** | Vol de mot de passe, hameçonnage ou force brute sur les comptes. | Élevé |
| **Intrusion d'un compte non enrôlé** | Tentative d'auto-enregistrement libre ou accès à un salon réservé. | Critique |
| **Perte ou vol d'un terminal mobile/PC** | Accès physique non autorisé aux sessions et clés locales d'un agent. | Élevé |
| **Fuite extraterritoriale par fédération** | Synchronisation non désirée avec un serveur Matrix étranger. | Critique |

---

## 4. Mesures de Protection Appliquées

- **Chiffrement fort de bout en bout (E2EE) :** Algorithme Megolm v1 AES-SHA2 appliqué par défaut à tous les salons.
- **Double facteur d'authentification obligatoire :** Imposition du TOTP dynamique (RFC 6238) via Authentik pour tous les agents.
- **Fermeture stricte des enregistrements :** `enable_registration: false` et `allow_guest_registration: false` dans Synapse.
- **Segmentation réseau étanche :** La base PostgreSQL ne possède aucun port publié vers l'hôte. Nginx lie les ports applicatifs strictement sur `127.0.0.1`.
- **Désactivation totale de la fédération :** `federation_domain_whitelist: []` et retrait des ressources de fédération du listener.
- **Limitation de débit (Rate-Limiting) :** Configuration `rc_login` anti-bruteforce active sur Synapse et Authentik.

---

## 5. Chiffrement de Bout en Bout (Messages)

Les messages échangés entre agents sont chiffrés directement dans le navigateur client par la bibliothèque Megolm :
- Le serveur Synapse ne reçoit que des événements de type `m.room.encrypted`.
- Dans la base PostgreSQL, le champ `ciphertext` stocke exclusivement des blocs binaires chiffrés en base64.
- Le serveur ne possède pas la clé de déchiffrement de session Megolm. Même sous contrainte judiciaire ou intrusion physique dans le serveur, le texte des messages est illisible.

---

## 6. Gestion des Identités et Rôles

- L'authentification est déléguée à Authentik via le protocole OIDC avec échange PKCE (Proof Key for Code Exchange).
- Les comptes sont provisionnés nominativement par l'administration dans le groupe `Agents Messagerie Souveraine`.
- Seul un compte administrateur d'urgence natif (`@admin:messagerie.local`) dispose d'une clé de secours locale pour les opérations de maintenance de l'API.

---

## 7. Protection des Fichiers et Pièces Jointes

- **Chiffrement symétrique côté client :** Chaque fichier est chiffré en AES-256-CTR par le client avant téléversement vers `/_matrix/media/v3/upload`.
- **Isolation des clés :** La clé de déchiffrement (256 bits), le vecteur d'initialisation (IV) et le condensat SHA-256 sont encapsulés dans le message Megolm, transmis uniquement aux membres autorisés du salon.
- **Stockage serveur opaque :** Le répertoire `/data/media_store` de Synapse ne contient que des flux d'octets chiffrés, inutilisables sans la clé détenue par les terminaux.

---

## 8. Fédération et Souveraineté Territoriale

Pour garantir l'autonomie stratégique du Burkina Faso :
- Toute fédération inter-domaines est bloquée par la directive `federation_domain_whitelist: []`.
- Les requêtes sur les endpoints `/_matrix/federation/` sont rejetées (HTTP 404 / 403). Aucune métadonnée ni événement ne transite hors du périmètre national.

---

## 9. Journalisation et Traçabilité

- Les journaux Synapse et Authentik consignent les événements de connexion, les échecs d'authentification et les adresses IP clientes.
- Les requêtes sensibles sont tracées avec un identifiant de corrélation (`Synapse-Trace-Id`).
- Aucun secret, mot de passe ou clé cryptographique n'est écrit dans les logs applicatifs.

---

## 10. Métadonnées Visibles par le Serveur et Minimisation

Le chiffrement de bout en bout protège le **contenu** des messages, mais **ne garantit pas l'anonymat absolu** des échanges. Par conception du protocole Matrix, le serveur et les administrateurs ont visibilité sur les métadonnées suivantes :

| Métadonnée visible | Nature et visibilité par le serveur | Mesure de minimisation appliquée |
|---|---|---|
| **Identifiants des correspondants** | Le serveur sait quel agent (`@alice_demo`) échange dans quel salon (`!room_id`). | Salons privés stricts, pas d'annuaire public, pseudonymes opérationnels possibles. |
| **Horodatage des messages** | Date, heure et seconde de chaque envoi (`stream_ordering`, `origin_server_ts`). | Nécessaire au séquencement distribué des événements. |
| **Volume et taille des messages** | Taille en octets du bloc chiffré (ex: 424 octets). | Le chiffrement par blocs et le padding masquent la longueur exacte du texte en clair. |
| **Taille des pièces jointes** | Taille du fichier chiffré stocké dans le media store. | Fichiers chiffrés sans extension apparente sur le système de fichiers serveur. |
| **Adresses IP des clients** | Enregistrées dans les en-têtes réseau Nginx (`$remote_addr`) et Synapse. | Masquage interne derrière le reverse proxy local, purge périodique des tables de logs. |
| **Topologie des salons** | Liste des membres ayant rejoint ou quitté un salon (`m.room.member`). | Directive `forget_rooms_on_leave: true` pour purger la mémoire d'appartenance après kick. |

---

## 11. Limites de Sécurité Connues (Transparence Technique)

1. **Stockage local des clients (IndexedDB) :**
   - Lorsqu'un agent déchiffre un message, celui-ci est mis en cache dans la base locale (IndexedDB) de son navigateur.
   - **Conséquence :** Une révocation administrative coupe instantanément l'envoi et la réception de tout *nouveau* message, mais ne peut pas effacer à distance les messages déjà déchiffrés stockés sur le terminal sans agent MDM (Mobile Device Management) sur le système hôte.
2. **Certificats TLS de développement :**
   - L'environnement de démonstration utilise une autorité racine locale (mkcert / OpenSSL). Pour un passage en production à l'échelle nationale, une PKI d'État (ANSSI-BF) devra émettre les certificats X.509 officiels.
3. **Résolution DNS locale :**
   - Les noms `messagerie.local` et `auth.messagerie.local` dépendent de la résolution statique `/etc/hosts` sur les machines clientes.

---

## 12. Risques Résiduels et Recommandations pour la Production

1. **Intégration d'un HSM (Hardware Security Module) :** Sécuriser la clé de signature Synapse (`signing.key`) dans un boîtier cryptographique certifié.
2. **Couplage OIDC Backchannel Logout :** Automatiser la purge des sessions Synapse dès la déconnexion dans Authentik.
3. **Déploiement d'un agent MDM souverain :** Compléter la plateforme avec un gestionnaire de flotte pour effacer à distance les caches locaux en cas de vol de terminal.
