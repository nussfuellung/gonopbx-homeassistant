#!/bin/bash
WEB_PORT=${WEB_PORT:-8080}
echo "Starting GonoPBX on port $WEB_PORT"
export GONOPBX_HTTP_PORT=$WEB_PORT
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
