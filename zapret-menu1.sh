#!/bin/sh
# ==========================================
# Zapret Manager (installer/updater + superclean uninstall) for OpenWRT
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
BOLD="\033[1m"
NC="\033[0m"

WORKDIR="/tmp/zapret-update"

show_menu() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo -e "╔════════════════════════════════════════╗"
    echo -e "║           ${MAGENTA}ZAPRET MENU${GREEN}            ║"
    echo -e "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "1) Установить или обновить Zapret"
    echo "2) Удалить Zapret (суперчисто)"
    echo "3) Проверить версию Zapret"
    echo "4) Выход (Enter)"
    echo -n "Выберите пункт: "
    read choice
    case "$choice" in
        1) install_update ;;
        2) uninstall_zapret ;;
        3) check_version ;;
        *) exit 0 ;;
    esac
}

install_update() {
    # Определяем архитектуру
    ARCH=$(opkg print-architecture | sort -k3 -n | tail -n1 | awk '{print $2}')
    [ -z "$ARCH" ] && ARCH=$(uname -m)
    echo -e "${CYAN}[INFO] Определена архитектура: $ARCH${NC}"

    # Текущая версия
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    if [ -n "$INSTALLED_VER" ]; then
        echo -e "${YELLOW}[INFO] Установлена версия zapret: $INSTALLED_VER${NC}"
    else
        echo -e "${YELLOW}[INFO] zapret пока не установлен${NC}"
    fi

    # Последняя версия на GitHub
    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$ARCH.zip" | cut -d '"' -f 4)

    if [ -z "$LATEST_URL" ]; then
        echo -e "${RED}[ERROR] Не удалось найти архив для архитектуры $ARCH${NC}"
        return
    fi

    LATEST_FILE=$(basename "$LATEST_URL")
    LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
    echo -e "${CYAN}[INFO] Последняя доступная версия: $LATEST_VER${NC}"

    if [ -n "$INSTALLED_VER" ] && [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
        echo -e "${GREEN}[OK] Установлена самая свежая версия${NC}"
        return
    fi

    # Проверка unzip
    if ! command -v unzip >/dev/null 2>&1; then
        echo -e "${YELLOW}[INFO] Устанавливаем unzip...${NC}"
        opkg update >/dev/null 2>&1
        opkg install unzip >/dev/null 2>&1 || { echo -e "${RED}[ERROR] Не удалось установить unzip${NC}"; return; }
    fi

    # Скачиваем и распаковываем
    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return
    echo -e "${CYAN}[INFO] Скачиваем $LATEST_FILE...${NC}"
    wget -q "$LATEST_URL" -O "$LATEST_FILE" || { echo -e "${RED}[ERROR] Не удалось скачать архив${NC}"; return; }

    echo -e "${CYAN}[INFO] Распаковываем...${NC}"
    unzip -o "$LATEST_FILE" >/dev/null || { echo -e "${RED}[ERROR] Не удалось распаковать архив${NC}"; return; }

    # Устанавливаем ipk
    for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
        [ -f "$PKG" ] && opkg install --force-reinstall "$PKG" >/dev/null 2>&1
    done

    cd / && rm -rf "$WORKDIR"

    # Перезапуск zapret
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret restart >/dev/null 2>&1
    echo -e "${GREEN}[DONE] Обновление Zapret завершено${NC}"
    sleep 2
    show_menu
}

uninstall_zapret() {
    clear
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════╗"
    echo -e "║  ${MAGENTA}Начинаем суперчистое удаление ZAPRET${GREEN}  ║"
    echo -e "╚════════════════════════════════════════╝${NC}"

    opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1

    for pid in $(ps | grep -i /opt/zapret | grep -v grep | awk '{print $1}'); do kill -9 $pid >/dev/null 2>&1; done
    for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do [ -e "$path" ] && rm -rf "$path"; done
    crontab -l | grep -v -i "zapret" | crontab - 2>/dev/null || true
    for set in $(ipset list -n 2>/dev/null | grep -i zapret); do ipset destroy "$set" >/dev/null 2>&1; done
    rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null
    for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
        chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
        for chain in $chains; do nft delete chain $table $chain >/dev/null 2>&1; done
    done
    for table in $(nft list tables 2>/dev/null | awk '{print $2}' | grep -i zapret); do nft delete table $table >/dev/null 2>&1; done
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret disable >/dev/null 2>&1 && rm -f /etc/init.d/zapret
    HOOK_DIR="/etc/hotplug.d/iface"
    [ -d "$HOOK_DIR" ] && for f in "$HOOK_DIR"/*zapret*; do [ -f "$f" ] && rm -f "$f"; done
    EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
    for f in $EXTRA_FILES; do [ -e "$f" ] && rm -rf "$f"; done

    echo -e "${GREEN}[DONE] Удаление Zapret завершено${NC}"
    sleep 2
    show_menu
}

check_version() {
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    echo -e "${YELLOW}Установленная версия:${NC} ${CYAN}${INSTALLED_VER:-не установлена}${NC}"

    ARCH=$(opkg print-architecture | sort -k3 -n | tail -n1 | awk '{print $2}')
    [ -z "$ARCH" ] && ARCH=$(uname -m)
    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$ARCH.zip" | cut -d '"' -f 4)
    LATEST_FILE=$(basename "$LATEST_URL")
    LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
    echo -e "${YELLOW}Последняя версия на GitHub:${NC} ${CYAN}${LATEST_VER:-не найдена}${NC}"
    sleep 3
    show_menu
}

# Старт меню
show_menu
