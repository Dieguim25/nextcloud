#!/bin/bash

# -----------------------------
# CONFIGURAÇÃO DE DIRETÓRIO DE DADOS DO NEXTCLOUD
# -----------------------------
DEFAULT_DATADIR="/var/www/html/nextcloud/data"
MOUNT_POINT="/mnt/ncdata"
SELECTED_DISK=""
USER_CHOICE=""

echo "🔍 Verificando ponto de montagem $MOUNT_POINT..."

# Verifica se o diretório existe
if [ ! -d "$MOUNT_POINT" ]; then
    echo "❌ Diretório $MOUNT_POINT não existe."
    mkdir -p "$MOUNT_POINT"
    echo "✅ Diretório $MOUNT_POINT criado."
fi

# Verifica se está montado
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "❌ $MOUNT_POINT não está montado."

    # Procura discos disponíveis (excluindo root e home)
    AVAILABLE_DISKS=$(lsblk -dpno NAME,SIZE | grep -Ev "sr0|loop|$(df / | tail -1 | awk '{print $1}')" | awk '{print $1}')

    if [ -n "$AVAILABLE_DISKS" ]; then
        OPTIONS=()
        i=1
        for disk in $AVAILABLE_DISKS; do
            OPTIONS+=("$i" "$disk")
            ((i++))
        done

        OPTIONS+=("0" "Usar diretório padrão ($DEFAULT_DATADIR)")

        USER_CHOICE=$(whiptail --title "Escolha do disco" --menu \
            "Selecione um disco para montar em $MOUNT_POINT ou escolha 0 para usar o diretório padrão:" 20 70 10 \
            "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

        if [ "$USER_CHOICE" = "0" ] || [ -z "$USER_CHOICE" ]; then
            NEXTCLOUD_DATADIR="$DEFAULT_DATADIR"
            echo "⚠️ Usando diretório padrão para dados: $NEXTCLOUD_DATADIR"
        else
            SELECTED_DISK=$(echo "$AVAILABLE_DISKS" | sed -n "${USER_CHOICE}p")
            
            # Pergunta se deseja formatar ou apenas montar
            if whiptail --title "Formatação" --yesno "Deseja formatar $SELECTED_DISK antes de montar em $MOUNT_POINT? (Sim = Apagar tudo)" 10 60 3>&1 1>&2 2>&3; then
                mkfs.ext4 "$SELECTED_DISK"
                echo "✅ Disco formatado."
            fi

            # Monta o disco
            mount "$SELECTED_DISK" "$MOUNT_POINT"
            echo "✅ Disco $SELECTED_DISK montado em $MOUNT_POINT."

            # Adiciona no fstab para montagem automática
            UUID=$(blkid -s UUID -o value "$SELECTED_DISK")
            if ! grep -q "$MOUNT_POINT" /etc/fstab; then
                echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
                echo "✅ Adicionado ao /etc/fstab para montagem automática."
            fi

            NEXTCLOUD_DATADIR="$MOUNT_POINT"
        fi
    else
        echo "⚠️ Nenhum disco adicional encontrado. Usando diretório padrão: $DEFAULT_DATADIR"
        NEXTCLOUD_DATADIR="$DEFAULT_DATADIR"
    fi
else
    echo "✅ $MOUNT_POINT já está montado."
    NEXTCLOUD_DATADIR="$MOUNT_POINT"
fi

export NEXTCLOUD_DATADIR
echo "📂 Diretório de dados definido: $NEXTCLOUD_DATADIR"

# -----------------------------
# VERIFICA DADOS EXISTENTES
# -----------------------------
if [ -d "$NEXTCLOUD_DATADIR" ] && [ "$(ls -A "$NEXTCLOUD_DATADIR")" ]; then
    EXISTING_USERS=$(ls "$NEXTCLOUD_DATADIR")
    echo "⚠️ Dados de usuários existentes detectados: $EXISTING_USERS"
    export EXISTING_USERS
fi
