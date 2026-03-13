#!/bin/bash
set -e

echo "============================================"
echo "   GonoPBX All-in-One Startup Script"
echo "============================================"

# 1. PostgreSQL Verzeichnis-Rechte fixen
mkdir -p /var/run/postgresql
chown -R postgres:postgres /var/run/postgresql

# 2. Datenbank initialisieren
echo "Starte lokalen Postgres-Server für das initiale Setup..."
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main start"
sleep 3

echo "Richte Datenbank und Admin-User ein..."
# Nutzer und DB erstellen (falls nicht vorhanden)
su - postgres -c "psql -c \"CREATE USER asterisk WITH PASSWORD 'gonopbx_db_pass';\"" || true
su - postgres -c "psql -c \"CREATE DATABASE asterisk_gui OWNER asterisk;\"" || true

# ADMIN-USER FIX: Erstellt den User 'admin' mit Passwort 'admin' (BCrypt Hash)
# Wir nutzen ON CONFLICT DO NOTHING, damit der User nicht jedes Mal überschrieben wird
# Falls deine Tabelle 'users' heißt, wird dieser Befehl den Admin anlegen:
su - postgres -c "psql -d asterisk_gui -c \"
INSERT INTO users (username, password, role, is_active) 
VALUES ('admin', '\$2b\$12\$8K1p/9Ec7IkfPZ.p1fS8beJ.0BshlPZ0Y/F97B6G4z6x1I8U6u6Zy', 'admin', true) 
ON CONFLICT (username) DO NOTHING;\"" || echo "Hinweis: Admin konnte nicht autom. angelegt werden (evtl. Tabellenstruktur noch leer)."

# Postgres wieder stoppen für Supervisor
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"
sleep 2

# 3. Port aus HA-Optionen auslesen
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
sed -i "s/8080/$WEB_PORT/g" /etc/nginx/nginx.conf

# 4. Asterisk Verzeichnisse
echo "Erstelle Asterisk-Verzeichnisse..."
mkdir -p /var/run/asterisk /var/spool/asterisk/voicemail /var/log/asterisk /var/lib/asterisk /usr/lib/asterisk/modules
chown -R root:root /var/www/html

echo "Initialisierung abgeschlossen. Übergebe an Supervisor..."

# 5. Supervisor starten
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
