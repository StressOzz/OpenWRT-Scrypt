#!/bin/sh
# ==========================================
#  FULL IPv6 DISABLE SCRIPT for OpenWRT 24+
# ==========================================

# Цвета
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo -e "${CYAN}[INFO]${RESET} Отключаем IPv6 на OpenWRT..."

# --- Network ---
echo -e "${YELLOW}[*]${RESET} Чистим IPv6 из настроек сети"
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
uci commit network
uci commit dhcp

# --- odhcpd ---
echo -e "${YELLOW}[*]${RESET} Останавливаем и убираем odhcpd"
 /etc/init.d/odhcpd stop
 /etc/init.d/odhcpd disable

# --- sysctl ---
echo -e "${YELLOW}[*]${RESET} Вносим sysctl настройки (полный запрет IPv6)"
sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf

cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# --- Restart DNS ---
/etc/init.d/dnsmasq restart

echo -e "${GREEN}[OK]${RESET} Все настройки применены!"
echo -e "${YELLOW}[WARN]${RESET} Для полной гарантии — перезагрузите роутер."

# --- Проверка ---
echo -e "${CYAN}[CHECK]${RESET} Проверяем IPv6..."
if ip -6 addr show | grep -q "inet6"; then
    echo -e "${RED}[FAIL]${RESET} IPv6 адреса всё ещё присутствуют!"
else
    echo -e "${GREEN}[PASS]${RESET} IPv6 адресов нет."
fi

if ping6 -c 1 google.com >/dev/null 2>&1; then
    echo -e "${RED}[FAIL]${RESET} IPv6 пинги ещё отвечают!"
else
    echo -e "${GREEN}[PASS]${RESET} IPv6 пинги отключены."
fi

echo -e "${CYAN}[INFO]${RESET} Скрипт завершён."
