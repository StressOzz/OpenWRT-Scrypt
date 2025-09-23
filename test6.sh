#!/bin/sh
# ==========================================
# Установка curl (musl, aarch64) на OpenWRT
# без архива, с запуском blockcheck.sh
# ==========================================

INSTALL_DIR="/opt/curl"
ZAPRET_DIR="/opt/zapret"
CURL_BIN_URL="https://github.com/stunnel/static-curl/releases/download/8.16.0/curl-linux-aarch64-musl-8.16.0"  # сам бинарник

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

mkdir -p "$INSTALL_DIR"

echo -e "${CYAN}[*] Скачиваем curl ...${NC}"
wget -q "$CURL_BIN_URL" -O "$INSTALL_DIR/curl" || { echo -e "${RED}[!] Ошибка скачивания${NC}"; exit 1; }

chmod +x "$INSTALL_DIR/curl"

# добавляем в PATH
PROFILE_LINE="export PATH=\$PATH:${INSTALL_DIR}"
if [ -d /etc/profile.d ]; then
    echo "$PROFILE_LINE" > /etc/profile.d/curl_path.sh 2>/dev/null || true
else
    if ! grep -qxF "$PROFILE_LINE" /etc/profile 2>/dev/null; then
        printf "%s\n" "$PROFILE_LINE" >> /etc/profile 2>/dev/null || true
    fi
fi
export PATH=$PATH:"${INSTALL_DIR}"

echo -e "${GREEN}[+] curl установлен в $INSTALL_DIR${NC}"
"$INSTALL_DIR/curl" --version | head -n 1

# запуск blockcheck.sh
if [ -x "${ZAPRET_DIR}/blockcheck.sh" ]; then
    echo -e "${CYAN}[*] Запускаем blockcheck.sh ...${NC}"
    cd "${ZAPRET_DIR}" || exit 1
    ./blockcheck.sh
else
    echo -e "${RED}[!] blockcheck.sh не найден в ${ZAPRET_DIR}${NC}"
    echo "Убедись, что zapret установлен туда или поправь переменную ZAPRET_DIR."
fi
