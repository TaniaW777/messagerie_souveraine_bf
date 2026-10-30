# Installation

Prérequis : Docker et Docker Compose.

1. Copier `.env.example` vers `.env` et changer le mot de passe PostgreSQL.
2. Préparer la config Synapse (voir `config/synapse/homeserver.yaml.example`).
3. Lancer : `docker compose up -d`
4. Vérifier : `docker compose ps` (3 services "Up").
5. Ouvrir Element : http://localhost:8080
6. Créer un compte :
   `docker exec -it msb-synapse register_new_matrix_user -c /data/homeserver.yaml -u admin -p MOT_DE_PASSE -a http://localhost:8008`