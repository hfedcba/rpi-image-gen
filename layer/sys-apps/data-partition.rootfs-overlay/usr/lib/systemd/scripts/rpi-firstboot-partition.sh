#!/bin/bash
#
# Non-interactive replacement for pi-gen's dialog-based setupPartitions.sh.
# Grows the root partition to a fixed target size and creates a BTRFS
# (dup profile) data partition from the space remaining on the physical
# disk, mounted at /data. Runs in two stages across a reboot: the kernel
# cannot safely re-read the partition table entry of the currently mounted
# root partition, so growing root requires a reboot before resize2fs can
# see the new size. Appending the data partition afterwards does not
# disturb root and can be done live.

set -eu

STATE_DIR=/etc/rpi-image-gen
STATE_FILE="$STATE_DIR/firstboot-partition.state"
DONE_FILE="$STATE_DIR/firstboot-partition.done"
DEFAULTS_FILE=/etc/default/rpi-firstboot-partition

ROOT_TARGET_MIN=6G
ROOT_TARGET_PCT=30
DATA_LABEL=DATA
DATA_MIN_FREE_M=256
# shellcheck disable=SC1090
[ -f "$DEFAULTS_FILE" ] && . "$DEFAULTS_FILE"

mkdir -p "$STATE_DIR"

[ -f "$DONE_FILE" ] && exit 0

state="pending"
[ -f "$STATE_FILE" ] && state="$(cat "$STATE_FILE")"

log() { logger -t rpi-firstboot-partition "$*"; echo "rpi-firstboot-partition: $*"; }

# Parse a "6G"/"512M"/"1024K"/plain-bytes size string into bytes.
parse_size_bytes() {
	local s="$1" num unit
	num=$(printf '%s' "$s" | grep -oE '^[0-9]+')
	unit=$(printf '%s' "$s" | grep -oE '[A-Za-z]+$' | tr '[:lower:]' '[:upper:]')
	case "$unit" in
	G | GB | GIB) echo $((num * 1024 * 1024 * 1024)) ;;
	M | MB | MIB) echo $((num * 1024 * 1024)) ;;
	K | KB | KIB) echo $((num * 1024)) ;;
	*) echo "$num" ;;
	esac
}

# Locate the Nth partition device of $disk via sysfs, independent of
# mmcblk0pN vs sdaN vs nvme0n1pN naming.
partdev() {
	local disk="$1" num="$2" d
	for d in "/sys/class/block/$(basename "$disk")"/*/partition; do
		[ -e "$d" ] || continue
		if [ "$(cat "$d")" = "$num" ]; then
			basename "$(dirname "$d")"
			return 0
		fi
	done
	return 1
}

ROOT_DEV="$(findmnt -no SOURCE /)"
ROOT_NAME="$(basename "$ROOT_DEV")"
DISK="/dev/$(lsblk -no PKNAME "$ROOT_DEV")"
ROOT_PART_NUM="$(cat "/sys/class/block/$ROOT_NAME/partition")"

mount -o remount,rw /

case "$state" in
pending)
	# Root is grown to whichever is larger: ROOT_TARGET_MIN, or
	# ROOT_TARGET_PCT % of the physical disk. Capped so DATA_MIN_FREE_M
	# is left over for the /data partition created in stage 2, unless
	# that isn't possible on this disk at all (then just take it all and
	# let stage 2's own free-space check skip /data creation).
	DISK_BYTES="$(blockdev --getsize64 "$DISK")"
	MIN_BYTES="$(parse_size_bytes "$ROOT_TARGET_MIN")"
	PCT_BYTES=$((DISK_BYTES * ROOT_TARGET_PCT / 100))
	TARGET_BYTES=$MIN_BYTES
	[ "$PCT_BYTES" -gt "$TARGET_BYTES" ] && TARGET_BYTES=$PCT_BYTES

	MAX_BYTES=$((DISK_BYTES - DATA_MIN_FREE_M * 1024 * 1024))
	[ "$MAX_BYTES" -lt "$MIN_BYTES" ] && MAX_BYTES=$DISK_BYTES
	[ "$TARGET_BYTES" -gt "$MAX_BYTES" ] && TARGET_BYTES=$MAX_BYTES

	TARGET_MIB=$((TARGET_BYTES / 1024 / 1024))
	log "stage 1: growing root partition ($ROOT_DEV on $DISK) to ${TARGET_MIB}MiB (min ${ROOT_TARGET_MIN}, ${ROOT_TARGET_PCT}% of $((DISK_BYTES / 1024 / 1024))MiB disk)"
	echo ", ${TARGET_MIB}MiB" | sfdisk --no-reread -N "$ROOT_PART_NUM" "$DISK"
	echo "stage2" > "$STATE_FILE"
	sync
	mount -o remount,ro / || true
	log "rebooting to apply root partition resize"
	systemctl reboot
	;;
stage2)
	log "stage 2: growing root filesystem and creating data partition"
	resize2fs "$ROOT_DEV"

	DATA_PART_NUM=$((ROOT_PART_NUM + 1))
	if ! DATA_NAME="$(partdev "$DISK" "$DATA_PART_NUM")"; then
		free_m="$(sfdisk -F "$DISK" 2>/dev/null | awk '/Unpartitioned space/ {print int($3)}' | tail -1)"
		if [ -z "${free_m:-}" ] || [ "$free_m" -lt "$DATA_MIN_FREE_M" ]; then
			log "not enough free space for a data partition ($DISK); skipping"
			echo "done" > "$STATE_FILE"
			touch "$DONE_FILE"
			mount -o remount,ro / || true
			exit 0
		fi
		echo ", +" | sfdisk --no-reread --append "$DISK"
		partprobe "$DISK" || true
		udevadm settle
		DATA_NAME="$(partdev "$DISK" "$DATA_PART_NUM")"
	fi
	DATA_DEV="/dev/$DATA_NAME"

	mkfs.btrfs -f -d dup -m dup -L "$DATA_LABEL" "$DATA_DEV"

	mkdir -p /data
	if ! grep -q "^LABEL=${DATA_LABEL}[[:space:]]" /etc/fstab; then
		printf 'LABEL=%s\t/data\tbtrfs\tdefaults,degraded,compress=lzo,noatime,nodiratime,autodefrag,commit=60\t0\t1\n' \
			"$DATA_LABEL" >> /etc/fstab
	fi
	mount /data

	echo "done" > "$STATE_FILE"
	touch "$DONE_FILE"
	mount -o remount,ro / || true
	log "data partition ready on $DATA_DEV"
	;;
*)
	log "unknown state '$state', giving up"
	exit 1
	;;
esac
