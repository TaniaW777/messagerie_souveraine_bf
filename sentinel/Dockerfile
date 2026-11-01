# SENTINEL BF — Image Docker
# Service de détection des connexions suspectes
# Messagerie Souveraine BF — Hackathon 226

FROM python:3.11-alpine

LABEL maintainer="Messagerie Souveraine BF"
LABEL description="SENTINEL BF — Cybersécurité et détection des menaces"
LABEL version="1.0"

# Dépendances système minimales
RUN apk add --no-cache \
    libpq \
    && apk add --no-cache --virtual .build-deps \
    gcc musl-dev postgresql-dev \
    && pip install --no-cache-dir psycopg2-binary==2.9.9 \
    && apk del .build-deps

# Répertoire de travail
WORKDIR /app

# Copie du code
COPY sentinel.py .

# Répertoire de données persistant
VOLUME ["/data"]

# Port webhook (interne uniquement, non exposé)
EXPOSE 8088

# Utilisateur non-root
RUN addgroup -S sentinel && adduser -S sentinel -G sentinel \
    && mkdir -p /data && chown sentinel:sentinel /data

USER sentinel

# Démarrage
CMD ["python3", "-u", "sentinel.py"]
