#!/bin/sh
# ==========================================
# Автоматическая установка curl (musl aarch64)
# и Zapret v71.4 на OpenWRT + запуск blockcheck.sh
# ==========================================

INSTALL_DIR="/opt/curl"
ZAPRET_DIR="/opt/zapret"
CURL_URL="https://github.com/stunnel/static-curl/releases/download/8.16.0/curl-linux-aarch64-musl-8.16.0.tar.xz"
ZAPRET_URL="https://github.com/bol-van/zapret/releases/download/v71.4/zapret-v71.4.zip"

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

mkdir -p "$INSTALL_DIR"

# --- Скачивание curl ---
echo -e "${CYAN}[*] Скачиваем curl ...${NC}"
rm -f /tmp/curl.tar.xz /tmp/curl.tar
wget -O /tmp/curl.tar.xz "$CURL_URL" || { echo -e "${RED}[!] Ошибка скачивания curl${NC}"; exit 1; }

# --- Распаковка .xz ---
echo -e "${CYAN}[*] Распаковываем .xz ...${NC}"
rm -f /tmp/curl.tar
unxz -k -f /tmp/curl.tar.xz || { echo -e "${RED}[!] Ошибка распаковки .xz${NC}"; exit 1; }

# --- Распаковка .tar ---
echo -e "${CYAN}[*] Распаковываем .tar в $INSTALL_DIR ...${NC}"
rm -rf "$INSTALL_DIR"/*
tar -xf /tmp/curl.tar -C "$INSTALL_DIR" || { echo -e "${RED}[!] Ошибка распаковки .tar${NC}"; exit 1; }
chmod +x "$INSTALL_DIR/curl"

# --- Добавляем curl в PATH ---
echo -e "${CYAN}[*] Добавляем curl в PATH ...${NC}"
PROFILE_LINE="export PATH=\$PATH:${INSTALL_DIR}"
if [ -d /etc/profile.d ]; then
    echo "$PROFILE_LINE" > /etc/profile.d/curl_path.sh 2>/dev/null || true
else
    if ! grep -qxF "$PROFILE_LINE" /etc/profile 2>/dev/null; then
        printf "%s\n" "$PROFILE_LINE" >> /etc/profile 2>/dev/null || true
    fi
fi
export PATH=$PATH:"${INSTALL_DIR}"
echo -e "${GREEN}[+] curl установлен:${NC}"
"$INSTALL_DIR/curl" --version | head -n1

# --- Скачиваем Zapret ---
echo -e "${CYAN}[*] Скачиваем Zapret v71.4 ...${NC}"
rm -rf /tmp/zapret /tmp/zapret.zip
wget -O /tmp/zapret.zip "$ZAPRET_URL" || { echo -e "${RED}[!] Ошибка скачивания Zapret${NC}"; exit 1; }

# --- Распаковываем Zapret ---
echo -e "${CYAN}[*] Распаковываем Zapret ...${NC}"
unzip -o /tmp/zapret.zip -d /tmp/ || { echo -e "${RED}[!] Ошибка распаковки Zapret${NC}"; exit 1; }

# --- Устанавливаем Zapret ---
echo -e "${CYAN}[*] Устанавливаем Zapret ...${NC}"
sh /tmp/zapret/install_easy.sh || { echo -e "${RED}[!] Ошибка установки Zapret${NC}"; exit 1; }

# --- Очистка временных файлов ---
rm -rf /tmp/zapret /tmp/zapret.zip
rm -f /tmp/curl.tar /tmp/curl.tar.xz

# --- Запуск blockcheck.sh ---
if [ -x "${ZAPRET_DIR}/blockcheck.sh" ]; then
    echo -e "${CYAN}[*] Запускаем blockcheck.sh ...${NC}"
    cd "${ZAPRET_DIR}" || exit 1
    ./blockcheck.sh
else
    echo -e "${RED}[!] blockcheck.sh не найден в ${ZAPRET_DIR}${NC}"
fi
