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

# Рабочая директория для скачивания и распаковки
WORKDIR="/tmp/zapret-update"

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

    # --- Новый блок: проверка статуса Zapret ---
    if [ -f /etc/init.d/zapret ]; then
        if /etc/init.d/zapret status 2>/dev/null | grep -qi "running"; then
            ZAPRET_STATUS="${GREEN}запущен${NC}"
        else
            ZAPRET_STATUS="${RED}остановлен${NC}"
        fi
    else
        ZAPRET_STATUS=""   # <-- если не установлен – пустая строка
    fi
}

# ==========================================
# Установка или обновление
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

    # --- Новый блок: Остановка сервиса до скачивания ---
    if [ -f /etc/init.d/zapret ]; then
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret ${CYAN}перед ${NC}скачиванием"
        /etc/init.d/zapret stop >/dev/null 2>&1
        PIDS=$(pgrep -f /opt/zapret)
        if [ -n "$PIDS" ]; then
            echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}zapret"
            for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
        fi
    fi
    # --- конец нового блока ---

    TARGET="$1"
    if [ "$TARGET" = "prev" ]; then
        TARGET_URL="$PREV_URL"
        TARGET_FILE="$PREV_FILE"
        TARGET_VER="$PREV_VER"
    else
        TARGET_URL="$LATEST_URL"
        TARGET_FILE="$LATEST_FILE"
        TARGET_VER="$LATEST_VER"
    fi
    [ "$USED_ARCH" = "нет пакета для вашей архитектуры" ] && {
        echo -e "${RED}[ERROR] Нет доступного пакета для вашей архитектуры: $LOCAL_ARCH${NC}"
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
    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return
    echo -e "${GREEN}🔴 ${CYAN}Скачиваем архив ${NC}$TARGET_FILE"
    wget -q "$TARGET_URL" -O "$TARGET_FILE" || { echo -e "${RED}[ERROR] Не удалось скачать $TARGET_FILE${NC}"; read -p "Нажмите Enter для продолжения..." dummy; return; }
    command -v unzip >/dev/null 2>&1 || { 
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем${NC} unzip ${CYAN}для распаковки архива${NC}"
        opkg update >/dev/null 2>&1
        opkg install unzip >/dev/null 2>&1
    }
    echo -e "${GREEN}🔴 ${CYAN}Распаковываем архив${NC}"
    unzip -o "$TARGET_FILE" >/dev/null
    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
    }
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
# Главное меню
# ==========================================
show_menu() {
    get_versions
    clear
    echo -e ""
    echo -e "███████╗ █████╗ ██████╗ ██████╗ ███████╗████████╗"
    echo -e "╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
    echo -e "  ███╔╝ ███████║██████╔╝██████╔╝█████╗     ██║   "
    echo -e " ███╔╝  ██╔══██║██╔═══╝ ██╔══██╗██╔══╝     ██║   "
    echo -e "███████╗██║  ██║██║     ██║  ██║███████╗   ██║   "
    echo -e "╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝   "
    echo -e "              ${MAGENTA}on remittor Manager by StressOzz${NC}"
    echo -e "                                          ${DGRAY}v1.6${NC}"
    echo -e "${GRAY}https://github.com/bol-van/zapret${NC}"
    echo -e "${GRAY}https://github.com/remittor/zapret-openwrt${NC}"

    [ "$INSTALLED_VER" = "$LATEST_VER" ] && INST_COLOR=$GREEN || INST_COLOR=$RED

    if [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
        INSTALLED_DISPLAY="$INSTALLED_VER (актуальная)"
        MENU1_TEXT="Установить последнюю версию"
    elif [ "$INSTALLED_VER" != "не найдена" ]; then
        INSTALLED_DISPLAY="$INSTALLED_VER (устарела)"
        MENU1_TEXT="Обновить до последней версии"
    else
        INSTALLED_DISPLAY="$INSTALLED_VER"
        MENU1_TEXT="Установить последнюю версию"
    fi

    echo -e ""
    echo -e "${YELLOW}Установленная версия: ${INST_COLOR}$INSTALLED_DISPLAY${NC}"
    echo -e "${YELLOW}Последняя версия на GitHub: ${NC}$LATEST_VER"
    echo -e "${YELLOW}Предыдущая версия на GitHub: ${CYAN}$PREV_VER${NC}"
    echo -e ""
    echo -e "${YELLOW}Архитектура устройства: ${NC}$LOCAL_ARCH"
    echo -e ""

    # --- Выводим статус только если не пуст ---
    [ -n "$ZAPRET_STATUS" ] && echo -e "${YELLOW}Статус службы Zapret: ${NC}$ZAPRET_STATUS"
    echo -e ""

    echo -e "${GREEN}1) $MENU1_TEXT${NC}"
    echo -e "${GREEN}2) Установить предыдущую версию${NC}"
    echo -e "${GREEN}3) Вернуть настройки по умолчанию${NC}"
    echo -e "${GREEN}4) Удалить Zapret${NC}"
    echo -e "${GREEN}5) Остановить Zapret${NC}"
    echo -e "${GREEN}6) Запустить Zapret${NC}"
    echo -e "${GREEN}7) Выход (Enter)${NC}"
    echo -e ""
    echo -n "Выберите пункт: "
    read choice
    case "$choice" in
        1) install_update "latest" ;;
        2) install_update "prev" ;;
        3)
            clear
            echo -e ""
            echo -e "${MAGENTA}Возврат к настройкам по умолчанию${NC}"
            echo -e ""
            if [ -f /opt/zapret/restore-def-cfg.sh ]; then
                [ -f /etc/init.d/zapret ] && /etc/init.d/zapret stop >/dev/null 2>&1
                chmod +x /opt/zapret/restore-def-cfg.sh
                /opt/zapret/restore-def-cfg.sh
                chmod +x /opt/zapret/sync_config.sh
                /opt/zapret/sync_config.sh
                [ -f /etc/init.d/zapret ] && /etc/init.d/zapret restart >/dev/null 2>&1
                echo -e "${BLUE}🔴 ${GREEN}Настройки возвращены, сервис перезапущен !${NC}"
            else
                echo -e "${GREEN}🔴 ${RED}Zapret не установлен !${NC}"
            fi
            echo -e ""
            read -p "Нажмите Enter для продолжения..." dummy
            show_menu
            ;;
        4) uninstall_zapret ;;
        5)
            clear
            echo -e ""
            echo -e "${MAGENTA}Остановка Zapret${NC}"
            echo -e ""
            [ -f /etc/init.d/zapret ] && {
                echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}Zapret"
                /etc/init.d/zapret stop >/dev/null 2>&1
            }
            PIDS=$(pgrep -f /opt/zapret)
            if [ -n "$PIDS" ]; then
                echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}Zapret"
                for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
            fi
            echo -e ""
            echo -e "${BLUE}🔴 ${GREEN}Zapret остановлен !${NC}"
            echo -e ""
            read -p "Нажмите Enter для продолжения..." dummy
            ;;
        6)
            clear
            echo -e ""
            echo -e "${MAGENTA}Запуск Zapret${NC}"
            echo -e ""
            [ -f /etc/init.d/zapret ] && {
                echo -e "${GREEN}🔴 ${CYAN}Запускаем сервис ${NC}Zapret"
                /etc/init.d/zapret start >/dev/null 2>&1
                echo -e ""
                echo -e "${BLUE}🔴 ${GREEN}Zapret запущен !${NC}"
            } || echo -e "${RED}Zapret не установлен${NC}"
            echo -e ""
            read -p "Нажмите Enter для продолжения..." dummy
            ;;
        *) exit 0 ;;
    esac
}

# ==========================================
# Старт скрипта (цикл)
# ==========================================
while true; do
    show_menu
done
