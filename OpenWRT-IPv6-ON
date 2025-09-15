#!/bin/sh
# ==========================================
#  RESTORE IPv6 SCRIPT for OpenWRT 24+
# ==========================================

# Цвета
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo -e "${CYAN}[INFO]${RESET} Включаем IPv6 обратно..."

# --- Network ---
echo -e "${YELLOW}[*]${RESET} Включаем IPv6 на LAN/WAN"
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
uci commit network
uci commit dhcp

# --- odhcpd ---
echo -e "${YELLOW}[*]${RESET} Запускаем odhcpd обратно"
/etc/init.d/odhcpd enable
/etc/init.d/odhcpd start

# --- sysctl ---
echo -e "${YELLOW}[*]${RESET} Чистим sysctl от запрета IPv6"
sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf

sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0
sysctl -w net.ipv6.conf.lo.disable_ipv6=0

# --- Restart DNS ---
/etc/init.d/dnsmasq restart

echo -e "${GREEN}[OK]${RESET} IPv6 снова включён!"
echo -e "${YELLOW}[WARN]${RESET} Рекомендуется перезагрузить роутер."

# --- Проверка ---
echo -e "${CYAN}[CHECK]${RESET} Проверяем IPv6..."
if ip -6 addr show | grep -q "inet6"; then
    echo -e "${GREEN}[PASS]${RESET} IPv6 адреса появились."
else
    echo -e "${RED}[FAIL]${RESET} IPv6 адресов нет, возможно провайдер не даёт IPv6."
fi

if ping6 -c 1 google.com >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${RESET} IPv6 пинги работают."
else
    echo -e "${RED}[FAIL]${RESET} IPv6 пинги не проходят (провайдер?)."
fi

echo -e "${CYAN}[INFO]${RESET} Скрипт завершён."
