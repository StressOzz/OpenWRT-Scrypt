#!/bin/sh
# ==========================================
#  zapret-openwrt installer/updater
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

WORKDIR="/tmp/zapret-update"
REPO="https://github.com/remittor/zapret-openwrt/releases/latest/download"

# 1. Определяем архитектуру
ARCH=$(opkg print-architecture | awk 'NR>1 {print $2}' | head -n1)
if [ -z "$ARCH" ]; then
    ARCH=$(uname -m)
fi
echo -e "${CYAN}[INFO] Определена архитектура: $ARCH${RESET}"

# 2. Определяем текущую версию (если установлено)
INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
if [ -n "$INSTALLED_VER" ]; then
    echo -e "${YELLOW}[INFO] Установлена версия zapret: $INSTALLED_VER${RESET}"
else
    echo -e "${YELLOW}[INFO] zapret пока не установлен${RESET}"
fi

# 3. Определяем последнюю версию в репозитории
LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
    | grep browser_download_url | grep "$ARCH.zip" | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo -e "${RED}[ERROR] Не удалось найти архив для архитектуры $ARCH${RESET}"
    exit 1
fi

LATEST_FILE=$(basename "$LATEST_URL")
LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
echo -e "${CYAN}[INFO] Последняя доступная версия: $LATEST_VER${RESET}"

if [ -n "$INSTALLED_VER" ] && [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
    echo -e "${GREEN}[OK] Установлена самая свежая версия, обновление не требуется${RESET}"
    exit 0
fi

# 4. Проверяем unzip
if ! command -v unzip >/dev/null 2>&1; then
    echo -e "${YELLOW}[INFO] Устанавливаем unzip...${RESET}"
    opkg update && opkg install unzip || {
        echo -e "${RED}[ERROR] Не удалось установить unzip${RESET}"
        exit 1
    }
fi

# 5. Скачиваем и распаковываем
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

echo -e "${CYAN}[INFO] Скачиваем $LATEST_FILE...${RESET}"
wget -q "$LATEST_URL" -O "$LATEST_FILE" || {
    echo -e "${RED}[ERROR] Не удалось скачать архив${RESET}"
    exit 1
}

echo -e "${CYAN}[INFO] Распаковываем...${RESET}"
unzip -o "$LATEST_FILE" >/dev/null || {
    echo -e "${RED}[ERROR] Не удалось распаковать архив${RESET}"
    exit 1
}

# 6. Устанавливаем ipk
for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
    if [ -f "$PKG" ]; then
        echo -e "${CYAN}[INFO] Установка $PKG...${RESET}"
        opkg install --force-reinstall "$PKG" || {
            echo -e "${RED}[ERROR] Ошибка установки $PKG${RESET}"
        }
    fi
done

# 7. Чистим
cd /
rm -rf "$WORKDIR"

echo -e "${GREEN}[DONE] Обновление zapret завершено${RESET}"
