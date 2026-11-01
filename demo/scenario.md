# Scénario de Démonstration Officiel — Messagerie Souveraine BF
*Version validée techniquement de bout en bout (Hackathon 2026)*

Ce scénario permet de dérouler une présentation complète en **3 à 5 minutes**, prouvant le fonctionnement réel des exigences de sécurité et de souveraineté.

---

## Prérequis de Démonstration

1. **Services démarrés** :
   ```bash
   cd ~/messagerie_souveraine_bf
   docker compose ps
   # Doit afficher : msb-postgres, msb-synapse, msb-element, msb-proxy (tous Up/healthy)
   ```
2. **Résolution DNS locale** (sur la machine de démo dans `/etc/hosts`) :
   ```
   127.0.0.1   messagerie.local
   127.0.0.1   auth.messagerie.local
   ```
3. **Certificats TLS mkcert reconnus** :
   Le navigateur accède à `https://messagerie.local` et `https://auth.messagerie.local` sans avertissement de sécurité.

---

## Comptes de Démonstration

| Rôle | Identifiant | Authentification | MFA TOTP |
|---|---|---|---|
| **Agent A (Ministère)** | `alice_test` | Authentik OIDC | Oui (Application TOTP) |
| **Agent B (Terrain)** | `bob_test` | Authentik OIDC | Oui (Application TOTP) |
| **Admin de Secours** | `admin` | Mot de passe local Synapse | Hors OIDC (procédure d'urgence) |

> *Note de sécurité :* Les utilisateurs ordinaires (`alice_test`, `bob_test`) n'ont aucun mot de passe dans Synapse. Ils sont obligés de s'authentifier via Authentik avec validation TOTP.

---

## Déroulé de la Démonstration (Étape par Étape)

### Étape 1 : Accès à Element et Redirection OIDC (0:00 - 0:45)
1. Ouvrir le navigateur sur `https://messagerie.local`.
2. L'interface officielle **Element Web — Messagerie Souveraine BF** s'affiche.
3. Cliquer sur le bouton officiel : **« Se connecter avec Authentik »**.
4. Le navigateur est redirigé de manière sécurisée en HTTPS vers `https://auth.messagerie.local`.
5. *Message clé jury :* L'identité est gérée souverainement par l'infrastructure nationale (Authentik), le serveur de messagerie ne connaît pas le mot de passe maître de l'agent.

### Étape 2 : Authentification Forte et Validation TOTP (0:45 - 1:15)
1. Saisir l'identifiant de l'agent (`alice_test`) et son mot de passe.
2. Authentik déclenche immédiatement l'étape **Validation TOTP**.
3. *(Test d'intégrité en direct optionnel)* : Taper un mauvais code `000000` -> Authentik refuse immédiatement l'accès.
4. Saisir le code TOTP à 6 chiffres depuis l'application d'authentification (Google Authenticator / FreeOTP).
5. Authentik valide le code et renvoie l'agent vers Synapse avec un code d'autorisation sécurisé PKCE.

### Étape 3 : Accès au Carnet et Création du Salon Chiffré E2EE (1:15 - 2:00)
1. Synapse délivre la session chiffrée, Element Web s'ouvre sur le compte `@alice_test:messagerie.local`.
2. Alice clique sur **Nouveau salon** (ex: *#crise-sanitaire-bf* ou *Canal Institutionnel BF*).
3. Alice active l'option **Chiffrement de bout en bout (E2EE)**.
4. Alice invite Bob (`@bob_test:messagerie.local`).
5. Bob accepte l'invitation sur son terminal ou session privée.

### Étape 4 : Échange de Messages Chiffrés (Megolm) & Preuve Base de Données (2:00 - 2:45)
1. Alice envoie un message confidentiel :
   > *"Rapport de situation confidentiel transmis — Neere !"*
2. Bob reçoit le message et le déchiffre instantanément sur son interface.
3. Bob répond de manière chiffrée :
   > *"Bien reçu, canal souverain opérationnel."*
4. **Preuve pour le jury (Terminal)** :
   Ouvrir un terminal et afficher la base PostgreSQL en direct :
   ```bash
   docker exec msb-postgres psql -U synapse -d synapse -c \
     "SELECT event_id, type FROM events WHERE type='m.room.encrypted' ORDER BY origin_server_ts DESC LIMIT 2;"
   ```
   *Résultat visible :* Le serveur ne stocke que des événements de type `m.room.encrypted` (chiffrement Megolm AES-256). Aucun mot en clair n'existe sur le disque ni dans la base de données.

### Étape 5 : Révocation Administrative Immédiate (2:45 - 3:30)
1. L'administrateur révoque l'accès d'un agent compromis ou en départ :
   ```bash
   # Obtenir le token admin
   TOKEN=$(curl -s -k -X POST https://messagerie.local/_matrix/client/v3/login \
     -H "Content-Type: application/json" \
     -d '{"type":"m.login.password","user":"admin","password":"<MOT_DE_PASSE_ADMIN>"}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

   # Désactiver le compte
   curl -s -k -X POST https://messagerie.local/_synapse/admin/v1/deactivate/@bob_test:messagerie.local \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"erase": false}'
   ```
2. **Constat immédiat :**
   - La session active de l'agent est instantanément révoquée (`M_UNKNOWN_TOKEN`).
   - Toute nouvelle tentative de connexion est bloquée (`M_FORBIDDEN` / `M_USER_DEACTIVATED`).
3. *Note de transparence technique :* La révocation bloque immédiatement toute émission/réception future, mais les messages déjà déchiffrés localement dans le cache du terminal client avant la révocation ne peuvent pas être effacés à distance (principe inhérent au chiffrement de bout en bout).

---

## Commandes Rapides pour le Présentateur

```bash
# Vérifier l'état de l'infrastructure
docker compose ps

# Vérifier les tables de la base de données
docker exec msb-postgres psql -U synapse -d synapse -c "SELECT count(*) FROM users;"

# Vérifier les messages chiffrés stockés
docker exec msb-postgres psql -U synapse -d synapse -c "SELECT type, room_id FROM events WHERE type='m.room.encrypted';"
```
