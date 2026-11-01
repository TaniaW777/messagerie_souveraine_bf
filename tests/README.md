# Guide des Campagnes de Tests — Messagerie Souveraine BF

Ce répertoire centralise les procédures, scripts et requêtes de validation technique de la plateforme **Messagerie Souveraine BF**.

---

## 1. Organisation des Tests

| Emplacement | Objet des tests | Méthode d'exécution |
|---|---|---|
| [`tests/postgres_validation.sql`](file:///home/jonathan-ouedraogo/messagerie_souveraine_bf/tests/postgres_validation.sql) | Vérification de la base PostgreSQL (comptes, chiffrement Megolm, adhésions, salons) | Requêtes SQL directes |
| [`tests/e2ee/`](file:///home/jonathan-ouedraogo/messagerie_souveraine_bf/tests/e2ee/) | Validation du chiffrement de bout en bout (E2EE) Megolm v1 AES-SHA2 | Client Element / API Matrix |
| [`tests/mfa/`](file:///home/jonathan-ouedraogo/messagerie_souveraine_bf/tests/mfa/) | Validation de l'authentification forte Authentik SSO OIDC et second facteur TOTP (RFC 6238) | Navigateur / API Authentik |
| [`tests/revocation/`](file:///home/jonathan-ouedraogo/messagerie_souveraine_bf/tests/revocation/) | Validation du cycle de vie des accès : exclusion d'un salon, révocation d'appareil et désactivation de compte | API Matrix / Synapse Admin API |
| [`scripts/health_check.sh`](file:///home/jonathan-ouedraogo/messagerie_souveraine_bf/scripts/health_check.sh) | Contrôle automatisé de santé de l'ensemble des conteneurs, sondes HTTP et ports | Script Bash automatisé |
| [`scripts/demo_video_preflight.sh`](file:///home/jonathan-ouedraogo/messagerie_souveraine_bf/scripts/demo_video_preflight.sh) | Pré-vol technique complet avant tournage de la vidéo de démonstration | Script Bash automatisé |

---

## 2. Exécution Rapide des Vérifications

### A. Contrôle de santé global de l'infrastructure
```bash
cd ~/messagerie_souveraine_bf
./scripts/health_check.sh
```

### B. Validation des données en base PostgreSQL
```bash
docker exec -i msb-postgres psql -U synapse -d synapse < tests/postgres_validation.sql
```

### C. Pré-vol pour la démonstration vidéo
```bash
./scripts/demo_video_preflight.sh
```

---

## 3. Comptes de Test Recommandés

Les tests opérationnels utilisent les comptes nominatifs configurés dans Authentik et Synapse :
- `alice_demo` (Responsable ministériel)
- `bob_demo` (Agent d'intervention)
- `charlie_demo` (Collaborateur cellule)
- `admin` (Compte d'administration système Synapse)

Les mots de passe et secrets TOTP temporaires sont stockés localement dans le fichier sécurisé `.credentials_demo.local` (`chmod 600`), strictement exclu de Git.
