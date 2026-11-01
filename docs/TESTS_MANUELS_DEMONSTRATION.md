# Guide de Tests Manuels et Démonstration — Messagerie Souveraine BF
*Procédure de validation pas-à-pas à destination du propriétaire du projet*
*Date : 31 Octobre 2026*

---

## Objectif du Guide

Ce document fournit un protocole d'exécution rigoureux et détaillé permettant au propriétaire du projet de tester manuellement et personnellement l'ensemble des fonctionnalités de la **Messagerie Souveraine BF** avant toute démonstration devant un jury ou toute mise en production.

Les tests distinguent clairement :
- Les **tests graphiques dans l'interface Element Web** (navigateur).
- Les **tests d'infrastructure et d'administration dans le terminal** (Docker / SQL / API Synapse).

---

## Prérequis Généraux aux Tests

Avant de démarrer les tests :

1. **Services actifs et sains :**
   ```bash
   cd ~/messagerie_souveraine_bf
   docker compose ps
   # msb-postgres, msb-synapse, msb-element, msb-proxy doivent être Up (healthy)
   ```
2. **Résolution DNS locale sur le poste de test :**
   Le fichier `/etc/hosts` de la machine exécutant le navigateur doit contenir :
   ```
   127.0.0.1   messagerie.local
   127.0.0.1   auth.messagerie.local
   ```
3. **Certificat TLS :**
   Le certificat local `mkcert` a été intégré dans la base NSS de Firefox Snap (`cert9.db`). L'accès à `https://messagerie.local` et `https://auth.messagerie.local` s'effectue en HTTPS sécurisé sans avertissement de sécurité.
4. **Comptes et secrets existants :**
   - Utiliser les identifiants existants consignés dans votre environnement local (`demo/scenario.md`).
   - Disposer de votre application d'authentification TOTP (Google Authenticator, Aegis, FreeOTP) déjà synchronisée avec les comptes d'Alice et Bob.
5. **Préparation du navigateur :**
   - Prévoir **deux fenêtres de navigation distinctes** :
     - Fenêtre 1 (Standard) : pour l'agent **Alice**.
     - Fenêtre 2 (Navigation Privée) : pour l'agent **Bob**.

---

## Protocole des Tests Manuels (TEST 1 à 12)

### TEST 1 : Accès à l'interface Element Web
- **Nature du test :** Graphique (Navigateur).
- **URL à ouvrir :** `https://messagerie.local`
- **Action :** Ouvrir Firefox et naviguer vers l'adresse indiquée.
- **Ce qui doit apparaître :**
  - Le cadenas HTTPS vert/sécurisé est affiché dans la barre d'adresse.
  - La page d'accueil personnalisée **Element Web — Messagerie Souveraine BF** s'affiche.
  - Le serveur Matrix par défaut est pré-rempli (`messagerie.local`).
  - Aucun lien d'inscription publique libre n'est proposé.
  - Un bouton central officiel **« Se connecter avec Authentik »** est visible.
- **Résultat attendu :** L'interface web se charge correctement sans aucune erreur de réseau ni d'alerte de certificat.
- **Comment savoir si le test est réussi :** L'écran de connexion présente le bouton de délégation d'identité Authentik.

---

### TEST 2 : Connexion avec Alice via Authentik
- **Nature du test :** Graphique (Navigateur).
- **URL initiale :** `https://messagerie.local`
- **Action :**
  1. Cliquer sur le bouton **« Se connecter avec Authentik »**.
  2. Le navigateur est redirigé vers `https://auth.messagerie.local`.
  3. Dans le formulaire Authentik, saisir l'identifiant d'Alice (`alice_demo`).
  4. Saisir le mot de passe d'Alice (identifiant de démonstration configuré localement).
  5. Cliquer sur **« Continuer »** (ou « Se connecter »).
- **Ce qui doit apparaître :** Le formulaire de saisie des identifiants laisse place à l'écran de demande du second facteur (MFA).
- **Résultat attendu :** Le premier facteur (mot de passe) est validé par Authentik, qui déclenche l'étape TOTP obligatoire.
- **Comment savoir si le test est réussi :** Authentik affiche un champ de saisie intitulé « Code d'authentification » ou « TOTP Authenticator ».

---

### TEST 3 : Validation du Second Facteur TOTP
- **Nature du test :** Graphique (Navigateur).
- **URL :** `https://auth.messagerie.local`
- **Action :**
  1. *(Test d'intégrité optionnel)* : Taper le code erroné `000000` et valider. Constater le refus immédiat avec un message d'erreur rouge.
  2. Ouvrir votre application d'authentification TOTP synchronisée avec le compte d'Alice (ou exécuter la commande de calcul OTP locale décrite dans `demo/scenario.md`).
  3. Saisir le code dynamique valide à 6 chiffres.
  4. Cliquer sur **« Valider »**.
- **Ce qui doit apparaître :** Le navigateur valide l'étape, transite brièvement par l'URL de redirection Synapse `/_synapse/client/oidc/callback`, puis bascule automatiquement sur Element Web.
- **Résultat attendu :** Authentik émet le code d'autorisation OIDC, Synapse valide l'échange de jetons et génère une session Matrix.
- **Comment savoir si le test est réussi :** Aucune erreur n'apparaît et la page bascule sur le tableau de bord de messagerie.

---

### TEST 4 : Accès au compte Matrix d'Alice
- **Nature du test :** Graphique (Navigateur).
- **URL :** `https://messagerie.local/#/home`
- **Où regarder :** En haut à gauche de l'interface Element Web, au niveau du profil utilisateur.
- **Ce qui doit apparaître :**
  - L'avatar utilisateur affiche l'identifiant `@alice_demo:messagerie.local`.
  - La barre latérale gauche liste les espaces et salons.
  - L'interface est pleinement opérationnelle et connectée en temps réel.
- **Résultat attendu :** Alice est connectée avec une session Matrix nominative sans avoir eu à saisir de mot de passe directement dans Synapse.
- **Comment savoir si le test est réussi :** L'identifiant complet `@alice_demo:messagerie.local` est confirmé dans les paramètres de profil.

---

### TEST 5 : Création d'un salon privé chiffré
- **Nature du test :** Graphique (Navigateur).
- **Où cliquer :**
  1. Dans la colonne de gauche, cliquer sur le bouton **« + »** à côté du titre **Salons**.
  2. Sélectionner **« Nouveau salon »**.
- **Actions dans la fenêtre modale :**
  1. Nom du salon : `Cellule de Crise Souveraine`.
  2. Visibilité : Conserver l'option par défaut **« Salon privé (sur invitation seulement) »**.
  3. Sécurité : Vérifier impérativement que l'interrupteur **« Activer le chiffrement de bout en bout »** est coché (icône cadenas).
  4. Cliquer sur **« Créer le salon »**.
- **Ce qui doit apparaître :**
  - Le salon s'ouvre dans la zone principale.
  - Un message système au centre indique : *"alice_demo a activé le chiffrement de bout en bout (algorithme m.megolm.v1.aes-sha2)"*.
  - Une icône de cadenas est visible dans l'en-tête du salon.
- **Résultat attendu :** Le salon est instancié avec le module cryptographique Megolm activé.
- **Comment savoir si le test est réussi :** Présence de la notification d'activation du chiffrement et de l'icône de cadenas.

---

### TEST 6 : Invitation de Bob
- **Nature du test :** Graphique (Navigateur).
- **Où cliquer :**
  1. Dans le salon chiffré créé, cliquer sur l'icône **Membres** (panneau latéral droit) ou sur le bouton **« Inviter dans ce salon »**.
  2. Saisir l'identifiant exact : `@bob_demo:messagerie.local`.
  3. Sélectionner Bob dans les résultats et cliquer sur **« Inviter »**.
- **Ce qui doit apparaître :**
  - Un message d'événement s'affiche dans le fil de discussion : *"alice_demo a invité bob_demo"*.
  - Dans la liste des membres, Bob apparaît avec la mention *"Invité"*.
- **Résultat attendu :** L'événement d'invitation d'état de salon est propagé par le serveur Synapse.
- **Comment savoir si le test est réussi :** L'invitation est visible en attente dans la liste des membres.

---

### TEST 7 : Connexion de Bob dans une fenêtre privée
- **Nature du test :** Graphique (Navigateur — Deuxième fenêtre).
- **Action :**
  1. Ouvrir une **nouvelle fenêtre de navigation privée** dans Firefox (`Ctrl+Shift+P`).
  2. Naviguer vers `https://messagerie.local`.
  3. Cliquer sur **« Se connecter avec Authentik »**.
  4. Saisir l'identifiant de Bob (`bob_demo`) et son mot de passe existant.
  5. Saisir le code TOTP valide à 6 chiffres associé au secret de Bob.
  6. Valider et accéder à Element Web sous le compte `@bob_demo:messagerie.local`.
  7. Dans la liste des salons à gauche, localiser l'invitation en surbrillance pour `Cellule de Crise Souveraine`.
  8. Cliquer sur **« Rejoindre »**.
- **Ce qui doit apparaître :**
  - Bob entre dans le salon chiffré.
  - Dans les deux fenêtres (Alice et Bob), l'événement système indique : *"bob_demo a rejoint le salon"*.
- **Résultat attendu :** Les deux utilisateurs sont désormais co-participants du salon sécurisé.
- **Comment savoir si le test est réussi :** Bob a accès à la zone de saisie du salon et l'icône cadenas est présente.

---

### TEST 8 : Échange bidirectionnel de messages
- **Nature du test :** Graphique (Navigateur — Deux fenêtres côte à côte).
- **Actions pas-à-pas :**
  1. **Depuis la fenêtre d'Alice :**
     - Saisir le message : `Transmission confidentielle test : message chiffré de bout en bout.`
     - Appuyer sur Entrée.
  2. **Vérification sur la fenêtre de Bob :**
     - Le message apparaît en quelques millisecondes.
     - Le texte est lisible en clair sur le terminal de Bob.
     - *(Note sur les avertissements de sécurité)* : Si un bouclier gris/rouge indique *"Appareils non vérifiés"*, cliquer sur continuer : il s'agit de la protection native Matrix prévenant qu'aucun échange d'émojis croisé n'a encore été réalisé.
  3. **Depuis la fenêtre de Bob :**
     - Saisir la réponse : `Bien reçu Alice, canal souverain parfaitement opérationnel.`
     - Appuyer sur Entrée.
  4. **Vérification sur la fenêtre d'Alice :**
     - La réponse de Bob apparaît instantanément en clair.
- **Résultat attendu :** La communication bidirectionnelle fonctionne sans encombre.
- **Comment savoir si le test est réussi :** Les deux interlocuteurs lisent parfaitement leurs messages respectifs.

---

### TEST 9 : Vérification du chiffrement en base PostgreSQL (Preuve Souveraine)
- **Nature du test :** Commande Terminal.
- **Contexte :** Prouver que Synapse et PostgreSQL ne stockent que du texte chiffré illisible, garantissant qu'aucune indiscrétion n'est possible sur le serveur.
- **Commande à exécuter sur la machine hôte :**
  ```bash
  docker exec msb-postgres psql -U synapse -d synapse -c "
  SELECT
      e.event_id,
      e.type,
      e.stream_ordering,
      (ej.json::jsonb -> 'content' ->> 'algorithm') AS algorithme,
      CASE
          WHEN (ej.json::jsonb -> 'content' ->> 'ciphertext') IS NOT NULL
          THEN 'Présent (' || LENGTH(ej.json::jsonb -> 'content' ->> 'ciphertext') || ' octets)'
          ELSE 'Absent'
      END AS presence_ciphertext
  FROM events e
  JOIN event_json ej ON e.event_id = ej.event_id
  WHERE e.type = 'm.room.encrypted'
  ORDER BY e.stream_ordering DESC
  LIMIT 5;
  "
  ```
- **Ce qui doit apparaître :**
  Un tableau SQL contenant les événements récents avec :
  - `type` : `m.room.encrypted`
  - `algorithme` : `m.megolm.v1.aes-sha2`
  - `presence_ciphertext` : `Présent (X octets)`
- **Résultat attendu :** Aucun mot en clair des phrases envoyées au TEST 8 n'existe dans la base de données.
- **Comment savoir si le test est réussi :** La présence du ciphertext Megolm est confirmée par PostgreSQL pour chaque message envoyé.

---

### TEST 10 : Consultation des appareils et sessions
- **Nature du test :** Mixte (Graphique Element + Commande Terminal).
- **A. Vérification Graphique dans Element :**
  1. Cliquer sur l'avatar d'Alice ou Bob (en haut à gauche) > **« Tous les paramètres »**.
  2. Cliquer sur l'onglet **« Sécurité & Vie privée »** (ou « Sessions »).
  3. Vérifier la liste des sessions actives : le navigateur actuel apparaît avec son identifiant de session unique (`Device ID`), son nom de navigateur et l'adresse IP cliente `127.0.0.1`.
- **B. Vérification via l'API d'Administration Synapse (Terminal) :**
  ```bash
  # 1. Obtenir le jeton administrateur depuis le compte de secours local
  ADMIN_TOKEN=$(curl -sk -X POST https://messagerie.local/_matrix/client/v3/login \
    --resolve messagerie.local:443:127.0.0.1 \
    -H "Content-Type: application/json" \
    -d '{"type":"m.login.password","user":"admin","password":"<MOT_DE_PASSE_ADMIN_EXISTANT>"}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")

  # 2. Interroger la liste des appareils de Bob
  curl -sk --resolve messagerie.local:443:127.0.0.1 \
    "https://messagerie.local/_synapse/admin/v2/users/@bob_demo:messagerie.local/devices" \
    -H "Authorization: Bearer $ADMIN_TOKEN" | python3 -m json.tool
  ```
- **Ce qui doit apparaître :** Une structure JSON listant les appareils avec `device_id`, `display_name`, `last_seen_ip` et `last_seen_ts`.
- **Résultat attendu :** L'administrateur a une visibilité complète sur le parc d'appareils connectés.
- **Comment savoir si le test est réussi :** L'appareil utilisé par Bob dans la fenêtre privée est listé dans la réponse API.

---

### TEST 11 : Désactivation d'un compte de test
- **Nature du test :** Commande Terminal.
- ⚠️ **RÈGLE DE SÉCURITÉ ABSOLUE :**
  **Ne réalisez PAS ce test sur `alice_demo`, `bob_demo`, ni `admin`** afin de préserver votre environnement de démonstration.
  Utilisez exclusivement le compte dédié prévu à cet effet : `@user_revoc_test:messagerie.local` (ou un compte temporaire jetable).
- **Commande à exécuter :**
  ```bash
  # Désactiver le compte de test dédié via l'API Admin Synapse
  curl -sk -X POST --resolve messagerie.local:443:127.0.0.1 \
    "https://messagerie.local/_synapse/admin/v1/deactivate/@user_revoc_test:messagerie.local" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"erase": false}'
  ```
- **Ce qui doit apparaître :** Réponse HTTP 200 : `{"id_server_unbind_result": "success"}`.
- **Contrôle en base PostgreSQL :**
  ```bash
  docker exec msb-postgres psql -U synapse -d synapse -c \
    "SELECT name, deactivated FROM users WHERE name='@user_revoc_test:messagerie.local';"
  ```
- **Résultat attendu :** La colonne `deactivated` passe à `1`.
- **Comment savoir si le test est réussi :** Le compte est marqué comme formellement désactivé dans Synapse et toutes ses sessions actives sont immédiatement révoquées côté serveur (`HTTP 401 M_UNKNOWN_TOKEN`).

---

### TEST 12 : Vérification du refus de connexion après désactivation
- **Nature du test :** Commande Terminal (ou tentative dans le navigateur).
- **Commande à exécuter :**
  ```bash
  curl -sk -X POST https://messagerie.local/_matrix/client/v3/login \
    --resolve messagerie.local:443:127.0.0.1 \
    -H "Content-Type: application/json" \
    -d '{"type":"m.login.password","user":"user_revoc_test","password":"PasswordInvalide123!"}'
  ```
- **Ce qui doit apparaître :** Une erreur HTTP 403 avec le code JSON d'erreur :
  ```json
  {
    "errcode": "M_FORBIDDEN",
    "error": "This account has been deactivated"
  }
  ```
- **Résultat attendu :** Synapse refuse catégoriquement d'authentifier un compte désactivé.
- **Comment savoir si le test est réussi :** Le serveur renvoie un code de refus `M_FORBIDDEN` / `M_USER_DEACTIVATED` et aucune session n'est délivrée.

---

## Synthèse d'Évaluation des Tests Manuels

| N° | Intitulé | Modalité | Statut attendu |
|---|---|---|---|
| **TEST 1** | Accès à Element Web | Graphique | ✅ Succès (HTTPS 200) |
| **TEST 2** | Connexion Alice via Authentik | Graphique | ✅ Succès (Redirection OIDC) |
| **TEST 3** | Validation TOTP Alice | Graphique | ✅ Succès (Code 6 chiffres validé) |
| **TEST 4** | Accès espace Matrix Alice | Graphique | ✅ Succès (Session `@alice_demo`) |
| **TEST 5** | Création salon chiffré E2EE | Graphique | ✅ Succès (Cadenas Megolm actif) |
| **TEST 6** | Invitation de Bob | Graphique | ✅ Succès (Invitation émise) |
| **TEST 7** | Connexion & adhésion Bob | Graphique | ✅ Succès (Session `@bob_demo` active) |
| **TEST 8** | Dialogue chiffré bidirectionnel | Graphique | ✅ Succès (Messages déchiffrés) |
| **TEST 9** | Preuve SQL chiffrement serveur | Terminal | ✅ Succès (Ciphertext seul en base) |
| **TEST 10** | Inventaire des appareils connectés | Mixte | ✅ Succès (Sessions listées) |
| **TEST 11** | Désactivation compte de test | Terminal | ✅ Succès (Statut désactivé `1`) |
| **TEST 12** | Refus de connexion post-révocation | Terminal | ✅ Succès (Rejet HTTP 403) |

---

## ROTATION DES IDENTIFIANTS APRÈS VALIDATION

> ⚠️ **IMPORTANT :**
> Ne réalisez cette procédure **qu'après avoir achevé tous vos tests de validation** avec les comptes de démonstration actuels.
> Cette procédure garantit la transition d'un prototype de démonstration vers un environnement sécurisé réservé à l'équipe.

### 1. Changement des mots de passe d'Alice et de Bob
Les mots de passe des utilisateurs ordinaires sont hébergés souverainement dans Authentik.
- **Option Interface Graphique :**
  1. Se connecter en tant qu'administrateur sur `https://auth.messagerie.local` avec le compte administrateur Authentik.
  2. Aller dans **Administration** > **Répertoire** > **Utilisateurs**.
  3. Cliquer sur l'utilisateur `alice_demo` (puis `bob_demo`).
  4. Choisir **« Définir le mot de passe »**, saisir le nouveau mot de passe fort et valider.
- **Option Ligne de Commande (Authentik Shell) :**
  ```bash
  sg docker -c "docker exec authentik-server-1 ak shell -c '
  from authentik.core.models import User
  u = User.objects.get(username=\"alice_demo\")
  u.set_password(\"NOUVEAU_MOT_DE_PASSE_ALICE_FORT\")
  u.save()
  b = User.objects.get(username=\"bob_demo\")
  b.set_password(\"NOUVEAU_MOT_DE_PASSE_BOB_FORT\")
  b.save()
  print(\"Mots de passe mis à jour avec succès.\")
  '"
  ```

### 2. Suppression des anciens appareils TOTP
Pour révoquer les clés TOTP de démonstration utilisées durant le hackathon :
```bash
sg docker -c "docker exec authentik-server-1 ak shell -c '
from authentik.stages.authenticator_totp.models import TOTPDevice
deleted, _ = TOTPDevice.objects.filter(user__username__in=[\"alice_demo\", \"bob_demo\"]).delete()
print(f\"{deleted} anciens périphériques TOTP supprimés.\")
'"
```

### 3. Réenrôlement des nouveaux appareils TOTP
1. Lors de la prochaine connexion d'Alice et Bob sur `https://messagerie.local`, après la saisie de leur nouveau mot de passe, Authentik constatera l'absence d'appareil TOTP configuré.
2. Authentik affichera un **nouveau QR Code unique**.
3. Chaque agent devra scanner ce nouveau QR Code avec son application d'authentification personnelle (Google Authenticator, Aegis, FreeOTP) et saisir le code de confirmation pour finaliser l'enrôlement.

### 4. Changement du mot de passe de l'administrateur Synapse
Le compte administrateur local de secours (`admin`) est géré directement dans Synapse :
```bash
# Générer un nouveau mot de passe fort
NEW_ADMIN_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
echo "Nouveau mot de passe admin de secours : $NEW_ADMIN_PASS"

# Mettre à jour le mot de passe de secours
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u admin \
  -p "$NEW_ADMIN_PASS" \
  --admin \
  http://localhost:8008
```

### 5. Vérification de l'invalidation des anciens identifiants
1. Tenter une connexion avec l'ancien mot de passe de démonstration : elle doit être immédiatement refusée par Authentik.
2. Tenter une génération TOTP avec l'ancienne clé secrète de démonstration : elle doit être rejetée lors de la phase de validation TOTP.
3. Vérifier que seules les nouvelles clés et nouveaux mots de passe permettent d'accéder au service.
