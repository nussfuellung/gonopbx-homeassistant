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

# Stoppe den temporären Postgres-Server wieder (Supervisor übernimmt gleich)
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"
sleep 2

# 3. Asterisk-Verzeichnisse erstellen und Rechte setzen (inklusive /var/lib/asterisk!)
echo "Erstelle Asterisk-Verzeichnisse..."
mkdir -p /var/run/asterisk
mkdir -p /var/spool/asterisk/voicemail
mkdir -p /var/log/asterisk
mkdir -p /var/lib/asterisk

chown -R asterisk:asterisk /var/run/asterisk /var/spool/asterisk /var/log/asterisk /var/lib/asterisk /etc/asterisk || true

echo "Initialisierung abgeschlossen. Übergebe an Supervisor..."

# 4. Supervisor starten
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
