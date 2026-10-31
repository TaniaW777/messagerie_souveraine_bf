# Installation

Ce guide permet de lancer la messagerie souveraine en local : PostgreSQL, Synapse (serveur Matrix) et Element Web (interface).

## Prérequis

- Docker Desktop (ou Docker + Docker Compose v2), démarré
- Git
- Ports libres sur la machine : **8008** (Synapse) et **8081** (Element)

## 1. Récupérer le projet

```powershell
git clone https://github.com/TaniaW777/messagerie_souveraine_bf.git
cd messagerie_souveraine_bf
git checkout develop
```

## 2. Créer le fichier `.env`

```powershell
Copy-Item .env.example .env
```

Ouvrir `.env` et remplacer `CHANGE_ME_mot_de_passe_long` par un mot de passe PostgreSQL (lettres et chiffres, 16 caractères ou plus). Ce fichier ne doit jamais être publié sur GitHub.

## 3. Créer les dossiers de données

```powershell
mkdir data\synapse, data\postgres
```

## 4. Créer la configuration de Synapse (une seule fois)

```powershell
docker run -it --rm -v "${PWD}/data/synapse:/data" -e SYNAPSE_SERVER_NAME=localhost -e SYNAPSE_REPORT_STATS=no matrixdotorg/synapse:latest generate
```

Trois fichiers apparaissent dans `data/synapse/` : `homeserver.yaml`, `localhost.log.config` et `localhost.signing.key`.

## 5. Brancher PostgreSQL et fermer l'inscription

Dans `data/synapse/homeserver.yaml`, remplacer le bloc `database:` (SQLite) par :

```yaml
database:
  name: psycopg2
  args:
    user: synapse
    password: LE_MOT_DE_PASSE_DU_.env
    database: synapse
    host: db
    port: 5432
    cp_min: 5
    cp_max: 10
enable_registration: false
```

Le mot de passe doit être **identique** à celui de `.env`. Le modèle sans secrets se trouve dans `config/synapse/homeserver.yaml.example`. Le fichier `homeserver.yaml` réel reste dans `data/` et n'est jamais publié.

## 6. Démarrer

```powershell
docker compose up -d
docker compose ps
```

Les trois services (`msb-postgres`, `msb-synapse`, `msb-element`) doivent être **Up** et **healthy** après 30 secondes environ.

## 7. Créer les comptes

Compte administrateur :

```powershell
docker exec -it msb-synapse register_new_matrix_user -c /data/homeserver.yaml -u admin -a http://localhost:8008
```

Comptes de démonstration (sans droits d'administration) :

```powershell
docker exec -it msb-synapse register_new_matrix_user -c /data/homeserver.yaml -u alice --no-admin http://localhost:8008
```

Les mots de passe sont saisis à l'invite et ne sont pas écrits dans ce dépôt.

## 8. Vérifier

| Vérification | Commande ou adresse | Résultat attendu |
|---|---|---|
| API Synapse | `curl.exe http://localhost:8008/_matrix/client/versions` | JSON avec la liste des versions Matrix |
| Tables PostgreSQL | `docker exec -it msb-postgres psql -U synapse -d synapse -P pager=off -c "\dt"` | Liste de tables Synapse |
| Interface | http://localhost:8081 | Page Element « Messagerie Souveraine BF » |
| Échange de messages | Deux sessions (fenêtre normale + fenêtre privée) | Les messages d'un compte apparaissent chez l'autre |

## Arrêt et remise à zéro

```powershell
docker compose down          # arrêter (les données sont conservées),puis supprimer le dossier data\ pour repartir de zéro
         
```

## Dépannage

| Symptôme | Cause probable |
|---|---|
| Synapse redémarre en boucle | Mot de passe différent entre `.env` et `homeserver.yaml` |
| Changement de mot de passe sans effet | PostgreSQL enregistre le mot de passe au premier démarrage : supprimer `data\postgres` |
| Element ne démarre pas | Port 8081 déjà utilisé : changer le port dans `docker-compose.yml` |
| Element ne trouve pas le serveur | Vérifier `base_url` dans `config/element/config.json` |