#!/bin/bash

NEXTCLOUD_DIR=${NEXTCLOUD_DIR:-"/var/www/nextcloud"}
CONFIG_FILE="$NEXTCLOUD_DIR/config/config.php"

# Função para obter a versão instalada
get_installed_version() {
    if [ -f "$NEXTCLOUD_DIR/version.php" ]; then
        INSTALLED_VERSION=$(grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php")
        echo "$INSTALLED_VERSION"
    else
        echo "Não foi possível detectar a versão instalada."
        exit 1
    fi
}

# Função para obter a versão mais recente do Nextcloud
get_latest_version() {
    LATEST_VERSION=$(curl -s https://nextcloud.com/changelog/ | grep -oP 'Version \K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    echo "$LATEST_VERSION"
}

INSTALLED_VERSION=$(get_installed_version)
LATEST_VERSION=$(get_latest_version)

echo "🖥️  Versão instalada: $INSTALLED_VERSION"
echo "🌐 Última versão disponível: $LATEST_VERSION"

if [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
    echo "⚠️ Existe uma nova versão disponível do Nextcloud!"
    echo "Atualize de $INSTALLED_VERSION para $LATEST_VERSION"
else
    echo "✅ Você já está com a versão mais recente do Nextcloud."
fi
