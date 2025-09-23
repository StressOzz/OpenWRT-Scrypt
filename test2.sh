#!/bin/sh
# ==========================================
# Установка static-curl (HTTP/3) для OpenWRT
# и запуск zapret/blockcheck.sh
# ==========================================

# --- Настройки ---
INSTALL_DIR="/opt/curl"      # куда ставим curl
ZAPRET_DIR="/opt/zapret"     # путь к zapret (правь если другой)
CURL_FILE="curl-linux-aarch64-musl-8.16.0.tar.xz"
URL="https://github.com/stunnel/static-curl/releases/download/8.16.0/${CURL_FILE}"

# --- Цвета ---
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

echo -e "${CYAN}[*] Скачиваем ${CURL_FILE} ...${NC}"
mkdir -p /tmp/curl-dl && cd /tmp/curl-dl || exit 1
wget -q --show-progress "$URL" || { echo -e "${RED}[!] Ошибка загрузки${NC}"; exit 1; }

echo -e "${CYAN}[*] Распаковываем в ${INSTALL_DIR} ...${NC}"
mkdir -p "$INSTALL_DIR"
tar -xvf "$CURL_FILE" -C "$INSTALL_DIR" --strip-components=1 || { echo -e "${RED}[!] Ошибка распаковки${NC}"; exit 1; }
chmod +x "$INSTALL_DIR/curl"

# --- Добавляем в PATH ---
PROFILE_LINE="export PATH=\$PATH:${INSTALL_DIR}"
if ! grep -qxF "$PROFILE_LINE" /etc/profile 2>/dev/null; then
    echo "$PROFILE_LINE" >> /etc/profile
fi
export PATH=$PATH:${INSTALL_DIR}

echo -e "${GREEN}[+] curl установлен в $INSTALL_DIR${NC}"
"$INSTALL_DIR/curl" --version | head -n 1

# --- Запуск blockcheck ---
if [ -x "${ZAPRET_DIR}/blockcheck.sh" ]; then
    echo -e "${CYAN}[*] Запускаем blockcheck.sh ...${NC}"
    cd "${ZAPRET_DIR}" || exit 1
    ./blockcheck.sh
else
    echo -e "${RED}[!] blockcheck.sh не найден в ${ZAPRET_DIR}${NC}"
    echo "Убедись, что zapret установлен туда или поправь переменную ZAPRET_DIR."
fi
