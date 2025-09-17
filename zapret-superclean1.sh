#!/bin/sh
# ==========================================
# Финальный суперчистый удалитель zapret-openwrt
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${CYAN}=== Начинаем суперчистое удаление zapret ===${NC}"

# -----------------------
# 1. Удаление пакетов через opkg с форсом
# -----------------------
echo -e "${GREEN}Удаляем пакеты zapret и luci-app-zapret...${NC}"
opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret 2>/dev/null || echo -e "${YELLOW}Пакеты уже удалены или не найдены${NC}"

# -----------------------
# 2. Убиваем все процессы zapret
# -----------------------
echo -e "${GREEN}Останавливаем процессы zapret...${NC}"
for pid in $(ps | grep -i /opt/zapret | grep -v grep | awk '{print $1}'); do
    echo -e "${GREEN}Убиваем процесс PID: $pid${NC}"
    kill -9 $pid
done

# -----------------------
# 3. Удаление папок и конфигов
# -----------------------
for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret; do
    [ -e "$path" ] && echo -e "${GREEN}Удаляем $path${NC}" && rm -rf "$path"
done

# -----------------------
# 4. Очистка cron-заданий
# -----------------------
echo -e "${GREEN}Удаляем cron-задания zapret...${NC}"
crontab -l | grep -v -i "zapret" | crontab - 2>/dev/null || true

# -----------------------
# 5. Очистка ipset и временных hostlist файлов
# -----------------------
echo -e "${GREEN}Удаляем ipset и hostlist zapret...${NC}"
for set in $(ipset list -n 2>/dev/null | grep -i zapret); do
    ipset destroy "$set" 2>/dev/null
done
rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null

# -----------------------
# 6. Очистка nftables цепочек
# -----------------------
echo -e "${GREEN}Удаляем цепочки nftables zapret...${NC}"
for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
    chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
    for chain in $chains; do
        nft delete chain $table $chain 2>/dev/null
    done
done

# -----------------------
# 7. Удаление init-скрипта и hotplug hook’ов
# -----------------------
if [ -f /etc/init.d/zapret ]; then
    echo -e "${GREEN}Отключаем и удаляем init-скрипт${NC}"
    /etc/init.d/zapret disable 2>/dev/null
    rm -f /etc/init.d/zapret
fi

HOOK_DIR="/etc/hotplug.d/iface"
if [ -d "$HOOK_DIR" ]; then
    for f in "$HOOK_DIR"/*zapret*; do
        [ -f "$f" ] && echo -e "${GREEN}Удаляем hook $f${NC}" && rm -f "$f"
    done
fi

# -----------------------
# 8. Удаление оставшихся файлов из оригинального скрипта
# -----------------------
# Любые config и ipset файлы, которые могли остаться
EXTRA_FILES="/opt/zapret/config /opt/zapret/config.default /opt/zapret/ipset"
for f in $EXTRA_FILES; do
    [ -e "$f" ] && echo -e "${GREEN}Удаляем остаточный файл/папку: $f${NC}" && rm -rf "$f"
done

# -----------------------
# 9. Финальный чек
# -----------------------
echo -e "${CYAN}=== Финальный чек ===${NC}"

echo -e "${YELLOW}Процессы zapret:${NC}"
ps | grep -i /opt/zapret | grep -v grep || echo -e "${GREEN}Не найдено${NC}"

echo -e "${YELLOW}IpSet zapret:${NC}"
ipset list -n 2>/dev/null | grep -i zapret || echo -e "${GREEN}Не найдено${NC}"

echo -e "${YELLOW}Cron-задания zapret:${NC}"
crontab -l | grep -i zapret || echo -e "${GREEN}Не найдено${NC}"

echo -e "${YELLOW}Папки и конфиги:${NC}"
for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret /etc/init.d/zapret; do
    [ ! -e "$path" ] && echo -e "${GREEN}$path удален${NC}"
done

echo -e "${CYAN}=== Удаление zapret завершено успешно! ===${NC}"
