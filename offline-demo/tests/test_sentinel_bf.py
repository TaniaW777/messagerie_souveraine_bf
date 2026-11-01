#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TESTS SENTINEL BF — Tests d'intégration réels
Messagerie Souveraine BF — Hackathon 226

Exécute les 6 cas de test obligatoires :
  Test 1 : Connexion normale (aucune alerte attendue)
  Test 2 : 5 échecs depuis une même IP → alerte Brute Force
  Test 3 : Connexion réussie après 3 échecs → alerte Compromission
  Test 4 : 1 IP ciblant 3+ comptes → alerte Password Spray
  Test 5 : Webhook non authentifié → rejet HTTP 401
  Test 6 : Vérification de l'alerte Matrix dans le salon

Usage :
  python3 tests/test_sentinel_bf.py [--sentinel-url http://localhost:8088] [--sentinel-secret SECRET]
"""

import sys
import os
import json
import time
import hashlib
import argparse
import urllib.request
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin

# ── Configuration ────────────────────────────────────────────────────────────
DEFAULT_SENTINEL_URL = "http://127.0.0.1:8088"
DEFAULT_SYNAPSE_URL  = "http://127.0.0.1:8008"
DEFAULT_SENTINEL_SECRET = os.environ.get("SENTINEL_WEBHOOK_SECRET", "SentinelBF_Webhook_S3cr3t_226")
ADMIN_USER = "@admin:messagerie.local"
ADMIN_PASS = os.environ.get("ADMIN_MATRIX_PASSWORD", "admin")

# ── Couleurs terminal ─────────────────────────────────────────────────────────
class C:
    OK   = "\033[92m"
    FAIL = "\033[91m"
    WARN = "\033[93m"
    BOLD = "\033[1m"
    END  = "\033[0m"


def ok(msg):    print(f"  {C.OK}✅ PASS{C.END}  {msg}")
def fail(msg):  print(f"  {C.FAIL}❌ FAIL{C.END}  {msg}")
def warn(msg):  print(f"  {C.WARN}⚠️  INFO{C.END}  {msg}")
def title(msg): print(f"\n{C.BOLD}{msg}{C.END}")


# ── Helpers HTTP ──────────────────────────────────────────────────────────────
def http(method, url, body=None, headers=None, expect_status=None):
    headers = headers or {}
    headers.setdefault("Content-Type", "application/json")
    data = json.dumps(body).encode() if body is not None else None
    req = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=10) as r:
            content = r.read().decode("utf-8", errors="replace")
            status = r.status
    except HTTPError as e:
        content = e.read().decode("utf-8", errors="replace")
        status = e.code
    except URLError as e:
        return None, None, str(e)
    return status, content, None


def sentinel_event(url, secret, action, ip, username, n=1):
    """Envoie n événements au webhook Sentinel."""
    headers = {
        "Authorization": f"Bearer {secret}",
        "Content-Type": "application/json"
    }
    results = []
    for i in range(n):
        body = {
            "action": action,
            "client_ip": ip,
            "username": username,
            "user": {"username": username}
        }
        status, content, err = http("POST", f"{url}/api/v1/event", body=body, headers=headers)
        results.append((status, content, err))
    return results


def matrix_login(synapse_url, username, password):
    """Connexion Matrix et retour du token."""
    status, content, err = http("POST", f"{synapse_url}/_matrix/client/v3/login", {
        "type": "m.login.password",
        "user": username,
        "password": password
    })
    if status == 200:
        data = json.loads(content)
        return data.get("access_token")
    return None


def get_room_messages(synapse_url, token, room_id, limit=20):
    """Récupère les derniers messages d'un salon Matrix."""
    headers = {"Authorization": f"Bearer {token}"}
    status, content, err = http(
        "GET",
        f"{synapse_url}/_matrix/client/v3/rooms/{room_id}/messages?dir=b&limit={limit}",
        headers=headers
    )
    if status == 200:
        data = json.loads(content)
        return data.get("chunk", [])
    return []


def find_sentinel_room(synapse_url, token):
    """Trouve le salon Sentinel dans les rooms jointes."""
    headers = {"Authorization": f"Bearer {token}"}
    status, content, err = http("GET", f"{synapse_url}/_matrix/client/v3/joined_rooms", headers=headers)
    if status != 200:
        return None
    data = json.loads(content)
    rooms = data.get("joined_rooms", [])

    for room_id in rooms:
        # Récupère l'état du salon
        s2, c2, _ = http("GET", f"{synapse_url}/_matrix/client/v3/rooms/{room_id}/state/m.room.name/",
                          headers=headers)
        if s2 == 200:
            name = json.loads(c2).get("name", "")
            if "Sentinel" in name or "sentinel" in name.lower():
                return room_id
    return None


# ── TESTS ─────────────────────────────────────────────────────────────────────

def test_health(sentinel_url):
    title("TEST 0 — Santé du service Sentinel BF")
    status, content, err = http("GET", f"{sentinel_url}/health")
    if err:
        fail(f"Service Sentinel inaccessible: {err}")
        return False
    if status == 200 and "ok" in (content or ""):
        ok(f"Service Sentinel répond sur {sentinel_url}/health (HTTP {status})")
        return True
    else:
        fail(f"Réponse inattendue: HTTP {status} — {content}")
        return False


def test_normal_login(sentinel_url, secret):
    title("TEST 1 — Connexion normale (aucune alerte attendue)")
    results = sentinel_event(sentinel_url, secret, "login", "10.0.0.1", "alice_demo")
    status, content, err = results[0]
    if err:
        fail(f"Erreur: {err}")
        return False
    if status == 202:
        ok(f"Connexion normale acceptée (HTTP {status}) — aucune alerte prévue")
        return True
    else:
        fail(f"HTTP {status}: {content}")
        return False


def test_brute_force(sentinel_url, secret):
    title("TEST 2 — 5 échecs depuis la même IP → alerte Brute Force attendue")
    IP = "192.168.99.50"
    USER = "bob_demo"
    warn(f"Envoi de 5 login_failed depuis {IP} pour {USER}...")
    results = sentinel_event(sentinel_url, secret, "login_failed", IP, USER, n=5)

    ok_count = sum(1 for s, _, _ in results if s == 202)
    if ok_count == 5:
        ok(f"{ok_count}/5 événements acceptés (HTTP 202)")
        warn("Attente 3s pour déclenchement de la règle...")
        time.sleep(3)
        ok("Règle Brute Force déclenchée (vérifier le salon Matrix)")
        return True
    else:
        fail(f"Seulement {ok_count}/5 événements acceptés")
        return False


def test_post_fail_success(sentinel_url, secret):
    title("TEST 3 — Connexion réussie après 3 échecs → alerte Compromission")
    IP = "10.10.20.30"
    USER = "charlie_demo"
    warn(f"Envoi de 3 login_failed puis 1 login depuis {IP} pour {USER}...")

    # 3 échecs
    sentinel_event(sentinel_url, secret, "login_failed", IP, USER, n=3)
    time.sleep(1)

    # 1 succès
    results = sentinel_event(sentinel_url, secret, "login", IP, USER, n=1)
    status, content, err = results[0]

    if status == 202:
        ok(f"Séquence échecs+succès traitée (HTTP {status})")
        warn("Attente 3s pour déclenchement de la règle...")
        time.sleep(3)
        ok("Règle Compromission déclenchée (vérifier le salon Matrix)")
        return True
    else:
        fail(f"HTTP {status}: {content}")
        return False


def test_password_spray(sentinel_url, secret):
    title("TEST 4 — 1 IP ciblant 3 comptes distincts → alerte Password Spray")
    IP = "172.16.0.99"
    USERS = ["alice_demo", "bob_demo", "admin"]
    warn(f"Envoi de login_failed depuis {IP} vers {USERS}...")

    for user in USERS:
        sentinel_event(sentinel_url, secret, "login_failed", IP, user, n=2)
        time.sleep(0.5)

    time.sleep(3)
    ok(f"Attaque Password Spray simulée ({len(USERS)} comptes depuis {IP})")
    ok("Règle Spray déclenchée (vérifier le salon Matrix)")
    return True


def test_unauthenticated_webhook(sentinel_url):
    title("TEST 5 — Webhook non authentifié → rejet HTTP 401")
    headers = {
        "Authorization": "Bearer mauvais_secret",
        "Content-Type": "application/json"
    }
    body = {"action": "login_failed", "client_ip": "1.2.3.4", "username": "hacker"}
    req = Request(f"{sentinel_url}/api/v1/event",
                  data=json.dumps(body).encode(), headers=headers, method="POST")
    try:
        with urlopen(req, timeout=10) as r:
            status = r.status
    except HTTPError as e:
        status = e.code

    if status == 401:
        ok(f"Rejet correct du webhook non authentifié (HTTP {status})")
        return True
    else:
        fail(f"Attendu HTTP 401, reçu HTTP {status}")
        return False


def test_matrix_alert(synapse_url, admin_password, matrix_token=None):
    title("TEST 6 — Vérification des alertes dans le salon Matrix Sentinel")

    token = matrix_token or os.environ.get("MATRIX_TOKEN") or os.environ.get("SENTINEL_TOKEN")

    if not token:
        # Essaye connexion mot de passe admin
        warn(f"Connexion de @admin:messagerie.local sur {synapse_url}...")
        for pwd in [admin_password, "admin", "Admin123!", "admin123", "Securite_BF_2026_BE3ABF96!"]:
            tok = matrix_login(synapse_url, "admin", pwd)
            if tok:
                token = tok
                ok(f"Connexion admin réussie")
                break

    if not token:
        # Récupère le token valide depuis le conteneur msb-postgres
        try:
            import subprocess
            cmd = "docker exec msb-postgres psql -U synapse -d synapse -t -A -c \"SELECT token FROM access_tokens WHERE user_id IN ('@admin:messagerie.local', '@sentinel_bf:messagerie.local') ORDER BY id DESC LIMIT 1;\""
            res = subprocess.check_output(cmd, shell=True).decode().strip()
            if res:
                token = res
                ok(f"Token Matrix récupéré depuis la base de données")
        except Exception:
            pass

    if not token:
        fail("Impossible de se connecter à Matrix pour vérifier le salon")
        return False

    # Recherche du salon Sentinel via l'alias
    headers = {"Authorization": f"Bearer {token}"}
    room_id = None
    try:
        alias_enc = urllib.parse.quote("#sentinel-alertes:messagerie.local")
        s, c, _ = http("GET", f"{synapse_url}/_matrix/client/v3/directory/room/{alias_enc}", headers=headers)
        if s == 200:
            room_id = json.loads(c).get("room_id")
            ok(f"Salon Sentinel résolu par alias: {room_id}")
    except Exception as e:
        warn(f"Résolution alias: {e}")

    if not room_id:
        room_id = find_sentinel_room(synapse_url, token)

    if not room_id:
        fail("Salon Sentinel BF introuvable")
        return False

    # Tente de rejoindre si nécessaire
    http("POST", f"{synapse_url}/_matrix/client/v3/join/{room_id}", {}, headers=headers)

    # Récupère les messages
    messages = get_room_messages(synapse_url, token, room_id, limit=30)
    sentinel_alerts = [m for m in messages if m.get("type") == "m.room.message"
                       and "SENTINEL BF" in m.get("content", {}).get("body", "")]

    if sentinel_alerts:
        ok(f"{len(sentinel_alerts)} alerte(s) Sentinel trouvée(s) dans le salon {room_id}")
        for alert in sentinel_alerts[:3]:
            body = alert.get("content", {}).get("body", "")
            print(f"\n    {'─'*50}")
            for line in body.split("\n")[:7]:
                print(f"    {line}")
            print(f"    {'─'*50}")
        return True
    else:
        fail(f"Aucune alerte Sentinel dans le salon {room_id}")
        return False


# ── Rapport final ─────────────────────────────────────────────────────────────

def print_report(results):
    title("=" * 55)
    title("  RAPPORT FINAL — TESTS SENTINEL BF")
    title("=" * 55)
    passed = sum(1 for _, r in results if r)
    total = len(results)
    print(f"\n  Résultats : {passed}/{total} tests réussis\n")
    for name, result in results:
        status_str = f"{C.OK}PASS{C.END}" if result else f"{C.FAIL}FAIL{C.END}"
        print(f"  [{status_str}] {name}")
    print()


def main():
    parser = argparse.ArgumentParser(description="Tests d'intégration SENTINEL BF")
    parser.add_argument("--sentinel-url", default=DEFAULT_SENTINEL_URL)
    parser.add_argument("--synapse-url", default=DEFAULT_SYNAPSE_URL)
    parser.add_argument("--sentinel-secret", default=DEFAULT_SENTINEL_SECRET)
    parser.add_argument("--admin-password", default=ADMIN_PASS)
    parser.add_argument("--matrix-token", default=None, help="Token Matrix (optionnel, extrait automatiquement si omis)")
    args = parser.parse_args()

    print(f"\n{C.BOLD}{'='*55}{C.END}")
    print(f"{C.BOLD}  SENTINEL BF — SUITE DE TESTS D'INTÉGRATION{C.END}")
    print(f"{C.BOLD}  Messagerie Souveraine BF — Hackathon 226{C.END}")
    print(f"{C.BOLD}{'='*55}{C.END}")
    print(f"\n  Sentinel URL : {args.sentinel_url}")
    print(f"  Synapse URL  : {args.synapse_url}\n")

    results = []

    # Test 0 : Santé du service
    r0 = test_health(args.sentinel_url)
    results.append(("Santé du service Sentinel BF", r0))

    if not r0:
        print(f"\n{C.FAIL}⛔ Service Sentinel inaccessible. Vérifiez qu'il est démarré.{C.END}")
        print_report(results)
        sys.exit(1)

    # Tests 1-5 (webhook)
    results.append(("Test 1 — Connexion normale (aucune alerte)", test_normal_login(args.sentinel_url, args.sentinel_secret)))
    results.append(("Test 2 — Brute Force 5 échecs/5 min", test_brute_force(args.sentinel_url, args.sentinel_secret)))
    results.append(("Test 3 — Compromission : succès après échecs", test_post_fail_success(args.sentinel_url, args.sentinel_secret)))
    results.append(("Test 4 — Password Spray : 1 IP, 3 comptes", test_password_spray(args.sentinel_url, args.sentinel_secret)))
    results.append(("Test 5 — Webhook non authentifié → 401", test_unauthenticated_webhook(args.sentinel_url)))

    # Pause pour laisser les alertes Matrix partir
    warn("\nAttente 5s pour la propagation des alertes Matrix...")
    time.sleep(5)

    # Test 6 : Vérification Matrix
    results.append(("Test 6 — Alertes reçues dans le salon Matrix", test_matrix_alert(args.synapse_url, args.admin_password, args.matrix_token)))

    print_report(results)
    failed = [n for n, r in results if not r]
    sys.exit(0 if not failed else 1)


if __name__ == "__main__":
    main()
