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
RUN /app/venv/bin/pip install uvicorn

# 5. Frontend bauen & DER INGRESS-INTERCEPTOR
WORKDIR /app/frontend
RUN npm install
RUN npx vite build --base="./"
WORKDIR /app/frontend/dist

# Logo-Pfad reparieren (das hat ja schon geklappt!)
RUN sed -i 's|"/logo| "./logo|g' index.html
RUN sed -i "s|'/logo| './logo|g" index.html
RUN sed -i 's|src="/|src="./|g' index.html
RUN sed -i 's|href="/|href="./|g' index.html

# Hier ist die Magie: Wir injizieren ein Skript in den <head> der index.html,
# das alle Anfragen an /api abfängt und den aktuellen Pfad (den Ingress-Pfad) davor setzt.
RUN sed -i '/<head>/a \
    <script>\
      const originalFetch = window.fetch;\
      window.fetch = async (...args) => {\
        let [resource, config] = args;\
        if (typeof resource === "string" && resource.startsWith("/api/")) {\
          const basePath = window.location.pathname.replace(/\\/$/, "");\
          resource = basePath + resource;\
        }\
        return originalFetch(resource, config);\
      };\
      const originalXHROpen = XMLHttpRequest.prototype.open;\
      XMLHttpRequest.prototype.open = function(method, url, ...rest) {\
        if (typeof url === "string" && url.startsWith("/api/")) {\
          const basePath = window.location.pathname.replace(/\\/$/, "");\
          url = basePath + url;\
        }\
        return originalXHROpen.call(this, method, url, ...rest);\
      };\
    </script>' index.html

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
