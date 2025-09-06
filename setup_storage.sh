#!/bin/bash
# Configuração do diretório de dados do Nextcloud, detecção de discos e backup de dados existentes

# Diretório padrão
NEXTCLOUD_DATADIR="/var/www/nextcloud/data"
USERS_LIST=()

# Verifica se /mnt/ncdata existe
if [ -d "/mnt/ncdata" ]; then
    NEXTCLOUD_DATADIR="/mnt/ncdata"
else
    # Verifica se existe mais de um disco disponível
    DISK_COUNT=$(lsblk -dn -o NAME | wc -l)
    if [ "$DISK_COUNT" -gt 1 ]; then
        CHOICE=$(whiptail --title "Diretório de dados" --menu "Mais de um disco detectado. Onde deseja montar o Nextcloud?" 15 60 3 \
            "1" "Montar em /mnt/ncdata existente" \
            "2" "Formatar e montar novo disco em /mnt/ncdata" 3>&1 1>&2 2>&3)
        case $CHOICE in
            1)
                NEXTCLOUD_DATADIR="/mnt/ncdata"
                ;;
            2)
                # Exemplo: formatar /dev/sdb e montar
                mkfs.ext4 /dev/sdb
                mkdir -p /mnt/ncdata
                mount /dev/sdb /mnt/ncdata
                NEXTCLOUD_DATADIR="/mnt/ncdata"
                ;;
        esac
    else
        echo "⚠️ Usando diretório padrão: $NEXTCLOUD_DATADIR"
    fi
fi

# Detecta usuários existentes no diretório
if [ -d "$NEXTCLOUD_DATADIR" ]; then
    for userdir in "$NEXTCLOUD_DATADIR"/*; do
        if [ -d "$userdir" ]; then
            USERS_LIST+=("$(basename "$userdir")")
        fi
    done
fi

# Exportar variáveis
export NEXTCLOUD_DATADIR
export USERS_LIST
