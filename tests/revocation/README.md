# Tests de Révocation — Messagerie Souveraine BF

## État

| Scénario | État |
|----------|------|
| Désactivation d'un compte via API Synapse | ✅ TESTÉ MANUELLEMENT |
| Refus de nouvelle authentification après désactivation | ✅ TESTÉ MANUELLEMENT |
| Révocation d'un appareil/session spécifique | ⏳ SCÉNARIO PRÉPARÉ, NON EXÉCUTÉ |
| Comportement des sessions déjà ouvertes | ⏳ SCÉNARIO PRÉPARÉ, NON EXÉCUTÉ |

## Ce qui a été validé manuellement

Lors des tests Synapse (instance séparée, version 1.164.1) :

- **Désactivation d'un utilisateur** via l'API d'administration Synapse
  (endpoint `PUT /_synapse/admin/v1/deactivate/{userId}`) : ✅ TESTÉ
- **Refus de nouvelle connexion** après désactivation : ✅ TESTÉ

> Ces tests ont été réalisés sur l'instance Synapse de développement
> (conteneur arrêté). Ils devront être reproduits sur l'instance
> démarrée depuis ce dépôt.

## API d'administration Synapse

```bash
# Obtenir un token admin
TOKEN=$(curl -s -X POST http://localhost:8008/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"admin","password":"MOT_DE_PASSE_ADMIN"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Désactiver un compte utilisateur
curl -s -X POST \
  "http://localhost:8008/_synapse/admin/v1/deactivate/@alice:messagerie.local" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"erase": false}'

# Vérifier l'état d'un compte
curl -s \
  "http://localhost:8008/_synapse/admin/v2/users/@alice:messagerie.local" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

## Scénarios de test

### TEST-REV-01 — Désactivation de compte

```
Acteur : Administrateur
Prérequis : Synapse démarré, compte alice existant
Étapes :
  1. alice est connectée sur Element (session active)
  2. L'admin appelle l'API de désactivation (commande ci-dessus)
  3. alice tente d'envoyer un message
Résultat attendu :
  - API retourne HTTP 200 {"id_server_unbind_result":"success"}
  - Le compte alice est marqué "deactivated" dans Synapse
Résultat obtenu : [NON EXÉCUTÉ sur cette instance]
```

### TEST-REV-02 — Refus de nouvelle authentification

```
Acteur : alice (compte désactivé)
Prérequis : TEST-REV-01 exécuté
Étapes :
  1. alice tente de se connecter avec ses identifiants
Résultat attendu : Erreur d'authentification (M_USER_DEACTIVATED)
Résultat obtenu : [NON EXÉCUTÉ sur cette instance]
```

### TEST-REV-03 — Révocation d'un appareil

```
Objectif : Révoquer un appareil/session spécifique sans désactiver le compte
Étapes :
  1. Lister les appareils d'alice :
     curl -s "http://localhost:8008/_synapse/admin/v2/users/@alice:messagerie.local/devices" \
       -H "Authorization: Bearer $TOKEN"
  2. Identifier l'ID de l'appareil à révoquer
  3. Révoquer l'appareil :
     curl -s -X DELETE \
       "http://localhost:8008/_synapse/admin/v2/users/@alice:messagerie.local/devices/DEVICE_ID" \
       -H "Authorization: Bearer $TOKEN"
Résultat attendu : Appareil révoqué, session invalide
Résultat obtenu : [NON EXÉCUTÉ]
```

### TEST-REV-04 — Comportement des sessions déjà ouvertes

```
Objectif : Vérifier ce qui se passe pour une session active après désactivation
Note : Synapse invalide le token d'accès lors de la désactivation.
  Les messages déjà reçus et déchiffrés restent sur l'appareil client.
Résultat obtenu : [NON EXÉCUTÉ]
```

## ⚠️ Limite importante

> **La révocation d'accès ne permet PAS d'effacer les messages
> déjà reçus ou déchiffrés par un utilisateur.**
>
> Une fois qu'un message a été déchiffré côté client (navigateur
> ou application mobile), il reste dans le stockage local du client.
> La désactivation du compte empêche de nouveaux accès, mais ne
> peut pas supprimer rétroactivement les données déjà reçues.
>
> Ce comportement est inhérent au chiffrement de bout en bout :
> il est intentionnel et documenté par le protocole Matrix.
