#!/bin/sh
# ==========================================
# Полное и безопасное удаление zapret-openwrt (доработанный вариант)
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${CYAN}=== Начинаем полное удаление zapret-openwrt ===${NC}"

# -----------------------
# 1. Удаление пакетов через opkg
# -----------------------
echo -e "${GREEN}Удаляем пакеты zapret и luci-app-zapret...${NC}"
opkg remove zapret luci-app-zapret || echo -e "${YELLOW}Пакеты уже удалены или не найдены${NC}"

# -----------------------
# 2. Остановка процессов zapret через ps/kill
# -----------------------
echo -e "${GREEN}Останавливаем процессы zapret...${NC}"
for pid in $(ps | grep -i /opt/zapret | grep -v grep | awk '{print $1}'); do
    echo -e "${GREEN}Убиваем процесс PID: $pid${NC}"
    kill -9 $pid
done

# -----------------------
# 3. Удаление папки /opt/zapret
# -----------------------
if [ -d "/opt/zapret" ]; then
    echo -e "${GREEN}Удаляем /opt/zapret...${NC}"
    rm -rf /opt/zapret
else
    echo -e "${YELLOW}/opt/zapret не найден${NC}"
fi

# -----------------------
# 4. Удаление конфигурационного файла /etc/config/zapret
# -----------------------
if [ -f "/etc/config/zapret" ]; then
    echo -e "${GREEN}Удаляем /etc/config/zapret...${NC}"
    rm -f /etc/config/zapret
else
    echo -e "${YELLOW}/etc/config/zapret не найден${NC}"
fi

# -----------------------
# 5. Очистка cron-заданий zapret
# -----------------------
echo -e "${GREEN}Удаляем cron-задания zapret...${NC}"
crontab -l | grep -v -i "zapret" | crontab - || echo -e "${YELLOW}Cron-задания не найдены${NC}"

# -----------------------
# 6. Очистка логов zapret
# -----------------------
if [ -d "/var/log/zapret" ]; then
    echo -e "${GREEN}Удаляем логи zapret...${NC}"
    rm -rf /var/log/zapret
fi

# -----------------------
# 7. Очистка ipset и hostlist zapret
# -----------------------
echo -e "${GREEN}Удаляем ipset и hostlist, связанные с zapret...${NC}"
for set in $(ipset list -n 2>/dev/null | grep -i zapret); do
    echo -e "${GREEN}Удаляем ipset: $set${NC}"
    ipset destroy "$set"
done
rm -f /tmp/*zapret* /var/run/*zapret*

# -----------------------
# 8. Удаление цепочек и таблиц nftables zapret (без ошибок)
# -----------------------
echo -e "${GREEN}Удаляем цепочки nftables, связанные с zapret...${NC}"
for table in $(nft list tables 2>/dev/null | awk '{print $2}'); do
    chains=$(nft list table $table 2>/dev/null | grep -i 'chain .*zapret' | awk '{print $2}')
    for chain in $chains; do
        echo -e "${GREEN}Удаляем цепочку $chain в таблице $table${NC}"
        nft delete chain $table $chain 2>/dev/null
    done
done

# -----------------------
# 9. Удаление OpenWRT firewall include
# -----------------------
FW_INCLUDE="/etc/firewall.zapret"
if [ -f "$FW_INCLUDE" ]; then
    echo -e "${GREEN}Удаляем include-файл firewall: $FW_INCLUDE${NC}"
    rm -f "$FW_INCLUDE"
fi

# -----------------------
# 10. Удаление init-скриптов и hook интерфейсов
# -----------------------
if [ -f "/etc/init.d/zapret" ]; then
    echo -e "${GREEN}Отключаем и удаляем init-скрипт /etc/init.d/zapret${NC}"
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
# 11. Финальный чек
# -----------------------
echo -e "${CYAN}=== Финальный чек: проверяем, что ничего Zapret не осталось ===${NC}"

echo -e "${YELLOW}Проверка процессов:${NC}"
ps | grep -i /opt/zapret | grep -v grep || echo -e "${GREEN}Процессов zapret не найдено${NC}"

echo -e "${YELLOW}Проверка ipset:${NC}"
ipset list -n 2>/dev/null | grep -i zapret || echo -e "${GREEN}IpSet zapret не найдено${NC}"

echo -e "${YELLOW}Проверка cron:${NC}"
crontab -l | grep -i zapret || echo -e "${GREEN}Cron-задания zapret отсутствуют${NC}"

echo -e "${YELLOW}Проверка папок и конфигов:${NC}"
[ ! -d /opt/zapret ] && echo -e "${GREEN}/opt/zapret удален${NC}"
[ ! -f /etc/config/zapret ] && echo -e "${GREEN}/etc/config/zapret удален${NC}"
[ ! -f /etc/firewall.zapret ] && echo -e "${GREEN}/etc/firewall.zapret удален${NC}"
[ ! -f /etc/init.d/zapret ] && echo -e "${GREEN}init-скрипт удален${NC}"

echo -e "${CYAN}=== Удаление zapret завершено успешно! ===${NC}"
