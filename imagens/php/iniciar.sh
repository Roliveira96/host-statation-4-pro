#!/bin/sh
set -e
mkdir -p "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR" "$APACHE_LOG_DIR" /tmp/php-sessoes
mkdir -p "$HOME_ESTAGIARIO/public_html"
exec apache2 -DFOREGROUND
