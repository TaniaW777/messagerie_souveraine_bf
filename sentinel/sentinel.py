#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SENTINEL BF — Service de détection des connexions suspectes
Messagerie Souveraine BF — Hackathon 226

Architecture :
  - Polling direct de authentik_events_event (PostgreSQL Authentik)
  - Endpoint webhook optionnel (POST /api/v1/event)
  - Moteur de règles de détection
  - Notifications dans un salon Matrix privé (@sentinel_bf:messagerie.local)

Aucun secret n'est codé en dur. Tout provient des variables d'environnement.
"""

import os
import sys
import json
import time
import logging
import hashlib
import sqlite3
import threading
import hmac
from collections import defaultdict, deque
from datetime import datetime, timezone, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from urllib.parse import urljoin
import urllib.request

# ---------------------------------------------------------------------------
# CONFIGURATION (depuis variables d'environnement)
# ---------------------------------------------------------------------------
SYNAPSE_URL           = os.environ.get("SYNAPSE_URL", "http://synapse:8008")
SENTINEL_ADMIN_USER   = os.environ.get("SENTINEL_ADMIN_USER", "@sentinel_bf:messagerie.local")
SENTINEL_ADMIN_ROOM   = os.environ.get("SENTINEL_ADMIN_ROOM", "")          # sera créé au démarrage
MATRIX_ALERT_ROOM_ALIAS = os.environ.get("MATRIX_ALERT_ROOM_ALIAS", "#sentinel-alertes:messagerie.local")

SYNAPSE_SHARED_SECRET = os.environ.get("SYNAPSE_REGISTRATION_SHARED_SECRET", "")
SENTINEL_MATRIX_TOKEN = os.environ.get("SENTINEL_MATRIX_TOKEN", "")        # rempli au démarrage
SENTINEL_ADMIN_INVITE = os.environ.get("SENTINEL_ADMIN_INVITE", "@admin:messagerie.local")
SENTINEL_WEBHOOK_SECRET = os.environ.get("SENTINEL_WEBHOOK_SECRET", "sentinel_bf_secret_default")

AUTHENTIK_PG_HOST    = os.environ.get("AUTHENTIK_PG_HOST", "authentik-postgresql-1")
AUTHENTIK_PG_PORT    = int(os.environ.get("AUTHENTIK_PG_PORT", "5432"))
AUTHENTIK_PG_USER    = os.environ.get("AUTHENTIK_PG_USER", "authentik")
AUTHENTIK_PG_PASS    = os.environ.get("AUTHENTIK_PG_PASS", "")
AUTHENTIK_PG_DB      = os.environ.get("AUTHENTIK_PG_DB", "authentik")

WEBHOOK_PORT         = int(os.environ.get("SENTINEL_WEBHOOK_PORT", "8088"))
POLL_INTERVAL_SEC    = int(os.environ.get("POLL_INTERVAL_SEC", "10"))
DATA_DIR             = os.environ.get("DATA_DIR", "/data")

# Règles de détection
BRUTE_FORCE_THRESHOLD = int(os.environ.get("BRUTE_FORCE_THRESHOLD", "5"))  # tentatives en
BRUTE_FORCE_WINDOW    = int(os.environ.get("BRUTE_FORCE_WINDOW", "300"))   # 300 secondes (5 min)
SPRAY_ACCOUNTS        = int(os.environ.get("SPRAY_ACCOUNTS", "3"))          # comptes distincts en
SPRAY_WINDOW          = int(os.environ.get("SPRAY_WINDOW", "600"))          # 600 secondes (10 min)
POST_FAIL_THRESHOLD   = int(os.environ.get("POST_FAIL_THRESHOLD", "3"))     # échecs avant succès suspect
ALERT_COOLDOWN        = int(os.environ.get("ALERT_COOLDOWN", "600"))        # 10 min anti-doublon

# ---------------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [SENTINEL BF] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%SZ",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(os.path.join(DATA_DIR, "sentinel.log"), encoding="utf-8")
    ]
)
log = logging.getLogger("sentinel_bf")

# ---------------------------------------------------------------------------
# BASE DE DONNÉES LOCALE (SQLite) — persistance des alertes et état
# ---------------------------------------------------------------------------
def init_db(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS processed_events (
            event_uuid TEXT PRIMARY KEY,
            action TEXT,
            processed_at TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            alert_type TEXT,
            signature TEXT,
            ip TEXT,
            username TEXT,
            severity TEXT,
            message TEXT,
            sent_at TEXT,
            matrix_sent INTEGER DEFAULT 0
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS sentinel_state (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)
    conn.commit()
    return conn


DB_PATH = os.path.join(DATA_DIR, "sentinel.db")
db_lock = threading.Lock()
db_conn: sqlite3.Connection = None  # initialisé dans main()

# ---------------------------------------------------------------------------
# ÉTAT EN MÉMOIRE (détection des patterns)
# ---------------------------------------------------------------------------
# {ip: deque[(timestamp, username)]}
ip_failures: dict = defaultdict(lambda: deque())
# {username: deque[timestamp]}
account_failures: dict = defaultdict(lambda: deque())
# {ip: set(usernames tentés)}
ip_targeted_accounts: dict = defaultdict(set)
# {signature: dernier timestamp d'alerte}
alert_cooldowns: dict = {}
state_lock = threading.Lock()

# ---------------------------------------------------------------------------
# UTILITAIRES POSTGRESQL (via psycopg2 ou pg8000 — stdlib compatible)
# ---------------------------------------------------------------------------
try:
    import psycopg2
    import psycopg2.extras
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False
    log.warning("psycopg2 non disponible — tentative avec pg8000")

try:
    import pg8000
    HAS_PG8000 = True
except ImportError:
    HAS_PG8000 = False


def pg_connect():
    """Crée une connexion PostgreSQL à la base Authentik."""
    if HAS_PSYCOPG2:
        return psycopg2.connect(
            host=AUTHENTIK_PG_HOST,
            port=AUTHENTIK_PG_PORT,
            user=AUTHENTIK_PG_USER,
            password=AUTHENTIK_PG_PASS,
            dbname=AUTHENTIK_PG_DB,
            connect_timeout=10
        )
    elif HAS_PG8000:
        return pg8000.connect(
            host=AUTHENTIK_PG_HOST,
            port=AUTHENTIK_PG_PORT,
            user=AUTHENTIK_PG_USER,
            password=AUTHENTIK_PG_PASS,
            database=AUTHENTIK_PG_DB
        )
    else:
        raise RuntimeError("Aucun driver PostgreSQL disponible (psycopg2 ou pg8000 requis)")


def get_last_cursor() -> str:
    """Retourne le dernier event_uuid traité (pour polling incrémental)."""
    with db_lock:
        row = db_conn.execute(
            "SELECT value FROM sentinel_state WHERE key='last_event_time'"
        ).fetchone()
    return row[0] if row else "1970-01-01T00:00:00+00:00"


def set_last_cursor(ts: str):
    with db_lock:
        db_conn.execute(
            "INSERT OR REPLACE INTO sentinel_state(key, value) VALUES ('last_event_time', ?)",
            (ts,)
        )
        db_conn.commit()


def is_processed(event_uuid: str) -> bool:
    with db_lock:
        row = db_conn.execute(
            "SELECT 1 FROM processed_events WHERE event_uuid=?", (event_uuid,)
        ).fetchone()
    return row is not None


def mark_processed(event_uuid: str, action: str):
    with db_lock:
        db_conn.execute(
            "INSERT OR IGNORE INTO processed_events(event_uuid, action, processed_at) VALUES (?,?,?)",
            (event_uuid, action, datetime.now(timezone.utc).isoformat())
        )
        db_conn.commit()

# ---------------------------------------------------------------------------
# MOTEUR DE RÈGLES DE DÉTECTION
# ---------------------------------------------------------------------------

def _clean_old(dq: deque, window_sec: int):
    """Supprime les entrées plus vieilles que window_sec de la deque."""
    cutoff = time.time() - window_sec
    while dq:
        item = dq[0]
        t = item[0] if isinstance(item, (tuple, list)) else item
        if t < cutoff:
            dq.popleft()
        else:
            break


def _cooldown_key(rule: str, ip: str, username: str = "") -> str:
    raw = f"{rule}:{ip}:{username}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def _in_cooldown(sig: str) -> bool:
    last = alert_cooldowns.get(sig, 0)
    return (time.time() - last) < ALERT_COOLDOWN


def _set_cooldown(sig: str):
    alert_cooldowns[sig] = time.time()


def analyze_event(event: dict):
    """
    Analyse un événement Authentik et déclenche les alertes si nécessaire.

    event = {
        'event_uuid': str,
        'action': str,       # 'login', 'login_failed', ...
        'client_ip': str,
        'created': datetime,
        'username': str,
        'context': dict
    }
    """
    action = event.get("action", "")
    ip = str(event.get("client_ip") or "unknown")
    username = event.get("username", "")
    ts = time.time()
    event_ts = event.get("created")
    if event_ts and hasattr(event_ts, "timestamp"):
        ts = event_ts.timestamp()

    with state_lock:
        if action == "login_failed":
            # Enregistre l'échec
            ip_failures[ip].append((ts, username))
            account_failures[username].append(ts)
            ip_targeted_accounts[ip].add(username)

            # --- Règle 1 : Brute Force (≥5 échecs en 5 min depuis même IP) ---
            _clean_old(ip_failures[ip], BRUTE_FORCE_WINDOW)
            count = len(ip_failures[ip])
            if count >= BRUTE_FORCE_THRESHOLD:
                sig = _cooldown_key("brute_force", ip)
                if not _in_cooldown(sig):
                    _set_cooldown(sig)
                    fire_alert(
                        alert_type="Tentatives répétées (Brute Force)",
                        ip=ip,
                        username=username,
                        severity="ÉLEVÉE",
                        details=f"{count} échecs en {BRUTE_FORCE_WINDOW//60} min depuis {ip}",
                        extra={"tentatives": count}
                    )

            # --- Règle 2 : Password Spraying (1 IP → ≥3 comptes distincts) ---
            spray_accs = ip_targeted_accounts[ip]
            # Nettoie les entrées pour cette IP dans la fenêtre
            ip_entries_in_window = [e for e in ip_failures[ip] if ts - e[0] <= SPRAY_WINDOW]
            accs_in_window = set(e[1] for e in ip_entries_in_window)
            if len(accs_in_window) >= SPRAY_ACCOUNTS:
                sig = _cooldown_key("spray", ip)
                if not _in_cooldown(sig):
                    _set_cooldown(sig)
                    fire_alert(
                        alert_type="Attaque distribuée (Password Spraying)",
                        ip=ip,
                        username=", ".join(list(accs_in_window)[:5]),
                        severity="CRITIQUE",
                        details=f"IP {ip} a ciblé {len(accs_in_window)} comptes en {SPRAY_WINDOW//60} min",
                        extra={"comptes_cibles": list(accs_in_window)}
                    )

        elif action == "login":
            # --- Règle 3 : Connexion suspecte après échecs multiples ---
            _clean_old(account_failures[username], BRUTE_FORCE_WINDOW * 2)
            fail_count = len(account_failures[username])
            if fail_count >= POST_FAIL_THRESHOLD:
                sig = _cooldown_key("post_fail_success", ip, username)
                if not _in_cooldown(sig):
                    _set_cooldown(sig)
                    fire_alert(
                        alert_type="Connexion suspecte après échecs multiples",
                        ip=ip,
                        username=username,
                        severity="ALERTE",
                        details=f"Connexion réussie de {username} depuis {ip} après {fail_count} échec(s)",
                        extra={"echecs_precedents": fail_count}
                    )
            # Réinitialise les compteurs de cet utilisateur après connexion réussie
            account_failures[username].clear()


# ---------------------------------------------------------------------------
# GESTION DES ALERTES
# ---------------------------------------------------------------------------

def fire_alert(alert_type: str, ip: str, username: str, severity: str, details: str, extra: dict = None):
    """Enregistre et notifie une alerte de sécurité."""
    now = datetime.now(timezone.utc)
    sig = _cooldown_key(alert_type, ip, username)

    log.warning(f"🚨 ALERTE [{severity}] {alert_type} — IP:{ip} USER:{username} — {details}")

    message = format_matrix_alert(
        alert_type=alert_type,
        username=username,
        ip=ip,
        dt=now,
        severity=severity,
        details=details,
        extra=extra or {}
    )

    with db_lock:
        db_conn.execute(
            """INSERT INTO alerts(alert_type, signature, ip, username, severity, message, sent_at)
               VALUES (?,?,?,?,?,?,?)""",
            (alert_type, sig, ip, username, severity, message, now.isoformat())
        )
        db_conn.commit()

    # Envoi Matrix dans un thread séparé pour ne pas bloquer le polling
    threading.Thread(target=send_matrix_alert, args=(message,), daemon=True).start()


def format_matrix_alert(alert_type, username, ip, dt, severity, details, extra):
    dt_str = dt.strftime("%d/%m/%Y %H:%M:%S UTC")
    extra_lines = ""
    if extra.get("tentatives"):
        extra_lines += f"\n**Tentatives :** {extra['tentatives']}"
    if extra.get("comptes_cibles"):
        comptes = ", ".join(extra["comptes_cibles"][:5])
        extra_lines += f"\n**Comptes ciblés :** {comptes}"
    if extra.get("echecs_precedents"):
        extra_lines += f"\n**Échecs précédents :** {extra['echecs_precedents']}"

    return (
        f"🚨 **SENTINEL BF — ALERTE DE SÉCURITÉ**\n\n"
        f"**Type :** {alert_type}\n"
        f"**Compte ciblé :** {username or 'N/A'}\n"
        f"**IP source :** {ip}\n"
        f"**Date et heure :** {dt_str}\n"
        f"**Gravité :** {severity}"
        f"{extra_lines}\n\n"
        f"**Détails :** {details}\n\n"
        f"_Action recommandée : Vérification de l'activité en cours._"
    )

# ---------------------------------------------------------------------------
# MATRICE — Envoi de notifications
# ---------------------------------------------------------------------------
matrix_token_lock = threading.Lock()
_matrix_token: str = ""
_matrix_room_id: str = ""


def matrix_request(method: str, path: str, body: dict = None, token: str = None) -> dict:
    """Effectue une requête à l'API Matrix."""
    url = urljoin(SYNAPSE_URL, path)
    data = json.dumps(body).encode("utf-8") if body else None
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except HTTPError as e:
        body_err = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Matrix HTTP {e.code} sur {url}: {body_err}")


def register_sentinel_user() -> str:
    """
    Enregistre @sentinel_bf:messagerie.local via le shared secret si nécessaire.
    Retourne le token d'accès.
    """
    import hmac as _hmac
    import hashlib as _hashlib

    localpart = "sentinel_bf"
    password = os.environ.get("SENTINEL_MATRIX_PASSWORD", "SentinelBF_Matr1x_S3cur!ty_2026")

    # Tente d'abord de se connecter
    try:
        resp = matrix_request("POST", "/_matrix/client/v3/login", {
            "type": "m.login.password",
            "identifier": {"type": "m.id.user", "user": localpart},
            "password": password
        })
        log.info(f"@sentinel_bf déjà enregistré, connexion réussie.")
        return resp["access_token"]
    except Exception as e:
        log.info(f"Connexion sentinel_bf non immédiate ({e}), tentative d'enregistrement...")

    if not SYNAPSE_SHARED_SECRET:
        raise RuntimeError("SYNAPSE_REGISTRATION_SHARED_SECRET manquant — impossible d'enregistrer sentinel_bf")

    # Génère le HMAC pour l'enregistrement via shared secret
    nonce_resp = matrix_request("GET", "/_synapse/admin/v1/register")
    nonce = nonce_resp["nonce"]

    mac_str = f"{nonce}\x00{localpart}\x00{password}\x00notadmin"
    mac = _hmac.new(SYNAPSE_SHARED_SECRET.encode("utf-8"), mac_str.encode("utf-8"), _hashlib.sha1).hexdigest()

    try:
        reg_resp = matrix_request("POST", "/_synapse/admin/v1/register", {
            "nonce": nonce,
            "username": localpart,
            "password": password,
            "admin": False,
            "mac": mac
        })
        log.info(f"✅ Compte @sentinel_bf enregistré avec succès.")
        return reg_resp["access_token"]
    except Exception as reg_err:
        if "M_USER_IN_USE" in str(reg_err):
            # L'utilisateur existe, connexion
            resp = matrix_request("POST", "/_matrix/client/v3/login", {
                "type": "m.login.password",
                "identifier": {"type": "m.id.user", "user": localpart},
                "password": password
            })
            return resp["access_token"]
        raise


def get_or_create_alert_room(token: str) -> str:
    """Crée le salon d'alertes Sentinel ou le rejoint s'il existe."""
    import urllib.parse
    room_alias = "sentinel-alertes"
    full_alias = f"#{room_alias}:messagerie.local"
    alias_enc = urllib.parse.quote(full_alias)

    # 1. Tente de résoudre l'alias
    try:
        resp = matrix_request("GET", f"/_matrix/client/v3/directory/room/{alias_enc}", token=token)
        room_id = resp.get("room_id")
        if room_id:
            log.info(f"Salon existant trouvé: {room_id}")
            try:
                matrix_request("POST", f"/_matrix/client/v3/join/{room_id}", {}, token=token)
            except Exception:
                pass
            return room_id
    except Exception as e:
        log.info(f"Recherche alias: {e}")

    # 2. Crée le salon
    try:
        resp = matrix_request("POST", "/_matrix/client/v3/createRoom", {
            "room_alias_name": room_alias,
            "name": "🔒 Sentinel BF — Alertes Sécurité",
            "topic": "Salon privé de notification d'incidents de sécurité — SENTINEL BF",
            "preset": "private_chat",
            "visibility": "private",
            "initial_state": [
                {
                    "type": "m.room.history_visibility",
                    "content": {"history_visibility": "joined"}
                }
            ]
        }, token=token)
        room_id = resp["room_id"]
        log.info(f"✅ Salon créé: {room_id}")
    except Exception as e:
        if "M_ROOM_IN_USE" in str(e):
            resp = matrix_request("GET", f"/_matrix/client/v3/directory/room/{alias_enc}", token=token)
            room_id = resp["room_id"]
        else:
            raise

    # Invite l'admin
    for invitee in [SENTINEL_ADMIN_INVITE, "@alice_demo:messagerie.local"]:
        try:
            matrix_request("POST", f"/_matrix/client/v3/rooms/{room_id}/invite",
                            {"user_id": invitee}, token=token)
            log.info(f"Invitation envoyée à {invitee}")
        except Exception as inv_e:
            log.warning(f"Invitation {invitee} ignorée: {inv_e}")

    return room_id


def send_matrix_alert(message: str):
    """Envoie un message formaté dans le salon Matrix d'alertes."""
    global _matrix_token, _matrix_room_id

    with matrix_token_lock:
        token = _matrix_token
        room_id = _matrix_room_id

    if not token or not room_id:
        log.warning("Token Matrix ou room_id manquant — alerte non envoyée")
        return

    txn_id = hashlib.sha256(f"{time.time()}{message}".encode()).hexdigest()[:16]
    try:
        matrix_request(
            "PUT",
            f"/_matrix/client/v3/rooms/{room_id}/send/m.room.message/{txn_id}",
            {
                "msgtype": "m.text",
                "body": message,
                "format": "org.matrix.custom.html",
                "formatted_body": message.replace("\n", "<br>").replace("**", "")
            },
            token=token
        )
        log.info("✅ Alerte Matrix envoyée avec succès.")

        # Marque comme envoyé dans la DB
        with db_lock:
            db_conn.execute(
                "UPDATE alerts SET matrix_sent=1 WHERE sent_at=(SELECT MAX(sent_at) FROM alerts)"
            )
            db_conn.commit()
    except Exception as e:
        log.error(f"❌ Envoi Matrix échoué: {e}")


# ---------------------------------------------------------------------------
# WEBHOOK HTTP — Endpoint optionnel pour push externe
# ---------------------------------------------------------------------------

class WebhookHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        log.debug(f"HTTP {fmt % args}")

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status":"ok","service":"sentinel_bf"}')
        elif self.path == "/api/v1/stats":
            self._check_auth()
            with db_lock:
                count = db_conn.execute("SELECT COUNT(*) FROM alerts").fetchone()[0]
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps({"total_alerts": count}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/v1/event":
            if not self._check_auth():
                return
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length)
            try:
                event = json.loads(raw.decode("utf-8"))
                # Normalise l'événement entrant
                parsed = {
                    "event_uuid": event.get("event_uuid", f"webhook_{time.time()}"),
                    "action": event.get("action", ""),
                    "client_ip": event.get("client_ip", "unknown"),
                    "created": datetime.now(timezone.utc),
                    "username": event.get("username", event.get("user", {}).get("username", "")),
                    "context": event.get("context", {})
                }
                analyze_event(parsed)
                self.send_response(202)
                self.end_headers()
                self.wfile.write(b'{"status":"accepted"}')
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'{"error":"invalid_json"}')
        else:
            self.send_response(404)
            self.end_headers()

    def _check_auth(self) -> bool:
        auth_header = self.headers.get("Authorization", "")
        expected = f"Bearer {SENTINEL_WEBHOOK_SECRET}"
        if not hmac.compare_digest(auth_header, expected):
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'{"error":"unauthorized"}')
            log.warning(f"Webhook non authentifié depuis {self.client_address[0]}")
            return False
        return True


# ---------------------------------------------------------------------------
# POLLING AUTHENTIK POSTGRESQL
# ---------------------------------------------------------------------------

def poll_authentik_events():
    """Boucle principale de polling des événements Authentik."""
    log.info(f"Démarrage du polling Authentik PostgreSQL ({AUTHENTIK_PG_HOST}:{AUTHENTIK_PG_PORT})")
    consecutive_errors = 0

    while True:
        try:
            conn = pg_connect()
            log.info("✅ Connexion PostgreSQL Authentik établie.")
            consecutive_errors = 0

            while True:
                try:
                    last_ts = get_last_cursor()
                    cur = conn.cursor()

                    if HAS_PSYCOPG2:
                        cur.execute(
                            """SELECT event_uuid, action, client_ip, created,
                                      "user", context
                               FROM authentik_events_event
                               WHERE created > %s
                                 AND action IN ('login', 'login_failed')
                               ORDER BY created ASC
                               LIMIT 200""",
                            (last_ts,)
                        )
                    else:
                        cur.execute(
                            """SELECT event_uuid, action, client_ip, created,
                                      "user", context
                               FROM authentik_events_event
                               WHERE created > %s
                                 AND action IN ('login', 'login_failed')
                               ORDER BY created ASC
                               LIMIT 200""",
                            (last_ts,)
                        )

                    rows = cur.fetchall()
                    cur.close()
                    conn.commit()

                    latest_ts = last_ts
                    for row in rows:
                        event_uuid, action, client_ip, created, user_json, context_json = row

                        if is_processed(str(event_uuid)):
                            continue

                        # Décode les champs JSON
                        user_data = user_json if isinstance(user_json, dict) else json.loads(user_json or "{}")
                        context_data = context_json if isinstance(context_json, dict) else json.loads(context_json or "{}")

                        username = user_data.get("username", context_data.get("username", ""))

                        event = {
                            "event_uuid": str(event_uuid),
                            "action": action,
                            "client_ip": str(client_ip) if client_ip else "unknown",
                            "created": created,
                            "username": username,
                            "context": context_data
                        }

                        analyze_event(event)
                        mark_processed(str(event_uuid), action)

                        if created:
                            ts_str = created.isoformat() if hasattr(created, "isoformat") else str(created)
                            if ts_str > latest_ts:
                                latest_ts = ts_str

                    if rows:
                        set_last_cursor(latest_ts)
                        log.info(f"Traités {len(rows)} événements (dernier: {latest_ts})")

                    time.sleep(POLL_INTERVAL_SEC)

                except Exception as inner_e:
                    log.error(f"Erreur polling: {inner_e}")
                    try:
                        conn.rollback()
                    except Exception:
                        pass
                    break  # Reconnexion

            try:
                conn.close()
            except Exception:
                pass

        except Exception as e:
            consecutive_errors += 1
            wait = min(60, 5 * consecutive_errors)
            log.error(f"Connexion PostgreSQL impossible ({e}) — réessai dans {wait}s")
            time.sleep(wait)


# ---------------------------------------------------------------------------
# POINT D'ENTRÉE
# ---------------------------------------------------------------------------

def setup_matrix():
    """Initialise le compte Matrix et le salon d'alertes."""
    global _matrix_token, _matrix_room_id

    max_retries = 10
    for attempt in range(max_retries):
        try:
            log.info(f"Initialisation Matrix (tentative {attempt+1}/{max_retries})...")
            token = register_sentinel_user()
            room_id = get_or_create_alert_room(token)

            with matrix_token_lock:
                _matrix_token = token
                _matrix_room_id = room_id

            # Sauvegarder dans la DB pour référence
            with db_lock:
                db_conn.execute("INSERT OR REPLACE INTO sentinel_state(key,value) VALUES ('room_id',?)", (room_id,))
                db_conn.commit()

            log.info(f"✅ Sentinel BF connecté — Salon d'alertes: {room_id}")

            # Message de démarrage
            startup_msg = (
                "🟢 **SENTINEL BF — SERVICE DÉMARRÉ**\n\n"
                f"Le service de surveillance est opérationnel.\n"
                f"**Règles actives :**\n"
                f"• Brute Force : {BRUTE_FORCE_THRESHOLD} échecs en {BRUTE_FORCE_WINDOW//60} min\n"
                f"• Password Spray : {SPRAY_ACCOUNTS} comptes en {SPRAY_WINDOW//60} min\n"
                f"• Compromission : {POST_FAIL_THRESHOLD} échecs puis succès\n\n"
                f"_Toutes les alertes seront publiées dans ce salon._"
            )
            send_matrix_alert(startup_msg)
            return

        except Exception as e:
            wait = min(30, 5 * (attempt + 1))
            log.warning(f"Setup Matrix échoué ({e}) — réessai dans {wait}s")
            time.sleep(wait)

    log.error("❌ Impossible d'initialiser Matrix après plusieurs tentatives. Le polling continue sans notifications Matrix.")


def main():
    global db_conn

    log.info("=" * 60)
    log.info("  SENTINEL BF — Démarrage")
    log.info("  Messagerie Souveraine BF — Hackathon 226")
    log.info("=" * 60)

    # Initialisation base locale
    os.makedirs(DATA_DIR, exist_ok=True)
    db_conn = init_db(DB_PATH)
    log.info(f"Base SQLite initialisée: {DB_PATH}")

    # Démarrage serveur webhook dans un thread
    server = HTTPServer(("0.0.0.0", WEBHOOK_PORT), WebhookHandler)
    webhook_thread = threading.Thread(target=server.serve_forever, daemon=True)
    webhook_thread.start()
    log.info(f"Serveur webhook démarré sur port {WEBHOOK_PORT}")

    # Initialisation Matrix dans un thread (non bloquant)
    matrix_thread = threading.Thread(target=setup_matrix, daemon=True)
    matrix_thread.start()

    # Boucle de polling principale (bloquante)
    poll_authentik_events()


if __name__ == "__main__":
    main()
