FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. System-Abhängigkeiten installieren (inkl. Asterisk Modulen & SQLite für Stasis)
RUN apt-get update && apt-get install -y \
    supervisor \
    postgresql postgresql-contrib \
    asterisk asterisk-modules sqlite3 \
    python3 python3-pip python3-venv \
    curl git nginx sed \
    && rm -rf /var/lib/apt/lists/*

# 2. Node.js installieren (für den Frontend-Build)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# 3. GonoPBX Code klonen
WORKDIR /app
RUN git clone https://github.com/ankaios76/gonopbx.git .

# 4. Python Backend einrichten (Virtual Environment)
RUN python3 -m venv /app/venv
RUN /app/venv/bin/pip install -r /app/backend/requirements.txt

# 5. Frontend bauen MIT RELATIVEN PFADEN (Wichtig für Home Assistant Ingress)
WORKDIR /app/frontend
RUN npm install
RUN npx vite build --base=./
RUN cp -r dist/* /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# 6. Asterisk Konfigurationen vorsichtig kopieren
# Wir behalten die Ubuntu-Standard-Modules.conf, damit Stasis nicht crasht
RUN rm -f /app/asterisk/config/modules.conf \
    && rm -f /app/asterisk/config/asterisk.conf \
    && cp -r /app/asterisk/config/* /etc/asterisk/ 2>/dev/null || true

# 7. Add-on Dateien in den Container kopieren
WORKDIR /
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Startbefehl
CMD ["/run.sh"]
