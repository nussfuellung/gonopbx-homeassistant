FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. System-Pakete
RUN apt-get update && apt-get install -y \
    supervisor postgresql postgresql-contrib \
    asterisk asterisk-modules sqlite3 \
    python3 python3-pip python3-venv \
    curl git nginx sed \
    && rm -rf /var/lib/apt/lists/*

# 2. Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# 3. GonoPBX Code
WORKDIR /app
RUN git clone https://github.com/ankaios76/gonopbx.git .

# 4. Python Backend Setup
RUN python3 -m venv /app/venv
RUN /app/venv/bin/pip install --upgrade pip
RUN /app/venv/bin/pip install -r /app/backend/requirements.txt
# WICHTIG: Wir installieren uvicorn explizit im venv
RUN /app/venv/bin/pip install uvicorn

# 5. Frontend bauen & PFAD-CHIRURGIE
WORKDIR /app/frontend
RUN npm install
RUN npx vite build --base="./"
WORKDIR /app/frontend/dist
# Wir löschen JEDEN absoluten Pfad zu /api oder /logo in den Dateien
RUN find . -type f \( -name "*.js" -o -name "*.html" \) -exec sed -i 's|"/api| "api|g' {} +
RUN find . -type f \( -name "*.js" -o -name "*.html" \) -exec sed -i "s|'/api| 'api|g" {} +
RUN find . -type f \( -name "*.js" -o -name "*.html" \) -exec sed -i 's|"/logo| "logo|g' {} +
RUN cp -r * /var/www/html/

# 6. Asterisk Configs
RUN rm -f /app/asterisk/config/modules.conf && \
    rm -f /app/asterisk/config/asterisk.conf && \
    cp -r /app/asterisk/config/* /etc/asterisk/ 2>/dev/null || true

# 7. Add-on Dateien
WORKDIR /
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
