# Scénario de Démonstration Officiel — Messagerie Souveraine BF
*Guide de présentation pour le jury du Hackathon 2026*

Ce document détaille le déroulement complet de la démonstration de la **Messagerie Souveraine BF**, prouvant le respect des exigences de sécurité, de souveraineté des données, d'authentification forte (OIDC + MFA TOTP), de chiffrement de bout en bout (E2EE Megolm) et de gouvernance administrative (révocation ciblée et désactivation).

---

## 1. Architecture et URLs de Démonstration

| Service | Rôle | URL d'accès | Protocole |
|---|---|---|---|
| **Element Web** | Interface utilisateur officielle | `https://messagerie.local` | HTTPS (TLS local) |
| **Matrix Synapse** | Serveur souverain de messagerie | `https://messagerie.local/_matrix/client/versions` | HTTPS (TLS local) |
| **Authentik** | Gestionnaire d'identité centralisé & MFA | `https://auth.messagerie.local` | HTTPS (TLS local) |
| **PostgreSQL** | Base de données souveraine | Interne Docker (`msb-internal`) | Chiffré au repos / E2EE |

---

## 2. Prérequis Techniques et Initialisation

### A. Démarrage des conteneurs
Les services doivent être démarrés et dans un état sain (`healthy`) :
```bash
cd ~/messagerie_souveraine_bf
docker compose ps
# Services attendus : msb-postgres, msb-synapse, msb-element, msb-proxy (tous Up)
# Authentik : authentik-server-1, authentik-worker-1, authentik-postgresql-1 (tous Up)
```

### B. Résolution DNS locale (Machine de démo)
Sur la machine hôte exécutant le navigateur, la résolution DNS doit être configurée dans `/etc/hosts` :
```bash
echo "127.0.0.1 messagerie.local auth.messagerie.local" | sudo tee -a /etc/hosts
```
*Vérification :*
```bash
ping -c 1 messagerie.local
```

### C. Confiance du Certificat TLS (Firefox)
L'autorité racine locale `mkcert` a été importée dans la base de certificats NSS de Firefox Snap (`cert9.db`) :
- Aucune exception de sécurité n'est requise si le profil par défaut est utilisé.
- Si un nouveau profil navigateur est ouvert ou si une alerte TLS s'affiche, accepter l'autorité locale `mkcert development CA` ou cliquer sur « Avancé » > « Accepter le risque et poursuivre ».

---

## 3. Comptes de Démonstration et Identifiants

Les comptes ont été pré-configurés dans Authentik et Matrix Synapse avec le flux MFA TOTP obligatoire.

| Identifiant | Rôle opérationnel | Mot de passe Authentik | Secret TOTP (Application OTP) |
|---|---|---|---|
| **`alice_test`** | Responsable ministériel | Mot de passe local (fichier sécurisé) | TOTP dynamique (secret local) |
| **`bob_test`** | Agent d'intervention | Mot de passe local (fichier sécurisé) | TOTP dynamique (secret local) |
| **`admin`** | Administrateur système Synapse | Accès de secours local (fichier sécurisé) | Compte de secours interne Synapse (API) |

### URIs pour configurateurs d'applications TOTP (Google Authenticator, FreeOTP, Aegis) :
- Clés TOTP chargées depuis le fichier local sécurisé, jamais intégrées à la documentation.
- Clés TOTP chargées depuis le fichier local sécurisé, jamais intégrées à la documentation.

*(Génération d'un code OTP en ligne de commande pour le présentateur) :*
```bash
# Générer le code TOTP actuel pour Alice
python3 -c "import hmac, base64, struct, hashlib, time; key=base64.b32decode("CHANGE_ME_TOTP_SECRET"); t=int(time.time()//30); msg=struct.pack('>Q', t); h=hmac.new(key, msg, hashlib.sha1).digest(); o=h[19]&15; code=(struct.unpack('>I', h[o:o+4])[0] & 0x7fffffff)%1000000; print(f'Code TOTP Alice: {code:06d}')"

# Générer le code TOTP actuel pour Bob
python3 -c "import hmac, base64, struct, hashlib, time; key=base64.b32decode("CHANGE_ME_TOTP_SECRET"); t=int(time.time()//30); msg=struct.pack('>Q', t); h=hmac.new(key, msg, hashlib.sha1).digest(); o=h[19]&15; code=(struct.unpack('>I', h[o:o+4])[0] & 0x7fffffff)%1000000; print(f'Code TOTP Bob: {code:06d}')"
```

---

## 4. Déroulement du Scénario Utilisateur dans Element Web

Ce parcours s'effectue avec **deux fenêtres de navigateur côte à côte** (ex: Fenêtre standard pour Alice, Fenêtre de navigation privée pour Bob).

```
+------------------------------------+   +------------------------------------+
|        Alice (Fenêtre Standard)    |   |      Bob (Navigation Privée)       |
|  https://messagerie.local          |   |  https://messagerie.local          |
|  @alice_test:messagerie.local      |   |  @bob_test:messagerie.local        |
+------------------------------------+   +------------------------------------+
```

### Étape 1 : Alice se connecte via Authentik
1. Ouvrir le navigateur sur `https://messagerie.local`.
2. L'interface **Element Web — Messagerie Souveraine BF** s'affiche.
3. Cliquer sur le bouton central **« Se connecter avec Authentik »**.
4. Le navigateur est redirigé de manière transparente vers `https://auth.messagerie.local`.

### Étape 2 : Alice valide son identité et son TOTP
1. Alice saisit son identifiant `alice_test` et son mot de passe `défini localement`.
2. Authentik demande immédiatement le **Code de sécurité à 6 chiffres (MFA TOTP)**.
3. *(Démonstration de refus optionnelle)* : Saisir `000000` -> Authentik rejette avec un message d'erreur.
4. Saisir le code TOTP valide généré par l'application (ou la commande ci-dessus).
5. Authentik valide l'authentification et redirige l'agent vers Synapse avec le code d'autorisation OIDC.

### Étape 3 : Alice accède à son espace sécurisé Element
1. Synapse valide le jeton OIDC et délivre une session Matrix.
2. Element Web affiche la page d'accueil de l'agent `@alice_test:messagerie.local`.
3. Noter que l'enregistrement public de compte tiers est désactivé sur le serveur : seuls les comptes provisionnés par l'administration sont autorisés.

### Étape 4 : Alice crée un salon privé chiffré
1. Alice clique sur l'icône **« + »** à côté de Salons > **« Nouveau salon »**.
2. Nom du salon : `Cellule de Crise Souveraine`.
3. Visibilité : **Salon privé** (par défaut).
4. Option de sécurité : Vérifier que l'option **« Activer le chiffrement de bout en bout »** est cochée (icône cadenas).
5. Cliquer sur **« Créer le salon »**.

### Étape 5 : Alice invite Bob
1. Dans le salon créé, cliquer sur le panneau latéral droit > **Inviter à ce salon**.
2. Saisir l'identifiant exact : `@bob_test:messagerie.local`.
3. Cliquer sur **« Inviter »**.
4. L'interface affiche l'invitation en attente.

### Étape 6 : Bob se connecte via Authentik et valide son TOTP
1. Ouvrir une **nouvelle fenêtre de navigation privée** sur `https://messagerie.local`.
2. Cliquer sur **« Se connecter avec Authentik »**.
3. Saisir `bob_test` et le mot de passe `défini localement`.
4. Saisir le code TOTP à 6 chiffres de Bob.
5. Bob accède à son interface Element Web en tant que `@bob_test:messagerie.local`.

### Étape 7 : Bob rejoint le salon chiffré
1. Dans la liste des salons de Bob, une invitation apparaît pour `Cellule de Crise Souveraine`.
2. Bob clique sur **« Rejoindre »**.
3. Les deux agents sont maintenant membres du salon privé chiffré.

### Étape 8 : Alice envoie un message confidentiel
1. Alice tape dans la zone de saisie :
   > *"Rapport de sécurité nationale : transmission chiffrée Megolm opérationnelle."*
2. Alice appuie sur Entrée.
3. Le message s'affiche avec le symbole de chiffrement (cadenas).

### Étape 9 : Bob reçoit et déchiffre le message
1. Sur la fenêtre de Bob, le message d'Alice apparaît instantanément en clair.
2. *(Note sur la vérification d'appareil)* : Si un bouclier gris ou rouge apparaît avec la mention "Appareils non vérifiés", c'est la protection native Matrix. Cliquer sur le message ou poursuivre : les clés de déchiffrement Megolm sont échangées automatiquement entre les deux sessions.

### Étape 10 : Bob répond de manière chiffrée
1. Bob saisit sa réponse :
   > *"Accusé de réception confirmé. Intégrité des échanges validée sur notre nœud souverain."*
2. Bob appuie sur Entrée.

### Étape 11 : Alice reçoit et déchiffre la réponse
1. Alice voit la réponse de Bob s'afficher immédiatement.
2. L'échange bidirectionnel chiffré de bout en bout est démontré.

---

## 5. Preuve de Souveraineté : Vérification en Base de Données

Pour prouver au jury que le serveur de messagerie ne stocke jamais les messages en clair :

Ouvrir un terminal sur la machine hôte :
```bash
docker exec msb-postgres psql -U synapse -d synapse -c \
  "SELECT event_id, type, stream_ordering, json_extract_path_text(convert_from(content::bytea, 'UTF8'), 'algorithm') AS algo FROM events WHERE type='m.room.encrypted' ORDER BY stream_ordering DESC LIMIT 3;"
```

**Résultat affiché :**
```
                    event_id                     |       type       | stream_ordering |         algo          
-------------------------------------------------+------------------+-----------------+-----------------------
 $1vX...                                         | m.room.encrypted |              32 | m.megolm.v1.aes-sha2
 $8pQ...                                         | m.room.encrypted |              31 | m.megolm.v1.aes-sha2
```
*Constat indiscutable :* Le serveur n'enregistre que des blocs chiffrés sous l'algorithme `m.megolm.v1.aes-sha2`. Aucun administrateur système ni attaquant ayant compromis la base de données ne peut lire les communications.

---

## 6. Démonstration des Capacités d'Administration et de Révocation

Cette séquence démontre la conformité avec les exigences de gouvernance et de réponse à incident.

### Étape A : Consultation des utilisateurs par l'administrateur
L'administrateur consulte l'inventaire des comptes depuis le terminal :
```bash
docker exec msb-postgres psql -U synapse -d synapse -c \
  "SELECT name, deactivated, admin FROM users ORDER BY creation_ts DESC LIMIT 6;"
```

### Étape B : Révocation ciblée d'un appareil (Appareil compromis ou perdu)
Lorsqu'un agent signale la perte d'un terminal (smartphone, tablette) :
1. Obtenir le token d'administration :
   ```bash
   ADMIN_TOKEN=$(curl -sk -X POST https://messagerie.local/_matrix/client/v3/login \
     --resolve messagerie.local:443:127.0.0.1 \
     -H "Content-Type: application/json" \
     -d '{"type":"m.login.password","user":"admin","password":"${ADMIN_PASSWORD}"}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
   ```
2. Lister les appareils d'un utilisateur :
   ```bash
   curl -sk --resolve messagerie.local:443:127.0.0.1 \
     "https://messagerie.local/_synapse/admin/v2/users/@bob_test:messagerie.local/devices" \
     -H "Authorization: Bearer $ADMIN_TOKEN" | python3 -m json.tool
   ```
3. Supprimer un appareil spécifique sans couper les autres appareils :
   ```bash
   # Remplacer DEVICE_ID par l'identifiant de l'appareil à révoquer
   curl -sk -X DELETE --resolve messagerie.local:443:127.0.0.1 \
     "https://messagerie.local/_synapse/admin/v2/users/@bob_test:messagerie.local/devices/<DEVICE_ID>" \
     -H "Authorization: Bearer $ADMIN_TOKEN"
   ```
4. **Constat :** La session de cet appareil est immédiatement invalidée (`HTTP 401 M_UNKNOWN_TOKEN`), tandis que les autres sessions de l'agent restent pleinement fonctionnelles.

### Étape C : Désactivation d'un compte utilisateur (Départ d'agent ou compromission)
1. Exécuter la désactivation via l'API Admin sur un compte de test :
   ```bash
   curl -sk -X POST --resolve messagerie.local:443:127.0.0.1 \
     "https://messagerie.local/_synapse/admin/v1/deactivate/@user_revoc_test:messagerie.local" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"erase": false}'
   ```
2. **Constat immédiat :**
   - Toutes les sessions actives de l'agent sont instantanément purgées du serveur (`HTTP 401 M_UNKNOWN_TOKEN`).
   - Toute nouvelle tentative de connexion est immédiatement bloquée par Synapse (`HTTP 403 M_FORBIDDEN` / `M_USER_DEACTIVATED`).
   - L'utilisateur est marqué `deactivated = 1` en base PostgreSQL.

---

## 7. Résultats Attendus et Limites Connues (Transparence Technique)

| Aspect | Résultat prouvé | Limite technique connue & explication |
|---|---|---|
| **MFA TOTP** | Imposé par Authentik, code invalide rejeté | Le serveur Matrix délègue l'authentification à Authentik via OIDC (standard PKCE). |
| **Chiffrement E2EE** | Seul du ciphertext Megolm présent en base PostgreSQL | Dans Element Web, un avertissement d'appareil non vérifié apparaît tant que les deux utilisateurs n'ont pas validé leurs clés mutuelles par émojis. |
| **Révocation d'accès** | Tokens d'accès immédiatement invalidés côté serveur | Les messages déjà reçus et déchiffrés localement dans le stockage navigateur (IndexedDB) restent en mémoire cache locale de la session avant coupure. |
| **Résolution DNS** | Entièrement locale via `/etc/hosts` (aucune fuite Internet) | Nécessite l'écriture de `127.0.0.1 messagerie.local` dans `/etc/hosts` sur chaque machine cliente accédant à la messagerie. |
| **Exposition réseau** | Reverse proxy restreint à `127.0.0.1` par défaut | Pour ouvrir la démonstration à d'autres postes du réseau local du hackathon, ajuster `MSB_BIND_ADDRESS=0.0.0.0` dans `.env` et redémarrer Nginx. |
