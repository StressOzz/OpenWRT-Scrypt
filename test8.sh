#!/bin/sh
# ==========================================
# Zapret on remittor Manager by StressOzz
# Скрипт для установки, обновления и полного удаления Zapret на OpenWRT
# ==========================================

# Цвета для вывода
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
BLUE="\033[0;34m"
NC="\033[0m"
GRAY='\033[38;5;239m'
DGRAY='\033[38;5;236m'

WORKDIR="/tmp/zapret-update"

# ==========================================
# Получение информации о версиях, архитектуре и статусе
# ==========================================
get_versions() {
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"

    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    command -v curl >/dev/null 2>&1 || {
        clear
        echo -e "${MAGENTA}ZAPRET on remittor Manager by StressOzz${NC}"
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем curl${NC}"
        opkg update >/dev/null 2>&1
        opkg install curl >/dev/null 2>&1
    }

    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$LOCAL_ARCH.zip" | cut -d '"' -f 4)
    PREV_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases \
        | grep browser_download_url | grep "$LOCAL_ARCH.zip" | sed -n '2p' | cut -d '"' -f 4)

    if [ -n "$LATEST_URL" ] && echo "$LATEST_URL" | grep -q '\.zip$'; then
        LATEST_FILE=$(basename "$LATEST_URL")
        LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
        USED_ARCH="$LOCAL_ARCH"
    else
        LATEST_VER="не найдена"
        USED_ARCH="нет пакета для вашей архитектуры"
    fi

    if [ -n "$PREV_URL" ] && echo "$PREV_URL" | grep -q '\.zip$'; then
        PREV_FILE=$(basename "$PREV_URL")
        PREV_VER=$(echo "$PREV_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
    else
        PREV_VER="не найдена"
    fi

    if [ -f /etc/init.d/zapret ]; then
        if /etc/init.d/zapret status 2>/dev/null | grep -qi "running"; then
            ZAPRET_STATUS="${GREEN}запущен${NC}"
        else
            ZAPRET_STATUS="${RED}остановлен${NC}"
        fi
    else
        ZAPRET_STATUS=""
    fi
}

# ==========================================
# Установка или обновление Zapret
# ==========================================
install_update() {
    clear
    echo -e ""
    if [ "$INSTALLED_VER" != "не найдена" ]; then
        echo -e "${MAGENTA}Начинаем обновление ZAPRET${NC}"
        ACTION="update"
    else
        echo -e "${MAGENTA}Начинаем установку ZAPRET${NC}"
        ACTION="install"
    fi
    echo -e ""
    get_versions

    TARGET="$1"

    # Определяем URL и файл
    if [ "$TARGET" != "latest" ] && [ "$TARGET" != "prev" ]; then
        TARGET_VER="$TARGET"
        TARGET_FILE="zapret_v$TARGET_VER_$LOCAL_ARCH.zip"
        TARGET_URL="https://github.com/remittor/zapret-openwrt/releases/download/v$TARGET_VER/$TARGET_FILE"
        # Проверка наличия файла на GitHub
        if ! curl --head --silent --fail "$TARGET_URL" >/dev/null; then
            echo -e "${RED}Пакет для версии $TARGET_VER не найден для архитектуры $LOCAL_ARCH${NC}"
            read -p "Нажмите Enter для продолжения..." dummy
            return
        fi
    elif [ "$TARGET" = "prev" ]; then
        TARGET_URL="$PREV_URL"
        TARGET_FILE="$PREV_FILE"
        TARGET_VER="$PREV_VER"
    else
        TARGET_URL="$LATEST_URL"
        TARGET_FILE="$LATEST_FILE"
        TARGET_VER="$LATEST_VER"
    fi

    if [ "$USED_ARCH" = "нет пакета для вашей архитектуры" ]; then
        echo -e "${RED}Нет доступного пакета для вашей архитектуры: ${NC}$LOCAL_ARCH"
        read -p "Нажмите Enter для продолжения..." dummy
        return
    fi

    if [ "$INSTALLED_VER" = "$TARGET_VER" ]; then
        echo -e "${BLUE}🔴 ${GREEN}Эта версия уже установлена !${NC}"
        read -p "Нажмите Enter для продолжения..." dummy
        return
    fi

    # Останавливаем Zapret
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret stop >/dev/null 2>&1
    PIDS=$(pgrep -f /opt/zapret)
    [ -n "$PIDS" ] && for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done

    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return
    echo -e "${GREEN}🔴 ${CYAN}Скачиваем архив ${NC}$TARGET_FILE"
    wget -q "$TARGET_URL" -O "$TARGET_FILE" || { echo -e "${RED}Не удалось скачать ${NC}$TARGET_FILE"; read -p "Нажмите Enter для продолжения..." dummy; return; }

    command -v unzip >/dev/null 2>&1 || { 
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем unzip${NC}"
        opkg update >/dev/null 2>&1
        opkg install unzip >/dev/null 2>&1
    }

    echo -e "${GREEN}🔴 ${CYAN}Распаковываем архив${NC}"
    unzip -o "$TARGET_FILE" >/dev/null

    PIDS=$(pgrep -f /opt/zapret)
    [ -n "$PIDS" ] && for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done

    for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
        [ -f "$PKG" ] && {
            echo -e "${GREEN}🔴 ${CYAN}Устанавливаем пакет ${NC}$PKG"
            opkg install --force-reinstall "$PKG" >/dev/null 2>&1
        }
    done

    echo -e "${GREEN}🔴 ${CYAN}Удаляем временные файлы и пакеты${NC}"
    cd /
    rm -rf "$WORKDIR"
    rm -f /tmp/*.ipk /tmp/*.zip /tmp/*zapret* 2>/dev/null

    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Перезапуск службы ${NC}zapret"
        chmod +x /opt/zapret/sync_config.sh
        /opt/zapret/sync_config.sh
        /etc/init.d/zapret restart >/dev/null 2>&1
    }

    echo -e ""
    if [ "$ACTION" = "update" ]; then
        echo -e "${BLUE}🔴 ${GREEN}Zapret успешно обновлён !${NC}"
    else
        echo -e "${BLUE}🔴 ${GREEN}Zapret успешно установлен !${NC}"
    fi
    echo -e ""
    read -p "Нажмите Enter для продолжения..." dummy
}

# ==========================================
# Удаление Zapret
# ==========================================
uninstall_zapret() {
    clear
    echo -e "${MAGENTA}Начинаем удаление ZAPRET${NC}"
    [ -f /etc/init.d/zapret ] && /etc/init.d/zapret stop >/dev/null 2>&1
    PIDS=$(pgrep -f /opt/zapret)
    [ -n "$PIDS" ] && for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
    opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1
    for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do [ -e "$path" ] && rm -rf "$path"; done
    if crontab -l >/dev/null 2>&1; then crontab -l | grep -v -i "zapret" | crontab -; fi
    for set in $(ipset list -n 2>/dev/null | grep -i zapret); do ipset destroy "$set" >/dev/null 2>&1; done
    rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null
    for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
        chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
        for chain in $chains; do nft delete chain $table $chain >/dev/null 2>&1; done
    done
    for table in $(nft list tables 2>/dev/null | awk '{print $2}' | grep -i zapret); do nft delete table $table >/dev/null 2>&1; done
    [ -f /etc/init.d/zapret ] && { /etc/init.d/zapret disable >/dev/null 2>&1; rm -f /etc/init.d/zapret; }
    HOOK_DIR="/etc/hotplug.d/iface"
    [ -d "$HOOK_DIR" ] && for f in "$HOOK_DIR"/*zapret*; do [ -f "$f" ] && rm -f "$f"; done
    EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
    for f in $EXTRA_FILES; do [ -e "$f" ] && rm -rf "$f"; done
    echo -e "${BLUE}🔴 ${GREEN}Zapret полностью удалён !${NC}"
    read -p "Нажмите Enter для продолжения..." dummy
}

# ==========================================
# Главное меню
# ==========================================
show_menu() {
    get_versions
    clear
    echo -e "███████╗ █████╗ ██████╗ ██████╗ ███████╗████████╗"
    echo -e "╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
    echo -e "  ███╔╝ ███████║██████╔╝██████╔╝█████╗     ██║   "
    echo -e " ███╔╝  ██╔══██║██╔═══╝ ██╔══██╗██╔══╝     ██║   "
    echo -e "███████╗██║  ██║██║     ██║  ██║███████╗   ██║   "
    echo -e "╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝   "
    echo -e "              ${MAGENTA}on remittor Manager by StressOzz${NC}"
    echo -e "                                          ${DGRAY}v1.7${NC}"
    echo -e "${GRAY}https://github.com/bol-van/zapret${NC}"
    echo -e "${GRAY}https://github.com/remittor/zapret-openwrt${NC}"

    [ "$INSTALLED_VER" = "$LATEST_VER" ] && INST_COLOR=$GREEN || INST_COLOR=$RED
    [ "$INSTALLED_VER" = "$LATEST_VER" ] && INSTALLED_DISPLAY="$INSTALLED_VER (актуальная)" || INSTALLED_DISPLAY="$INSTALLED_VER (устарела)"
    MENU1_TEXT="[1] Установить/Обновить до последней версии"

    echo -e "${YELLOW}Установленная версия: ${INST_COLOR}$INSTALLED_DISPLAY${NC}"
    echo -e "${YELLOW}Последняя версия на GitHub: ${NC}$LATEST_VER"
    echo -e "${YELLOW}Предыдущая версия на GitHub: ${CYAN}$PREV_VER${NC}"
    echo -e "${YELLOW}Архитектура устройства: ${NC}$LOCAL_ARCH"
    [ -n "$ZAPRET_STATUS" ] && echo -e "${YELLOW}Статус службы Zapret: ${NC}$ZAPRET_STATUS"
    echo -e ""
    echo -e "${GREEN}1) $MENU1_TEXT${NC}"
    echo -e "${GREEN}2) Установить предыдущую версию${NC}"
    echo -e "${GREEN}3) Вернуть настройки по умолчанию${NC}"
    echo -e "${GREEN}4) Удалить Zapret${NC}"
    echo -e "${GREEN}5) Остановить Zapret${NC}"
    echo -e "${GREEN}6) Запустить Zapret${NC}"
    echo -e "${GREEN}7) Установить конкретную версию${NC}"
    echo -e "${GREEN}8) Выход (Enter)${NC}"
    echo -n "Выберите пункт: "
    read choice
    case "$choice" in
        1) install_update "latest"; show_menu ;;
        2) install_update "prev"; show_menu ;;
        3)
            clear
            echo -e "${MAGENTA}Возврат к настройкам по умолчанию${NC}"
            if [ -f /opt/zapret/restore-def-cfg.sh ]; then
                [ -f /etc/init.d/zapret ] && /etc/init.d/zapret stop >/dev/null 2>&1
                chmod +x /opt/zapret/restore-def-cfg.sh
                /opt/zapret/restore-def-cfg.sh
                chmod +x /opt/zapret/sync_config.sh
                /opt/zapret/sync_config.sh
                [ -f /etc/init.d/zapret ] && /etc/init.d/zapret restart >/dev/null 2>&1
                echo -e "${BLUE}🔴 ${GREEN}Настройки возвращены, сервис перезапущен !${NC}"
            else
                echo -e "${RED}Zapret не установлен !${NC}"
            fi
            read -p "Нажмите Enter для продолжения..." dummy
            show_menu
            ;;
        4) uninstall_zapret; show_menu ;;
        5)
            clear
            echo -e "${MAGENTA}Остановка Zapret${NC}"
            [ -f /etc/init.d/zapret ] && /etc/init.d/zapret stop >/dev/null 2>&1
            PIDS=$(pgrep -f /opt/zapret)
            [ -n "$PIDS" ] && for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
            echo -e "${BLUE}🔴 ${GREEN}Zapret остановлен !${NC}"
            read -p "Нажмите Enter для продолжения..." dummy
            show_menu
            ;;
        6)
            clear
            echo -e "${MAGENTA}Запуск Zapret${NC}"
            [ -f /etc/init.d/zapret ] && /etc/init.d/zapret start >/dev/null 2>&1
            echo -e "${BLUE}🔴 ${GREEN}Zapret запущен !${NC}"
            read -p "Нажмите Enter для продолжения..." dummy
            show_menu
            ;;
        7)
            clear
            echo -e "${MAGENTA}Установка конкретной версии${NC}"
            echo -n "Введите версию (например 1.6): "
            read user_ver
            if [ -z "$user_ver" ]; then
                echo -e "${RED}Версия не введена !${NC}"
                read -p "Нажмите Enter для продолжения..." dummy
            else
                install_update "$user_ver"
            fi
            show_menu
            ;;
        *) exit 0 ;;
    esac
}

# ==========================================
# Старт скрипта
# ==========================================
show_menu
