ARG BUILD_FROM=ubuntu:22.04
FROM $BUILD_FROM

# Verhindert interaktive Prompts während der Installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. System-Abhängigkeiten, Supervisor, Datenbank, Asterisk und Webserver installieren
RUN apt-get update && apt-get install -y \
    supervisor \
    postgresql postgresql-contrib \
    asterisk \
    python3 python3-pip python3-venv \
    curl git nginx \
    && rm -rf /var/lib/apt/lists/*

# 2. Node.js installieren (für das Frontend)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# 3. GonoPBX Original-Code herunterladen
WORKDIR /app
RUN git clone https://github.com/ankaios76/gonopbx.git .

# 4. Python Backend einrichten
# Wir nutzen ein virtual environment (venv), das ist bei neueren Ubuntu-Versionen Pflicht
RUN python3 -m venv /app/venv
RUN /app/venv/bin/pip install -r /app/backend/requirements.txt

# 5. Frontend bauen und in den Nginx-Webordner kopieren
WORKDIR /app/frontend
RUN npm install
RUN VITE_UI_LANG=de npm run build
RUN cp -r dist/* /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# 6. Asterisk Konfigurationen kopieren (wie im Original)
RUN cp -r /app/asterisk/config/* /etc/asterisk/ 2>/dev/null || true

# 7. Eigene Konfigurationen in den Container kopieren
WORKDIR /
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Home Assistant Add-on Startbefehl
CMD ["/run.sh"]
