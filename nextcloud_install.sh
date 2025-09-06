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
# VERIFICAÇÃO DE WHIPTAIL
# -----------------------------
if ! command -v whiptail &>/dev/null; then
    echo "⚠️ whiptail não encontrado. Instalando..."
    apt-get update
    apt-get install -y whiptail
fi

# -----------------------------
# FUNÇÕES AUXILIARES
# -----------------------------
download_scripts() {
    echo "⬇️ Baixando scripts auxiliares para $SCRIPTS_DIR..."
    mkdir -p "$SCRIPTS_DIR"
    for script in setup_storage.sh setup_nextcloud.sh setup_users.sh setup_ssl.sh; do
        curl -sSL "$REPO_BASE/$script" -o "$SCRIPTS_DIR/$script"
        chmod +x "$SCRIPTS_DIR/$script"
    done
    echo "✅ Scripts baixados."
}

check_dependencies() {
    echo "🔍 Verificando dependências principais (PHP, PostgreSQL, Redis, Apache2)..."
    DEPENDENCIES_EXIST=false

    if dpkg -l | grep -q "php8"; then
        DEPENDENCIES_EXIST=true
    fi
    if dpkg -l | grep -q "postgresql"; then
        DEPENDENCIES_EXIST=true
    fi
    if dpkg -l | grep -q "redis-server"; then
        DEPENDENCIES_EXIST=true
    fi
    if dpkg -l | grep -q "apache2"; then
        DEPENDENCIES_EXIST=true
    fi

    if [ "$DEPENDENCIES_EXIST" = true ]; then
        echo "⚠️ Pelo menos uma das dependências principais já está instalada."
    else
        echo "✅ Nenhuma dependência principal instalada, será feita a instalação completa."
    fi
}

check_existing_installation() {
    if [ "$DEPENDENCIES_EXIST" = false ]; then
        echo "✅ Nenhuma dependência instalada previamente, pulando verificação de instalação existente."
        return
    fi

    CHOICE=$(whiptail --title "Instalação Existente" --menu "Pacotes detectados. Deseja continuar limpando o sistema?" 15 60 2 \
        "1" "Remover todos e instalar do zero" \
        "2" "Encerrar instalação" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1)
            apt-get remove --purge -y apache2* php8.* postgresql* redis-server*
            apt-get autoremove -y
            apt-get clean
            NEEDS_REBOOT=true
            ;;
        2)
            exit 1
            ;;
    esac
}

reboot_if_needed() {
    if [ "$NEEDS_REBOOT" = true ]; then
        if whiptail --title "Reinício necessário" --yesno "O servidor precisa reiniciar. Deseja reiniciar agora?" 10 60 3>&1 1>&2 2>&3; then
            reboot
            exit
        else
            whiptail --title "Atenção" --msgbox "Após reinício, execute novamente o script para continuar a instalação." 10 60
            exit
        fi
    fi
}

# -----------------------------
# CONFIGURAÇÃO DE TIMEZONE, LOCALE, PHONE REGION E LANGUAGE
# -----------------------------
# Valores padrão brasileiros
DEFAULT_TZ="America/Sao_Paulo"
DEFAULT_LOCALE_VAL="pt_BR"
DEFAULT_PHONE_REGION_VAL="BR"
DEFAULT_LANGUAGE_VAL="pt"

# NEXTCLOUD_TIMEZONE
NEXTCLOUD_TIMEZONE=$(whiptail --title "Fuso Horário" \
    --inputbox "Digite o fuso horário do servidor:" 10 60 "$DEFAULT_TZ" 3>&1 1>&2 2>&3)
if [[ -z "$NEXTCLOUD_TIMEZONE" || "$NEXTCLOUD_TIMEZONE" =~ ^[[:space:]]*$ ]]; then
    NEXTCLOUD_TIMEZONE="$DEFAULT_TZ"
fi
timedatectl set-timezone "$NEXTCLOUD_TIMEZONE"

# DEFAULT_LOCALE
DEFAULT_LOCALE=$(whiptail --title "Locale" \
    --inputbox "Digite o locale padrão do Nextcloud:" 10 60 "$DEFAULT_LOCALE_VAL" 3>&1 1>&2 2>&3)
if [[ -z "$DEFAULT_LOCALE" || "$DEFAULT_LOCALE" =~ ^[[:space:]]*$ ]]; then
    DEFAULT_LOCALE="$DEFAULT_LOCALE_VAL"
fi

# DEFAULT_PHONE_REGION
DEFAULT_PHONE_REGION=$(whiptail --title "Phone Region" \
    --inputbox "Digite a região telefônica padrão do Nextcloud:" 10 60 "$DEFAULT_PHONE_REGION_VAL" 3>&1 1>&2 2>&3)
if [[ -z "$DEFAULT_PHONE_REGION" || "$DEFAULT_PHONE_REGION" =~ ^[[:space:]]*$ ]]; then
    DEFAULT_PHONE_REGION="$DEFAULT_PHONE_REGION_VAL"
fi

# FORCE_LANGUAGE
FORCE_LANGUAGE=$(whiptail --title "Idioma" \
    --inputbox "Digite o idioma padrão do Nextcloud:" 10 60 "$DEFAULT_LANGUAGE_VAL" 3>&1 1>&2 2>&3)
if [[ -z "$FORCE_LANGUAGE" || "$FORCE_LANGUAGE" =~ ^[[:space:]]*$ ]]; then
    FORCE_LANGUAGE="$DEFAULT_LANGUAGE_VAL"
fi

export NEXTCLOUD_TIMEZONE DEFAULT_LOCALE DEFAULT_PHONE_REGION FORCE_LANGUAGE

echo "✅ Configurações definidas:"
echo "🌐 Timezone: $NEXTCLOUD_TIMEZONE"
echo "🌐 Locale: $DEFAULT_LOCALE"
echo "🌐 Phone Region: $DEFAULT_PHONE_REGION"
echo "🌐 Language: $FORCE_LANGUAGE"

# -----------------------------
# EXECUÇÃO PRINCIPAL
# -----------------------------
clear
echo "🚀 Iniciando instalação autônoma do Nextcloud"

download_scripts
check_dependencies
check_existing_installation
reboot_if_needed

# Diretório de dados
source "$SCRIPTS_DIR/setup_storage.sh"

# Domínio Nextcloud
NEXTCLOUD_DOMAIN=$(whiptail --inputbox "Digite o domínio para o Nextcloud:" 10 60 3>&1 1>&2 2>&3)
export NEXTCLOUD_DOMAIN

# Instalar Nextcloud, banco, Apache, Redis
source "$SCRIPTS_DIR/setup_nextcloud.sh"

# Configurar usuários
source "$SCRIPTS_DIR/setup_users.sh"

# SSL opcional
if whiptail --title "SSL/HTTPS" --yesno "Deseja configurar HTTPS com Let’s Encrypt?" 10 60 3>&1 1>&2 2>&3; then
    source "$SCRIPTS_DIR/setup_ssl.sh"
fi

# Cron de atualizações
CRON_SCRIPT="$SCRIPTS_DIR/nextcloud_check_update.sh"
if [ ! -f "$CRON_SCRIPT" ]; then
cat <<'EOF' > "$CRON_SCRIPT"
#!/bin/bash
NEXTCLOUD_DIR="/var/www/nextcloud"
INSTALLED=$(grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php" 2>/dev/null || echo "desconhecida")
LATEST=$(curl -s https://nextcloud.com/changelog/ | grep -oP 'Version \K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
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

# Conclusão
NEXTCLOUD_VERSION=$(grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php" 2>/dev/null || echo "desconhecida")
echo "✅ Instalação do Nextcloud $NEXTCLOUD_VERSION concluída!"
echo "🌐 Acesse: http://$NEXTCLOUD_DOMAIN ou https://$NEXTCLOUD_DOMAIN se SSL configurado"
echo "📄 Senhas dos usuários registradas em $NEXTCLOUD_DATADIR/$ADMIN_USER/files/Usuários.txt"
