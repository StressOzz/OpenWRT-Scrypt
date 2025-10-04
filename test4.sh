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
    # Проверяем, установлена ли пакетом zapret и сохраняем версию
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"

    # Определяем архитектуру устройства
    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    # Проверяем, установлен ли curl, иначе ставим его для загрузки с GitHub
    command -v curl >/dev/null 2>&1 || {
        clear
        echo -e ""
        echo -e "${MAGENTA}ZAPRET on remittor Manager by StressOzz${NC}"
        echo -e ""
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем${NC} curl ${CYAN}для загрузки информации с ${NC}GitHub"
        opkg update >/dev/null 2>&1
        opkg install curl >/dev/null 2>&1
    }

    # Получаем ссылки на последнюю и предыдущую версии пакета для текущей архитектуры
    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$LOCAL_ARCH.zip" | cut -d '"' -f 4)
    PREV_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases \
        | grep browser_download_url | grep "$LOCAL_ARCH.zip" | sed -n '2p' | cut -d '"' -f 4)

    # Определяем имя файлов и версии из ссылок
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

    # Проверяем статус службы zapret (запущен/остановлен)
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

    # Получаем версии, архитектуру и статус
    get_versions

    # Определяем, что за версия пришла
    TARGET="$1"
    case "$TARGET" in
        latest)
            TARGET_URL="$LATEST_URL"
            TARGET_FILE="$LATEST_FILE"
            TARGET_VER="$LATEST_VER"
            ACTION="install"
            ;;
        prev)
            TARGET_URL="$PREV_URL"
            TARGET_FILE="$PREV_FILE"
            TARGET_VER="$PREV_VER"
            ACTION="install"
            ;;
        *)
            # TARGET - конкретная версия, например "1.7"
            TARGET_VER="$TARGET"
            ACTION="install"
            # Ищем URL для выбранной версии
            TARGET_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases \
                | grep browser_download_url | grep "zapret_v$TARGET_VER" | grep "$LOCAL_ARCH.zip" | cut -d '"' -f 4)
            if [ -z "$TARGET_URL" ]; then
                echo -e "${RED}Не найден пакет для версии $TARGET_VER и архитектуры $LOCAL_ARCH${NC}"
                read -p "Нажмите Enter для продолжения..." dummy
                return
            fi
            TARGET_FILE=$(basename "$TARGET_URL")
            ;;
    esac

    # Проверка архитектуры
    [ "$USED_ARCH" = "нет пакета для вашей архитектуры" ] && {
        echo -e "${RED}Нет доступного пакета для вашей архитектуры: ${NC}$LOCAL_ARCH"
        read -p "Нажмите Enter для продолжения..." dummy
        return
    }

    # Если версия уже установлена, выходим
    if [ "$INSTALLED_VER" = "$TARGET_VER" ]; then
        echo -e "${BLUE}🔴 ${GREEN}Эта версия уже установлена !${NC}"
        read -p "Нажмите Enter для продолжения..." dummy
        return
    fi

    # Остановка службы
    if [ -f /etc/init.d/zapret ]; then
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
        PIDS=$(pgrep -f /opt/zapret)
        [ -n "$PIDS" ] && for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
    fi

    # Создаем рабочую папку и скачиваем архив
    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return
    echo -e "${GREEN}🔴 ${CYAN}Скачиваем архив ${NC}$TARGET_FILE"
    wget -q "$TARGET_URL" -O "$TARGET_FILE" || { echo -e "${RED}Не удалось скачать ${NC}$TARGET_FILE"; read -p "Enter..." dummy; return; }

    # Проверка unzip
    command -v unzip >/dev/null 2>&1 || { 
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем${NC} unzip"
        opkg update >/dev/null 2>&1
        opkg install unzip >/dev/null 2>&1
    }

    # Распаковка архива
    echo -e "${GREEN}🔴 ${CYAN}Распаковываем архив${NC}"
    unzip -o "$TARGET_FILE" >/dev/null

    # Установка пакетов из архива
    for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
        [ -f "$PKG" ] && {
            echo -e "${GREEN}🔴 ${CYAN}Устанавливаем пакет ${NC}$PKG"
            opkg install --force-reinstall "$PKG" >/dev/null 2>&1
        }
    done

    # Очистка временных файлов
    cd /
    rm -rf "$WORKDIR" /tmp/*.ipk /tmp/*.zip /tmp/*zapret* 2>/dev/null

    # Перезапуск службы
    [ -f /etc/init.d/zapret ] && {
        chmod +x /opt/zapret/sync_config.sh
        /opt/zapret/sync_config.sh
        /etc/init.d/zapret restart >/dev/null 2>&1
    }

    # Сообщение
    echo -e ""
    echo -e "${BLUE}🔴 ${GREEN}Zapret версия $TARGET_VER успешно установлена!${NC}"
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

    # Определяем архитектуру
    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    # Получаем последние версии
    RELEASES=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases \
        | grep '"tag_name"' | grep -Eo '[0-9]+\.[0-9]+[0-9]*' | head -n 10)

    if [ -z "$RELEASES" ]; then
        echo -e "${RED}Не удалось получить список версий${NC}"
        read -p "Нажмите Enter для продолжения..." dummy
        return
    fi

    # Выводим список с номерами
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

    # Вызываем функцию установки/обновления с выбранной версией
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

    # Остановка службы
    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
    }

    # Убийство оставшихся процессов
    PIDS=$(pgrep -f /opt/zapret)
    if [ -n "$PIDS" ]; then
        echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}zapret"
        for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
    fi

    # Удаление пакетов
    echo -e "${GREEN}🔴 ${CYAN}Удаляем пакеты${NC} zapret ${CYAN}и ${NC}luci-app-zapret"
    opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1

    # Удаление конфигураций и рабочих папок
    echo -e "${GREEN}🔴 ${CYAN}Удаляем конфигурации и рабочие папки${NC}"
    for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do [ -e "$path" ] && rm -rf "$path"; done

    # Очистка crontab от заданий zapret
    if crontab -l >/dev/null 2>&1; then
        crontab -l | grep -v -i "zapret" | crontab -
        echo -e "${GREEN}🔴 ${CYAN}Очищаем${NC} crontab ${CYAN}задания${NC}"
    fi

    # Удаление ipset
    echo -e "${GREEN}🔴 ${CYAN}Удаляем${NC} ipset"
    for set in $(ipset list -n 2>/dev/null | grep -i zapret); do ipset destroy "$set" >/dev/null 2>&1; done

    # Удаление временных файлов
    echo -e "${GREEN}🔴 ${CYAN}Удаляем временные файлы${NC}"
    rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null

    # Удаление цепочек и таблиц nftables
    echo -e "${GREEN}🔴 ${CYAN}Удаляем цепочки и таблицы${NC} nftables"
    for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
        chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
        for chain in $chains; do nft delete chain $table $chain >/dev/null 2>&1; done
    done
    for table in $(nft list tables 2>/dev/null | awk '{print $2}' | grep -i zapret); do nft delete table $table >/dev/null 2>&1; done

    # Удаление init-скрипта
    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Отключаем и удаляем${NC} init-скрипт"
        /etc/init.d/zapret disable >/dev/null 2>&1
        rm -f /etc/init.d/zapret
    }

    # Удаление hook-скриптов
    echo -e "${GREEN}🔴 ${CYAN}Удаляем${NC} hook ${CYAN}скрипты${NC}"
    HOOK_DIR="/etc/hotplug.d/iface"
    [ -d "$HOOK_DIR" ] && for f in "$HOOK_DIR"/*zapret*; do [ -f "$f" ] && rm -f "$f"; done

    # Удаление оставшихся файлов конфигурации
    echo -e "${GREEN}🔴 ${CYAN}Удаляем оставшиеся файлы конфигурации${NC}"
    EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
    for f in $EXTRA_FILES; do [ -e "$f" ] && rm -rf "$f"; done

    echo -e ""
    echo -e "${BLUE}🔴 ${GREEN}Zapret полностью удалён !${NC}"
    echo -e ""
    read -p "Нажмите Enter для продолжения..." dummy
}

# ==========================================
# Главное меню
# ==========================================
show_menu() {
    get_versions  # Получаем версии, архитектуру и статус службы
    clear
    echo -e ""
    # Выводим баннер скрипта
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

    # Определяем цвет для отображения версии (актуальная/устарела)
    [ "$INSTALLED_VER" = "$LATEST_VER" ] && INST_COLOR=$GREEN || INST_COLOR=$RED

    # Настройка текста для меню в зависимости от версии
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

    # Вывод информации о версиях и архитектуре
    echo -e ""
    echo -e "${YELLOW}Установленная версия: ${INST_COLOR}$INSTALLED_DISPLAY${NC}"
    echo -e "${YELLOW}Последняя версия на GitHub: ${NC}$LATEST_VER"
    echo -e "${YELLOW}Предыдущая версия на GitHub: ${CYAN}$PREV_VER${NC}"
    echo -e ""
    echo -e "${YELLOW}Архитектура устройства: ${NC}$LOCAL_ARCH"
    echo -e ""

    # Выводим статус службы zapret, если он известен
    [ -n "$ZAPRET_STATUS" ] && echo -e "${YELLOW}Статус службы Zapret: ${NC}$ZAPRET_STATUS"
    echo -e ""

    # Вывод пунктов меню
    echo -e "${GREEN}1) $MENU1_TEXT${NC}"
    echo -e "${GREEN}2) Установить предыдущую версию${NC}"
    echo -e "${GREEN}3) Вернуть настройки по умолчанию${NC}"
    echo -e "${GREEN}4) Удалить Zapret${NC}"
    echo -e "${GREEN}5) Остановить Zapret${NC}"
    echo -e "${GREEN}6) Запустить Zapret${NC}"
    echo -e "${GREEN}7) Установить конкретную версию${NC}"
    echo -e "${GREEN}8) Выход (Enter)${NC}"
    echo -e ""
    echo -n "Выберите пункт: "
    read choice
    case "$choice" in
        1) install_update "latest" ;;  # Установка/обновление до последней версии
        2) install_update "prev" ;;    # Установка предыдущей версии
        3)
            clear
            echo -e ""
            echo -e "${MAGENTA}Возврат к настройкам по умолчанию${NC}"
            echo -e ""
            # Проверка скрипта восстановления и его запуск
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
            echo -e ""
            read -p "Нажмите Enter для продолжения..." dummy
            show_menu
            ;;
        4) uninstall_zapret ;;  # Полное удаление Zapret
        5)
            clear
            echo -e ""
            echo -e "${MAGENTA}Остановка Zapret${NC}"
            echo -e ""
            # Остановка службы через init.d и убийство процессов
            if [ -f /etc/init.d/zapret ]; then
                echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}Zapret"
                /etc/init.d/zapret stop >/dev/null 2>&1
                PIDS=$(pgrep -f /opt/zapret)
                if [ -n "$PIDS" ]; then
                    echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}Zapret"
                    for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1; done
                fi
                echo -e ""
                echo -e "${BLUE}🔴 ${GREEN}Zapret остановлен !${NC}"
            else
                echo -e "${RED}Zapret не установлен !${NC}"
            fi
            echo -e ""
            read -p "Нажмите Enter для продолжения..." dummy
            ;;
        6)
            clear
            echo -e ""
            echo -e "${MAGENTA}Запуск Zapret${NC}"
            echo -e ""
            # Запуск службы через init.d
            if [ -f /etc/init.d/zapret ]; then
                echo -e "${GREEN}🔴 ${CYAN}Запускаем сервис ${NC}Zapret"
                /etc/init.d/zapret start >/dev/null 2>&1
                echo -e ""
                echo -e "${BLUE}🔴 ${GREEN}Zapret запущен !${NC}"
            else
                echo -e "${RED}Zapret не установлен !${NC}"
            fi
            echo -e ""
            read -p "Нажмите Enter для продолжения..." dummy
            ;;
            
        7) choose_version ;;
            
        *) exit 0 ;;  # Выход по Enter или любой другой невалидной опции
    esac
}

# ==========================================
# Старт скрипта (цикл)
# ==========================================
while true; do
    show_menu  # Показываем главное меню бесконечно
done
