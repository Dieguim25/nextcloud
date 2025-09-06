#!/bin/bash

# -----------------------------
# VERIFICAR VARIÁVEIS NECESSÁRIAS
# -----------------------------
if [ -z "$NEXTCLOUD_DATADIR" ] || [ -z "$NEXTCLOUD_DIR" ]; then
    echo "❌ NEXTCLOUD_DATADIR ou NEXTCLOUD_DIR não definido. Execute setup_storage.sh e setup_nextcloud.sh antes."
    exit 1
fi

# Função para gerar senhas aleatórias
generate_random_string() {
    tr -dc 'A-Za-z0-9!@#$%&*()_+{}[]' </dev/urandom | head -c "$1"
}

# -----------------------------
# CRIAÇÃO ADMIN
# -----------------------------
echo "⬇️ Configuração do usuário admin principal"
ADMIN_USER=$(whiptail --inputbox "Nome do usuário admin:" 10 60 3>&1 1>&2 2>&3)
ADMIN_PASS=$(whiptail --passwordbox "Senha para $ADMIN_USER:" 10 60 3>&1 1>&2 2>&3)

# Criar arquivo de registro de logins
USERS_FILE="$NEXTCLOUD_DATADIR/$ADMIN_USER/files/Usuários.txt"
mkdir -p "$(dirname "$USERS_FILE")"
touch "$USERS_FILE"
chown www-data:www-data "$USERS_FILE"
chmod 640 "$USERS_FILE"

# Verifica se pasta do admin já existe
if [ -d "$NEXTCLOUD_DATADIR/$ADMIN_USER" ]; then
    if whiptail --yesno "A pasta de dados do admin já existe. Manter os dados existentes?" 10 60 3>&1 1>&2 2>&3; then
        OLD_FOLDER="${ADMIN_USER}_old_$(date +%Y%m%d%H%M%S)"
        mv "$NEXTCLOUD_DATADIR/$ADMIN_USER" "$NEXTCLOUD_DATADIR/$OLD_FOLDER"
        echo "✅ Pasta antiga renomeada para $OLD_FOLDER"
    else
        rm -rf "$NEXTCLOUD_DATADIR/$ADMIN_USER"
        echo "⚠️ Dados antigos removidos"
    fi
fi

# Criar admin no Nextcloud
export OC_PASS="$ADMIN_PASS"
sudo -u www-data php $NEXTCLOUD_DIR/occ user:add --display-name="$ADMIN_USER" --group="admin" --password-from-env $ADMIN_USER
echo "Usuário: $ADMIN_USER | Senha: $ADMIN_PASS" >> "$USERS_FILE"

# Mover arquivos antigos se existir
if [ -n "$OLD_FOLDER" ] && [ -d "$NEXTCLOUD_DATADIR/$OLD_FOLDER" ]; then
    mv "$NEXTCLOUD_DATADIR/$OLD_FOLDER/"* "$NEXTCLOUD_DATADIR/$ADMIN_USER/"
fi
sudo -u www-data php $NEXTCLOUD_DIR/occ files:scan --path="$ADMIN_USER"

# -----------------------------
# OUTROS USUÁRIOS EXISTENTES
# -----------------------------
EXISTING_OTHERS=()
for dir in "$NEXTCLOUD_DATADIR"/*/ ; do
    [ -d "$dir" ] || continue
    USERNAME=$(basename "$dir")
    if [ "$USERNAME" != "$ADMIN_USER" ]; then
        EXISTING_OTHERS+=("$USERNAME")
    fi
done

if [ ${#EXISTING_OTHERS[@]} -gt 0 ]; then
    if whiptail --yesno "Existem outros usuários na pasta de dados. Deseja criar algum deles no Nextcloud?" 10 60 3>&1 1>&2 2>&3; then
        OPTIONS=()
        for u in "${EXISTING_OTHERS[@]}"; do
            OPTIONS+=("$u" "$u" OFF)
        done
        SELECTED=$(whiptail --title "Selecionar usuários" --checklist "Escolha quais usuários criar:" 15 60 8 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

        for u in $SELECTED; do
            u=$(echo "$u" | tr -d '"')
            OLD_FOLDER="${u}_old_$(date +%Y%m%d%H%M%S)"
            mv "$NEXTCLOUD_DATADIR/$u" "$NEXTCLOUD_DATADIR/$OLD_FOLDER"
            USER_PASS="$(generate_random_string 16)"
            export OC_PASS="$USER_PASS"
            sudo -u www-data php $NEXTCLOUD_DIR/occ user:add --password-from-env $u
            mv "$NEXTCLOUD_DATADIR/$OLD_FOLDER/"* "$NEXTCLOUD_DATADIR/$u/"
            sudo -u www-data php $NEXTCLOUD_DIR/occ files:scan --path="$u"
            echo "Usuário: $u | Senha: $USER_PASS" >> "$USERS_FILE"
            echo "✅ Usuário $u criado e sincronizado"
        done

        # Perguntar sobre usuários não selecionados
        NOT_SELECTED=()
        for u in "${EXISTING_OTHERS[@]}"; do
            if [[ ! " $SELECTED " =~ " $u " ]]; then
                NOT_SELECTED+=("$u")
            fi
        done

        for u in "${NOT_SELECTED[@]}"; do
            if whiptail --yesno "Deseja manter backup dos dados do usuário $u em BKP_OLD?" 10 60 3>&1 1>&2 2>&3; then
                mkdir -p "$NEXTCLOUD_DATADIR/BKP_OLD"
                mv "$NEXTCLOUD_DATADIR/$u" "$NEXTCLOUD_DATADIR/BKP_OLD/"
                echo "✅ Dados do usuário $u movidos para BKP_OLD"
            else
                rm -rf "$NEXTCLOUD_DATADIR/$u"
                echo "⚠️ Dados do usuário $u excluídos"
            fi
        done
    fi
fi

echo "✅ Configuração de usuários concluída!"
echo "📄 Todas as senhas estão registradas em $USERS_FILE"
