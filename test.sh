#!/bin/sh
# ==========================================
# Установка static-curl с поддержкой HTTP/3
# и запуск zapret/blockcheck.sh
# ==========================================

# --- Настройки ---
INSTALL_DIR="/opt/curl"
ZAPRET_DIR="/opt/zapret"    # путь к zapret (правь если другой)

# --- Цвета ---
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

echo -e "${CYAN}[*] Определяем архитектуру...${NC}"
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)   CURL_FILE="curl-linux-x86_64.tar.xz" ;;
    aarch64)  CURL_FILE="curl-linux-aarch64.tar.xz" ;;
    arm*)     CURL_FILE="curl-linux-armv7.tar.xz" ;;
    mips*)    CURL_FILE="curl-linux-mips.tar.xz" ;;  # может потребовать правку
    *)
        echo -e "${RED}[!] Неизвестная архитектура: $ARCH${NC}"
        exit 1
    ;;
esac

# последнюю версию можно обновить при необходимости
VERSION="v8.10.1"
URL="https://github.com/stunnel/static-curl/releases/download/${VERSION}/${CURL_FILE}"

echo -e "${CYAN}[*] Скачиваем $CURL_FILE ...${NC}"
mkdir -p /tmp/curl-dl && cd /tmp/curl-dl || exit 1
wget -q --show-progress "$URL" || { echo -e "${RED}Ошибка загрузки${NC}"; exit 1; }

echo -e "${CYAN}[*] Распаковываем в ${INSTALL_DIR} ...${NC}"
mkdir -p "$INSTALL_DIR"
tar -xvf "$CURL_FILE" -C "$INSTALL_DIR" --strip-components=1 || exit 1
chmod +x "$INSTALL_DIR/curl"

# --- Обновляем PATH ---
PROFILE_LINE="export PATH=\$PATH:${INSTALL_DIR}"
if ! grep -qxF "$PROFILE_LINE" /etc/profile; then
    echo "$PROFILE_LINE" >> /etc/profile
fi
export PATH=$PATH:${INSTALL_DIR}

echo -e "${GREEN}[+] curl установлен в $INSTALL_DIR${NC}"
$INSTALL_DIR/curl --version | head -n 1

# --- Запускаем blockcheck ---
if [ -x "${ZAPRET_DIR}/blockcheck.sh" ]; then
    echo -e "${CYAN}[*] Запускаем blockcheck.sh ...${NC}"
    cd "${ZAPRET_DIR}" || exit 1
    ./blockcheck.sh
else
    echo -e "${RED}[!] blockcheck.sh не найден в ${ZAPRET_DIR}${NC}"
    echo "Скопируйте zapret в этот каталог или поправьте переменную ZAPRET_DIR."
fi
