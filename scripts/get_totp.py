#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GÉNÉRATEUR TOTP INSTANTANÉ (RFC 6238) — MESSAGERIE SOUVERAINE BF
Fonctionne en Python standard (aucune dépendance pip requise).

Usage :
  python3 scripts/get_totp.py [alice|bob|charlie]
"""

import sys
import time
import base64
import hmac
import hashlib
import struct

SECRETS = {
    "alice_demo": {
        "name": "Alice Demo (Responsable Crise)",
        "secret": "7ABNKPM53FWAI2I4ANCM3KO5FAKZVCTC",
        "email": "alice_demo@messagerie.local"
    },
    "bob_demo": {
        "name": "Bob Demo (Agent Terrain)",
        "secret": "32JUCZHCXYAHSWFNQHWIPWQ2GSSZWZMZ",
        "email": "bob_demo@messagerie.local"
    },
    "charlie_demo": {
        "name": "Charlie Demo (Collaborateur)",
        "secret": "GH7UKRBYEW7U7J54UCWWGAXRGFDZSGYF",
        "email": "charlie_demo@messagerie.local"
    }
}

def generate_totp(b32_secret: str, interval: int = 30) -> tuple:
    key = base64.b32decode(b32_secret, casefold=True)
    t = int(time.time())
    counter = t // interval
    rem = interval - (t % interval)
    msg = struct.pack(">Q", counter)
    h = hmac.new(key, msg, hashlib.sha1).digest()
    offset = h[19] & 0x0f
    bin_code = (struct.unpack(">I", h[offset:offset+4])[0] & 0x7fffffff) % 1000000
    return f"{bin_code:06d}", rem

def main():
    target = sys.argv[1].lower() if len(sys.argv) > 1 else "all"
    
    print("\n" + "=" * 65)
    print("  🔑 CODES TOTP DYNAMIQUES — MESSAGERIE SOUVERAINE BF")
    print("=" * 65)

    found = False
    for user_key, data in SECRETS.items():
        if target != "all" and target not in user_key:
            continue
        found = True
        code, rem = generate_totp(data["secret"])
        print(f"\n  👤 Utilisateur : \033[1m{data['name']}\033[0m")
        print(f"     Identifiant : {user_key}")
        print(f"     Code TOTP   : \033[92m\033[1m{code[:3]} {code[3:]}\033[0m  (Valide encore {rem}s)")
        print(f"     Secret b32  : {data['secret']}")

    if not found:
        print(f"\n  ❌ Utilisateur inconnu: '{target}'. Choix: alice, bob, charlie, all")

    print("\n" + "=" * 65 + "\n")

if __name__ == "__main__":
    main()
