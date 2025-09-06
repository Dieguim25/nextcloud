#!/bin/bash

# -----------------------------
# VARIÁVEIS PRINCIPAIS
# -----------------------------
SCRIPTS_DIR="/var/scripts"
REPO_BASE="https://raw.githubusercontent.com/Dieguim25/nextcloud/main"
NEXTCLOUD_DIR="/var/www/nextcloud"
NEXTCLOUD_DATADIR="/var/www/nextcloud/data"
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
    for pkg in "${DEPENDENCIES[@]}"; do
        dpkg -s "$pkg" &>/dev/null || MISSING+=("$pkg")
    done

    if [ ${#MISSING[@]} -eq 0 ]; then
        echo "✅ Todas as dependências estão instaladas."
    else
        echo "⚠️ Pacotes faltando: ${MISSING[*]}"
        whiptail --title "Dependências faltando" --msgbox "Os seguintes pacotes não estão instalados:\n${MISSING[*]}\nEles serão instalados agora." 15 70
        apt-get update
        apt-get install -y "${MISSING[@]}"
        NEEDS_REBOOT=true
    fi
}

check_radical_mode() {
    echo "🔍 Verificando instalações existentes..."
    EXISTING=$(dpkg -l | grep -E "apache2|php8.3|postgresql|redis-server")
    if [ -n "$EXISTING" ]; then
        CHOICE=$(whiptail --title "Modo Radical" --menu "Pacotes detectados. Deseja continuar limpando o sistema?" 15 60 2 \
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
    fi
}

reboot_if_needed() {
    echo "🔄 Reiniciando sistema para aplicar mudanças..."
    (sleep 5 && reboot) &
    exit
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

# 3️⃣ Verificar modo radical / limpeza do sistema
check_radical_mode

# 4️⃣ Perguntar sobre reboot somente se necessário
if [ "$NEEDS_REBOOT" = true ]; then
    read -p "Algumas mudanças exigem reinício. Deseja reiniciar agora? (s/N): " REBOOT_CHOICE
    if [[ "$REBOOT_CHOICE" =~ ^[Ss]$ ]]; then
        reboot_if_needed
    fi
fi

# 5️⃣ Selecionar fuso horário e configurar locale, phone region e language
echo "⬇️ Selecionando fuso horário..."
source "$SCRIPTS_DIR/setup_timezone.sh"

# 6️⃣ Configurar diretório de dados (storage) e importar variáveis
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

# 1️⃣2️⃣ Configurar auto-execução após reboot via systemd
SERVICE_FILE="/etc/systemd/system/nextcloud-install.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "⬇️ Criando serviço systemd para execução automática após reboot..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Instalador Autônomo Nextcloud
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /var/scripts/nextcloud_install.sh
User=root
WorkingDirectory=/root
StandardOutput=journal
StandardError=journal
Restart=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nextcloud-install.service
    echo "✅ Serviço systemd criado e habilitado para iniciar após reboot."
else
    echo "⚠️ Serviço systemd já existe, pulando criação."
fi

# 1️⃣3️⃣ Conclusão
NEXTCLOUD_VERSION=$(grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php" 2>/dev/null || echo "desconhecida")
echo "✅ Instalação do Nextcloud $NEXTCLOUD_VERSION concluída!"
echo "🌐 Acesse: http://$NEXTCLOUD_DOMAIN ou https://$NEXTCLOUD_DOMAIN se SSL configurado"
echo "📄 Senhas dos usuários registradas em $NEXTCLOUD_DATADIR/$ADMIN_USER/files/Usuários.txt"
echo "🌐 Timezone configurado: $NEXTCLOUD_TIMEZONE"
echo "🌐 Locale: $DEFAULT_LOCALE, Phone Region: $DEFAULT_PHONE_REGION, Language: $FORCE_LANGUAGE"
