#!/bin/sh
# ==========================================
# Zapret on remittor Manager by StressOzz
# Скрипт для установки, обновления и полного удаления Zapret на OpenWRT
# ==========================================

# Цвета для вывода
GREEN="\033[1;32m"       # Зеленый для успешных действий и статусов
RED="\033[1;31m"         # Красный для ошибок или остановленных процессов
CYAN="\033[1;36m"        # Голубой для информационных сообщений
YELLOW="\033[1;33m"      # Желтый для подчеркивания важных данных
MAGENTA="\033[1;35m"     # Фиолетовый для заголовков и названия скрипта
BLUE="\033[0;34m"        # Синий для завершения действий
NC="\033[0m"             # Сброс цвета
GRAY='\033[38;5;239m'    # Темно-серый для ссылок
DGRAY='\033[38;5;236m'   # Очень темный серый для версии

# Рабочая директория для скачивания и распаковки
WORKDIR="/tmp/zapret-update"  # Временная папка для загрузки архивов

# ==========================================
# Функция получения информации о версиях, архитектуре и статусе
# ==========================================
get_versions() {
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"

    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    command -v curl >/dev/null 2>&1 || {
        clear
        echo -e ""
        echo -e "${MAGENTA}ZAPRET on remittor Manager by StressOzz${NC}"
        echo -e ""
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем${NC} curl ${CYAN}для загрузки информации с ${NC}GitHub"
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

if [ "$TARGET" = "prev" ]; then
    TARGET_URL="$PREV_URL"
    TARGET_FILE="$PREV_FILE"
    TARGET_VER="$PREV_VER"
elif [ "$TARGET" = "latest" ]; then
    TARGET_URL="$LATEST_URL"
    TARGET_FILE="$LATEST_FILE"
    TARGET_VER="$LATEST_VER"
else
    # TARGET содержит конкретную версию, например 1.7
    TARGET_VER="$TARGET"
    TARGET_FILE=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases \
        | grep browser_download_url | grep "$TARGET_VER" | grep "$LOCAL_ARCH.zip" | cut -d '"' -f 4 | xargs basename)
    TARGET_URL="https://github.com/remittor/zapret-openwrt/releases/download/v$TARGET_VER/$TARGET_FILE"
fi

    [ "$USED_ARCH" = "нет пакета для вашей архитектуры" ] && {
        echo -e "${RED}Нет доступного пакета для вашей архитектуры: ${NC}$LOCAL_ARCH"
        echo -e ""
        read -p "Нажмите Enter для продолжения..." dummy
        return
    }

    if [ "$INSTALLED_VER" = "$TARGET_VER" ]; then
        echo -e "${BLUE}🔴 ${GREEN}Эта версия уже установлена !${NC}"
        echo -e ""
        read -p "Нажмите Enter для продолжения..." dummy
        return
    fi

    if [ -f /etc/init.d/zapret ]; then
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
        PIDS=$(pgrep -f /opt/zapret)
        if [ -n "$PIDS" ]; then
            echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}zapret"
            for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
        fi
    fi

    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return
    echo -e "${GREEN}🔴 ${CYAN}Скачиваем архив ${NC}$TARGET_FILE"
    wget -q "$TARGET_URL" -O "$TARGET_FILE" || { echo -e "${RED}Не удалось скачать ${NC}$TARGET_FILE"; read -p "Нажмите Enter для продолжения..." dummy; return; }

    command -v unzip >/dev/null 2>&1 || { 
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем${NC} unzip ${CYAN}для распаковки архива${NC}"
        opkg update >/dev/null 2>&1
        opkg install unzip >/dev/null 2>&1
    }

    echo -e "${GREEN}🔴 ${CYAN}Распаковываем архив${NC}"
    unzip -o "$TARGET_FILE" >/dev/null

    PIDS=$(pgrep -f /opt/zapret)
    if [ -n "$PIDS" ]; then
        echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}zapret"
        for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
    fi

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
# Выбор и установка конкретной версии из списка релизов GitHub
# ==========================================
choose_version() {
    clear
    echo -e ""
    echo -e "${MAGENTA}Доступные версии Zapret (последние 10)${NC}"
    echo -e ""

    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    RELEASES=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases \
        | grep '"tag_name"' | grep -Eo '[0-9]+\.[0-9]+[0-9]*' | head -n 10)

    if [ -z "$RELEASES" ]; then
        echo -e "${RED}Не удалось получить список версий${NC}"
        read -p "Нажмите Enter для продолжения..." dummy
        return
    fi

    i=1
    echo "$RELEASES" | while read ver; do
        echo -e "${GREEN}$i) ${NC}$ver"
        i=$((i+1))
    done

    echo -e ""
    echo -n "Введите номер версии для установки (или Enter для выхода): "
    read num
    [ -z "$num" ] && return

    SELECTED=$(echo "$RELEASES" | sed -n "${num}p")
    [ -z "$SELECTED" ] && { echo -e "${RED}Неверный номер${NC}"; sleep 2; return; }

    echo -e ""
    echo -e "${CYAN}Вы выбрали версию: ${GREEN}$SELECTED${NC}"
    echo -e ""

    install_update "$SELECTED"
}

# ==========================================
# Полное удаление Zapret
# ==========================================
uninstall_zapret() {
    clear
    echo -e ""
    echo -e "${MAGENTA}Начинаем удаление ZAPRET${NC}"
    echo -e ""

    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
    }

    PIDS=$(pgrep -f /opt/zapret)
    if [ -n "$PIDS" ]; then
        echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}zapret"
        for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
    fi

    echo -e "${GREEN}🔴 ${CYAN}Удаляем пакеты${NC} zapret ${CYAN}и ${NC}luci-app-zapret"
    opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1

    echo -e "${GREEN}🔴 ${CYAN}Удаляем конфигурации и рабочие папки${NC}"
    for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do [ -e "$path" ] && rm -rf "$path"; done

    if crontab -l >/dev/null 2>&1; then
        crontab -l | grep -v -i "zapret" | crontab -
        echo -e "${GREEN}🔴 ${CYAN}Очищаем${NC} crontab ${CYAN}задания${NC}"
    fi

    echo -e "${GREEN}🔴 ${CYAN}Удаляем${NC} ipset"
    for set in $(ipset list -n 2>/dev/null | grep -i zapret); do ipset destroy "$set" >/dev/null 2>&1; done

    echo -e "${GREEN}🔴 ${CYAN}Удаляем временные файлы${NC}"
    rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null

    echo -e "${GREEN}🔴 ${CYAN}Удаляем цепочки и таблицы${NC} nftables"
    for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
        chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
        for chain in $chains; do nft delete chain $table $chain >/dev/null 2>&1; done
    done

    echo -e ""
    echo -e "${BLUE}🔴 ${GREEN}Zapret полностью удалён!${NC}"
    echo -e ""
    read -p "Нажмите Enter для продолжения..." dummy
}

# ==========================================
# Главное меню
# ==========================================
show_menu() {
    clear
    get_versions
    echo -e "${MAGENTA}ZAPRET on remittor Manager by StressOzz${NC}"
    echo -e ""
    echo -e "Установленная версия: ${GREEN}$INSTALLED_VER${NC}"
    [ -n "$ZAPRET_STATUS" ] && echo -e "Статус сервиса: $ZAPRET_STATUS"
    echo -e "Последняя версия: ${GREEN}$LATEST_VER${NC}"
    echo -e "Предыдущая версия: ${GREEN}$PREV_VER${NC}"
    echo -e ""
    echo -e "${CYAN}1) Установить последнюю версию${NC}"
    echo -e "${CYAN}2) Установить предыдущую версию${NC}"
    echo -e "${CYAN}3) Установить конкретную версию${NC}"
    echo -e "${CYAN}4) Полностью удалить Zapret${NC}"
    echo -e "${CYAN}5) Выйти${NC}"
    echo -e ""
    echo -n "Выберите действие: "
    read choice

    case "$choice" in
        1) install_update "latest" ;;
        2) install_update "prev" ;;
        3) choose_version ;;
        4) uninstall_zapret ;;
        5) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}"; sleep 2 ;;
    esac
}

# ==========================================
# Основной цикл
# ==========================================
while true; do
    show_menu
done
