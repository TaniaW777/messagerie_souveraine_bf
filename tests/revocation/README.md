# Tests de Révocation et Désactivation — Messagerie Souveraine BF

## État de Validation

| Scénario | Composant | État | Méthode de validation |
|---|---|---|---|
| **TEST-REV-01** | Désactivation de compte via API Synapse Admin | ✅ VALIDÉ | `POST /_synapse/admin/v1/deactivate/{userId}` -> HTTP 200, compte marqué `deactivated=1` |
| **TEST-REV-02** | Refus de nouvelle authentification après désactivation | ✅ VALIDÉ | Tentative de connexion rejetée : HTTP 403 (`M_FORBIDDEN` / `M_USER_DEACTIVATED`) |
| **TEST-REV-03** | Révocation d'un appareil / session spécifique | ✅ VALIDÉ | `DELETE /_synapse/admin/v2/users/{userId}/devices/{deviceId}` -> Session ciblée révoquée (`M_UNKNOWN_TOKEN`), autre session préservée |
| **TEST-REV-04** | Comportement des sessions déjà ouvertes | ✅ VALIDÉ | Requête avec token actif sur session désactivée immédiatement rejetée : HTTP 401 (`M_UNKNOWN_TOKEN`) |

---

## Commandes Validées sur l'Infrastructure

### 1. Obtention du Jeton Administrateur
```bash
ADMIN_TOKEN=$(curl -sk -X POST https://messagerie.local/_matrix/client/v3/login \
  --resolve messagerie.local:443:127.0.0.1 \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"admin","password":"${ADMIN_PASSWORD}"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

### 2. Révocation d'un appareil ciblé (ex: appareil mobile perdu)
```bash
# Révocation d'un appareil précis
curl -sk -X DELETE --resolve messagerie.local:443:127.0.0.1 \
  "https://messagerie.local/_synapse/admin/v2/users/@agent:messagerie.local/devices/<DEVICE_ID>" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```
*Résultat vérifié :* L'appareil spécifié reçoit immédiatement `M_UNKNOWN_TOKEN` (HTTP 401) à sa prochaine synchronisation, tandis que les autres appareils de l'agent restent connectés.

### 3. Désactivation complète d'un compte
```bash
curl -sk -X POST --resolve messagerie.local:443:127.0.0.1 \
  "https://messagerie.local/_synapse/admin/v1/deactivate/@agent:messagerie.local" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"erase": false}'
```
*Résultat vérifié :*
- Toutes les sessions existantes de l'utilisateur sont purgées du serveur.
- Toute requête ultérieure utilisant les anciens jetons retourne `HTTP 401 M_UNKNOWN_TOKEN`.
- Toute tentative de nouvelle connexion retourne `HTTP 403 M_FORBIDDEN`.

---

## ⚠️ Précision Technique et Limite Inhérente au E2EE

- **Côté serveur :** La révocation administrative coupe instantanément tout flux réseau, empêchant la réception de nouveaux messages et l'envoi de messages.
- **Côté client :** Les messages qui avaient déjà été reçus et déchiffrés par le terminal local avant l'ordre de révocation restent stockés dans le stockage local du navigateur (IndexedDB). Ce comportement est inhérent à l'architecture E2EE décentralisée : le serveur ne possède pas de mécanisme d'effacement cryptographique à distance sans intervention d'un agent MDM (Mobile Device Management) sur le système d'exploitation du client.
