#!/bin/bash
set -e

echo "============================================"
echo "   GonoPBX Master Startup Script"
echo "============================================"

# --- FIX 1: Der Fake-Docker Befehl ---
# Fängt "docker exec pbx_asterisk asterisk..." ab und führt "asterisk..." direkt aus!
cat << 'EOF' > /usr/bin/docker
#!/bin/bash
args=()
found=0
for arg in "$@"; do
    if [ "$arg" = "asterisk" ]; then found=1; fi
    if [ "$found" = "1" ]; then args+=("$arg"); fi
done
if [ "$found" = "1" ]; then
    exec "${args[@]}"
fi
EOF
chmod +x /usr/bin/docker

# --- FIX 2: Asterisk Manager (AMI) Konfiguration ---
# Erzwingt die korrekten Zugangsdaten, damit das Backend "Online" geht.
cat << 'EOF' > /etc/asterisk/manager.conf
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1

[admin]
secret = gonopbx_ami_pass
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.255
read = all
write = all
EOF

# 1. PostgreSQL Verzeichnis-Rechte & Init
mkdir -p /var/run/postgresql
chown -R postgres:postgres /var/run/postgresql

echo "Starte Postgres..."
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main start"
sleep 5

# 2. Datenbank-Setup
echo "Checke Datenbank..."
su - postgres -c "psql -c \"CREATE USER asterisk WITH PASSWORD 'gonopbx_db_pass';\"" || true
su - postgres -c "psql -c \"CREATE DATABASE asterisk_gui OWNER asterisk;\"" || true

# 3. Das Backend manuell "antiggen" (Migrations)
echo "Starte Backend-Initialisierung..."
cd /app/backend

export DATABASE_URL="postgresql://asterisk:gonopbx_db_pass@127.0.0.1:5432/asterisk_gui"
export ASTERISK_HOST="127.0.0.1"
export ASTERISK_PORT="5038"
export ASTERISK_USER="admin"
export ASTERISK_PASSWORD="gonopbx_ami_pass"
export ADMIN_PASSWORD="admin"

timeout 15s /app/venv/bin/python3 -m uvicorn main:app --host 127.0.0.1 --port 8000 &
sleep 10

# 4. Jetzt den Admin-User reindrücken
echo "Erstelle Admin-User..."
su - postgres -c "psql -d asterisk_gui -c \"INSERT INTO users (username, password, role, is_active) VALUES ('admin', '\$2b\$12\$8K1p/9Ec7IkfPZ.p1fS8beJ.0BshlPZ0Y/F97B6G4z6x1I8U6u6Zy', 'admin', true) ON CONFLICT (username) DO NOTHING;\"" || true

# 5. Sauberer Übergang zum Supervisor
echo "Stoppe temporäre Dienste für Supervisor-Übernahme..."
pkill -f uvicorn || true
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /etc/postgresql/14/main stop"
sleep 2

# 6. Nginx Port-Anpassung & Asterisk Verzeichnisse
WEB_PORT=8080
if [ -f /data/options.json ]; then
    CONFIG_PORT=$(grep -o '"web_port": *[0-9]*' /data/options.json | grep -o '[0-9]*' || true)
    if [ ! -z "$CONFIG_PORT" ]; then WEB_PORT=$CONFIG_PORT; fi
fi
sed -i "s/8080/$WEB_PORT/g" /etc/nginx/nginx.conf

# Wichtig für Asterisk-Fehlervermeidung
mkdir -p /var/run/asterisk /var/log/asterisk /var/lib/asterisk /var/spool/asterisk/voicemail

echo "Übergabe an Supervisor. Ab hier übernehmen die Logs!"
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
