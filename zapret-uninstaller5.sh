#!/bin/sh
# ==========================================
#  ZAPRET SUPER CLEANER 3000
#  "The Matrix edition"
# ==========================================


clear

GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"
BOLD="\033[1m"

echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║            MATRIX ZAPRET TERMINATOR            ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${RESET}"

sleep 1
echo -e "${GREEN}>>> INITIATING SUPER CLEAN PROTOCOL...${RESET}"
sleep 1

# Удаляем процессы
echo -e "${GREEN}[PROC] Уничтожение процессов zapret...${RESET}"
pkill -9 nfqws >/dev/null 2>&1
pkill -9 tpws  >/dev/null 2>&1
sleep 0.5

# Удаляем ipset
echo -e "${GREEN}[IPSET] Стирание следов ipset zapret...${RESET}"
ipset destroy zapret-hosts  >/dev/null 2>&1
ipset destroy zapret-ip     >/dev/null 2>&1
sleep 0.5

# Удаляем cron
echo -e "${GREEN}[CRON] Удаление cron-заданий zapret...${RESET}"
crontab -l | grep -v "zapret" | crontab -
sleep 0.5

# Удаляем файлы и папки
echo -e "${GREEN}[FILES] Стирание конфигов и директорий...${RESET}"
rm -rf /opt/zapret /etc/config/zapret /etc/firewall.zapret /etc/init.d/zapret
sleep 0.5

echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║       ✅ ZAPRET УНИЧТОЖЕН БЕЗ СЛЕДА ✅        ║"
echo "║              ALL TRACE ERASED...               ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Эффект «Матрицы» в конце
for i in {1..20}; do
    echo -e "${GREEN}$(cat /dev/urandom | tr -dc '01' | head -c 60)${RESET}"
    sleep 0.05
done
