#!/bin/sh
# ==========================================
#  IPv6 TOGGLE MENU SCRIPT for OpenWRT 24+
#  Автоопределение LAN-интерфейса
# ==========================================

# Цвета
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

clear

# --- Автоопределяем LAN-интерфейс ---
LAN_IF=$(uci get network.lan.ifname 2>/dev/null)
if [ -z "$LAN_IF" ]; then
    # Если uci не вернул значение, пробуем стандартный br-lan
    LAN_IF="br-lan"
fi

# Проверяем текущее состояние IPv6 (глобальный адрес на LAN)
echo -e "${CYAN}[INFO]${RESET} Проверяем текущее состояние IPv6 на интерфейсе ${LAN_IF}..."
if ip -6 addr show dev "$LAN_IF" 2>/dev/null | grep -q "scope global"; then
    IPV6_STATE="enabled"
    echo -e "${GREEN}[INFO]${RESET} IPv6 ${GREEN}включён.${RESET}"
else
    IPV6_STATE="disabled"
    echo -e "${RED}[INFO]${RESET} IPv6 ${RED}отключён.${RESET}"
fi

# --- Меню ---
echo -e "${MAGENTA}╔══════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}║${CYAN}     Управление IPv6 (OpenWRT)    ${MAGENTA}║${RESET}"
echo -e "${MAGENTA}╠══════════════════════════════════╣${RESET}"
echo -e "${MAGENTA}║${GREEN} 1) Включить IPv6                 ${MAGENTA}║${RESET}"
echo -e "${MAGENTA}║${RED} 2) Выключить IPv6                ${MAGENTA}║${RESET}"
echo -e "${MAGENTA}║${YELLOW} 0) Отмена                        ${MAGENTA}║${RESET}"
echo -e "${MAGENTA}╚══════════════════════════════════╝${RESET}"
echo -n -e "${YELLOW}Выберите опцию [0-2]: ${RESET}"
read -r CHOICE

case "$CHOICE" in
    1)
        if [ "$IPV6_STATE" = "enabled" ]; then
            echo -e "${YELLOW}[WARN]${RESET} IPv6 уже включён."
        else
            echo -e "${CYAN}[INFO]${RESET} Включаем IPv6..."

            # --- Network ---
            echo -e "${YELLOW}[*]${RESET} LAN/WAN IPv6 включаем"
            uci set network.lan.ipv6='1'
            uci set network.wan.ipv6='1'
            uci set network.lan.delegate='1'

            # --- DHCP / RA ---
            echo -e "${YELLOW}[*]${RESET} Включаем DHCPv6 и RA"
            uci set dhcp.lan.dhcpv6='server'
            uci set dhcp.lan.ra='server'

            # --- DNS ---
            echo -e "${YELLOW}[*]${RESET} Включаем AAAA-записи (IPv6 DNS)"
            uci delete dhcp.@dnsmasq[0].filter_aaaa 2>/dev/null

            # --- Commit ---
            uci commit network >/dev/null 2>&1
            uci commit dhcp >/dev/null 2>&1

            # --- odhcpd ---
            echo -e "${YELLOW}[*]${RESET} Запускаем odhcpd"
            /etc/init.d/odhcpd enable
            /etc/init.d/odhcpd start

            # --- sysctl ---
            echo -e "${YELLOW}[*]${RESET} Разрешаем IPv6 на уровне ядра"
            sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
            sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
            sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf
            cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.lo.disable_ipv6=0
EOF
            sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
            sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
            sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1

            # --- Restart DNS ---
            /etc/init.d/dnsmasq restart >/dev/null 2>&1

            echo -e "${GREEN}[OK]${RESET} IPv6 включён!"
        fi
        ;;
    2)
        if [ "$IPV6_STATE" = "disabled" ]; then
            echo -e "${YELLOW}[WARN]${RESET} IPv6 уже отключён."
        else
            echo -e "${CYAN}[INFO]${RESET} Отключаем IPv6..."

            # --- Network ---
            echo -e "${YELLOW}[*]${RESET} LAN/WAN IPv6 отключаем"
            uci set network.lan.ipv6='0'
            uci set network.wan.ipv6='0'
            uci set network.lan.delegate='0'
            uci -q delete network.globals.ula_prefix

            # --- DHCP / RA ---
            echo -e "${YELLOW}[*]${RESET} Отключаем DHCPv6 и RA"
            uci set dhcp.lan.dhcpv6='disabled'
            uci set dhcp.lan.ra='disabled'
            uci -q delete dhcp.lan.dhcpv6
            uci -q delete dhcp.lan.ra

            # --- DNS ---
            echo -e "${YELLOW}[*]${RESET} Фильтруем AAAA-записи (IPv6 DNS)"
            uci set dhcp.@dnsmasq[0].filter_aaaa='1'

            # --- Commit ---
            uci commit network >/dev/null 2>&1
            uci commit dhcp >/dev/null 2>&1

            # --- odhcpd ---
            echo -e "${YELLOW}[*]${RESET} Останавливаем odhcpd"
            /etc/init.d/odhcpd stop >/dev/null 2>&1
            /etc/init.d/odhcpd disable >/dev/null 2>&1

            # --- sysctl ---
            echo -e "${YELLOW}[*]${RESET} Запрещаем IPv6 на уровне ядра"
            sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
            sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
            sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf
            cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
            sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
            sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
            sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1

            # --- Restart DNS ---
            /etc/init.d/dnsmasq restart >/dev/null 2>&1

            echo -e "${GREEN}[OK]${RESET} IPv6 отключён!"
        fi
        ;;
    0)
        echo -e "${CYAN}[INFO]${RESET} Действие отменено пользователем. Выход."
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${RESET} Некорректный выбор. Введите 0, 1 или 2."
        exit 1
        ;;
esac

# --- Проверка ---
echo -e "${YELLOW}[*]${RESET} Проверяем IPv6 на интерфейсе ${LAN_IF}:"
if ip -6 addr show dev "$LAN_IF" 2>/dev/null | grep -q "scope global"; then
    echo -e "${GREEN}[PASS]${RESET} IPv6 ${GREEN}включён.${RESET}"
else
    echo -e "${RED}[PASS]${RESET} IPv6 ${RED}отключён.${RESET}"
fi

echo -e "${CYAN}[INFO]${RESET} Скрипт завершён. Рекомендуется перезагрузка роутера."
