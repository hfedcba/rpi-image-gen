#!/bin/bash
#
# Non-interactive replacement for the hostname-from-MAC step that used to
# be part of pi-gen's dialog-based firstStart.sh wizard. Runs once on
# first boot.

set -eu

STATE_DIR=/etc/rpi-image-gen
DONE_FILE="$STATE_DIR/hostname-from-mac.done"
DEFAULTS_FILE=/etc/default/rpi-hostname-from-mac

HOSTNAME_PREFIX=homegearpi
# shellcheck disable=SC1090
[ -f "$DEFAULTS_FILE" ] && . "$DEFAULTS_FILE"

[ -f "$DONE_FILE" ] && exit 0

mac="$(ip -o link show | awk '$2 != "lo:" && /ether/ {print $(NF-2); exit}')"
if [ -z "$mac" ]; then
	logger -t rpi-hostname-from-mac "no MAC address found yet, will retry next boot"
	exit 0
fi

newhost="${HOSTNAME_PREFIX}-$(echo "$mac" | tr ':' '-')"
oldhost="$(cat /etc/hostname 2>/dev/null || echo raspberrypi)"

mount -o remount,rw / 2>/dev/null || true

echo "$newhost" > /etc/hostname
hostnamectl set-hostname "$newhost" 2>/dev/null || hostname "$newhost" || true

if grep -qE "^127\.0\.1\.1[[:space:]]+${oldhost}([[:space:]]|\$)" /etc/hosts; then
	sed -i -E "s/^127\.0\.1\.1([[:space:]]+)${oldhost}(([[:space:]]|\$).*)?\$/127.0.1.1\\1${newhost}\\2/" /etc/hosts
elif ! grep -qE "^127\.0\.1\.1[[:space:]]+${newhost}([[:space:]]|\$)" /etc/hosts; then
	printf '127.0.1.1\t%s\n' "$newhost" >> /etc/hosts
fi

touch "$DONE_FILE"
mount -o remount,ro / 2>/dev/null || true

logger -t rpi-hostname-from-mac "hostname set to $newhost"
