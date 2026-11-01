# Tests MFA / TOTP — Messagerie Souveraine BF

## État

| Composant | État |
|-----------|------|
| MFA TOTP dans Authentik | ✅ TESTÉ MANUELLEMENT |
| Intégration OIDC Authentik → Synapse | 🔶 CONFIGURÉ MAIS NON TESTÉ |
| MFA imposé via OIDC sur Element Web | ⏳ EN ATTENTE PRÉREQUIS TLS |

## Prérequis avant exécution des tests

1. Authentik accessible en HTTPS depuis le réseau Docker (`msb-public`)
2. Fournisseur OIDC configuré dans Authentik (cf. `docs/installation.md`)
3. Section `oidc_providers` activée dans `data/synapse/homeserver.yaml`
4. Certificat TLS valide ou ajouté à la chaîne de confiance de Synapse

## Ce qui a été validé manuellement (Authentik seul)

Les étapes suivantes ont été exécutées manuellement le 2026-10-31
**directement dans Authentik**, sans passer par Synapse/Element :

1. Création d'un utilisateur de test dans Authentik.
2. Première connexion avec identifiant + mot de passe.
3. Affichage du QR code TOTP.
4. Association avec Google Authenticator.
5. Validation du code OTP.
6. Nouvelle connexion → demande directe du code OTP.
7. Authentification réussie.

> **Note** : cette validation confirme que Authentik gère correctement
> le TOTP. Elle ne valide pas l'intégration avec Synapse.

## Scénario de test OIDC + MFA (à exécuter)

### Préparer l'environnement

```bash
# 1. Vérifier qu'Authentik est accessible
curl -sk https://auth.messagerie.local/application/o/synapse/.well-known/openid-configuration | python3 -m json.tool

# 2. Vérifier la configuration OIDC dans Synapse
docker exec msb-synapse grep -A 20 "oidc_providers" /data/homeserver.yaml

# 3. Vérifier les logs Synapse
docker logs msb-synapse --tail 50
```

### Tests fonctionnels

#### TEST-MFA-01 — Redirection vers Authentik

```
Acteur : Utilisateur non authentifié
Étapes :
  1. Ouvrir http://localhost:8081 dans le navigateur
  2. Cliquer sur "Se connecter avec Authentik" (ou équivalent SSO)
  3. Observer la redirection vers https://auth.messagerie.local
Résultat attendu : Page de connexion Authentik affichée
Résultat obtenu : [NON EXÉCUTÉ — prérequis TLS manquants]
```

#### TEST-MFA-02 — Authentification + TOTP

```
Acteur : Utilisateur avec TOTP configuré
Étapes :
  1. Saisir identifiant + mot de passe dans Authentik
  2. Observer la demande du code TOTP
  3. Saisir le code depuis l'application TOTP
  4. Observer le retour vers Element
Résultat attendu : Accès à la messagerie accordé
Résultat obtenu : [NON EXÉCUTÉ — prérequis TLS manquants]
```

#### TEST-MFA-03 — Refus d'un code incorrect

```
Acteur : Utilisateur avec TOTP configuré
Étapes :
  1. Saisir identifiant + mot de passe corrects
  2. Saisir un code TOTP incorrect (ex: 000000)
Résultat attendu : Authentification refusée, message d'erreur
Résultat obtenu : [NON EXÉCUTÉ — prérequis TLS manquants]
```

#### TEST-MFA-04 — Connexion directe locale bloquée

```
Objectif : Vérifier que les utilisateurs ne peuvent pas
  contourner le MFA via l'authentification locale Synapse.
Note : à évaluer après validation de l'intégration OIDC.
  La désactivation des méthodes locales ne doit intervenir
  qu'après confirmation d'un accès admin de secours.
Résultat obtenu : [NON EXÉCUTÉ]
```

## Prochaine étape

Voir `docs/installation.md` section "Intégration OIDC" pour les
instructions de configuration préalables.
