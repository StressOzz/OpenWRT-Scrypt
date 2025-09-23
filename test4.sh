#!/bin/sh
# ==========================================
# Универсальный скрипт установки static-curl для OpenWRT
# с учетом BusyBox wget/tar и запуском blockcheck.sh
# ==========================================

INSTALL_DIR="/opt/curl"
ZAPRET_DIR="/opt/zapret"
CURL_FILE="curl-linux-aarch64-musl-8.16.0.tar.xz"
URL="https://github.com/stunnel/static-curl/releases/download/8.16.0/${CURL_FILE}"

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

# Проверяем wget и tar
command -v wget >/dev/null 2>&1 || { echo -e "${RED}[!] Не найден wget${NC}"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo -e "${RED}[!] Не найден tar${NC}"; exit 1; }

echo -e "${CYAN}[*] Скачиваем ${CURL_FILE} ...${NC}"
mkdir -p /tmp/curl-dl && cd /tmp/curl-dl || exit 1
wget -q "$URL" -O "$CURL_FILE" || { echo -e "${RED}[!] Ошибка загрузки${NC}"; exit 1; }

echo -e "${CYAN}[*] Распаковываем ...${NC}"
mkdir -p "$INSTALL_DIR" /tmp/curl-extract
tar -xvaf "$CURL_FILE" -C /tmp/curl-extract || { echo -e "${RED}[!] Ошибка распаковки${NC}"; exit 1; }

# Определяем верхний каталог архива и переносим содержимое
TOPDIR=$(ls /tmp/curl-extract | head -n1)
mv /tmp/curl-extract/"$TOPDIR"/* "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR/curl"

# Обновляем PATH
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

# Запуск blockcheck
if [ -x "${ZAPRET_DIR}/blockcheck.sh" ]; then
    echo -e "${CYAN}[*] Запускаем blockcheck.sh ...${NC}"
    cd "${ZAPRET_DIR}" || exit 1
    ./blockcheck.sh
else
    echo -e "${RED}[!] blockcheck.sh не найден в ${ZAPRET_DIR}${NC}"
    echo "Убедись, что zapret установлен туда или поправь переменную ZAPRET_DIR."
fi
