# Tests Chiffrement de Bout en Bout (E2EE) — Messagerie Souveraine BF

## État

| Fonctionnalité | État |
|----------------|------|
| Chiffrement Olm/Megolm natif Matrix | ✅ DISPONIBLE (fourni par Synapse/Element) |
| Test E2EE avec deux utilisateurs réels | ⏳ EN ATTENTE (Synapse doit être démarré) |
| Vérification de l'absence de déchiffrement côté serveur | ⏳ EN ATTENTE |

## Principe important

Matrix implémente le chiffrement de bout en bout via les protocoles
**Olm** (sessions 1-à-1) et **Megolm** (salons de groupe).

> **Le chiffrement n'est pas automatique pour tous les salons.**
> Il doit être activé explicitement à la création du salon ou
> dans les paramètres. Element propose l'activation par défaut
> pour les conversations privées (DM).

Le serveur Synapse ne voit que des messages chiffrés.
Il ne peut pas déchiffrer le contenu des messages E2EE.

## Prérequis

- Synapse démarré et accessible (`http://localhost:8008`)
- Element accessible (`http://localhost:8081`)
- Deux comptes utilisateurs créés (ex: `alice` et `bob`)
- Deux navigateurs ou sessions différentes (normale + privée)

## Création des comptes de test

```bash
# Compte alice
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u alice --no-admin \
  http://localhost:8008

# Compte bob
docker exec -it msb-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u bob --no-admin \
  http://localhost:8008
```

## Scénario de test E2EE

### TEST-E2EE-01 — Création d'une conversation chiffrée

```
Acteurs : alice (fenêtre normale), bob (fenêtre privée)
Étapes :
  1. alice se connecte sur http://localhost:8081
  2. alice démarre une conversation directe avec bob
  3. alice active le chiffrement (icône cadenas ou DM par défaut)
  4. bob se connecte et accepte la conversation
  5. Vérifier l'icône de chiffrement dans l'interface Element
Résultat attendu : Icône de cadenas verte, mention "E2EE activé"
Résultat obtenu : [NON EXÉCUTÉ — Synapse non démarré]
```

### TEST-E2EE-02 — Échange de messages

```
Acteurs : alice, bob
Étapes :
  1. alice envoie "Message de test chiffré"
  2. Vérifier que bob reçoit le message déchiffré
  3. bob répond "Réponse de test"
  4. Vérifier que alice reçoit la réponse déchiffrée
Résultat attendu : Messages lisibles uniquement par les participants
Résultat obtenu : [NON EXÉCUTÉ]
```

### TEST-E2EE-03 — Vérification côté base de données

```
Objectif : Prouver que PostgreSQL ne stocke pas les messages en clair
Étapes :
  1. Après l'échange de messages chiffrés
  2. Exécuter la requête SQL :
     docker exec msb-postgres psql -U synapse -d synapse \
       -c "SELECT content FROM events WHERE type='m.room.message' LIMIT 5;"
  3. Observer que le contenu est chiffré (format ciphertext JSON)
Résultat attendu : Contenu illisible de type {"algorithm":"m.megolm.v1.aes-sha2",...}
Résultat obtenu : [NON EXÉCUTÉ]
```

### TEST-E2EE-04 — Nouvel appareil

```
Objectif : Vérifier le comportement lors de l'ajout d'un nouvel appareil
Étapes :
  1. alice se connecte sur un troisième navigateur
  2. Observer l'avertissement dans la conversation E2EE
  3. alice vérifie/valide son nouvel appareil
  4. Vérifier que les anciens messages restent lisibles si partage clé
Résultat attendu : Avertissement de sécurité, puis accès après vérification
Résultat obtenu : [NON EXÉCUTÉ]
```

## Limite connue

La révocation d'accès ou la désactivation d'un compte **ne supprime pas**
les messages déjà reçus et déchiffrés par un utilisateur.
Le chiffrement E2EE garantit la confidentialité en transit,
pas la suppression des données côté client.
