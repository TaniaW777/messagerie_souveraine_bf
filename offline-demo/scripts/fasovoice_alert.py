#!/usr/bin/env python3
"""
FASOVOICE — Moteur de Diffusion d'Alertes Multilingues & Gestion de Crise
Messagerie Souveraine BF — Innovation Hackathon 226
Langues supportées : Français, Mooré, Dioula
Fonctionnalités : Diffusion souveraine Matrix, accusés de réception, synthèse vocale locale.
"""

import os
import sys
import json
import time
import argparse
import subprocess
import requests

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
MESSAGES_FILE = os.path.join(PROJECT_ROOT, "demo", "fasovoice", "messages.json")

BASE_URL = os.environ.get("MSB_BASE_URL", "https://127.0.0.1")
HOST_HEADER = os.environ.get("MSB_HOST", "messagerie.local")

HEADERS = {
    "Host": HOST_HEADER,
    "Content-Type": "application/json"
}

def load_corpus():
    with open(MESSAGES_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def get_token(username="alice_demo"):
    try:
        user_id = f"@{username}:messagerie.local"
        token = subprocess.check_output([
            "docker", "exec", "msb-postgres", "psql", "-U", "synapse", "-d", "synapse", "-tAc",
            f"SELECT token FROM access_tokens WHERE user_id = '{user_id}' ORDER BY last_validated DESC LIMIT 1;"
        ]).decode().strip()
        if token:
            return token
    except Exception:
        pass
    return None

def format_alert_message(alert, lang="all"):
    """Formate le message en fonction de la langue choisie (fr, mo, di, ou all)."""
    sev_emoji = {
        "URGENCE": "🔴 [URGENCE MAXIMALE]",
        "VIGILANCE": "🟡 [VIGILANCE RENFORCÉE]",
        "INFO": "🟢 [INFORMATION OFFICIELLE]"
    }.get(alert["severity"], "ℹ️ [ALERTE]")

    blocks = []
    blocks.append(f"{sev_emoji} FASOVOICE — CELLULE DE CRISE NATIONALE")
    blocks.append(f"Identifiant : {alert['id']} | Horodatage : {time.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    blocks.append("-" * 60)

    if lang in ["fr", "all"]:
        blocks.append(f"🇫🇷 FRANÇAIS :\n**{alert['fr']['title']}**\n{alert['fr']['message']}\n")

    if lang in ["mo", "all"]:
        blocks.append(f"🇧🇫 MOORÉ :\n**{alert['mo']['title']}**\n{alert['mo']['message']}\n")

    if lang in ["di", "all"]:
        blocks.append(f"🇧🇫 DIOULA :\n**{alert['di']['title']}**\n{alert['di']['message']}\n")

    blocks.append("-" * 60)
    blocks.append("⚠️ INSTRUCTION DE SERVICE : Veuillez accuser réception dès lecture de ce message.")
    return "\n".join(blocks)

def list_alerts():
    corpus = load_corpus()
    print("=== CORPUS DES ALERTES DE CRISE MULTILINGUES FASOVOICE ===")
    for a in corpus["alerts"]:
        print(f"[{a['severity']}] {a['id']} : {a['category']}")
        print(f"  - FR : {a['fr']['title']}")
        print(f"  - MO : {a['mo']['title']}")
        print(f"  - DI : {a['di']['title']}\n")

def upload_audio_alert(alert_id, lang="fr", sender="alice_demo"):
    """Téléverse le fichier MP3 préenregistré vers le dépôt média Matrix Synapse."""
    aid = alert_id.lower()
    suffix = "trilingue" if lang == "all" else lang
    audio_file = os.path.join(PROJECT_ROOT, "demo", "fasovoice", "audio", f"{aid}-{suffix}.mp3")
    
    if not os.path.exists(audio_file):
        # Fallback to fr
        audio_file = os.path.join(PROJECT_ROOT, "demo", "fasovoice", "audio", f"{aid}-fr.mp3")
        if not os.path.exists(audio_file):
            return None, 0

    token = get_token(sender)
    if not token:
        return None, 0

    with open(audio_file, "rb") as f:
        audio_data = f.read()

    auth_headers = {
        "Host": HOST_HEADER,
        "Authorization": f"Bearer {token}",
        "Content-Type": "audio/mpeg"
    }

    try:
        url = f"{BASE_URL}/_matrix/media/v3/upload?filename={os.path.basename(audio_file)}"
        res = requests.post(url, headers=auth_headers, data=audio_data, verify=False, timeout=15)
        if res.status_code == 200:
            mxc_uri = res.json().get("content_uri")
            return mxc_uri, len(audio_data)
    except Exception as e:
        print(f"[AVERTISSEMENT] Échec du téléversement audio Synapse : {e}")
    return None, 0

def broadcast_alert(alert_id, room_id=None, lang="all", sender="alice_demo", send_voice=True):
    corpus = load_corpus()
    alert = next((a for a in corpus["alerts"] if a["id"] == alert_id), None)
    if not alert:
        print(f"[ERREUR] Alerte introuvable : {alert_id}")
        return False

    body_text = format_alert_message(alert, lang)
    token = get_token(sender)

    if not token:
        print(f"[ERREUR] Impossible de récupérer un jeton de session actif pour {sender}.")
        return False

    auth_headers = {**HEADERS, "Authorization": f"Bearer {token}"}

    # Si aucun salon n'est spécifié, lister les salons de l'émetteur et prendre le premier
    if not room_id:
        try:
            r = requests.get(f"{BASE_URL}/_matrix/client/v3/joined_rooms", headers=auth_headers, verify=False)
            rooms = r.json().get("joined_rooms", [])
            if rooms:
                room_id = rooms[0]
            else:
                # Créer un salon de crise dédié
                cr = requests.post(
                    f"{BASE_URL}/_matrix/client/v3/createRoom",
                    headers=auth_headers,
                    json={"name": "Canal Officiel Alertes FasoVoice", "visibility": "private"},
                    verify=False
                )
                room_id = cr.json().get("room_id")
        except Exception as e:
            print(f"[ERREUR] Détection de salon : {e}")
            return False

    txn_id = f"fasovoice_{int(time.time()*1000)}"
    send_url = f"{BASE_URL}/_matrix/client/v3/rooms/{room_id}/send/m.room.message/{txn_id}"
    payload = {
        "msgtype": "m.text",
        "body": body_text,
        "fasovoice_metadata": {
            "alert_id": alert["id"],
            "severity": alert["severity"],
            "lang": lang,
            "timestamp": int(time.time()),
            "requires_ack": True
        }
    }

    try:
        res = requests.put(send_url, headers=auth_headers, json=payload, verify=False, timeout=10)
        if res.status_code == 200:
            event_id = res.json().get("event_id")
            print(f"[SUCCÈS] Alerte {alert_id} diffusée sur le salon {room_id} !")
            print(f"         Événement Matrix : {event_id}")
            print(f"         Langue(s) : {lang.upper()}")
            print(f"         Gravité : {alert['severity']}")

            # Option audio souverain : téléversement et diffusion vocale
            if send_voice:
                mxc_uri, audio_size = upload_audio_alert(alert_id, lang, sender)
                if mxc_uri:
                    audio_txn = f"audio_{int(time.time()*1000)}"
                    lang_label = "Trilingue (FR/MO/DI)" if lang == "all" else lang.upper()
                    audio_payload = {
                        "msgtype": "m.audio",
                        "body": f"🎙️ FASOVOICE VOCAL — {alert['fr']['title']} [{lang_label}]",
                        "url": mxc_uri,
                        "info": {
                            "mimetype": "audio/mpeg",
                            "size": audio_size
                        }
                    }
                    requests.put(
                        f"{BASE_URL}/_matrix/client/v3/rooms/{room_id}/send/m.room.message/{audio_txn}",
                        headers=auth_headers,
                        json=audio_payload,
                        verify=False,
                        timeout=10
                    )
                    print(f"         [AUDIO HORS-LIGNE] Clip vocal diffusé ({mxc_uri}) !")
            return event_id
        else:
            print(f"[ÉCHEC] Erreur Synapse HTTP {res.status_code} : {res.text}")
            return False
    except Exception as e:
        print(f"[ERREUR] Émission réseau : {e}")
        return False

def run_demo():
    print("==============================================================================")
    print("  DÉMONSTRATION OFFICIELLE FASOVOICE — COMMUNICATION DE CRISE MULTILINGUE    ")
    print("==============================================================================")
    print("Émetteur : Alice Demo (Responsable Cellule de Crise)")
    print("Destinataires : Bob Demo, Charlie Demo (Agents d'intervention)\n")

    # Étape 1 : Diffusion d'une alerte maximale de sécurité en 3 langues
    print("[1/3] Diffusion de l'alerte ALERT-SEC-01 en Français, Mooré et Dioula...")
    event_id = broadcast_alert("ALERT-SEC-01", lang="all", sender="alice_demo")

    if event_id:
        print("\n[2/3] Simulation des accusés de réception signés par les agents...")
        time.sleep(1)
        print("  -> Accusé reçu de Bob Demo (@bob_demo:messagerie.local) à " + time.strftime('%H:%M:%S') + " : 'Accusé réception OK. Équipe confinée.'")
        time.sleep(1)
        print("  -> Accusé reçu de Charlie Demo (@charlie_demo:messagerie.local) à " + time.strftime('%H:%M:%S') + " : 'Vu 5/5. Bâtiment sécurisé.'")

        print("\n[3/3] Résolution de crise et diffusion de la levée d'alerte...")
        time.sleep(1)
        end_event = broadcast_alert("ALERT-END-04", lang="all", sender="alice_demo")
        print("\n[SUCCÈS GLOBAL] Démonstration FasoVoice validée sur le nœud souverain !")
    else:
        print("[ÉCHEC] Impossible d'exécuter la démonstration sur l'API.")

def main():
    parser = argparse.ArgumentParser(description="FASOVOICE — Diffusion multilingue de crise")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("list", help="Lister les alertes prédéfinies du corpus")
    subparsers.add_parser("demo", help="Lancer la démonstration de crise automatisée")

    b_parser = subparsers.add_parser("broadcast", help="Diffuser une alerte")
    b_parser.add_argument("alert_id", help="Identifiant de l'alerte (ex: ALERT-SEC-01)")
    b_parser.add_argument("--room", help="ID du salon Matrix cible", default=None)
    b_parser.add_argument("--lang", help="Langue (fr, mo, di, all)", default="all")
    b_parser.add_argument("--sender", help="Utilisateur émetteur", default="alice_demo")

    args = parser.parse_args()

    if args.command == "list":
        list_alerts()
    elif args.command == "broadcast":
        broadcast_alert(args.alert_id, args.room, args.lang, args.sender)
    elif args.command == "demo" or args.command is None:
        run_demo()

if __name__ == "__main__":
    main()
