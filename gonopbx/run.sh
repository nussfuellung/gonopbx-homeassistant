#!/bin/bash
set -e

echo "Starting GonoPBX All-in-One..."

# 1. Postgres Setup
mkdir -p /var/run/postgresql
chown -R postgres:postgres /var/run/postgresql
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main start"
sleep 3

# 2. Datenbank erstellen
su - postgres -c "psql -c \"CREATE USER asterisk WITH PASSWORD 'gonopbx_db_pass';\"" || true
su - postgres -c "psql -c \"CREATE DATABASE asterisk_gui OWNER asterisk;\"" || true
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"

# 3. Hintergrund-Task: Admin anlegen, sobald die Tabellen da sind
(
    sleep 15 # Warte, bis Supervisor das Backend gestartet hat
    for i in {1..10}; do
        if su - postgres -c "psql -d asterisk_gui -c \"INSERT INTO users (username, password, role, is_active) VALUES ('admin', '\$2b\$12\$8K1p/9Ec7IkfPZ.p1fS8beJ.0BshlPZ0Y/F97B6G4z6x1I8U6u6Zy', 'admin', true) ON CONFLICT (username) DO NOTHING;\"" 2>/dev/null; then
            echo "Admin-User erfolgreich angelegt!"
            break
        fi
        echo "Warte auf Datenbank-Tabellen... ($i/10)"
        sleep 5
    done
) &

# 4. Port & Start
WEB_PORT=8080
if [ -f /data/options.json ]; then
    CONFIG_PORT=$(grep -o '"web_port": *[0-9]*' /data/options.json | grep -o '[0-9]*' || true)
    if [ ! -z "$CONFIG_PORT" ]; then WEB_PORT=$CONFIG_PORT; fi
fi
sed -i "s/8080/$WEB_PORT/g" /etc/nginx/nginx.conf

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
