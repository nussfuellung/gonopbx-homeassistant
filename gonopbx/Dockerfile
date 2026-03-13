FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. System-Abhängigkeiten installieren
RUN apt-get update && apt-get install -y \
    supervisor \
    postgresql postgresql-contrib \
    asterisk asterisk-modules sqlite3 \
    python3 python3-pip python3-venv \
    curl git nginx sed \
    && rm -rf /var/lib/apt/lists/*

# 2. Node.js installieren
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# 3. GonoPBX Code klonen
WORKDIR /app
RUN git clone https://github.com/ankaios76/gonopbx.git .

# 4. Python Backend einrichten
RUN python3 -m venv /app/venv
RUN /app/venv/bin/pip install -r /app/backend/requirements.txt

# 5. Frontend bauen MIT RELATIVEN PFADEN
# Das sorgt dafür, dass die App ihre API unter ./api statt /api sucht
WORKDIR /app/frontend
RUN npm install
RUN npx vite build --base="./"
RUN cp -r dist/* /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# 6. Asterisk Konfigurationen vorsichtig kopieren
RUN rm -f /app/asterisk/config/modules.conf \
    && rm -f /app/asterisk/config/asterisk.conf \
    && cp -r /app/asterisk/config/* /etc/asterisk/ 2>/dev/null || true

# 7. Add-on Dateien kopieren
WORKDIR /
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
