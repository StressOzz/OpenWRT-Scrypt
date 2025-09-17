#!/bin/sh
# ==========================================
# Финальный суперчистый удалитель zapret-openwrt
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
NC="\033[0m"
BOLD="\033[1m"

clear

echo -e "${GREEN}${BOLD}"
echo -e "╔════════════════════════════════════════╗"
echo -e "║  ${MAGENTA}Начинаем суперчистое удаление ZAPRET${GREEN}  ║"
echo -e "╚════════════════════════════════════════╝"
echo -e "${NC}"

# 1. Удаление пакетов
opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1

# 2. Убиваем процессы
for pid in $(ps | grep -i /opt/zapret | grep -v grep | awk '{print $1}'); do
    kill -9 $pid >/dev/null 2>&1
done

# 3. Удаление папок и конфигов
for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do
    [ -e "$path" ] && rm -rf "$path"
done

# 4. Очистка cron
crontab -l | grep -v -i "zapret" | crontab - 2>/dev/null || true

# 5. Очистка ipset и hostlist
for set in $(ipset list -n 2>/dev/null | grep -i zapret); do
    ipset destroy "$set" >/dev/null 2>&1
done
rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null

# 6. Очистка nftables цепочек и таблиц
for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
    chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
    for chain in $chains; do
        nft delete chain $table $chain >/dev/null 2>&1
    done
done
for table in $(nft list tables 2>/dev/null | awk '{print $2}' | grep -i zapret); do
    nft delete table $table >/dev/null 2>&1
done

# 7. Init-скрипт и hotplug
[ -f /etc/init.d/zapret ] && /etc/init.d/zapret disable >/dev/null 2>&1 && rm -f /etc/init.d/zapret
HOOK_DIR="/etc/hotplug.d/iface"
if [ -d "$HOOK_DIR" ]; then
    for f in "$HOOK_DIR"/*zapret*; do
        [ -f "$f" ] && rm -f "$f"
    done
fi

# 8. Остатки
EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
for f in $EXTRA_FILES; do
    [ -e "$f" ] && rm -rf "$f"
done

# =======================
# Финальный чек (цветной)
# =======================

echo -e "${YELLOW}Пакеты:${NC}"
for pkg in zapret luci-app-zapret; do
    if opkg list-installed | grep -q "^$pkg"; then
        echo -e "${CYAN}$pkg ${RED}установлен!${NC}"
    else
        echo -e "${CYAN}$pkg ${RED}удалён${NC}"
    fi
done

echo -e "${YELLOW}Процессы zapret:${NC}"
ps | grep -i /opt/zapret | grep -v grep \
  && echo -e "${RED}Найдены процессы!${NC}" \
  || echo -e "${CYAN}Не найдено${NC}"

echo -e "${YELLOW}IpSet zapret:${NC}"
ipset list -n 2>/dev/null | grep -i zapret \
  && echo -e "${RED}IpSet найден!${NC}" \
  || echo -e "${CYAN}Не найдено${NC}"

echo -e "${YELLOW}Cron-задания zapret:${NC}"
crontab -l | grep -i zapret \
  && echo -e "${RED}Есть записи в cron!${NC}" \
  || echo -e "${CYAN}Не найдено${NC}"

echo -e "${YELLOW}Папки и конфиги:${NC}"
for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret /etc/init.d/zapret /opt/zapret/ipset; do
    if [ -e "$path" ]; then
        echo -e "${CYAN}$path ${RED}ещё существует!${NC}"
    else
        echo -e "${CYAN}$path ${RED}удалён${NC}"
    fi
done

echo -e "${GREEN}${BOLD}"
echo -e "╔════════════════════════════════════════╗"
echo -e "║   ${MAGENTA}Удаление ZAPRET успешно завершено!${GREEN}   ║"
echo -e "╚════════════════════════════════════════╝"
echo -e "${NC}"
