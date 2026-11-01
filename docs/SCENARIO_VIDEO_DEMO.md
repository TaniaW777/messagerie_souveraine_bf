# Scénario Officiel de Démonstration Vidéo — Messagerie Souveraine BF
*Guide de tournage, narration et conducteur technique pour la vidéo de présentation*

---

## Fiche Technique de la Démonstration

- **Projet :** Messagerie Souveraine BF (Hackathon 2026)
- **Durée totale indicative :** 12 à 14 minutes
- **Intervenants à l'écran :**
  - Fenêtre 1 (Standard) : **Alice** (`@alice_demo:messagerie.local`)
  - Fenêtre 2 (Navigation Privée) : **Bob** (`@bob_demo:messagerie.local`)
  - Fenêtre 3 (Terminal Linux) : Administrateur système
- **URLs officielles :**
  - Client web : `https://messagerie.local`
  - Gestionnaire d'identité : `https://auth.messagerie.local`
- **Prérequis d'enregistrement :**
  - Exécuter au préalable : `./scripts/demo_video_preflight.sh`
  - Les identifiants de démonstration sont stockés localement dans `.credentials_demo.local` (non public).

---

## Scène 1 — Présentation Globale du Projet
- **Durée indicative :** 1 minute 30
- **Visuel :** Titre du projet, schéma d'architecture ou page d'accueil d'Element Web.
- **Objectif :** Poser le cadre institutionnel et les impératifs de souveraineté numérique pour le Burkina Faso.
- **Actions :**
  1. Afficher la page d'accueil de la plateforme avec le logo et les armoiries de la Messagerie Souveraine BF.
  2. Présenter la pile logicielle retenue (Synapse, Element Web, PostgreSQL, Authentik, Nginx).
- **Narration orale suggérée :**
  > « Bonjour à tous. Nous vous présentons aujourd'hui la plateforme **Messagerie Souveraine BF**, une solution de communication sécurisée et souveraine conçue pour répondre aux exigences stratégiques des institutions et administrations publiques du Burkina Faso.
  > Face aux risques de surveillance et d'interruption de service des solutions tierces, notre architecture garantit une autonomie technologique totale : un serveur Matrix Synapse pour le routage souverain, un chiffrement de bout en bout Megolm inviolable, une délégation d'identité centralisée avec Authentik incluant une authentification multifacteur TOTP obligatoire, et une base de données PostgreSQL isolée. »

---

## Scène 2 — Infrastructure et État des Services
- **Durée indicative :** 1 minute 30
- **Visuel :** Terminal Linux.
- **Objectif :** Démontrer que l'infrastructure est saine, isolée et protégée sur le plan réseau.
- **Actions :**
  1. Exécuter le script de contrôle de santé :
     ```bash
     ./scripts/health_check.sh
     ```
  2. Montrer l'isolation des ports (tous liés sur `127.0.0.1`, aucun port sur `0.0.0.0`) :
     ```bash
     docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
     ```
- **Narration orale suggérée :**
  > « Avant de manipuler l'interface utilisateur, vérifions l'infrastructure sous-jacente. Notre script de contrôle automatisé confirme que l'ensemble des conteneurs — PostgreSQL, Synapse, Element Web, le proxy Nginx et Authentik — sont dans un état nominal et sain.
  > Remarquez la règle de durcissement réseau : aucun service interne n'est exposé sur l'adresse publique 0.0.0.0. Tout le trafic externe passe obligatoirement par notre reverse proxy TLS local. »

---

## Scène 3 — Authentification Forte (SSO OIDC + MFA TOTP)
- **Durée indicative :** 2 minutes
- **Visuel :** Navigateur Firefox sur `https://messagerie.local`.
- **Objectif :** Prouver l'intégration OIDC avec Authentik et l'application obligatoire du second facteur TOTP.
- **Actions :**
  1. Naviguer sur `https://messagerie.local`. Constater le cadenas TLS vert et l'absence de bouton d'inscription publique.
  2. Cliquer sur le bouton officiel **« Se connecter avec Authentik »**.
  3. Redirection automatique vers `https://auth.messagerie.local`.
  4. Saisir l'identifiant `alice_demo` et son mot de passe (extrait de `.credentials_demo.local`).
  5. *Test d'intégrité* : Saisir le mauvais code TOTP `000000` -> Montrer le rejet immédiat par Authentik.
  6. Saisir le code TOTP dynamique valide à 6 chiffres.
  7. Constater la redirection transparente vers Synapse et l'ouverture de la session Element Web pour `@alice_demo:messagerie.local`.
- **Narration orale suggérée :**
  > « Passons à l'authentification. Les inscriptions libres sont désactivées sur le serveur pour empêcher toute création de compte illégitime. Lorsqu'Alice se connecte, Element Web délègue l'authentification à notre fournisseur d'identité Authentik en OIDC.
  > Après validation du premier facteur mot de passe, Authentik exige immédiatement le second facteur TOTP. Si un code erroné est entré, l'accès est instantanément bloqué. Avec le code dynamique valide fourni par notre application d'authentification, Alice obtient son jeton sécurisé et accède à sa messagerie nominative. »

---

## Scène 4 — Création d'une Conversation Privée Chiffrée
- **Durée indicative :** 1 minute 30
- **Visuel :** Element Web (Alice à gauche) et ouverture de la fenêtre Bob (à droite).
- **Objectif :** Créer un salon privé avec chiffrement Megolm obligatoire et inviter un collaborateur.
- **Actions :**
  1. Alice clique sur « + » > « Nouveau salon ».
  2. Nom du salon : `Cellule de Crise Souveraine`.
  3. Vérifier que la visibilité est **Privée** et que le **Chiffrement de bout en bout (cadenas)** est actif.
  4. Alice invite `@bob_demo:messagerie.local`.
  5. Dans la deuxième fenêtre, Bob se connecte via Authentik (OIDC + TOTP).
  6. Bob reçoit la notification d'invitation et clique sur **« Rejoindre »**.
- **Narration orale suggérée :**
  > « Alice crée maintenant un salon de travail réservé à une cellule de crise. Le salon est configuré comme strictement privé avec le chiffrement de bout en bout Megolm imposé par défaut.
  > Alice invite son collègue Bob. De son côté, Bob s'authentifie avec son propre second facteur TOTP dans une session isolée. Dès sa connexion, il accepte l'invitation et intègre le salon sécurisé. »

---

## Scène 5 — Échanges en Temps Réel
- **Durée indicative :** 1 minute
- **Visuel :** Deux fenêtres côte à côte (Alice et Bob).
- **Objectif :** Démontrer la réactivité et la fluidité des communications chiffrées.
- **Actions :**
  1. Alice envoie : *"Ordre de mission : activation du protocole de transmission sécurisée."*
  2. Le message s'affiche instantanément chez Bob en clair avec le cadenas de chiffrement.
  3. Bob répond : *"Message reçu 5 sur 5. Chiffrement validé sur notre infrastructure locale."*
  4. Alice reçoit immédiatement la réponse.
- **Narration orale suggérée :**
  > « Nous observons ici l'échange bilatéral en temps réel. Pour les utilisateurs, l'expérience est transparente et instantanée : les messages sont déchiffrés localement dans le navigateur grâce aux clés cryptographiques échangées directement entre leurs sessions Element. »

---

## Scène 6 — Preuve de Souveraineté Cryptographique dans PostgreSQL
- **Durée indicative :** 2 minutes
- **Visuel :** Terminal Linux connecté à la base PostgreSQL.
- **Objectif :** Prouver au jury que le serveur de stockage ne peut pas lire le contenu des conversations (chiffrement Megolm au repos).
- **Actions :**
  1. Exécuter la requête SQL de vérification :
     ```bash
     docker exec msb-postgres psql -U synapse -d synapse -f /tests/postgres_validation.sql
     ```
     *(ou exécuter la requête ciblée sur events / event_json).*
  2. Montrer que la colonne `algorithm` vaut `m.megolm.v1.aes-sha2`.
  3. Montrer que la colonne `ciphertext` contient des blocs chiffrés en base64 de plusieurs centaines d'octets.
  4. Constater que la chaîne *"Ordre de mission"* ou *"Message reçu"* est introuvable dans la base :
     ```bash
     docker exec msb-postgres psql -U synapse -d synapse -c \
       "SELECT count(*) FROM event_json WHERE json::text LIKE '%Ordre de mission%';"
     ```
     *(Résultat affiché : 0).*
- **Narration orale suggérée :**
  > « Voici la preuve la plus importante de notre démarche souveraine. Si un attaquant ou un administrateur système indélicat accède directement à la base de données PostgreSQL de Synapse, que peut-il lire ? Rien.
  > Comme le prouve cette requête SQL, le serveur ne stocke que des blocs chiffrés sous l'algorithme Megolm v1 AES-SHA2. Une recherche textuelle sur les mots clés échangés renvoie zéro résultat. La confidentialité des secrets de l'État est mathématiquement protégée. »

---

## Scène 7 — Gestion des Accès et Révocation Immédiate
- **Durée indicative :** 2 minutes
- **Visuel :** Element Web et Terminal.
- **Objectif :** Démontrer le retrait d'un membre et la confirmation formelle que le serveur rejette toute tentative ultérieure d'envoi.
- **Actions :**
  1. Alice (administratrice du salon) retire Bob de la conversation (« Exclure du salon » / Kick).
  2. Côté Bob, l'accès au salon passe en lecture seule ou le salon disparaît de sa liste active.
  3. **Tentative d'envoi non autorisée par Bob** : Exécuter la tentative via l'API client avec le token de Bob :
     ```bash
     curl -sk -X PUT https://messagerie.local/_matrix/client/v3/rooms/<ROOM_ID>/send/m.room.message/txn_test \
       -H "Authorization: Bearer <TOKEN_BOB>" \
       -H "Content-Type: application/json" \
       -d '{"msgtype":"m.text","body":"Tentative illégitime"}'
     ```
  4. Montrer la réponse d'erreur HTTP 403 renvoyée par le serveur :
     ```json
     {"errcode":"M_FORBIDDEN","error":"User @bob_demo:messagerie.local not in room..."}
     ```
  5. Montrer dans PostgreSQL l'événement d'adhésion `leave` confirmant la clôture des droits de Bob.
- **Narration orale suggérée :**
  > « La souveraineté implique également la maîtrise du cycle de vie des accès. Lorsqu'un agent quitte une cellule ou que son habilitation est suspendue, l'administrateur peut révoquer son accès au salon.
  > Alice retire Bob. Si Bob tente d'émettre un nouveau message, Synapse rejette immédiatement la requête avec le code d'erreur standard M_FORBIDDEN. Le serveur garantit l'étanchéité des communications. »

---

## Scène 8 — Gouvernance et Sécurité Système
- **Durée indicative :** 1 minute 30
- **Visuel :** Terminal et console d'administration.
- **Objectif :** Présenter les mécanismes de défense en profondeur.
- **Actions :**
  1. Présenter la politique de rate-limiting `rc_login` configurée dans Synapse contre les attaques par force brute.
  2. Montrer que le compte administrateur de secours est fonctionnel et réservé à l'API d'administration.
  3. Montrer que les fichiers de secrets locaux sont protégés (`chmod 600`) et exclus de Git.
- **Narration orale suggérée :**
  > « Sur le plan de la gouvernance et de la sécurité système, notre plateforme intègre des limites de débit contre les attaques par déni de service et force brute, un compte d'administration d'urgence protégé et une hygiène rigoureuse des secrets : aucun mot de passe ni clé privée n'est consigné dans les dépôts versionnés. »

---

## Scène 9 — Conclusion et Perspectives
- **Durée indicative :** 1 minute
- **Visuel :** Écran récapitulatif des livrables et contacts.
- **Objectif :** Clôturer la démonstration sur un bilan positif et les perspectives de passage à l'échelle.
- **Actions :**
  1. Récapituler les 5 piliers validés : Authentification forte MFA, Chiffrement E2EE inviolable, Révocation active, Hébergement maîtrisé, Interface moderne et intuitive.
- **Narration orale suggérée :**
  > « En conclusion, Messagerie Souveraine BF démontre qu'il est possible de bâtir un système de messagerie hautement sécurisé, conforme aux standards internationaux Matrix et OIDC, entièrement maîtrisé sur notre infrastructure et prêt pour les besoins de communication critiques du Burkina Faso. Nous vous remercions pour votre attention. »
