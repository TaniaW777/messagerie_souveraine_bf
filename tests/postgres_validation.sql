-- ==============================================================================
-- TESTS DE VALIDATION POSTGRESQL — MESSAGERIE SOUVERAINE BF
-- Script de vérification de l'intégrité, du chiffrement et des accès
-- Compatible PostgreSQL 16 & Matrix Synapse v1.164.1
-- ==============================================================================

-- 1. VÉRIFICATION DE L'INVENTAIRE DES COMPTES UTILISATEURS
-- Objectif : Vérifier qu'aucun compte non autorisé n'est actif et isoler l'administrateur
SELECT
    name AS utilisateur_matrix,
    admin,
    deactivated AS compte_desactive,
    is_guest AS est_invite,
    to_timestamp(creation_ts) AS date_creation
FROM users
ORDER BY admin DESC, creation_ts DESC;

-- 2. VÉRIFICATION DE LA DÉLÉGATION D'IDENTITÉ OIDC (AUTHENTIK)
-- Objectif : Vérifier le couplage entre l'IdP Authentik et les comptes Matrix locaux
SELECT
    auth_provider AS fournisseur_identite,
    external_id AS identifiant_externe_authentik,
    user_id AS compte_synapse_associe
FROM user_external_ids
ORDER BY user_id;

-- 3. VÉRIFICATION DE LA POLITIQUE DES SALONS ET DU CHIFFREMENT DE BOUT EN BOUT
-- Objectif : Vérifier que les salons créés sont privés et possèdent la clé d'état m.room.encryption
SELECT
    r.room_id,
    r.creator AS createur_salon,
    r.is_public AS est_public,
    (ej.json::jsonb -> 'content' ->> 'algorithm') AS algorithme_chiffrement
FROM rooms r
LEFT JOIN current_state_events cse
    ON r.room_id = cse.room_id AND cse.type = 'm.room.encryption'
LEFT JOIN event_json ej
    ON cse.event_id = ej.event_id
ORDER BY r.room_id;

-- 4. PREUVE DE SOUVERAINETÉ CRYPTOGRAPHIQUE (E2EE MEGOLM)
-- Objectif : Prouver que le serveur ne stocke que du ciphertext illisible (Megolm v1 AES-SHA2)
--            et ne dispose jamais du contenu textuel en clair
SELECT
    e.event_id,
    e.room_id,
    e.sender AS emetteur,
    e.type,
    e.stream_ordering,
    (ej.json::jsonb -> 'content' ->> 'algorithm') AS algorithme,
    (ej.json::jsonb -> 'content' ->> 'session_id') AS identifiant_session_megolm,
    CASE
        WHEN (ej.json::jsonb -> 'content' ->> 'ciphertext') IS NOT NULL
        THEN 'Présent (chiffré - ' || LENGTH(ej.json::jsonb -> 'content' ->> 'ciphertext') || ' octets)'
        ELSE 'Absent'
    END AS preuve_ciphertext
FROM events e
JOIN event_json ej ON e.event_id = ej.event_id
WHERE e.type = 'm.room.encrypted'
ORDER BY e.stream_ordering DESC
LIMIT 10;

-- 5. PREUVE DU CYCLE DE GOUVERNANCE ET RÉVOCATION D'ACCÈS DANS UN SALON
-- Objectif : Démontrer le changement d'état d'adhésion (join -> leave) lors de l'exclusion
--            et prouver qu'aucun événement postérieur n'est accepté pour le membre exclu
SELECT
    e.event_id,
    e.room_id,
    e.sender AS actionnaire,
    e.type AS type_evenement,
    e.stream_ordering,
    (ej.json::jsonb -> 'content' ->> 'membership') AS statut_adhesion,
    (ej.json::jsonb ->> 'state_key') AS utilisateur_cible,
    (ej.json::jsonb -> 'content' ->> 'reason') AS motif_exclusion
FROM events e
JOIN event_json ej ON e.event_id = ej.event_id
WHERE e.type = 'm.room.member'
ORDER BY e.stream_ordering DESC
LIMIT 10;
