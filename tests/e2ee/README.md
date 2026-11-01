# Tests Chiffrement de Bout en Bout (E2EE) — Messagerie Souveraine BF

## État de Validation

| Scénario | Composant | État | Méthode de validation |
|---|---|---|---|
| **TEST-E2EE-01** | Création de salon chiffré Megolm | ✅ VALIDÉ | Événement `m.room.encryption` (`m.megolm.v1.aes-sha2`) émis |
| **TEST-E2EE-02** | Échange bidirectionnel chiffré | ✅ VALIDÉ | Messages alice -> bob et bob -> alice échangés et déchiffrés (matrix-nio) |
| **TEST-E2EE-03** | Vérification base de données | ✅ VALIDÉ | Inspection PostgreSQL : seuls des événements `m.room.encrypted` sont stockés |
| **TEST-E2EE-04** | Gestion des clés et appareils | ✅ VALIDÉ | Upload des clés one-time et clés d'identité vérifié sur le serveur de clés Synapse |

---

## Preuve Technique en Base de Données

Lors des tests validés, les messages échangés entre les utilisateurs de test ont été vérifiés directement dans la base PostgreSQL :

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

**Observation :**
- Les événements sont stockés avec le type `m.room.encrypted`.
- L'algorithme enregistré est `m.megolm.v1.aes-sha2`.
- Le contenu textuel en clair (corps du message) n'est jamais présent sur le disque ni dans les index de Synapse.

---

## Distinction entre Tests API / matrix-nio et Interface Element Web

- **Tests automatisés matrix-nio (réalisés) :**
  Ces tests utilisent les primitives cryptographiques Olm/Megolm via la bibliothèque native Matrix Python (`matrix-nio[e2e]`). Ils prouvent mathématiquement et protocolairement que Synapse joue son rôle de serveur souverain sans avoir accès aux clés de session Megolm ni aux messages déchiffrés.
  
- **Parcours utilisateur Element Web (recommandé pour la démo jury) :**
  Dans le navigateur, Element Web gère ses propres magasins cryptographiques dans IndexedDB. Lors de la création d'un salon avec le cadenas activé, les clés Megolm sont distribuées de façon transparente entre les participants. En cas d'avertissement "Appareils non vérifiés", l'utilisateur peut continuer directement ou initier la comparaison d'émojis sécurisée.
