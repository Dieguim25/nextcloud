#!/bin/bash

# -----------------------------
# VARIÁVEIS PRINCIPAIS
# -----------------------------
SCRIPTS_DIR="/var/scripts"
REPO_BASE="https://raw.githubusercontent.com/Dieguim25/nextcloud/main"
NEXTCLOUD_DIR="/var/www/nextcloud"
NEXTCLOUD_DATADIR="/var/www/nextcloud/data"
DEPENDENCIES_EXIST=false
NEEDS_REBOOT=false

# -----------------------------
# FUNÇÕES AUXILIARES
# -----------------------------

download_scripts() {
    echo "⬇️ Baixando scripts auxiliares para $SCRIPTS_DIR..."
    mkdir -p "$SCRIPTS_DIR"
    for script in setup_storage.sh setup_nextcloud.sh setup_users.sh setup_ssl.sh setup_timezone.sh; do
        curl -sSL "$REPO_BASE/$script" -o "$SCRIPTS_DIR/$script"
        chmod +x "$SCRIPTS_DIR/$script"
    done
    echo "✅ Scripts baixados."
}

check_dependencies() {
    echo "🔍 Verificando dependências essenciais..."

    DEPENDENCIES=(apache2 libapache2-mod-fcgid php8.3 php8.3-fpm php8.3-cli php8.3-common \
    php8.3-pgsql php8.3-curl php8.3-gd php8.3-mbstring php8.3-intl php8.3-xml php8.3-zip \
    php8.3-bcmath php8.3-apcu php8.3-redis php8.3-memcached php8.3-imagick php8.3-gmp \
    php8.3-ldap php8.3-imap redis-server smbclient ffmpeg libreoffice-core)

    MISSING=()
    INSTALLED=0

    for pkg in "${DEPENDENCIES[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            MISSING+=("$pkg")
        else
            INSTALLED=$((INSTALLED + 1))
        fi
    done

    # Se algum pacote já estava instalado antes, setar true
    if [ $INSTALLED -gt 0 ]; then
        DEPENDENCIES_EXIST=true
    else
        DEPENDENCIES_EXIST=false
    fi

    # Instalar pacotes faltantes, mas não alterar DEPENDENCIES_EXIST
    if [ ${#MISSING[@]} -ne 0 ]; then
        echo "⚠️ Instalando dependências faltantes: ${MISSING[*]}"
        apt-get update
        apt-get install -y "${MISSING[@]}"
        NEEDS_REBOOT=true
    else
        echo "✅ Todas as dependências já estavam instaladas."
    fi
}

check_existing_installation() {
    if [ "$DEPENDENCIES_EXIST" = false ]; then
        echo "✅ Nenhuma dependência instalada previamente, pulando verificação de instalação existente."
        return
    fi

    echo "🔍 Pacotes existentes detectados, verificando instalação existente..."
    CHOICE=$(whiptail --title "Instalação Existente" --menu "Pacotes detectados. Deseja continuar limpando o sistema?" 15 60 2 \
        "1" "Remover todos e instalar do zero" \
        "2" "Encerrar instalação" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1)
            echo "⚠️ Removendo pacotes existentes..."
            apt-get remove --purge -y apache2* php8.3* postgresql* redis-server*
            apt-get autoremove -y
            apt-get clean
            NEEDS_REBOOT=true
            ;;
        2)
            echo "❌ Instalação encerrada pelo usuário."
            exit 1
            ;;
    esac
}

reboot_if_needed() {
    if [ "$NEEDS_REBOOT" = true ]; then
        if whiptail --title "Reinício necessário" --yesno "O servidor precisa reiniciar. Deseja reiniciar agora?" 10 60 3>&1 1>&2 2>&3; then
            echo "🔄 Reiniciando sistema..."
            reboot
            exit
        else
            whiptail --title "Atenção" --msgbox "Após reinício, execute novamente o script para continuar a instalação." 10 60
            exit
        fi
    fi
}

# -----------------------------
# EXECUÇÃO PRINCIPAL
# -----------------------------
clear
echo "🚀 Iniciando instalação autônoma do Nextcloud"

# 1️⃣ Baixar scripts auxiliares
download_scripts

# 2️⃣ Checar dependências
check_dependencies

# 3️⃣ Verificar instalações existentes
check_existing_installation

# 4️⃣ Reinício se necessário
reboot_if_needed

# 5️⃣ Selecionar fuso horário interativo
echo "⬇️ Selecionando fuso horário..."
source "$SCRIPTS_DIR/setup_timezone.sh"

# 6️⃣ Configurar diretório de dados (storage)
echo "⬇️ Configurando diretório de dados..."
source "$SCRIPTS_DIR/setup_storage.sh"

# 7️⃣ Perguntar domínio para Nextcloud
NEXTCLOUD_DOMAIN=$(whiptail --inputbox "Digite o domínio para o Nextcloud:" 10 60 3>&1 1>&2 2>&3)
export NEXTCLOUD_DOMAIN

# 8️⃣ Instalar Nextcloud, banco, Redis, Apache, fuso horário e locale
echo "⬇️ Instalando Nextcloud e configurando banco/Apache/Redis..."
source "$SCRIPTS_DIR/setup_nextcloud.sh"

# 9️⃣ Configurar usuários existentes e admin
echo "⬇️ Configurando usuários e sincronizando dados..."
source "$SCRIPTS_DIR/setup_users.sh"

# 🔟 Configurar SSL/HTTPS (opcional)
if whiptail --title "SSL/HTTPS" --yesno "Deseja configurar HTTPS com Let’s Encrypt?" 10 60 3>&1 1>&2 2>&3; then
    echo "⬇️ Configurando SSL/HTTPS..."
    source "$SCRIPTS_DIR/setup_ssl.sh"
else
    echo "⚠️ SSL não configurado. Lembre-se de configurar HTTPS manualmente."
fi

# 1️⃣1️⃣ Criar cron de verificação de updates
echo "⬇️ Configurando cron para verificação automática de atualizações do Nextcloud"
CRON_SCRIPT="$SCRIPTS_DIR/nextcloud_check_update.sh"

if [ ! -f "$CRON_SCRIPT" ]; then
cat <<'EOF' > "$CRON_SCRIPT"
#!/bin/bash
NEXTCLOUD_DIR="/var/www/nextcloud"

get_installed_version() {
    if [ -f "$NEXTCLOUD_DIR/version.php" ]; then
        grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php"
    else
        echo "desconhecida"
    fi
}

get_latest_version() {
    curl -s https://nextcloud.com/changelog/ | grep -oP 'Version \K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

INSTALLED=$(get_installed_version)
LATEST=$(get_latest_version)

echo "🖥️  Versão instalada: $INSTALLED"
echo "🌐 Última versão disponível: $LATEST"

if [ "$INSTALLED" != "$LATEST" ]; then
    echo "⚠️ Atualização disponível: $LATEST"
else
    echo "✅ Você está com a versão mais recente."
fi
EOF
chmod +x "$CRON_SCRIPT"
fi

(crontab -l 2>/dev/null; echo "0 3 * * * $CRON_SCRIPT >> /var/log/nextcloud_update_check.log 2>&1") | crontab -

# 1️⃣2️⃣ Conclusão
NEXTCLOUD_VERSION=$(grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php" 2>/dev/null || echo "desconhecida")
echo "✅ Instalação do Nextcloud $NEXTCLOUD_VERSION concluída!"
echo "🌐 Acesse: http://$NEXTCLOUD_DOMAIN ou https://$NEXTCLOUD_DOMAIN se SSL configurado"
echo "📄 Senhas dos usuários registradas em $NEXTCLOUD_DATADIR/$ADMIN_USER/files/Usuários.txt"
echo "🌐 Timezone configurado: $NEXTCLOUD_TIMEZONE"
echo "🌐 Locale: $DEFAULT_LOCALE, Phone Region: $DEFAULT_PHONE_REGION, Language: $FORCE_LANGUAGE"
