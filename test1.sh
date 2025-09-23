#!/bin/sh
# Install static curl with HTTP/3 support and run zapret/blockcheck.sh
# Portable for OpenWrt-ish environments (busybox ash)
# Usage: sh install-curl-http3.sh
set -u
# Note: don't use `set -o pipefail` for /bin/sh (busybox sh may not support it)

INSTALL_DIR="/opt/curl"
ZAPRET_DIR="/opt/zapret"    # adjust if zapret is elsewhere
VERSION="${VERSION:-v8.10.1}"  # allow override by env var

# helpers
msg() { printf "%b\n" "$1"; }
err() { printf "%b\n" "$1" >&2; }

msg "\033[1;36m[*] Определяем архитектуру...\033[0m"
ARCH=$(uname -m 2>/dev/null || echo "unknown")

case "$ARCH" in
    x86_64|amd64)   FILE_ARCH="x86_64" ;;
    aarch64|arm64)  FILE_ARCH="aarch64" ;;
    armv7l|armv7*)  FILE_ARCH="armv7" ;;
    armv6l|armv6*)  FILE_ARCH="armv6" ;;
    mipsel|mips*)   FILE_ARCH="mipsel" ;;
    *)
        err "\033[1;31m[!] Неизвестная архитектура: $ARCH\033[0m"
        exit 1
    ;;
esac

CURL_FILE="curl-linux-${FILE_ARCH}.tar.xz"
URL="https://github.com/stunnel/static-curl/releases/download/${VERSION}/${CURL_FILE}"

msg "\033[1;36m[*] Используем: $CURL_FILE\033[0m"

# check for required tools
need() {
    command -v "$1" >/dev/null 2>&1 || { err "\033[1;31m[!] Требуется '$1' — установи через opkg и повтори.\033[0m"; exit 2; }
}
need awk  # used later for listing if needed

# choose downloader: prefer wget, fallback to curl
if command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
elif command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
else
    err "\033[1;31m[!] Ни wget, ни curl не найдены. Установи один из них (opkg update; opkg install wget) и повтори.\033[0m"
    exit 2
fi

TMPDIR=$(mktemp -d 2>/dev/null || echo "/tmp/curl-dl-$$")
trap 'rm -rf "$TMPDIR"' EXIT

msg "\033[1;36m[*] Скачиваем $URL ...\033[0m"
ARCHIVE="$TMPDIR/$CURL_FILE"
if [ "$DOWNLOADER" = "wget" ]; then
    # busybox wget may not support --show-progress; use -q or -O
    wget -q -O "$ARCHIVE" "$URL" || { err "\033[1;31mОшибка загрузки $URL\033[0m"; exit 3; }
else
    # curl
    curl -sSL -o "$ARCHIVE" "$URL" || { err "\033[1;31mОшибка загрузки $URL\033[0m"; exit 3; }
fi

msg "\033[1;36m[*] Распаковываем в временную директорию...\033[0m"
mkdir -p "$TMPDIR/extract"
if tar -tf "$ARCHIVE" >/dev/null 2>&1; then
    tar -xf "$ARCHIVE" -C "$TMPDIR/extract" || { err "\033[1;31mОшибка распаковки\033[0m"; exit 4; }
else
    err "\033[1;31mАрхив не найден или повреждён\033[0m"
    exit 4
fi

# find curl binary inside archive
CANDIDATE=$(find "$TMPDIR/extract" -type f -name curl -perm -111 2>/dev/null | head -n 1 || true)
if [ -z "$CANDIDATE" ]; then
    # maybe it's named curl.exe or located in bin/
    CANDIDATE=$(find "$TMPDIR/extract" -type f -iname 'curl*' 2>/dev/null | head -n 1 || true)
fi

if [ -z "$CANDIDATE" ]; then
    err "\033[1;31mНе удалось найти бинарник curl внутри архива.\033[0m"
    err "Содержимое архива:"
    find "$TMPDIR/extract" -maxdepth 3 -ls | awk '{print $11}' || true
    exit 5
fi

msg "\033[1;36m[*] Устанавливаем в $INSTALL_DIR ...\033[0m"
mkdir -p "$INSTALL_DIR"
# move binary
cp -f "$CANDIDATE" "$INSTALL_DIR/curl" || { err "\033[1;31mОшибка копирования бинарника\033[0m"; exit 6; }
chmod +x "$INSTALL_DIR/curl" || true

# update PATH persistently
PROFILE_SNIPPET="export PATH=\$PATH:${INSTALL_DIR}"
if [ -d /etc/profile.d ]; then
    echo "$PROFILE_SNIPPET" > /etc/profile.d/curl_path.sh 2>/dev/null || true
else
    # append to /etc/profile if not already present
    if ! grep -qxF "$PROFILE_SNIPPET" /etc/profile 2>/dev/null; then
        printf "%s\n" "$PROFILE_SNIPPET" >> /etc/profile 2>/dev/null || true
    fi
fi
# export for current session
export PATH=$PATH:"${INSTALL_DIR}"

msg "\033[1;32m[+] curl установлен в $INSTALL_DIR\033[0m"
"$INSTALL_DIR/curl" --version 2>/dev/null | head -n 1 || msg "Не удалось запустить $INSTALL_DIR/curl --version"

# run blockcheck if present
if [ -x "${ZAPRET_DIR}/blockcheck.sh" ]; then
    msg "\033[1;36m[*] Запускаем blockcheck.sh ...\033[0m"
    cd "${ZAPRET_DIR}" || exit 1
    ./blockcheck.sh
else
    err "\033[1;31m[!] blockcheck.sh не найден в ${ZAPRET_DIR}\033[0m"
    err "Скопируй zapret в этот каталог или поправь переменную ZAPRET_DIR."
fi
