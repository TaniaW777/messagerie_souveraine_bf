# Politique de Sécurité — Messagerie Souveraine BF

## Vue d'ensemble

Ce document décrit les mesures de sécurité implémentées,
les décisions d'architecture retenues et les limites connues
du prototype de messagerie souveraine.

---

## 1. Gestion des secrets

### Règles absolues

- Aucun secret ne doit être commité dans Git.
- Le fichier `.env` est ignoré par `.gitignore`.
- Les fichiers `data/synapse/homeserver.yaml` et `*.signing.key`
  sont ignorés (dans `data/` qui est gitignored).
- Seuls les fichiers `*.example` contenant des valeurs fictives
  sont versionnés.

### Secrets concernés

| Secret | Localisation | Criticité |
|--------|-------------|-----------|
| `POSTGRES_PASSWORD` | `.env` | Haute |
| `SYNAPSE_REGISTRATION_SHARED_SECRET` | `.env` → `homeserver.yaml` | Haute |
| `SYNAPSE_MACAROON_SECRET_KEY` | `.env` → `homeserver.yaml` | Haute |
| `SYNAPSE_FORM_SECRET` | `.env` → `homeserver.yaml` | Haute |
| `messagerie.local.signing.key` | `data/synapse/` | **Critique** |
| `AUTHENTIK_OIDC_CLIENT_SECRET` | `.env` | Haute |

### Alerte : secrets exposés dans l'historique Git

> ⚠️ **INCIDENT DE SÉCURITÉ IDENTIFIÉ**
>
> Une analyse de l'historique Git a révélé que des valeurs réelles
> des secrets Synapse (`registration_shared_secret`, `macaroon_secret_key`,
> `form_secret`) ont été committées dans le commit `1f3fe96` de la
> branche `feature/infrastructure`.
>
> Ces valeurs doivent être considérées comme **compromises**.

#### Procédure de rotation recommandée

**Secrets pouvant être renouvelés sans risque** :
- `registration_shared_secret` : remplacer dans `homeserver.yaml`, redémarrer
- `macaroon_secret_key` : remplacer, redémarrer (invalide les tokens actifs)
- `form_secret` : remplacer, redémarrer

```bash
# Générer de nouveaux secrets
python3 -c "import secrets; print('registration_shared_secret:', secrets.token_urlsafe(64))"
python3 -c "import secrets; print('macaroon_secret_key:', secrets.token_urlsafe(64))"
python3 -c "import secrets; print('form_secret:', secrets.token_urlsafe(64))"
```

**Secret NE PAS changer automatiquement** :
- `signing_key` : clé de fédération Matrix — son changement nécessite
  une procédure de migration. Sur une instance de développement local
  sans fédération, elle peut être régénérée en recréant les données.

#### Nettoyage de l'historique Git

> ⚠️ **Ne pas exécuter sans validation de toute l'équipe.**
> La réécriture de l'historique affecte toutes les branches et
> nécessite un `git push --force` coordonné.

Si le dépôt a été publié avec ces secrets, il faut :
1. Révoquer et remplacer les secrets exposés.
2. Utiliser `git-filter-repo` pour supprimer les valeurs de l'historique.
3. Forcer la synchronisation de toutes les copies locales.
4. Considérer le dépôt GitHub comme potentiellement compromis si public.

---

## 2. Configuration réseau

### Isolation des services

- **PostgreSQL** : accessible uniquement sur le réseau interne Docker
  (`msb-internal`), jamais exposé sur l'hôte.
- **Synapse** : écoute sur `127.0.0.1:8008` (pas `0.0.0.0`).
- **Element** : écoute sur `127.0.0.1:8081` (pas `0.0.0.0`).

### `x_forwarded`

Le paramètre `x_forwarded: true` dans Synapse doit être activé
**uniquement** si un reverse proxy (nginx, Traefik) est configuré
et qu'il transmet le header `X-Forwarded-For`.

Sans proxy, `x_forwarded: false` est obligatoire pour éviter
l'usurpation d'adresse IP cliente.

---

## 3. Authentification

### Inscriptions publiques

```yaml
enable_registration: false
```

Les inscriptions publiques sont désactivées. Seul un administrateur
peut créer des comptes via l'API ou la commande `register_new_matrix_user`.

### MFA TOTP via Authentik

Le MFA TOTP est opérationnel dans Authentik (testé manuellement).
L'intégration avec Synapse via OIDC est en cours de configuration.

### Méthodes d'authentification locales

> ⚠️ **Risque de contournement du MFA**
>
> Tant que l'authentification locale (mot de passe Synapse direct)
> est activée, les utilisateurs peuvent se connecter sans passer
> par Authentik et donc sans TOTP.
>
> La désactivation des méthodes locales ne doit intervenir qu'après :
> 1. Validation complète de l'intégration OIDC
> 2. Vérification d'un accès administrateur de secours

---

## 4. Chiffrement de bout en bout

### Protocoles utilisés

- **Olm** : chiffrement des sessions 1-à-1 (courbes Curve25519, AES-256)
- **Megolm** : chiffrement des salons de groupe

### Garanties

- Le serveur Synapse ne peut pas déchiffrer les messages E2EE.
- PostgreSQL stocke les messages sous forme chiffrée.

### Limites

- Le chiffrement E2EE doit être activé par l'utilisateur (pas automatique
  pour tous les salons, sauf DM dans Element).
- La révocation d'accès ne supprime pas les messages déjà déchiffrés.
- Les clés de session Megolm sont partagées entre les appareils du même
  utilisateur — un appareil compromis peut accéder à l'historique.

---

## 5. Rotation des clés

| Élément | Fréquence recommandée | Risque si non fait |
|---------|----------------------|-------------------|
| `POSTGRES_PASSWORD` | Annuelle ou sur incident | Accès DB compromis |
| Secrets Synapse | Sur incident | Tokens falsifiables |
| Clé de signature Synapse | Sur incident (procédure spéciale) | Fédération invalide |
| Client secret OIDC | Sur incident | Authentification compromise |

---

## 6. Commandes de vérification sécurité

```bash
# Vérifier qu'aucun secret n'est tracké par Git
git ls-files | xargs grep -l "CHANGE_ME" 2>/dev/null

# Vérifier le .gitignore
git check-ignore -v .env data/ data/synapse/homeserver.yaml

# Scanner les secrets dans l'historique
git log --all -p | grep -E "(registration_shared_secret|macaroon_secret_key|form_secret):" | grep -v "CHANGE_ME"

# Vérifier les permissions du .env
ls -la .env   # doit être -rw------- (600)
```

---

## Références

- [Synapse Security](https://matrix-org.github.io/synapse/latest/security_checklist.html)
- [Matrix E2EE](https://spec.matrix.org/v1.11/client-server-api/#end-to-end-encryption)
- [Authentik Security](https://docs.goauthentik.io/docs/security)
