#!/bin/bash
set -e

echo "============================================"
echo "   GonoPBX Master Startup Script"
echo "============================================"

# 1. PostgreSQL Verzeichnis-Rechte & Init
mkdir -p /var/run/postgresql
chown -R postgres:postgres /var/run/postgresql

# Wir starten Postgres hier und lassen es für den Moment LAUFEN
echo "Starte Postgres..."
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main start"
sleep 5

# 2. Datenbank-Setup (nur falls nötig)
echo "Checke Datenbank..."
su - postgres -c "psql -c \"CREATE USER asterisk WITH PASSWORD 'gonopbx_db_pass';\"" || true
su - postgres -c "psql -c \"CREATE DATABASE asterisk_gui OWNER asterisk;\"" || true

# 3. Das Backend manuell "antiggen" (Migrations)
echo "Starte Backend-Initialisierung..."
cd /app/backend
# Wir führen das Backend kurz aus, damit es die Tabellen erstellt
# (Falls GonoPBX ein Migrations-Skript hat, hier einfügen. Sonst starten wir uvicorn kurz)
timeout 15s /app/venv/bin/python3 -m uvicorn main:app --host 127.0.0.1 --port 8000 &
sleep 10

# 4. Jetzt den Admin-User reindrücken (Tabellen sind jetzt sicher da)
echo "Erstelle Admin-User..."
su - postgres -c "psql -d asterisk_gui -c \"INSERT INTO users (username, password, role, is_active) VALUES ('admin', '\$2b\$12\$8K1p/9Ec7IkfPZ.p1fS8beJ.0BshlPZ0Y/F97B6G4z6x1I8U6u6Zy', 'admin', true) ON CONFLICT (username) DO NOTHING;\""

# 5. Sauberer Übergang zum Supervisor
echo "Stoppe temporäre Dienste für Supervisor-Übernahme..."
pkill -f uvicorn || true
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"
sleep 2

# 6. Nginx Port-Anpassung (Wichtig für HA)
WEB_PORT=8080
if [ -f /data/options.json ]; then
    CONFIG_PORT=$(grep -o '"web_port": *[0-9]*' /data/options.json | grep -o '[0-9]*' || true)
    if [ ! -z "$CONFIG_PORT" ]; then WEB_PORT=$CONFIG_PORT; fi
fi
sed -i "s/8080/$WEB_PORT/g" /etc/nginx/nginx.conf

echo "Übergabe an Supervisor. Ab hier übernehmen die Logs!"
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
