# Scénario Officiel de Démonstration Vidéo (3 Minutes Max)
## Messagerie Souveraine BF — Sprint Technique Pré-Hackathon 226

**Durée totale maximale :** **3 minutes (180 secondes)** — *Strictement conforme à la Section ❹ du règlement officiel du MTDPCE.*  
**Intervenants à l'écran :**
- Fenêtre 1 (Gauche) : **Alice Demo** (`@alice_demo:messagerie.local` - Responsable de crise)
- Fenêtre 2 (Droite) : **Bob Demo** (`@bob_demo:messagerie.local` - Agent de terrain)
- Fenêtre 3 (Terminal incrusté) : Preuve SQL et API Synapse

---

## Chronogramme Minute par Minute (Conducteur de Tournage)

```
00:00 ──────────────── 00:35 ──────────────── 01:20 ──────────────── 02:05 ──────────────── 02:45 ── 03:00
 │  Authentification   │   Échange E2EE      │    Révocation      │   Innovation       │   Conclusion
 │  OIDC + MFA TOTP    │   & Preuve SQL      │    Immédiate       │   FASOVOICE        │
```

---

### Séquence 1 : Authentification Forte & Contrôle d'Accès (00:00 - 00:35 | Durée : 35s)
- **Visuel :** Navigateur sur `https://messagerie.local`. Clic sur « Se connecter avec Authentik ». Redirection vers `https://auth.messagerie.local`.
- **Actions à l'écran :**
  1. Alice saisit son identifiant `alice_demo` et son mot de passe.
  2. Authentik demande immédiatement le code à 6 chiffres TOTP (RFC 6238).
  3. Saisie du code dynamique valide. Redirection transparente vers Element Web.
  4. Montrer que l'auto-inscription publique est désactivée sur le serveur.
- **Voix off (narration concise) :**
  > « Bienvenue dans la démonstration de la Messagerie Souveraine BF. Seuls les agents pré-enrôlés par l'État peuvent accéder au système. L'authentification délègue l'identité à notre IdP Authentik souverain avec un second facteur TOTP obligatoire. Aucun compte étranger ne peut s'inscrire librement. »

---

### Séquence 2 : Échange Chiffré E2EE & Preuve SQL (00:35 - 01:20 | Durée : 45s)
- **Visuel :** Deux fenêtres côte à côte (Alice et Bob dans le salon chiffré `Cellule de Crise Souveraine`), avec incrustation du terminal.
- **Actions à l'écran :**
  1. Alice envoie un message confidentiel : *« Ordre de mission : sécurisation du secteur opérationnel. »*
  2. Bob reçoit et déchiffre instantanément le message avec l'icône cadenas E2EE.
  3. Bob répond de manière chiffrée.
  4. **Preuve en direct :** Dans le terminal, exécuter la requête PostgreSQL :
     ```bash
     docker exec msb-postgres psql -U synapse -d synapse -c \
       "SELECT event_id, type, (ej.json::jsonb->'content'->>'algorithm') AS algo, LENGTH(ej.json::jsonb->'content'->>'ciphertext') AS octets FROM events e JOIN event_json ej ON e.event_id=ej.event_id WHERE e.type='m.room.encrypted' ORDER BY e.stream_ordering DESC LIMIT 2;"
     ```
  5. Montrer que la base ne stocke que du ciphertext Megolm (`m.megolm.v1.aes-sha2`). Zéro texte en clair !
- **Voix off :**
  > « Toutes les communications sont chiffrées de bout en bout avec le protocole Megolm v1 AES-SHA2. Côté serveur, notre inspection directe de PostgreSQL le prouve : aucun message n'apparaît en clair. Même un administrateur système ou un attaquant ayant compromis la base ne peut rien lire. »

---

### Séquence 3 : Révocation Immédiate en Direct (01:20 - 02:05 | Durée : 45s)
- **Visuel :** Alice retire Bob du salon ; tentative d'envoi de Bob et terminal d'administration.
- **Actions à l'écran :**
  1. Alice exclut Bob du salon (`Exclure du salon` / Kick).
  2. Côté Bob, l'accès au salon se ferme immédiatement.
  3. Bob tente d'émettre un message via l'API :
     Le serveur Synapse renvoie immédiatement **HTTP 403 `M_FORBIDDEN`** (*« User not in room »*).
  4. La requête SQL de contrôle montre le changement de statut `membership = leave` et l'absence de tout nouvel événement pour Bob.
- **Voix off :**
  > « Épreuve de révocation : Alice exclut Bob de la cellule. Instantanément, la session de Bob perd ses droits sur le salon. Toute tentative d'envoi ultérieure est immédiatement rejetée par le serveur avec le code HTTP 403 Forbidden. L'étanchéité des communications est garantie. »

---

### Séquence 4 : Innovation — FASOVOICE (02:05 - 02:45 | Durée : 40s)
- **Visuel :** Console d'alerte de crise sur `https://messagerie.local/fasovoice/`.
- **Actions à l'écran :**
  1. Alice ouvre la console **FasoVoice**.
  2. Sélectionne l'alerte sécuritaire `ALERT-SEC-01` en mode **Trilingue (Français, Mooré, Dioula)**.
  3. Clic sur **« Lire l'Alerte (Audio) »** -> la synthèse vocale locale énonce l'alerte en direct.
  4. Clic sur **« Diffuser Immédiatement »** : le message trilingue arrive instantanément dans les salons Matrix.
  5. Montrer la réception en direct des accusés de réception horodatés des agents sur le terrain.
- **Voix off :**
  > « Notre innovation : FASOVOICE. En situation de crise, les ordres doivent être compris de tous. FasoVoice permet de diffuser des alertes vérifiées en Français, Mooré et Dioula, avec lecture audio locale sans aucune API externe payante, et un suivi temps réel des accusés de réception. »

---

### Séquence 5 : Conclusion et Bilan Souverain (02:45 - 03:00 | Durée : 15s)
- **Visuel :** Écran récapitulatif avec les technologies (Synapse, Element, Authentik, Nginx, PostgreSQL) et les mentions légales.
- **Voix off :**
  > « Messagerie Souveraine BF offre à l'État burkinabè une solution 100% open source, mathématiquement inviolable, multilingue et installable en une seule commande. La Patrie ou la Mort, nous Vaincrons ! »

---

## Fiche Pratique pour le Tournage

| Étape | Commande d'initialisation | Durée chrono |
|---|---|---|
| **Préparation** | `./scripts/demo_video_preflight.sh` | Avant enregistrement |
| **Vérification santé** | `./scripts/health_check.sh` | Validation préalable |
| **Preuve SQL E2EE** | `tests/postgres_validation.sql` | Pendant séquence 2 |
| **Console FasoVoice** | `https://messagerie.local/fasovoice/` | Pendant séquence 4 |
