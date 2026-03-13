#!/bin/bash
set -e

echo "============================================"
echo "   GonoPBX All-in-One Startup Script"
echo "============================================"

# 1. PostgreSQL Verzeichnis-Rechte fixen
mkdir -p /var/run/postgresql
chown -R postgres:postgres /var/run/postgresql

# 2. Datenbank initialisieren (nur wenn sie noch nicht existiert)
echo "Starte lokalen Postgres-Server für das initiale Setup..."
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main start"
sleep 3

# Erstelle den Asterisk-User und die Datenbank (Passwörter passend zur supervisord.conf)
echo "Richte Datenbank-Nutzer ein..."
su - postgres -c "psql -c \"CREATE USER asterisk WITH PASSWORD 'gonopbx_db_pass';\"" || true
su - postgres -c "psql -c \"CREATE DATABASE asterisk_gui OWNER asterisk;\"" || true

# Stoppe den temporären Postgres-Server wieder (Supervisor übernimmt gleich)
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"
sleep 2

# 3. Port aus Home Assistant Optionen auslesen
echo "Lese Add-on Konfiguration..."
WEB_PORT=8080
if [ -f /data/options.json ]; then
    # Holt sich den Port aus der HA-Config (falls vorhanden)
    CONFIG_PORT=$(grep -o '"web_port": *[0-9]*' /data/options.json | grep -o '[0-9]*' || true)
    if [ ! -z "$CONFIG_PORT" ]; then
        WEB_PORT=$CONFIG_PORT
    fi
fi

echo "Konfiguriere Web-Port auf: $WEB_PORT"
# Tauscht die 8080 in der Nginx-Config gegen den gewünschten Port aus
sed -i "s/8080/$WEB_PORT/g" /etc/nginx/sites-available/default

# 4. Asterisk-Verzeichnisse zur Sicherheit anlegen (Wir laufen als root)
echo "Erstelle Asterisk-Verzeichnisse..."
mkdir -p /var/run/asterisk \
         /var/spool/asterisk/voicemail \
         /var/log/asterisk \
         /var/lib/asterisk \
         /usr/lib/asterisk/modules

echo "Initialisierung abgeschlossen. Übergebe an Supervisor..."

# 5. Supervisor starten
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
