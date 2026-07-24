#!/bin/bash
#
# Runs once all other first-boot steps present on this image (partitioning,
# Homegear install if that layer is included, and the forced password
# change if layer readonly-root enabled one) have finished, and locks root
# back to read-only.
#
# Waiting for the password change specifically matters because it isn't
# one of our own first-boot services - it's PAM-triggered, at whatever
# unpredictable time the admin first logs in. Locking root read-only as
# soon as partitioning finishes (which is usually well before that first
# login) would just reproduce the same "Authentication token manipulation
# error" this whole layer exists to avoid.
#
# NOTE: earlier versions moved /etc/passwd,shadow,group,gshadow onto /data
# and symlinked them back, so runtime account changes would persist without
# a manual 'rw'. That was removed: /data (btrfs on a separate partition)
# mounts a second or so into boot, AFTER early services that do NSS user
# lookups - systemd-networkd (User=systemd-network) and systemd-resolved
# (User=systemd-resolve) start at sysinit and would find /etc/passwd a
# dangling symlink, fail with status=217/USER, hit their start-limit and
# stay down for the rest of the boot (network dead, despite the kernel's
# own SLAAC address making the box look reachable). The account database
# must live on the always-present root. The cost is that a password change
# made after first boot needs a manual 'rw' first (the ro/rw helpers exist
# for exactly this) - a standard read-only-appliance trade-off, and far
# preferable to a machine that boots with no working network.

set -eu

STATE_DIR=/etc/rpi-image-gen
DONE_FILE="$STATE_DIR/firstboot.done"
DEFAULTS_FILE=/etc/default/rpi-firstboot-finalize

PASSWORD_CHANGE_REQUIRED=n
PASSWORD_CHANGE_USER=
# shellcheck disable=SC1090
[ -f "$DEFAULTS_FILE" ] && . "$DEFAULTS_FILE"

[ -f "$DONE_FILE" ] && exit 0

log() { logger -t rpi-firstboot-finalize "$*"; echo "rpi-firstboot-finalize: $*"; }

# Every optional first-boot component this image ships is required to be
# done before we finalize; detected by the presence of its unit file (or,
# for the password change, its defaults file) rather than hardcoded, so
# this script doesn't need to know which layers are present.
missing=0
if [ -f /usr/lib/systemd/system/rpi-firstboot-partition.service ]; then
	[ -f /etc/rpi-image-gen/firstboot-partition.done ] || missing=1
fi
if [ -f /usr/lib/systemd/system/rpi-firstboot-homegear.service ]; then
	[ -f /etc/rpi-image-gen/homegear-install.done ] || missing=1
fi
if [ "$PASSWORD_CHANGE_REQUIRED" = "y" ] && [ -n "$PASSWORD_CHANGE_USER" ]; then
	lastchange=$(awk -F: -v u="$PASSWORD_CHANGE_USER" '$1==u {print $3}' /etc/shadow)
	[ -n "$lastchange" ] && [ "$lastchange" != "0" ] || missing=1
fi

if [ "$missing" -ne 0 ]; then
	log "other first-boot steps not finished yet, will check again next boot"
	exit 0
fi

# Root is already rw here (rpi-firstboot-rw.service, which this unit
# Requires=, keeps it so all through first boot); remount rw anyway so the
# state file below can't fail on a surprise ro mount. No "|| true": if this
# genuinely can't get a writable root, fail loudly rather than mark first
# boot done with the flag unwritten and loop next boot.
mount -o remount,rw /

touch "$DONE_FILE"
mount -o remount,ro / || true
log "first boot complete, root is read-only"
