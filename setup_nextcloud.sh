#!/bin/bash
# Instala Nextcloud, Apache, PHP8.3, PostgreSQL, Redis e configura timezone

: "${NEXTCLOUD_DATADIR:?NEXTCLOUD_DATADIR não definida}"

# -----------------------------
# Escolha do fuso horário
# -----------------------------
TIMEZONE=$(whiptail --title "Fuso horário" --menu "Escolha o fuso horário do servidor Nextcloud:" 20 60 10 \
$(timedatectl list-timezones | awk '{print NR " " $0}' | head -n 10) 3>&1 1>&2 2>&3)

if [ -z "$TIMEZONE" ]; then
    TIMEZONE="UTC"
fi
export NEXTCLOUD_TIMEZONE="$TIMEZONE"

# Definir locale e idioma padrão (ajustável conforme fuso)
DEFAULT_LOCALE="en"
DEFAULT_PHONE_REGION="US"
FORCE_LANGUAGE="en"
export DEFAULT_LOCALE
export DEFAULT_PHONE_REGION
export FORCE_LANGUAGE

# -----------------------------
# Instalação de pacotes essenciais
# -----------------------------
apt-get update -y
apt-get install -y apache2 libapache2-mod-fcgid php8.3 php8.3-fpm php8.3-cli php8.3-common php8.3-pgsql \
php8.3-curl php8.3-gd php8.3-mbstring php8.3-intl php8.3-xml php8.3-zip \
php8.3-bcmath php8.3-apcu php8.3-redis php8.3-memcached php8.3-imagick \
php8.3-gmp php8.3-ldap php8.3-imap redis-server smbclient ffmpeg libreoffice-core \
postgresql postgresql-contrib unzip curl whiptail

# -----------------------------
# Configuração PostgreSQL
# -----------------------------
DB_USER="nc_$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)"
DB_PASS=$(tr -dc 'A-Za-z0-9!@#$%&*()_+' </dev/urandom | head -c30)
DB_NAME="nextcloud"

sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER ENCODING 'UTF8';"

export DB_USER
export DB_PASS
export DB_NAME

# -----------------------------
# Configuração Redis
# -----------------------------
systemctl enable redis-server
systemctl restart redis-server

# -----------------------------
# Configuração Apache + HTTP2
# -----------------------------
a2enmod rewrite headers env dir mime setenvif ssl http2 proxy_fcgi
a2enconf php8.3-fpm
systemctl restart apache2

# -----------------------------
# Download da última versão do Nextcloud
# -----------------------------
NEXTCLOUD_VERSION=$(curl -s https://nextcloud.com/changelog/ | grep -oP 'Version \K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
NEXTCLOUD_ZIP="nextcloud-$NEXTCLOUD_VERSION.zip"
NEXTCLOUD_URL="https://download.nextcloud.com/server/releases/$NEXTCLOUD_ZIP"

cd /tmp || exit
curl -LO "$NEXTCLOUD_URL"
unzip -q "$NEXTCLOUD_ZIP"
cp -r nextcloud/* "$NEXTCLOUD_DATADIR"
rm -rf nextcloud*

# Permissões corretas
chown -R www-data:www-data "$NEXTCLOUD_DATADIR"
find "$NEXTCLOUD_DATADIR" -type d -exec chmod 750 {} \;
find "$NEXTCLOUD_DATADIR" -type f -exec chmod 640 {} \;

# -----------------------------
# Configuração timezone e idioma no config.php
# -----------------------------
CONFIG_PHP="$NEXTCLOUD_DATADIR/config/config.php"
php <<PHP_SCRIPT
<?php
\$configFile = '$CONFIG_PHP';
if (file_exists(\$configFile)) {
    \$config = include \$configFile;
    \$config['default_locale'] = '$DEFAULT_LOCALE';
    \$config['default_phone_region'] = '$DEFAULT_PHONE_REGION';
    \$config['force_language'] = '$FORCE_LANGUAGE';
    file_put_contents(\$configFile, "<?php\nreturn " . var_export(\$config, true) . ";");
}
?>
PHP_SCRIPT

# Exporta versão instalada
export NEXTCLOUD_VERSION
