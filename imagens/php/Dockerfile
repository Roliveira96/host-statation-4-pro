# Apache + PHP 8.3 rodando como o próprio estagiário (sem root).
# Pacotes do Ubuntu: nada para compilar, o que poupa a CPU Jaguar do PS4.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      apache2 libapache2-mod-php8.3 \
      php8.3-mysql php8.3-sqlite3 php8.3-gd php8.3-curl php8.3-mbstring \
      php8.3-xml php8.3-zip php8.3-intl php8.3-bcmath \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && a2enmod rewrite headers remoteip \
 && a2dissite 000-default \
 && sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf

COPY apache-estagio.conf /etc/apache2/conf-enabled/estagio.conf
COPY php-estagio.ini /etc/php/8.3/apache2/conf.d/99-estagio.ini
COPY iniciar.sh /usr/local/bin/iniciar.sh

# Sem root, o Apache não usa /var/run: tudo vai para /tmp (tmpfs no compose)
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_RUN_DIR=/tmp/apache2/run \
    APACHE_PID_FILE=/tmp/apache2/run/apache2.pid \
    APACHE_LOCK_DIR=/tmp/apache2/lock \
    APACHE_LOG_DIR=/tmp/apache2/log

EXPOSE 8080
CMD ["/usr/local/bin/iniciar.sh"]
