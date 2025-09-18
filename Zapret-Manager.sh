#!/bin/sh
# ==========================================
# Zapret on remittor Manager
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

# Рабочая директория для скачивания и распаковки
WORKDIR="/tmp/zapret-update"

# ==========================================
# Функция получения информации о версиях и архитектуре
# ==========================================
get_versions() {
    # Определяем текущую установленную версию Zapret
    INSTALLED_VER=$(opkg list-installed | grep '^zapret ' | awk '{print $3}')
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"

    # Определяем архитектуру роутера
    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    # Если не удалось, берём из opkg, исключая noarch
    [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH=$(opkg print-architecture | grep -v "noarch" | sort -k3 -n | tail -n1 | awk '{print $2}')

    # Получаем ссылку на последнюю версию для этой архитектуры с GitHub
    LATEST_URL=$(curl -s https://api.github.com/repos/remittor/zapret-openwrt/releases/latest \
        | grep browser_download_url | grep "$LOCAL_ARCH.zip" | cut -d '"' -f 4)

    # Проверяем, есть ли такой пакет
    if [ -n "$LATEST_URL" ] && echo "$LATEST_URL" | grep -q '\.zip$'; then
        LATEST_FILE=$(basename "$LATEST_URL")
        # Из имени файла определяем версию
        LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+\.[0-9]+)_.*\.zip/\1/')
        USED_ARCH="$LOCAL_ARCH"
    else
        # Если пакета нет, отмечаем это
        LATEST_VER="не найдена"
        USED_ARCH="нет пакета для вашей архитектуры"
    fi
}

# ==========================================
# Главное меню
# ==========================================
show_menu() {
    get_versions
    clear
    echo -e ""
    echo -e "${MAGENTA}ZAPRET on remittor Manager${GREEN}${NC}"

    # Цвет установленной версии (зелёный = актуальна, красный = не актуальна)
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

# ==========================================
# Установка или обновление
# ==========================================
install_update() {
    clear
    echo -e ""
    echo -e "${MAGENTA}Начинаем установку ZAPRET${NC}"
    echo -e ""
    get_versions

    # Если пакет для архитектуры отсутствует
    [ "$USED_ARCH" = "нет пакета для вашей архитектуры" ] && {
        echo -e "${RED}[ERROR] Нет доступного пакета для вашей архитектуры: $LOCAL_ARCH${NC}"
        echo -e ""
        read -p "Нажмите Enter для продолжения..." dummy
        show_menu
        return
    }

    # Если версия уже актуальна
    if [ "$INSTALLED_VER" = "$LATEST_VER" ]; then
        echo -e "${BLUE}🔴 ${GREEN}Установлена самая свежая версия !${NC}"
        echo -e ""
        read -p "Нажмите Enter для продолжения..." dummy
        show_menu
        return
    fi

    # Устанавливаем unzip, если не установлен
    command -v unzip >/dev/null 2>&1 || { 
        echo -e "${GREEN}🔴 ${CYAN}Устанавливаем${NC} unzip ${CYAN}для распаковки${NC}"
        opkg update >/dev/null 2>&1
        opkg install unzip >/dev/null 2>&1
    }

    # Создаём рабочую директорию
    mkdir -p "$WORKDIR" && cd "$WORKDIR" || return

    echo -e "${GREEN}🔴 ${CYAN}Скачиваем архив ${NC}$LATEST_FILE"
    wget -q "$LATEST_URL" -O "$LATEST_FILE"

    echo -e "${GREEN}🔴 ${CYAN}Распаковываем архив${NC}"
    unzip -o "$LATEST_FILE" >/dev/null

    # Устанавливаем все ipk пакеты (zapret и luci)
    for PKG in zapret_*.ipk luci-app-zapret_*.ipk; do
        [ -f "$PKG" ] && {
            echo -e "${GREEN}🔴 ${CYAN}Устанавливаем пакет ${NC}$PKG${NC}"
            opkg install --force-reinstall "$PKG" >/dev/null 2>&1
        }
    done

    # Удаляем временные файлы
    echo -e "${GREEN}🔴 ${CYAN}Удаляем временные файлы и пакеты${NC}"
    cd /
    rm -rf "$WORKDIR"
    rm -f /tmp/*.ipk /tmp/*.zip /tmp/*zapret* 2>/dev/null

    # Перезапускаем сервис zapret
    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Перезапуск службы ${NC}zapret"
        /etc/init.d/zapret restart >/dev/null 2>&1
    }

    echo -e ""
    echo -e "${BLUE}🔴 ${GREEN}Zapret установлен/обновлен !${NC}"
    echo -e ""
    read -p "Нажмите Enter для продолжения..." dummy
    show_menu
}

# ==========================================
# Полное удаление Zapret
# ==========================================
uninstall_zapret() {
    clear
    echo -e ""
    echo -e "${MAGENTA}Начинаем удаление ZAPRET${NC}"
    echo -e ""

    # Остановка сервиса
    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Останавливаем сервис ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
    }

    # Убийство оставшихся процессов
    echo -e "${GREEN}🔴 ${CYAN}Убиваем все процессы ${NC}zapret"
    for pid in $(ps | grep -i /opt/zapret | grep -v grep | awk '{print $1}'); do
        kill -9 $pid >/dev/null 2>&1
    done

    # Удаляем пакеты zapret
    echo -e "${GREEN}🔴 ${CYAN}Удаляем пакеты${NC} zapret ${CYAN}и ${NC}luci-app-zapret${NC}"
    opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1

    # Удаляем конфиги и рабочие папки
    echo -e "${GREEN}🔴 ${CYAN}Удаляем конфигурации и рабочие папки${NC}"
    for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do [ -e "$path" ] && rm -rf "$path"; done

    # Очистка crontab
    echo -e "${GREEN}🔴 ${CYAN}Очищаем${NC} crontab ${CYAN}задания${NC}"
    crontab -l | grep -v -i "zapret" | crontab - 2>/dev/null || true

    # Удаляем ipset
    echo -e "${GREEN}🔴 ${CYAN}Удаляем${NC} ipset"
    for set in $(ipset list -n 2>/dev/null | grep -i zapret); do ipset destroy "$set" >/dev/null 2>&1; done

    # Удаляем временные файлы
    echo -e "${GREEN}🔴 ${CYAN}Удаляем временные файлы${NC}"
    rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null

    # Удаляем цепочки и таблицы nftables
    echo -e "${GREEN}🔴 ${CYAN}Удаляем цепочки и таблицы${NC} nftables"
    for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
        chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
        for chain in $chains; do nft delete chain $table $chain >/dev/null 2>&1; done
    done
    for table in $(nft list tables 2>/dev/null | awk '{print $2}' | grep -i zapret); do nft delete table $table >/dev/null 2>&1; done

    # Удаляем init-скрипт
    [ -f /etc/init.d/zapret ] && {
        echo -e "${GREEN}🔴 ${CYAN}Отключаем и удаляем${NC} init-скрипт"
        /etc/init.d/zapret disable >/dev/null 2>&1
        rm -f /etc/init.d/zapret
    }

    # Удаляем hook скрипты
    echo -e "${GREEN}🔴 ${CYAN}Удаляем${NC} hook ${CYAN}скрипты${NC}"
    HOOK_DIR="/etc/hotplug.d/iface"
    [ -d "$HOOK_DIR" ] && for f in "$HOOK_DIR"/*zapret*; do [ -f "$f" ] && rm -f "$f"; done

    # Удаляем оставшиеся файлы конфигурации
    echo -e "${GREEN}🔴 ${CYAN}Удаляем оставшиеся файлы конфигурации${NC}"
    EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
    for f in $EXTRA_FILES; do [ -e "$f" ] && rm -rf "$f"; done

    echo -e ""
    echo -e "${BLUE}🔴 ${GREEN}Zapret полностью удалён !${NC}"
    echo -e ""
    read -p "Нажмите Enter для продолжения..." dummy
    show_menu
}

# ==========================================
# Старт скрипта
# ==========================================
show_menu
