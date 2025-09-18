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

get_versions() {
    # Текущая версия
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не установл"

    # Последняя версия на GitHub
    ARCH=$(opkg print-architecture | sort -k3 -n | tail -n1 | awk '{print $2}')
    [ -z "$ARCH" ] && ARCH=$(uname -m)
    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$ARCH.zip" | cut -d '"' -f 4)
    if [ -n "$LATEST_URL" ]; then
        LATEST_FILE=$(basename "$LATEST_URL")
        LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
    else
        LATEST_VER="не найдена"
    fi
}

show_menu() {
    get_versions
    clear

    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ${MAGENTA}ZAPRET on remittor Manager       ${GREEN}║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════╣${NC}"

    # Вывод версий с цветовой подсветкой
    if [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
        INST_COLOR=$GREEN
    else
        INST_COLOR=$RED
    fi

    echo -e "${GREEN}║ ${YELLOW}Установленная версия: ${INST_COLOR}$INSTALLED_VER      ${GREEN}║${NC}"
    echo -e "${GREEN}║ ${YELLOW}Последняя версия GitHub: ${CYAN}$LATEST_VER   ${GREEN}║${NC}"

    echo -e "${GREEN}╠════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║ 1) Установить или обновить             ║${NC}"
    echo -e "${GREEN}║ 2) Удалить                             ║${NC}"
    echo -e "${GREEN}║ 3) Выход (Enter)                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo -n "Выберите пункт: "
    read choice
    case "$choice" in
        1) install_update ;;
        2) uninstall_zapret ;;
        *) exit 0 ;;
    esac
}

install_update() {
    clear

    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ${MAGENTA}Начинаем установку ZAPRET       ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"

    ARCH=$(opkg print-architecture | sort -k3 -n | tail -n1 | awk '{print $2}')
    [ -z "$ARCH" ] && ARCH=$(uname -m)

    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$ARCH.zip" | cut -d '"' -f 4)
    [ -z "$LATEST_URL" ] && { echo -e "${RED}[ERROR] Архив не найден${NC}"; sleep 2; show_menu; return; }

    LATEST_FILE=$(basename "$LATEST_URL")
    LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')

    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')

    if [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
        echo -e "${GREEN}[OK] Установлена самая свежая версия${NC}"
        sleep 2
        show_menu
        return
    fi

    command -v unzip >/dev/null 2>&1 || { opkg update >/dev/null 2>&1; opkg install unzip >/dev/null 2>&1; }

    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return
    echo -e "${CYAN}[INFO] Скачиваем $LATEST_FILE...${NC}"
    wget -q "$LATEST_URL" -O "$LATEST_FILE"
    echo -e "${CYAN}[INFO] Распаковываем...${NC}"
    unzip -o "$LATEST_FILE" >/dev/null

    for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
        [ -f "$PKG" ] && { echo -e "${CYAN}[INFO] Установка $PKG...${NC}"; opkg install --force-reinstall "$PKG" >/dev/null 2>&1; }
    done

    cd / && rm -rf "$WORKDIR"
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret restart >/dev/null 2>&1

    echo -e "${GREEN}[DONE] Zapret установлен/обновлен${NC}"
    sleep 2
    show_menu
}

uninstall_zapret() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        ${MAGENTA}Начинаем удаление ZAPRET        ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

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

    echo -e "${GREEN}[DONE] Zapret полностью удален${NC}"
    sleep 2
    show_menu
}

# Старт
show_menu
