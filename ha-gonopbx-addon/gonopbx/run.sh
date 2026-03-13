#!/usr/bin/with-contenv bashio

WEB_PORT=$(bashio::config 'web_port')

bashio::log.info "Starting GonoPBX..."
bashio::log.info "Webinterface Port: $WEB_PORT"

export GONOPBX_HTTP_PORT=$WEB_PORT

exec /usr/bin/supervisord
