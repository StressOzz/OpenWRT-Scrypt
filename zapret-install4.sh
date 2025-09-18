#!/bin/sh
# ==========================================
#  zapret-openwrt installer/updater (quiet)
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

WORKDIR="/tmp/zapret-update"

# 1. Определяем архитектуру
ARCH=$(opkg print-architecture | sort -k3 -n | tail -n1 | awk '{print $2}')
[ -z "$ARCH" ] && ARCH=$(uname -m)
echo -e "${CYAN}[INFO] Определена архитектура: $ARCH${RESET}"

# 2. Определяем текущую версию
INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
if [ -n "$INSTALLED_VER" ]; then
    echo -e "${YELLOW}[INFO] Установлена версия zapret: $INSTALLED_VER${RESET}"
else
    echo -e "${YELLOW}[INFO] zapret пока не установлен${RESET}"
fi

# 3. Определяем последнюю версию в GitHub
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
    opkg update >/dev/null 2>&1
    opkg install unzip >/dev/null 2>&1 || {
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
        opkg install --force-reinstall "$PKG" >/dev/null 2>&1 || {
            echo -e "${RED}[ERROR] Ошибка установки $PKG${RESET}"
        }
    fi
done

# 7. Чистим
cd /
rm -rf "$WORKDIR"

# 8. Перезапускаем zapret
if /etc/init.d/zapret status >/dev/null 2>&1; then
    echo -e "${CYAN}[INFO] Перезапуск zapret...${RESET}"
    /etc/init.d/zapret restart >/dev/null 2>&1
fi

echo -e "${GREEN}[DONE] Обновление zapret завершено${RESET}"
