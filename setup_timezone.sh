#!/bin/bash
# Script para selecionar timezone e definir locale, phone region e language

TIMEZONE=$(whiptail --title "Escolha o Fuso Horário" --menu "Selecione seu timezone:" 40 80 35 \
"UTC" "Tempo Universal Coordenado" \
# América do Norte
"America/New_York" "Estados Unidos - Nova York" \
"America/Chicago" "Estados Unidos - Chicago" \
"America/Denver" "Estados Unidos - Denver" \
"America/Los_Angeles" "Estados Unidos - Los Angeles" \
"America/Anchorage" "Estados Unidos - Anchorage" \
"America/Phoenix" "Estados Unidos - Phoenix" \
"America/Toronto" "Canadá - Toronto" \
"America/Vancouver" "Canadá - Vancouver" \
# América do Sul
"America/Sao_Paulo" "Brasil - São Paulo" \
"America/Rio_Branco" "Brasil - Rio Branco" \
"America/Buenos_Aires" "Argentina - Buenos Aires" \
"America/Santiago" "Chile - Santiago" \
"America/Lima" "Peru - Lima" \
# Europa
"Europe/London" "Reino Unido - Londres" \
"Europe/Berlin" "Alemanha - Berlim" \
"Europe/Paris" "França - Paris" \
"Europe/Madrid" "Espanha - Madrid" \
"Europe/Rome" "Itália - Roma" \
"Europe/Moscow" "Rússia - Moscou" \
"Europe/Istanbul" "Turquia - Istambul" \
# Ásia
"Asia/Tokyo" "Japão - Tóquio" \
"Asia/Seoul" "Coreia do Sul - Seul" \
"Asia/Shanghai" "China - Xangai" \
"Asia/Kolkata" "Índia - Kolkata" \
"Asia/Dubai" "Emirados Árabes Unidos - Dubai" \
"Asia/Singapore" "Singapura" \
# África
"Africa/Johannesburg" "África do Sul - Joanesburgo" \
"Africa/Cairo" "Egito - Cairo" \
"Africa/Lagos" "Nigéria - Lagos" \
# Oceania
"Australia/Sydney" "Austrália - Sydney" \
"Australia/Perth" "Austrália - Perth" \
"Pacific/Auckland" "Nova Zelândia - Auckland" \
3>&1 1>&2 2>&3)

# Se o usuário não escolher nada, default para UTC
if [ -z "$TIMEZONE" ]; then
    TIMEZONE="UTC"
fi
export NEXTCLOUD_TIMEZONE="$TIMEZONE"

# -----------------------------
# Mapear timezone para locale, phone region e linguagem
# -----------------------------
case "$TIMEZONE" in
    America/*)
        DEFAULT_LOCALE="pt_BR"
        DEFAULT_PHONE_REGION="BR"
        FORCE_LANGUAGE="pt"
        ;;
    Europe/*)
        DEFAULT_LOCALE="de_DE"
        DEFAULT_PHONE_REGION="DE"
        FORCE_LANGUAGE="de"
        ;;
    Asia/*)
        DEFAULT_LOCALE="zh_CN"
        DEFAULT_PHONE_REGION="CN"
        FORCE_LANGUAGE="zh"
        ;;
    Africa/*)
        DEFAULT_LOCALE="en_US"
        DEFAULT_PHONE_REGION="ZA"
        FORCE_LANGUAGE="en"
        ;;
    Australia/* | Pacific/*)
        DEFAULT_LOCALE="en_AU"
        DEFAULT_PHONE_REGION="AU"
        FORCE_LANGUAGE="en"
        ;;
    UTC)
        DEFAULT_LOCALE="en_US"
        DEFAULT_PHONE_REGION="US"
        FORCE_LANGUAGE="en"
        ;;
    *)
        DEFAULT_LOCALE="en_US"
        DEFAULT_PHONE_REGION="US"
        FORCE_LANGUAGE="en"
        ;;
esac

export DEFAULT_LOCALE
export DEFAULT_PHONE_REGION
export FORCE_LANGUAGE

echo "🌐 Timezone selecionado: $NEXTCLOUD_TIMEZONE"
echo "🌐 Locale: $DEFAULT_LOCALE"
echo "🌐 Phone Region: $DEFAULT_PHONE_REGION"
echo "🌐 Language: $FORCE_LANGUAGE"
