#!/bin/bash

# -----------------------------
# VARIÁVEIS PRINCIPAIS
# -----------------------------
SCRIPTS_DIR="/var/scripts"
REPO_BASE="https://raw.githubusercontent.com/user/nextcloud/mais"
NEXTCLOUD_DIR="/var/www/nextcloud"
NEXTCLOUD_DATADIR="/var/www/nextcloud/data"

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
                echo "✅ Sistema limpo."
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

# 2️⃣ Verificar modo radical / limpeza do sistema
check_radical_mode

# 3️⃣ Perguntar sobre reboot
read -p "Deseja reiniciar o servidor agora para continuar a instalação limpa? (s/N): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Ss]$ ]]; then
    reboot_if_needed
fi

# 4️⃣ Configurar diretório de dados (storage) e importar variáveis
echo "⬇️ Configurando diretório de dados..."
source "$SCRIPTS_DIR/setup_storage.sh"

# 5️⃣ Perguntar domínio para Nextcloud
NEXTCLOUD_DOMAIN=$(whiptail --inputbox "Digite o domínio para o Nextcloud:" 10 60 3>&1 1>&2 2>&3)
export NEXTCLOUD_DOMAIN

# 6️⃣ Instalar Nextcloud, banco, Redis, Apache e timezone
echo "⬇️ Instalando Nextcloud e configurando banco/Apache/Redis..."
source "$SCRIPTS_DIR/setup_nextcloud.sh"

# 7️⃣ Configurar usuários existentes e admin
echo "⬇️ Configurando usuários e sincronizando dados..."
source "$SCRIPTS_DIR/setup_users.sh"

# 8️⃣ Configurar SSL/HTTPS (opcional)
if whiptail --title "SSL/HTTPS" --yesno "Deseja configurar HTTPS com Let’s Encrypt?" 10 60 3>&1 1>&2 2>&3; then
    echo "⬇️ Configurando SSL/HTTPS..."
    source "$SCRIPTS_DIR/setup_ssl.sh"
else
    echo "⚠️ SSL não configurado. Lembre-se de configurar HTTPS manualmente."
fi

# 9️⃣ Criar cron de verificação de updates
echo "⬇️ Configurando cron para verificação automática de atualizações do Nextcloud"
CRON_SCRIPT="$SCRIPTS_DIR/nextcloud_check_update.sh"

# Criar script de verificação se não existir
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

# Adicionar cron diário às 3h
(crontab -l 2>/dev/null; echo "0 3 * * * $CRON_SCRIPT >> /var/log/nextcloud_update_check.log 2>&1") | crontab -
echo "✅ Cron de verificação de updates criado. Logs em /var/log/nextcloud_update_check.log"

# 10️⃣ Conclusão
NEXTCLOUD_VERSION=$(grep -oP "'version' => '\K[0-9]+\.[0-9]+\.[0-9]+'" "$NEXTCLOUD_DIR/version.php" 2>/dev/null || echo "desconhecida")
echo "✅ Instalação do Nextcloud $NEXTCLOUD_VERSION concluída!"
echo "🌐 Acesse: http://$NEXTCLOUD_DOMAIN ou https://$NEXTCLOUD_DOMAIN se SSL configurado"
echo "📄 Senhas dos usuários registradas em $NEXTCLOUD_DATADIR/$ADMIN_USER/files/Usuários.txt"
