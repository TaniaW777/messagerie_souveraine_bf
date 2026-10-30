# Scénario de démonstration (3 minutes)

## 0:00 - 0:45 : Connexion & 2FA (Le gardien Authentik)
- L'Agent A ouvre Element Web (le carnet).
- Authentik demande le code (2FA).
- L'Agent A entre dans le canal #sante-bf.
- *Note pour le jury :* Le Membre 2 explique que le facteur (Synapse) ne voit pas le mot de passe, seulement Authentik le valide.

## 0:45 - 1:30 : Échange chiffré (La serrure Olm/Megolm)
- L'Agent A envoie "Bonjour" (ou "Neere" en Mooré) à l'Agent B.
- *Note pour le jury :* Le Membre 2 montre que la base de données (PostgreSQL) et le réseau ne voient que du charabia (Olm/Megolm).

## 1:30 - 2:15 : Révocation immédiate (Le départ)
- L'Admin retire l'Agent B via Authentik/Synapse.
- L'Agent B ne reçoit plus les nouvelles lettres.
- *Note pour le jury :* Le Membre 2 prouve que la serrure (Megolm) change.

## 2:15 - 3:00 : Innovation & Langues (Ton rôle - Membre 3)
- Montre les canaux institutionnels (#sante-bf, #education-bf).
- Montre l'interface en Mooré ou Dioula (ex: "Neere" au lieu de "Bonjour").
- Montre la classification "Secret" (interdiction capture d'écran).
- *Note pour le jury :* Explique pourquoi c'est utile pour l'administration burkinabè.

---
**RÈGLES D'OR (Membre 3) :**
1. Comprendre la 2FA (Authentik) et le chiffrement (Olm/Megolm) pour l'entretien.
2. Pas de secrets sur GitHub.
3. Commits progressifs (photo du travail chaque jour).
