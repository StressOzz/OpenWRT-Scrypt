#!/bin/sh
# ==========================================
# Zapret on remittor Manager — reviewed & improved
# (compatibility fixes, safer nft/ipset removal, robust arch matching,
#  better package discovery/install and safer cleanup)
# Tested for POSIX / OpenWrt ash environments (23.05+ / 24+)
# ==========================================

# minimal safety
if [ "$(id -u 2>/dev/null || echo 1)" != "0" ]; then
  echo "ERROR: please run as root"
  exit 1
fi

# Colors (keep simple, safe for BusyBox ash)
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
BLUE="\033[0;34m"
NC="\033[0m"

WORKDIR="/tmp/zapret-update-$$"
API_URL="https://api.github.com/repos/remittor/zapret-openwrt/releases/latest"

cleanup() {
  [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
}
trap cleanup EXIT INT TERM

ensure_cmd() {
  # ensure command exists, install opkg package if not (best-effort)
  cmd="$1"; pkg="$2"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo -e "${YELLOW}-> Устанавливаем пакет: $pkg${NC}"
    opkg update >/dev/null 2>&1 || true
    opkg install "$pkg" >/dev/null 2>&1 || {
      echo -e "${RED}ERROR: Не удалось установить $pkg — продолжим, но команда $cmd может отсутствовать${NC}"
    }
  }
}

get_local_arch() {
  LOCAL_ARCH=""
  # try /etc/openwrt_release first
  if [ -f /etc/openwrt_release ]; then
    LOCAL_ARCH=$(awk -F\' '/DISTRIB_ARCH/ {print $2; exit}' /etc/openwrt_release 2>/dev/null || true)
  fi
  # fallback to opkg print-architecture (pick highest priority non-all)
  if [ -z "$LOCAL_ARCH" ]; then
    ARCH_LINE=$(opkg print-architecture 2>/dev/null | awk '$1=="arch" && $2!="all" {print $2" "$3}' | sort -k2 -n | tail -n1)
    LOCAL_ARCH=$(echo "$ARCH_LINE" | awk '{print $1}' 2>/dev/null || true)
  fi
  [ -z "$LOCAL_ARCH" ] && LOCAL_ARCH="unknown"
  echo "$LOCAL_ARCH"
}

get_installed_version() {
  INSTALLED_VER=$(opkg list-installed 2>/dev/null | awk '/^zapret /{print $3; exit}') || INSTALLED_VER=""
  [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"
  echo "$INSTALLED_VER"
}

find_latest_asset() {
  local arch="$1"
  local assets urls match base
  assets=$(curl -s -H "Accept: application/vnd.github.v3+json" -H "User-Agent: zapret-manager" "$API_URL" | grep -i "browser_download_url" | cut -d '"' -f4)
  # 1) exact arch match (e.g. aarch64_cortex-a53)
  match=$(echo "$assets" | grep -i "${arch}\.zip" | head -n1 || true)
  if [ -n "$match" ]; then echo "$match"; return 0; fi

  # 2) try base arch (before underscore), e.g. aarch64
  base=$(echo "$arch" | cut -d'_' -f1)
  match=$(echo "$assets" | grep -i "${base}_" | head -n1 || true)
  if [ -n "$match" ]; then echo "$match"; return 0; fi

  # 3) try generic fallback
  match=$(echo "$assets" | grep -i "_generic\.zip" | head -n1 || true)
  if [ -n "$match" ]; then echo "$match"; return 0; fi

  # 4) as a last resort, return first zip asset
  match=$(echo "$assets" | grep -i "\.zip" | head -n1 || true)
  echo "$match"
}

show_menu() {
  LOCAL_ARCH=$(get_local_arch)
  INSTALLED_VER=$(get_installed_version)
  LATEST_URL="$(find_latest_asset "$LOCAL_ARCH")"
  if [ -n "$LATEST_URL" ]; then
    LATEST_FILE=$(basename "$LATEST_URL")
    LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+(\.[0-9]+)*).*/\1/')
  else
    LATEST_VER="не найдена"
    LATEST_FILE=""
  fi

  clear
  echo -e ""
  echo -e "${MAGENTA}ZAPRET on remittor Manager (reviewed)${NC}"
  echo -e ""
  echo -e "${YELLOW}Установленная версия: ${INSTALLED_VER}${NC}"
  echo -e "${YELLOW}Последняя версия на GitHub: ${CYAN}${LATEST_VER}${NC}"
  echo -e "${YELLOW}Архитектура устройства: ${CYAN}${LOCAL_ARCH}${NC}"
  echo -e ""
  echo -e "${GREEN}1) Установить или обновить${NC}"
  echo -e "${GREEN}2) Удалить${NC}"
  echo -e "${GREEN}3) Выход (Enter)${NC}"
  echo -n "Выберите пункт: "
  read choice
  case "$choice" in
    1) install_update ;;
    2) uninstall_zapret ;;
    *) exit 0 ;;
  esac
}

install_update() {
  echo -e "\n${MAGENTA}Начинаем установку/обновление ZAPRET${NC}\n"
  LOCAL_ARCH=$(get_local_arch)
  INSTALLED_VER=$(get_installed_version)
  LATEST_URL="$(find_latest_asset "$LOCAL_ARCH")"
  if [ -z "$LATEST_URL" ]; then
    echo -e "${RED}ERROR: не удалось найти релиз для вашей архитектуры ($LOCAL_ARCH)${NC}"
    read -p "Нажмите Enter..." dummy
    show_menu
    return
  fi
  LATEST_FILE=$(basename "$LATEST_URL")
  LATEST_VER=$(echo "$LATEST_FILE" | sed -E 's/.*zapret_v([0-9]+(\.[0-9]+)*).*/\1/')

  # consider installed up-to-date if installed version contains the release version
  if [ "$INSTALLED_VER" != "не найдена" ] && echo "$INSTALLED_VER" | grep -q "$LATEST_VER"; then
    echo -e "${BLUE}-> Уже установлена версия ${LATEST_VER} (или новее)${NC}"
    read -p "Нажмите Enter..." dummy
    show_menu
    return
  fi

  # ensure tools
  ensure_cmd curl curl
  ensure_cmd unzip unzip

  mkdir -p "$WORKDIR" || { echo "ERROR: Не удалось создать $WORKDIR"; return; }
  cd "$WORKDIR" || return

  echo -e "${GREEN}-> Скачиваем: ${CYAN}${LATEST_URL}${NC}"
  curl -L -s -o "$LATEST_FILE" "$LATEST_URL" || { echo -e "${RED}Ошибка скачивания${NC}"; read -p "Нажмите Enter..." dummy; show_menu; return; }

  echo -e "${GREEN}-> Распаковываем архив${NC}"
  unzip -o "$LATEST_FILE" >/dev/null 2>&1 || { echo -e "${RED}Ошибка распаковки${NC}"; }

  # find ipk files recursively
  echo -e "${GREEN}-> Ищем .ipk и устанавливаем${NC}"
  find "$WORKDIR" -type f \( -name "zapret_*.ipk" -o -name "luci-app-zapret_*.ipk" \) -print | while read -r PKG; do
    echo -e "  -> Устанавливаем: $PKG"
    opkg install --force-reinstall "$PKG" >/dev/null 2>&1 || {
      echo -e "    ${YELLOW}Начиная установку, повторяем попытку без --force-reinstall${NC}"
      opkg install "$PKG" >/dev/null 2>&1 || echo -e "    ${RED}Не удалось установить $PKG${NC}"
    }
  done

  # enable/restart service if present
  if [ -f /etc/init.d/zapret ]; then
    /etc/init.d/zapret enable >/dev/null 2>&1 || true
    /etc/init.d/zapret restart >/dev/null 2>&1 || true
  fi

  echo -e "\n${GREEN}-> Очистка временных файлов${NC}"
  cleanup

  echo -e "\n${BLUE}✅ Zapret установлен/обновлён (${LATEST_VER})${NC}\n"
  read -p "Нажмите Enter..." dummy
  show_menu
}

uninstall_zapret() {
  echo -e "\n${MAGENTA}Начинаем удаление ZAPRET${NC}\n"

  # stop service if present
  [ -f /etc/init.d/zapret ] && { /etc/init.d/zapret stop >/dev/null 2>&1 || true; /etc/init.d/zapret disable >/dev/null 2>&1 || true; }

  # try to kill running processes (pidof/pgrep fallback)
  PIDS=""
  if command -v pidof >/dev/null 2>&1; then
    PIDS=$(pidof zapret 2>/dev/null || true)
  fi
  if [ -z "$PIDS" ] && command -v pgrep >/dev/null 2>&1; then
    PIDS=$(pgrep -f /opt/zapret 2>/dev/null || true)
  fi
  if [ -z "$PIDS" ]; then
    PIDS=$(ps w 2>/dev/null | grep -F "/opt/zapret" | grep -v grep | awk '{print $1}') || true
  fi
  if [ -n "$PIDS" ]; then
    echo -e "${GREEN}-> Убиваем процессы: $PIDS${NC}"
    for pid in $PIDS; do kill -9 "$pid" >/dev/null 2>&1 || true; done
  fi

  # remove packages (try gentle first, then force)
  echo -e "${GREEN}-> Удаляем пакеты zapret и luci-app-zapret${NC}"
  opkg remove zapret luci-app-zapret >/dev/null 2>&1 || opkg remove --force-removal-of-dependent-packages zapret luci-app-zapret >/dev/null 2>&1 || true

  # remove configs and folders
  echo -e "${GREEN}-> Удаляем конфигурации и рабочие папки${NC}"
  for path in /opt/zapret /etc/config/zapret /etc/firewall.zapret /usr/share/zapret /etc/init.d/zapret; do
    [ -e "$path" ] && rm -rf "$path" >/dev/null 2>&1 || true
  done

  # remove crontab entries (system files and crontab command)
  echo -e "${GREEN}-> Чистим crontab${NC}"
  sed -i '/zapret/d' /etc/crontabs/* 2>/dev/null || true
  if command -v crontab >/dev/null 2>&1 && crontab -l >/dev/null 2>&1; then
    crontab -l | grep -v -i "zapret" | crontab - 2>/dev/null || true
  fi

  # destroy ipsets
  echo -e "${GREEN}-> Удаляем ipset, содержащие 'zapret'${NC}"
  if command -v ipset >/dev/null 2>&1; then
    ipset list -n 2>/dev/null | grep -i zapret | while read -r s; do
      ipset destroy "$s" >/dev/null 2>&1 || true
    done
  fi

  # nftables cleanup: flush+delete chains that contain 'zapret' and delete tables named 'zapret*'
  echo -e "${GREEN}-> Очищаем nftables (цепочки/таблицы с 'zapret')${NC}"
  nft list tables 2>/dev/null | awk '{print $2" "$3}' | while read -r family table; do
    # skip empty lines
    [ -z "$table" ] && continue
    nft list table "$family" "$table" 2>/dev/null | grep -i "chain .*zapret" >/dev/null 2>&1 && {
      nft list table "$family" "$table" 2>/dev/null | grep -i "chain .*zapret" | awk '{print $2}' | while read -r chain; do
        [ -n "$chain" ] && {
          nft flush chain "$family" "$table" "$chain" >/dev/null 2>&1 || true
          nft delete chain "$family" "$table" "$chain" >/dev/null 2>&1 || true
        }
      done
    }
    # if table name itself contains zapret -> delete table
    echo "$table" | grep -qi zapret && nft delete table "$family" "$table" >/dev/null 2>&1 || true
  done

  # remove hook scripts
  echo -e "${GREEN}-> Удаляем hook-скрипты${NC}"
  HOOK_DIRS="/etc/hotplug.d/iface /etc/hotplug.d/route /etc/hotplug.d/net"
  for HOOK_DIR in $HOOK_DIRS; do
    [ -d "$HOOK_DIR" ] && for f in "$HOOK_DIR"/*zapret*; do [ -f "$f" ] && rm -f "$f" >/dev/null 2>&1 || true; done
  done

  # other cleanup
  rm -f /tmp/*zapret* /var/run/*zapret* 2>/dev/null || true

  echo -e "\n${BLUE}✅ Zapret полностью удалён (попытка). Проверьте логи и правила nft/ipset вручную, если нужно.${NC}\n"
  read -p "Нажмите Enter..." dummy
  show_menu
}

# start
show_menu
