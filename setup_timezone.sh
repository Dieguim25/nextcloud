#!/bin/bash

# -----------------------------
# Gerar lista de fusos horários do sistema
# -----------------------------
TIMEZONES=()
while IFS= read -r zone; do
    # Ignorar arquivos binários ou zonas de sistema (Etc, posix)
    if [[ "$zone" != *Etc* && "$zone" != *posix* && "$zone" != *right* ]]; then
        # Extrair caminho relativo após /usr/share/zoneinfo/
        tz="${zone#/usr/share/zoneinfo/}"
        TIMEZONES+=("$tz" "$tz")
    fi
done < <(find /usr/share/zoneinfo -type f)

# -----------------------------
# MENU DE SELEÇÃO
# -----------------------------
CHOICE=$(whiptail --title "Seleção de Fuso Horário" --menu "Escolha o fuso horário do servidor:" 40 120 30 "${TIMEZONES[@]}" 3>&1 1>&2 2>&3)

if [ -z "$CHOICE" ]; then
    echo "❌ Nenhum fuso horário selecionado. Encerrando."
    exit 1
fi

export NEXTCLOUD_TIMEZONE="$CHOICE"
timedatectl set-timezone "$NEXTCLOUD_TIMEZONE"

# -----------------------------
# CONFIGURAÇÃO DE LOCALE, PHONE_REGION E LANGUAGE
# -----------------------------
case "$NEXTCLOUD_TIMEZONE" in
    America/*)
        DEFAULT_LOCALE="en_US"
        DEFAULT_PHONE_REGION="US"
        FORCE_LANGUAGE="en"
        ;;
    Europe/*)
        DEFAULT_LOCALE="en_GB"
        DEFAULT_PHONE_REGION="GB"
        FORCE_LANGUAGE="en"
        ;;
    Africa/*)
        DEFAULT_LOCALE="en_GB"
        DEFAULT_PHONE_REGION="ZA"
        FORCE_LANGUAGE="en"
        ;;
    Asia/*)
        DEFAULT_LOCALE="en_US"
        DEFAULT_PHONE_REGION="IN"
        FORCE_LANGUAGE="en"
        ;;
    Australia/*)
        DEFAULT_LOCALE="en_AU"
        DEFAULT_PHONE_REGION="AU"
        FORCE_LANGUAGE="en"
        ;;
    Pacific/*)
        DEFAULT_LOCALE="en_US"
        DEFAULT_PHONE_REGION="US"
        FORCE_LANGUAGE="en"
        ;;
    *)
        DEFAULT_LOCALE="en"
        DEFAULT_PHONE_REGION="US"
        FORCE_LANGUAGE="en"
        ;;
esac

export DEFAULT_LOCALE
export DEFAULT_PHONE_REGION
export FORCE_LANGUAGE

echo "✅ Fuso horário configurado: $NEXTCLOUD_TIMEZONE"
echo "🌐 Locale: $DEFAULT_LOCALE, Phone Region: $DEFAULT_PHONE_REGION, Language: $FORCE_LANGUAGE"
