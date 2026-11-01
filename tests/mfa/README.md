# Tests MFA / TOTP — Messagerie Souveraine BF

## État de Validation

| Scénario | Composant | État | Méthode de validation |
|---|---|---|---|
| **TEST-MFA-01** | Redirection vers Authentik | ✅ VALIDÉ | Redirection OIDC PKCE Synapse ↔ Authentik (`/application/o/authorize/`) |
| **TEST-MFA-02** | Authentification + TOTP valide | ✅ VALIDÉ | Découverte OIDC, saisie credentials, saisie OTP, émission session Matrix |
| **TEST-MFA-03** | Refus de code TOTP incorrect | ✅ VALIDÉ | Code OTP `000000` rejeté par Authentik (`HTTP 200` avec message d'erreur d'étape) |
| **TEST-MFA-04** | Blocage connexion locale non-admin | ✅ VALIDÉ | Comptes OIDC créés sans `password_hash` Synapse : bypass local impossible |

---

## Architecture de Sécurité Validée

1. **Fournisseur OIDC centralisé :** Authentik (2026.8.5) configuré avec un provider nommé `Synapse` et les flux `authorization_code` et `refresh_token`.
2. **Politique MFA obligatoire :** Le flux d'authentification par défaut Authentik impose la succession :
   - Étape 1 : Identification (`username`)
   - Étape 2 : Mot de passe (`password`)
   - Étape 3 : Validation du facteur de possession TOTP 6 chiffres (`authenticator_totp`)
3. **Protection contre le contournement :**
   - Les utilisateurs OIDC (`alice_test`, `bob_test`) n'ont aucun condensat de mot de passe stocké dans Synapse (`password_hash IS NULL`).
   - Seul le compte d'urgence d'administration (`admin`) dispose d'une authentification locale par mot de passe robuste dans Synapse, réservée aux opérations de secours et d'administration.

---

## Résultats des Tests Automatisés

Le script de test automatisé a vérifié les points suivants de bout en bout :
- Découverte des métadonnées OIDC : `https://auth.messagerie.local/application/o/synapse/.well-known/openid-configuration` (HTTP 200)
- Initialisation du flux PKCE Synapse : redirection vers Authentik avec `client_id` et `redirect_uri` conformes.
- Soumission d'un mauvais code TOTP : rejet immédiat par le moteur de validation Authentik.
- Soumission du code TOTP valide calculé par HMAC-SHA1 : acceptation, redirection vers le callback Synapse `https://messagerie.local/_synapse/client/oidc/callback`, et délivrance du jeton Matrix d'accès.

---

## Procédure Manuelle dans le Navigateur (Element Web)

1. Se rendre sur `https://messagerie.local`.
2. Cliquer sur le bouton **« Se connecter avec Authentik »**.
3. Saisir l'identifiant (ex: `alice_test`) et le mot de passe (`Securite_BF_2026!`).
4. À l'invite TOTP, saisir le code à 6 chiffres fourni par l'application d'authentification.
5. Constater la redirection automatique vers l'espace de travail Element Web avec le profil de l'agent actif.
