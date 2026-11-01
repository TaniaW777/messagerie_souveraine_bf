#!/usr/bin/env python3
"""
Script de provisionnement reproductible Authentik — Messagerie Souveraine BF
Exécutable à l'intérieur du conteneur authentik-server ou via 'docker exec'.
Configure le provider OIDC Synapse, l'application et les comptes démo avec MFA TOTP.
"""

import os
import sys
import json
import base64

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "authentik.root.settings")

try:
    import django
    django.setup()
except Exception as e:
    print(f"[ERREUR] Échec de l'initialisation Django Authentik : {e}")
    sys.exit(1)

from django.contrib.auth import get_user_model
from authentik.core.models import Group, Application
from authentik.providers.oauth2.models import OAuth2Provider, ScopeMapping
from authentik.stages.authenticator_totp.models import TOTPDevice

User = get_user_model()

def provision(client_id, client_secret, users_data):
    print("=== Provisionnement Authentik pour Messagerie Souveraine BF ===")

    # 1. Groupe des agents souverains
    group, _ = Group.objects.get_or_create(
        name="Agents Messagerie Souveraine",
        defaults={"is_superuser": False}
    )
    print(f"[OK] Groupe '{group.name}' vérifié.")

    # 2. Scope Mappings par défaut
    scopes = []
    for managed_name in [
        "goauthentik.io/providers/oauth2/scope-openid",
        "goauthentik.io/providers/oauth2/scope-email",
        "goauthentik.io/providers/oauth2/scope-profile"
    ]:
        m = ScopeMapping.objects.filter(managed=managed_name).first()
        if m:
            scopes.append(m)

    # 3. Fournisseur OAuth2/OIDC pour Synapse
    redirect_uris = [
        {
            "url": "https://messagerie.local/_synapse/client/oidc/callback",
            "matching_mode": "strict",
            "redirect_uri_type": "authorization"
        }
    ]

    provider, p_created = OAuth2Provider.objects.update_or_create(
        name="Synapse",
        defaults={
            "client_type": "confidential",
            "client_id": client_id,
            "client_secret": client_secret,
            "include_claims_in_id_token": True,
            "sub_mode": "user_username",
            "issuer_mode": "per_provider",
            "_redirect_uris": redirect_uris,
            "access_token_validity": "hours=24",
            "refresh_token_validity": "days=30",
        }
    )
    if scopes:
        provider.property_mappings.set(scopes)
    print(f"[OK] Provider OIDC 'Synapse' configuré (Client ID: {client_id[:8]}...).")

    # 4. Application Synapse
    app, a_created = Application.objects.update_or_create(
        slug="synapse",
        defaults={
            "name": "Synapse",
            "provider": provider,
            "group": group,
            "meta_description": "Serveur de Messagerie Souveraine Matrix Synapse"
        }
    )
    print(f"[OK] Application '{app.name}' reliée au provider.")

    # 5. Provisionnement des comptes utilisateurs
    for u in users_data:
        username = u["username"]
        email = u.get("email", f"{username}@messagerie.local")
        name = u.get("name", username)
        password = u.get("password")
        totp_secret = u.get("totp_secret")

        user, u_created = User.objects.get_or_create(
            username=username,
            defaults={"name": name, "email": email, "is_active": True}
        )
        if password:
            user.set_password(password)
            user.is_active = True
            user.save()
        user.groups.add(group)

        # Configuration du dispositif TOTP
        if totp_secret:
            # Encodage hexadécimal si nécessaire ou stockage direct
            device, d_created = TOTPDevice.objects.update_or_create(
                user=user,
                name="TOTP App",
                defaults={
                    "confirmed": True,
                    "key": totp_secret,
                    "step": 30,
                    "digits": 6,
                    "tolerance": 1,
                }
            )
            print(f"[OK] Utilisateur '{username}' provisionné avec MFA TOTP actif.")
        else:
            print(f"[OK] Utilisateur '{username}' provisionné.")

    print("=== Provisionnement Authentik terminé avec succès ===")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--config-json":
        data = json.loads(sys.argv[2])
        provision(data["client_id"], data["client_secret"], data.get("users", []))
    else:
        # Lecture depuis les variables d'environnement
        cid = os.environ.get("AUTHENTIK_OIDC_CLIENT_ID", "4fefcfb8d9ef06172863facab0c41fed")
        csec = os.environ.get("AUTHENTIK_OIDC_CLIENT_SECRET", "")
        provision(cid, csec, [])
