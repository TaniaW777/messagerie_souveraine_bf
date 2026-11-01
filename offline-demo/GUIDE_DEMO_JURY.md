# 🇧🇫 GUIDE OFFICIEL DE DÉMONSTRATION DEVANT LE JURY
## Sprint Technique Pré-Hackathon 226 — Édition 2026 (MTDPCE / DGTD)
**Challenge :** La messagerie souveraine de l'administration  
**Niveau d'engagement open source :** « Étendre et adapter » (Matrix Synapse, Element Web, Authentik)  
**Durée de l'entretien technique :** 15 minutes chrono (Éliminatoire)

---

## 📋 SOMMAIRE RAPIDE

1. [Tous les Identifiants et Secrets de Test (La Totale)](#1-tous-les-identifiants-et-secrets-de-test-la-totale)
2. [Générateur de Codes TOTP en 1 Clic](#2-générateur-de-codes-totp-en-1-clic)
3. [Chronogramme de l'Entretien (15 Minutes Chrono)](#3-chronogramme-de-lentretien-15-minutes-chrono)
4. [SÉQUENCE 1 (00:00 - 03:00) : Pitch & Architecture (3 min)](#séquence-1-0000---0300--pitch--architecture-3-min)
5. [SÉQUENCE 2 (03:00 - 11:00) : Les 5 Épreuves Tirées au Sort (8 min)](#séquence-2-0300---1100--les-5-épreuves-tirées-au-sort-8-min)
   - [Épreuve A : « Le serveur ne lit rien »](#épreuve-a--le-serveur-ne-lit-rien-inspection-base-de-données--trafic)
   - [Épreuve B : « Révocation »](#épreuve-b--révocation-immédiate-dun-agent-en-plein-échange)
   - [Épreuve C : « Intrus »](#épreuve-c--rejet-strict-dun-intrus-non-enrôlé)
   - [Épreuve D : « Innovation » (FasoVoice & Sentinel BF)](#épreuve-d--innovation-endogène-fasovoice--sentinel-bf)
   - [Épreuve E : « Explication du code »](#épreuve-e--explication-du-code-cryptographie--authentification)
6. [SÉQUENCE 3 (11:00 - 15:00) : Questions Pièges du Jury & Réponses En Béton (4 min)](#séquence-3-1100---1500--questions-du-jury--réponses-en-béton-4-min)
7. [Fiche Mémo des Commandes d'Urgence](#7-fiche-mémo-des-commandes-durgence)

---

## 1. TOUS LES IDENTIFIANTS ET SECRETS DE TEST (LA TOTALE)

> **⚠️ RÈGLE OFFICIELLE :** Seules des données et des comptes fictifs sont autorisés. Aucune donnée personnelle réelle.

### 🌐 Points d'Accès de la Plateforme (100% Hors-Ligne)

| Service | URL dans le navigateur | Description |
|---|---|---|
| **Element Web** | `https://messagerie.local` | Interface de messagerie chiffrée |
| **Authentik SSO** | `https://auth.messagerie.local` | Portail d'identité étatique & MFA TOTP |
| **FasoVoice Console** | `https://messagerie.local/fasovoice/` | Console de crise multilingue (Mooré/Dioula/FR) |
| **Matrix Synapse API** | `https://messagerie.local/_matrix/client/versions` | Point d'entrée API du homeserver |
| **Sentinel BF Health** | `http://127.0.0.1:8088/health` | Sonde du moteur de détection d'intrusions |

---

### 👥 Tableau Complet des Comptes Fictifs de Démonstration

| Rôle & Fonction | Identifiant / Username | Mot de passe complet | Clé secrète TOTP (Base32) | Email fictif |
|---|---|---|---|---|
| **Responsable Cellule de Crise** | `alice_demo` | `Securite_BF_2026_BE3ABF96!` | `7ABNKPM53FWAI2I4ANCM3KO5FAKZVCTC` | `alice_demo@messagerie.local` |
| **Agent d'Intervention Terrain** | `bob_demo` | `Securite_BF_2026_0E100AE6!` | `32JUCZHCXYAHSWFNQHWIPWQ2GSSZWZMZ` | `bob_demo@messagerie.local` |
| **Collaborateur d'État** | `charlie_demo` | `Securite_BF_2026_82D4B6B4!` | `GH7UKRBYEW7U7J54UCWWGAXRGFDZSGYF` | `charlie_demo@messagerie.local` |
| **Admin Système d'Urgence** | `admin` | `admin` | *Compte secours API Synapse* | `@admin:messagerie.local` |
| **Agent Cybersécurité Sentinel** | `sentinel_bf` | `SentinelBF_Matr1x_S3cur!ty_2026` | *Automatique via shared secret* | `@sentinel_bf:messagerie.local` |

---

## 2. GÉNÉRATEUR DE CODES TOTP EN 1 CLIC

Pour vous connecter avec n'importe quel compte pendant la démo sans installer d'application sur votre téléphone, ouvrez un terminal et lancez :

```bash
python3 scripts/get_totp.py
```

Pour obtenir le code d'un compte précis :
```bash
python3 scripts/get_totp.py alice    # Code pour Alice
python3 scripts/get_totp.py bob      # Code pour Bob
python3 scripts/get_totp.py charlie  # Code pour Charlie
```

**Exemple de retour instantané :**
```text
  👤 Utilisateur : Alice Demo (Responsable Crise)
     Identifiant : alice_demo
     Code TOTP   : 418 923  (Valide encore 28s)
```

---

## 3. CHRONOGRAMME DE L'ENTRETIEN (15 MINUTES CHRONO)

```
00:00 ─── 03:00 : Présentation concept & architecture souveraine (3 min)
03:00 ─── 11:00 : 3 Épreuves tirées au sort par le jury (8 min)
11:00 ─── 15:00 : Questions de sécurité du jury & soutenance (4 min)
```

---

## SÉQUENCE 1 (00:00 - 03:00) : PITCH & ARCHITECTURE (3 MIN)

### Ce qu'il faut dire mot pour mot au jury :

> *"Monsieur le Président du jury, membres du jury :*
> 
> *Aujourd'hui, nos agents publics utilisent WhatsApp ou Telegram pour des ordres de mission et des notes de service. Ces données transitent par des serveurs à l'étranger, hors de tout contrôle de l'État burkinabè, sans possibilité de révocation centralisée et avec des risques majeurs d'interception.*
> 
> *Notre réponse s'appelle **Messagerie Souveraine BF**. Elle repose sur 4 piliers non négociables :*
> 
> 1. * **Souveraineté intégrale :** Hébergée localement sur infrastructure de l'État, démarrable en une seule commande, sans carte bancaire, sans VPS et **sans aucune connexion Internet**.*
> 2. * **Confidentialité absolue :** Protocole standard open source **Matrix Olm/Megolm v1** garantissant que le serveur ne stocke que du bruit chiffré illisible.*
> 3. * **Identité vérifiée & Révocation :** Authentification déléguée à **Authentik** avec **MFA TOTP (RFC 6238)** obligatoire et fermeture totale des inscriptions publiques.*
> 4. * **Deux innovations endogènes majeures :**
>    - ***FasoVoice :** diffusion d'ordres vocaux et textuels en **Français**, **Mooré** et **Dioula** avec synthèse vocale 100% locale sans API cloud.*
>    - ***Sentinel BF :** module de détection d'intrusions en direct alertant l'administrateur dans un salon Matrix sécurisé dès qu'une attaque par force brute ou password spraying survient.*
> 
> *Nous avons choisi le niveau d'engagement open source **« Étendre et adapter »** avec une conformité stricte aux exigences du MTDPCE."*

### Affichage écran pendant le pitch :
Ouvrir la page d'accueil personnalisée :
👉 `https://messagerie.local`

---

## SÉQUENCE 2 (03:00 - 11:00) : LES 5 ÉPREUVES TIRÉES AU SORT (8 MIN)

Le jury tire au sort **trois (03)** des épreuves suivantes :

---

### ÉPREUVE A : « LE SERVEUR NE LIT RIEN » (Inspection base de données & trafic)

**Objectif exigé :** Prouver au jury qu'aucun message et aucun fichier ne circule ni n'est stocké en clair sur le serveur.

#### Étape 1 : Envoyer un message depuis le navigateur
1. Connectez-vous sur `https://messagerie.local` avec **Alice** (`alice_demo` / `Securite_BF_2026_BE3ABF96!`, code TOTP via `python3 scripts/get_totp.py alice`).
2. Entrez dans le salon chiffré **« 🔴 Ordres de Mission État »**.
3. Envoyez le message confidentiel :
   ```text
   SECRET D'ÉTAT : Déploiement souverain validé à Ouagadougou secteur 15.
   ```

#### Étape 2 : Inviter le jury à inspecter PostgreSQL en direct
Ouvrez votre terminal et exécutez la commande suivante :

```bash
docker exec msb-postgres psql -U synapse -d synapse -c \
  "SELECT event_id, type, SUBSTRING(json::text, 1, 160) AS payload_chiffre FROM event_json WHERE type = 'm.room.encrypted' ORDER BY stream_ordering DESC LIMIT 1;"
```

**Ce que le jury voit à l'écran :**
```text
-[ RECORD 1 ]----+--------------------------------------------------------------------------------------------------------------------------------------------------
event_id        | $abc123xyz...
type            | m.room.encrypted
payload_chiffre | {"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEoIBq9vL2n...","sender_key":"...","session_id":"..."}
```

#### Étape 3 : La preuve par le texte en clair (Recherche infructueuse)
Prouvez que le mot « Ouagadougou » n'existe nulle part dans la base de données :

```bash
docker exec msb-postgres psql -U synapse -d synapse -c \
  "SELECT COUNT(*) FROM event_json WHERE json::text ILIKE '%Ouagadougou%';"
```
👉 **Résultat affiché : `0`**. Le serveur est mathématiquement aveugle.

#### Étape 4 : Preuve pour les fichiers téléversés
```bash
ls -lh data/synapse/media_store/local_content/
file data/synapse/media_store/local_content/*/*/* 2>/dev/null | head -2
```
👉 **Résultat :** Les pièces jointes sont des blocs binaires chiffrés en **AES-256-CTR** (`data`), sans extension et indéchiffrables sans la clé détenue uniquement par le client.

---

### ÉPREUVE B : « RÉVOCATION » (Révocation immédiate d'un agent en plein échange)

**Objectif exigé :** Révoquer un agent pendant une conversation de groupe ; il doit perdre immédiatement l'accès, y compris aux nouveaux messages.

#### Étape 1 : Mettre en scène deux agents
- Fenêtre normale du navigateur : **Alice** (`alice_demo`)
- Fenêtre de navigation privée : **Bob** (`bob_demo` / `Securite_BF_2026_0E100AE6!`, code via `python3 scripts/get_totp.py bob`)
- Les deux agents sont dans le même salon et échangent : Bob confirme *"Bien reçu Alice, je suis en route."*

#### Étape 2 : Déclencher la révocation administrative en direct
Dans le terminal, exécutez :

```bash
ADMIN_TOKEN=$(docker exec msb-postgres psql -U synapse -d synapse -t -A -c \
  "SELECT token FROM access_tokens WHERE user_id = '@admin:messagerie.local' ORDER BY id DESC LIMIT 1;")

curl -sk -X POST "http://127.0.0.1:8008/_synapse/admin/v1/deactivate/@bob_demo:messagerie.local" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"erase": false}'
```

👉 **Réponse retournée :** `{"id_server_unbind_result":"success"}`

#### Étape 3 : Constat immédiat sous les yeux du jury
1. Retournez immédiatement sur la fenêtre de **Bob** :
   - Bob tente d'envoyer un message : ❌ **Échec immédiat / Message bloqué**.
   - Element Web affiche : **« Votre session a été déconnectée »** ou erreur d'authentification (`HTTP 401 M_UNKNOWN_TOKEN`).
2. Sur la fenêtre d'**Alice**, envoyez un nouveau message :
   ```text
   Message confidentiel post-éviction de Bob.
   ```
3. Bob ne recevra **jamais** ce message.
4. Bob tente de se reconnecter sur `https://messagerie.local` :
   - Rejet côté Authentik / Synapse : ❌ `HTTP 403 M_FORBIDDEN` (`M_USER_DEACTIVATED`).

---

### ÉPREUVE C : « INTRUS » (Rejet strict d'un intrus non enrôlé)

**Objectif exigé :** Un compte non enrôlé tente de rejoindre la messagerie ou un groupe ; il doit être rejeté.

#### Étape 1 : Tentative d'inscription publique libre (Auto-enregistrement)
Exécutez dans le terminal :

```bash
curl -sk -X POST https://messagerie.local/_matrix/client/v3/register \
  -H "Content-Type: application/json" \
  -d '{"username":"hacker_anonyme","password":"MotDePasse123!","auth":{"type":"m.login.dummy"}}'
```

**Ce que le jury voit :**
```json
{
  "errcode": "M_FORBIDDEN",
  "error": "Registration has been disabled"
}
```
👉 **Preuve :** `enable_registration: false` bloque catégoriquement toute inscription libre.

#### Étape 2 : Tentative de connexion par force brute avec un compte inexistant
```bash
curl -sk -X POST https://messagerie.local/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"intrus_inconnu","password":"PiratePassword2026!"}'
```

**Ce que le jury voit :**
```json
{
  "errcode": "M_FORBIDDEN",
  "error": "Invalid username or password"
}
```

#### Étape 3 : Tentative d'accès à un salon privé sans invitation
```bash
curl -sk -X POST "https://messagerie.local/_matrix/client/v3/join/%23cellule-crise%3Amessagerie.local" \
  -H "Authorization: Bearer syt_jeton_forged_999"
```
👉 **Résultat :** `HTTP 401 M_UNKNOWN_TOKEN` / `HTTP 403 M_FORBIDDEN`.

---

### ÉPREUVE D : « INNOVATION ENDOGÈNE » (FasoVoice & Sentinel BF)

**Objectif exigé :** Démontrer une innovation originale, pertinente pour le contexte burkinabè et fonctionnelle en direct.

> *Vous avez DEUX innovations fonctionnelles majeures à présenter :*

#### 1. Innovation 1 : FASOVOICE — Console de Crise Multilingue (Mooré, Dioula, Français)
1. Ouvrez dans le navigateur : `https://messagerie.local/fasovoice/`
2. Cliquez sur l'ordre de crise : **« ALERTE ORDRE DE SÉCURITÉ »**
3. Montrez au jury :
   - Le texte en **Français** : *« Alerte sécurité nationale. Confinement immédiat... »*
   - Le texte en **Mooré** : *« Laafi kamba koeese. Zĩnd-y y zak ramba pʋsẽ... »*
   - Le texte en **Dioula** : *« Jamana lakanali kibaru. Aw bɛɛ k'aw to soo... »*
4. Cliquez sur le bouton de lecture audio **« Écouter en Mooré »** ou **« Écouter en Dioula »** :
   - L'audio se déclenche immédiatement sans aucun accès internet.
   - Montrez les 16 fichiers audios locaux : `ls -l demo/fasovoice/audio/*.mp3`
5. Déclenchez la diffusion Matrix en 1 ligne :
   ```bash
   python3 scripts/fasovoice_alert.py demo
   ```
   👉 L'alerte trilingue est instantanément diffusée dans le salon Matrix avec la pièce jointe audio !

#### 2. Innovation 2 : SENTINEL BF — Détection d'Attaques & Alertes Administrateur
1. Montrez le conteneur actif : `docker ps | grep sentinel`
2. Lancez la simulation d'une attaque de brute force devant le jury :
   ```bash
   python3 tests/test_sentinel_bf.py
   ```
3. Montrez le résultat : **7/7 tests réussis**.
4. Ouvrez le salon Matrix d'Alice ou inspectez la base SQLite pour montrer l'alerte reçue en direct :
   ```bash
   python3 -c "import sqlite3; c=sqlite3.connect('data/sentinel/sentinel.db'); print(c.execute('SELECT alert_type, ip, username, severity, sent_at FROM alerts ORDER BY id DESC LIMIT 1').fetchone())"
   ```
   **Message généré :**
   ```text
   🚨 SENTINEL BF — ALERTE DE SÉCURITÉ
   Type : Attaque distribuée (Password Spraying)
   IP source : 172.16.0.99
   Gravité : CRITIQUE
   Action recommandée : Vérification de l'activité en cours.
   ```

---

### ÉPREUVE E : « EXPLICATION DU CODE » (Cryptographie & Authentification)

**Objectif exigé :** Le jury désigne une fonction liée au chiffrement ou à l'authentification ; l'expliquer clairement.

#### Cas 1 : Si le jury interroge sur le CHIFFREMENT (Olm/Megolm E2EE)
- **Fichier à citer :** Configuration Synapse `data/synapse/homeserver.yaml` et client Element.
- **Principe à expliquer :**
  > *"Nous utilisons l'algorithme à cliquet cryptographique double (Double Ratchet) via **Olm** pour les canaux point-à-point, et **Megolm v1** pour les groupes.*
  > *Lorsqu'Alice écrit dans un groupe, une session Megolm unique génère une clé de session symétrique AES-256. Cette clé de session est chiffrée individuellement avec la clé publique Olm de chaque participant autorisé (Bob, Charlie) et transmise via l'événement `m.room_key`.*
  > *Le message lui-même est chiffré en AES-CBC avec HMAC-SHA256. Le homeserver Synapse ne voit passer que l'événement `m.room.encrypted`. Il n'a jamais accès à la clé de déchiffrement."*

#### Cas 2 : Si le jury interroge sur l'AUTHENTIFICATION (Authentik OIDC + TOTP)
- **Fichier à citer :** `sentinel/sentinel.py`, `scripts/get_totp.py` et `data/synapse/homeserver.yaml` (section `oidc_providers`).
- **Principe à expliquer :**
  > *"L'authentification est découplée de Synapse par délégation **OIDC avec échange PKCE (RFC 7636)**.*
  > *Le serveur Authentik impose une succession d'étapes : mot de passe fort puis validation d'un facteur de possession dynamique **TOTP (RFC 6238)**.*
  > *Le calcul TOTP repose sur `HMAC-SHA1(K, T)` où `K` est le secret partagé de 160 bits (Base32) et `T` est le pas de temps de 30 secondes `floor(time() / 30)`. Les 4 bits de poids faible désignent un décalage dynamique pour extraire un code de 6 chiffres.*
  > *Les comptes utilisateurs n'ont aucun mot de passe stocké dans Synapse : tout contournement direct est rendu impossible."*

#### Cas 3 : Si le jury interroge sur SENTINEL BF
- **Fichier à citer :** `sentinel/sentinel.py` (lignes 210-330).
- **Principe à expliquer :**
  > *"Sentinel BF interroge la table `authentik_events_event` de PostgreSQL toutes les 10 secondes.*
  > *Il maintient des fenêtres temporelles glissantes (`deque`) pour chaque IP et compte.*
  > *Si 5 échecs surviennent en 300 secondes depuis la même IP, la règle `brute_force` se déclenche.*
  > *Si une IP tente 3 comptes différents en 600 secondes, la règle `password_spray` déclenche une alerte de gravité CRITIQUE.*
  > *Un mécanisme de cooldown de 10 minutes par signature SHA-256 évite le spam d'alertes.*
  > *La notification est ensuite envoyée via l'API client Matrix Synapse avec le compte technique `@sentinel_bf`."*

---

## SÉQUENCE 3 (11:00 - 15:00) : QUESTIONS DU JURY & RÉPONSES EN BÉTON (4 MIN)

### Q1 : « Pourquoi avoir choisi Matrix Synapse plutôt que Signal ou XMPP ? »
> **Réponse :**
> *"Signal-Server est conçu pour un service centralisé unique et dépend fortement de services cloud propriétaires (AWS, Google Cloud Phone verification). XMPP/OMEMO manque de maturité sur la synchronisation multi-terminaux et les salons de grande taille.*
> *Matrix avec Olm/Megolm est un standard ouvert mondialement reconnu, recommandé pour les communications étatiques souveraines (ex: Tchap en France, BwMessenger en Allemagne). Il sépare nativement l'identité, le transport et le chiffrement sans dépendre d'aucun opérateur télécom."*

### Q2 : « Le serveur ne lit pas les messages, mais quelles sont les métadonnées qu'il voit ? »
> **Réponse (Transparence exemplaire = points maximaux) :**
> *"Le protocole Matrix protège le contenu, mais pour acheminer les messages, le serveur voit nécessairement :*
> 1. *Les identifiants émetteurs et destinataires (`@alice_demo`, `@bob_demo`).*
> 2. *L'horodatage exact des envois (`origin_server_ts`).*
> 3. *La taille en octets du bloc chiffré.*
> 4. *L'adresse IP des clients.*
> *Pour minimiser ces métadonnées : les salons sont tous privés, la fédération est coupée pour empêcher toute fuite à l'extérieur, les adresses IP sont masquées derrière Nginx local et la directive `forget_rooms_on_leave: true` purge l'historique d'appartenance lors d'un départ."*

### Q3 : « Pourquoi l'agent révoqué conserve-t-il les anciens messages sur son écran ? »
> **Réponse :**
> *"C'est une propriété fondamentale du chiffrement de bout en bout (E2EE) : les messages déjà reçus ont été déchiffrés localement et mis en cache dans le stockage du navigateur (IndexedDB). Le serveur ne possède aucun moyen technique d'effacer à distance la mémoire physique d'un appareil déconnecté.*
> *En revanche, côté serveur, la révocation coupe instantanément tout nouveau flux réseau (HTTP 401/403) : l'agent ne peut plus émettre, ni recevoir les futurs messages, ni obtenir les clés de session futures. Pour un effacement local, une solution MDM d'État devra compléter la plateforme en production."*

### Q4 : « Avez-vous développé votre propre cryptographie ? »
> **Réponse (Strict respect du règlement) :**
> *"Non, absolument pas. Le règlement du Hackathon interdit formellement toute cryptographie développée par les équipes. Nous utilisons exclusivement des implémentations standard certifiées : la bibliothèque Megolm v1 (AES-256 + HMAC-SHA256) auditée par NCC Group, et l'algorithme TOTP RFC 6238 d'Authentik."*

### Q5 : « Comment garantissez-vous que votre solution fonctionne sans Internet ? »
> **Réponse :**
> *"Toutes les dépendances ont été encapsulées :*
> - *Les 6 images Docker sont préchargées localement (`offline-demo/images/`).*
> - *Les polices et scripts Element Web sont embarqués en local.*
> - *Les certificats TLS sont générés localement par autorité interne.*
> - *FasoVoice embarque 16 fichiers audio pré-enregistrés en local.*
> - *Notre script `scripts/package_offline_demo.sh` génère un pack 100% autonome utilisable sur une machine totalement déconnectée."*

---

## 7. FICHE MÉMO DES COMMANDES D'URGENCE

Gardez ce bloc de commandes sous les yeux pendant la démonstration :

```bash
# 1. Vérifier la santé de tous les services (tout doit être OK)
bash scripts/health_check.sh

# 2. Obtenir instantanément les codes TOTP d'Alice, Bob ou Charlie
python3 scripts/get_totp.py

# 3. Prouver que la base PostgreSQL ne contient que du chiffré
docker exec msb-postgres psql -U synapse -d synapse -c \
  "SELECT event_id, type, SUBSTRING(json::text, 1, 140) FROM event_json WHERE type = 'm.room.encrypted' ORDER BY stream_ordering DESC LIMIT 1;"

# 4. Révocation immédiate de Bob en une ligne
ADMIN_TOKEN=$(docker exec msb-postgres psql -U synapse -d synapse -t -A -c \
  "SELECT token FROM access_tokens WHERE user_id = '@admin:messagerie.local' ORDER BY id DESC LIMIT 1;")
curl -sk -X POST "http://127.0.0.1:8008/_synapse/admin/v1/deactivate/@bob_demo:messagerie.local" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"erase": false}'

# 5. Tester l'intrusion (auto-inscription rejetée)
curl -sk -X POST https://messagerie.local/_matrix/client/v3/register \
  -H "Content-Type: application/json" -d '{"username":"intrus","password":"Password123!"}'

# 6. Exécuter la suite de tests de cybersécurité Sentinel BF (7/7 pass)
python3 tests/test_sentinel_bf.py

# 7. Exécuter le banc de tests complet de sécurité E2EE (8/8 pass)
python3 tests/test_matrix_security.py
```

---
*Document certifié conforme aux exigences officielles du MTDPCE / DGTD — Hackathon 226.*  
*Bonne chance pour votre passage devant le jury !*
