# GUIDE DE DÉMONSTRATION JURY — MESSAGERIE SOUVERAINE BF
## Hackathon 226 | 3 minutes pour convaincre

---

## ACCÈS RAPIDE

| Service | URL | Statut |
|---------|-----|--------|
| 💬 **Messagerie** | https://messagerie.local | Cliquer ici |
| 🔑 **Portail Auth** | https://auth.messagerie.local | (Redirigé auto.) |
| 🎙️ **FasoVoice** | https://messagerie.local/fasovoice/ | Innovation |

---

## COMPTES DE DÉMONSTRATION

| Nom | Identifiant | Rôle |
|-----|------------|------|
| 👩 Alice | `alice_demo` | Responsable cellule de crise |
| 👨 Bob | `bob_demo` | Agent d'intervention terrain |
| 👨 Charlie | `charlie_demo` | Observateur officiel |

> Le mot de passe se trouve dans `.credentials_demo.local`

---

## SCÉNARIO 3 MINUTES

### ⏱️ 0:00 — Souveraineté (30 sec)
- Montrer que **zéro Internet n'est nécessaire** : déconnecter le câble ou désactiver le Wi-Fi
- Exécuter : `./scripts/health_check.sh` → tous les checks VERTS ✅
- Montrer `docker ps` → 7 conteneurs, tous `healthy`

---

### ⏱️ 0:30 — Authentification sécurisée (45 sec)
1. Ouvrir **https://messagerie.local**
2. Cliquer "Se connecter" → Redirection automatique vers Authentik
3. Saisir `alice_demo` + mot de passe
4. **TOTP** : saisir le code à 6 chiffres depuis l'app d'authentification (Google Authenticator)
5. Accès accordé → Tableau de bord Element ✅

---

### ⏱️ 1:15 — Messagerie chiffrée E2EE (60 sec)
1. Ouvrir le **salon de crise** (salon partagé entre Alice, Bob, Charlie)
2. Envoyer un message → Vérifier l'icône 🔒 (Megolm AES-256)
3. Depuis un second navigateur, se connecter en tant que `bob_demo`
4. Tenter l'accès depuis un compte **non autorisé** → Refus confirmé ✅
5. Envoyer un fichier → Vérifier qu'il est chiffré ✅

---

### ⏱️ 2:15 — FasoVoice : Innovation trilingue hors-ligne (45 sec)
1. Ouvrir **https://messagerie.local/fasovoice/**
2. Sélectionner l'alerte **ALERT-SEC-01** (Urgence sécurité)
3. Cliquer **🇫🇷 Français** → Lecture audio préenregistrée locale
4. Cliquer **🌐 Trilingue** → Lecture FR + Mooré + Dioula
5. Cliquer **📢 Diffuser sur Matrix** → Alerte envoyée au salon de crise
6. Vérifier dans Element : l'alerte + le clip audio ᶠasoVoice sont reçus ✅

---

### ⏱️ 3:00 — Fin
- Conclure : **Souveraineté totale, chiffrement de bout en bout, support des langues nationales burkinabè**

---

## COMMANDES UTILES POUR LE JURY

```bash
# Contrôle de santé complet
./scripts/health_check.sh

# Vérifier que la fédération est désactivée (sécurité)
curl -sk https://127.0.0.1/_matrix/federation/v1/version | grep -i "error\|404"

# Démonstration FasoVoice via CLI
python3 scripts/fasovoice_alert.py demo

# Tester le rejet d'un intrus
python3 tests/test_matrix_security.py
```

---

## EN CAS DE PROBLÈME

| Symptôme | Solution |
|----------|---------|
| "Impossible de se connecter" | Vérifier `/etc/hosts` (ligne `127.0.0.1 messagerie.local`) |
| Certificat non reconnu | Importer `certs/rootCA.pem` → voir INSTALL.md |
| Service non démarré | `./scripts/start.sh` |
| Bilan de santé échoué | `docker logs msb-synapse` ou `docker logs authentik-server-1` |

---

## NOTES TECHNIQUES

- **Chiffrement** : Megolm v1 (AES-256-SHA2) — chiffrement de bout en bout Matrix
- **IdP** : Authentik 2026.8.5 — OIDC + TOTP sans cloud
- **Fédération** : Désactivée (`federation_domain_whitelist: []`)
- **Ports** : Tous liés à `127.0.0.1` uniquement (aucune exposition réseau par défaut)
- **Données** : PostgreSQL 16 — persistance garantie hors connexion
