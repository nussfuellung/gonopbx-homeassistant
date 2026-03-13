#!/bin/bash
set -e

echo "Starting GonoPBX All-in-One Initialization..."

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

# Stoppe den temporären Postgres-Server wieder
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"
sleep 2

# 3. Asterisk-Verzeichnisse zur Sicherheit anlegen (Rechte bleiben bei root)
echo "Erstelle Asterisk-Verzeichnisse..."
mkdir -p /var/run/asterisk \
         /var/spool/asterisk/voicemail \
         /var/log/asterisk \
         /var/lib/asterisk \
         /usr/lib/asterisk/modules

echo "Initialisierung abgeschlossen. Übergebe an Supervisor..."

# 4. Supervisor starten
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
