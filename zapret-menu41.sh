#!/bin/sh
# ==========================================
# Zapret on remittor Manager (installer/updater + superclean uninstall) for OpenWRT
# ==========================================

# Цвета для вывода
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
BLUE="\033[0;34m"
NC="\033[0m"

WORKDIR="/tmp/zapret-update"

# ==============================
# Получение версий и архитектуры
# ==============================
get_versions() {
    # Текущая установленная версия
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"

    # Определение локальной архитектуры устройства
    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    # Получение последней версии под эту архитектуру с GitHub
    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$LOCAL_ARCH.zip" | cut -d '"' -f 4)

    if [ -n "$LATEST_URL" ] && echo "$LATEST_URL" | grep -q '\.zip$'; then
        LATEST_FILE=$(basename "$LATEST_URL")
        LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
        USED_ARCH="$LOCAL_ARCH"
    else
        LATEST_VER="не найдена"
        USED_ARCH="нет пакета для вашей архитектуры"
    fi
}

# ==============================
# Главное меню
# ==============================
show_menu() {
    get_versions
    clear

    echo -e ""
    echo -e "${MAGENTA}ZAPRET on remittor Manager${GREEN}${NC}"

    # Цвет версии: красный, если отличается, зелёный если совпадает
    [ "$INSTALLED_VER" = "$LATEST_VER" ] && INST_COLOR=$GREEN || INST_COLOR=$RED

    echo -e ""
    echo -e "${YELLOW}Установленная версия: ${INST_COLOR}$INSTALLED_VER${NC}"
    echo -e "${YELLOW}Последняя версия GitHub: ${CYAN}$LATEST_VER${NC}"
    echo -e ""
    echo -e "${YELLOW}Архитектура устройства: ${GREEN}$LOCAL_ARCH${NC}"
    echo -e ""
    echo -e "${GREEN}1) Установить или обновить${NC}"
    echo -e "${GREEN}2) Удалить${NC}"
    echo -e "${GREEN}3) Выход (Enter)${NC}"
    echo -e ""
    echo -n "Выберите пункт: "
    read choice
    case "$choice" in
        1) install_update ;;
        2) uninstall_zapret ;;
        *) exit 0 ;;
    esac
}

# ==============================
# Установка или обновление Zapret
# ==============================
install_update() {
    clear
    echo -e ""
    echo -e "${MAGENTA}Начинаем установку ZAPRET${NC}"
    echo -e ""

    get_versions

    # Проверка доступного пакета для архитектуры
    [ "$USED_ARCH" = "нет пакета для вашей архитектуры" ] && {
        echo -e "${RED}[ERROR] Нет доступного пакета для вашей архитектуры: $LOCAL_ARCH${NC}"
        sleep 2
        show_menu
        return
    }

    # Проверка актуальности версии
    if [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
        echo -e "${BLUE}🔴 ${GREEN}Установлена самая свежая версия${NC}"
        sleep 2
        show_menu
        return
    fi

    # Установка unzip если нет
    command -v unzip >/dev/null 2>&1 || { opkg update >/dev/null 2>&1; opkg install unzip >/dev/null 2>&1; }

    # Создание временной папки
    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return

    echo -e "${GREEN}🔴 ${CYAN}Скачиваем $LATEST_FILE...${NC}"
    wget -q "$LATEST_URL" -O "$LATEST_FILE"

    echo -e "${GREEN}🔴 ${CYAN}Распаковываем...${NC}"
    unzip -o "$LATEST_FILE" >/dev/null

    # Установка всех пакетов
    for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
        [ -f "$PKG" ] && {
            echo -e "${GREEN}🔴 ${CYAN}Установка $PKG...${NC}"
            opkg install --force-reinstall "$PKG" >/dev/null 2>&1
        }
    done

    # Очистка всех временных файлов и скачанных пакетов
    cd /
    rm -rf "$WORKDIR"
    rm -f /tmp/*.ipk /tmp/*.zip /tmp/*zapret* 2>/dev/null

    # Перезапуск службы
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret restart >/dev/null 2>&1

    echo -e ""
    echo -e "${BLUE}🔴 ${GREEN}Zapret установлен/обновлен и все временные файлы удалены${NC}"
    sleep 2
    show_menu
}

# ==============================
# Удаление Zapret
# ==============================
uninstall_zapret() {
    clear
    echo -e ""
    echo -e "${MAGENTA}Начинаем удаление ZAPRET${NC}"
    echo -e ""

    # Удаление пакетов через opkg
    opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1

    # Убийство всех процессов Zapret
    for pid in $(ps | grep -i /opt/zapret | grep -v grep | awk '{print $1}'); do kill -9 $pid >/dev/null 2>&1; done

    # Удаление всех конфигов и папок
    for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do [ -e "$path" ] && rm -rf "$path"; done

    # Чистим крон задания
    crontab -l | grep -v -i "zapret" | crontab - 2>/dev/null || true

    # Удаление ipset
    for set in $(ipset list -n 2>/dev/null | grep -i zapret); do ipset destroy "$set" >/dev/null 2>&1; done

    # Удаление всех временных файлов
    rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null

    # Удаление nftables цепочек и таблиц Zapret
    for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
        chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
        for chain in $chains; do nft delete chain $table $chain >/dev/null 2>&1; done
    done
    for table in $(nft list tables 2>/dev/null | awk '{print $2}' | grep -i zapret); do nft delete table $table >/dev/null 2>&1; done

    # Отключение службы и удаление init скрипта
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret disable >/dev/null 2>&1 && rm -f /etc/init.d/zapret

    # Удаление hook скриптов
    HOOK_DIR="/etc/hotplug.d/iface"
    [ -d "$HOOK_DIR" ] && for f in "$HOOK_DIR"/*zapret*; do [ -f "$f" ] && rm -f "$f"; done

    # Очистка оставшихся файлов конфигурации
    EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
    for f in $EXTRA_FILES; do [ -e "$f" ] && rm -rf "$f"; done

    echo -e "${BLUE}🔴 ${GREEN}Zapret полностью удален и все временные файлы удалены${NC}"
    sleep 2
    show_menu
}

# ==============================
# Старт скрипта
# ==============================
show_menu
