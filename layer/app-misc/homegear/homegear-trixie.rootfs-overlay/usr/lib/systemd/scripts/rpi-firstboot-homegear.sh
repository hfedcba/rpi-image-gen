#!/bin/bash
#
# Port of pi-gen's firstStartCustom.sh. Runs once, after the /data
# partition (see layer data-partition) is mounted, since Homegear's
# postinst script detects and uses /data/homegear-data if it already
# exists at install time. Root is kept read-write by layer
# firstboot-assistant's rpi-firstboot-rw.service, which runs before this
# unit on every boot until first boot is fully done; no remount here.
#
# This is only the backend: it is run by rpi-firstboot-homegear.service,
# which is not enabled and is started on demand by
# /usr/sbin/homegear-firstboot at the first interactive login. Everything
# printed here ends up in the journal, where that script picks it up and
# renders it in a dialog progress box - so keep the output informative.

set -eu

# apt must never try to open a dialog of its own here: its stdout is a
# pipe into the journal, not a terminal.
export DEBIAN_FRONTEND=noninteractive

STATE_DIR=/etc/rpi-image-gen
DONE_FILE="$STATE_DIR/homegear-install.done"

[ -f "$DONE_FILE" ] && exit 0

mkdir -p "$STATE_DIR"

# Create Homegear data directory before installing Homegear so it can be
# detected in Homegear's postinst script.
mkdir -p /data/homegear-data
chown homegear:homegear /data/homegear-data

# The progress box downstream shows whatever reaches stdout. apt is
# quiet for long stretches even when it is working hard - contacting the
# mirrors during `update`, then "Building dependency tree..." over this
# large package set on a Pi - so announce each slow phase ourselves,
# otherwise the box just says "Installing Homegear..." for a minute and
# looks hung. stdbuf line-buffers apt's own output so its lines surface
# as they happen instead of in 4 KB blocks (apt full-buffers stdout once
# it is a pipe rather than a terminal).
echo "==> Updating package lists (contacting mirrors)..."
stdbuf -oL -eL apt-get update

echo "==> Installing Homegear and add-ons - downloading several hundred MB, this takes a while..."
stdbuf -oL -eL apt-get -y install \
	homegear homegear-management homegear-webssh homegear-adminui \
	homegear-nodes-core homegear-nodes-extra homegear-homematicbidcos \
	homegear-homematicwired homegear-insteon homegear-max \
	homegear-philipshue homegear-sonos homegear-kodi homegear-beckhoff \
	homegear-knx homegear-enocean homegear-intertechno homegear-ccu \
	homegear-nanoleaf || stdbuf -oL -eL apt-get -y -f install

echo "==> Configuring Homegear..."

sed -i 's/debugLevel = 4/debugLevel = 3/g' /etc/homegear/main.conf
sed -i 's/tempPath = \/var\/lib\/homegear\/tmp/tempPath = \/var\/tmp\/homegear/g' /etc/homegear/main.conf
sed -i 's/# databasePath =/databasePath = \/var\/lib\/homegear\/db/g' /etc/homegear/main.conf
sed -i 's/# writeableDataPath =/writeableDataPath =/g' /etc/homegear/main.conf
sed -i 's/# databaseBackupPath =/databaseBackupPath = \/data\/homegear-data/g' /etc/homegear/main.conf
sed -i 's/familyDataPath = \/var\/lib\/homegear\/families/familyDataPath = \/data\/homegear-data\/families/g' /etc/homegear/main.conf
sed -i 's/nodeBlueDataPath = \/var\/lib\/homegear\/node-blue\/data/nodeBlueDataPath = \/data\/homegear-data\/node-blue/g' /etc/homegear/main.conf
sed -i 's/databaseMemoryJournal = false/databaseMemoryJournal = true/g' /etc/homegear/main.conf
sed -i 's/databaseWALJournal = true/databaseWALJournal = false/g' /etc/homegear/main.conf
sed -i 's/databaseSynchronous = true/databaseSynchronous = false/g' /etc/homegear/main.conf

sed -i 's/session.save_path = "\/var\/lib\/homegear\/tmp\/php"/session.save_path = "\/var\/tmp\/homegear\/php"/g' /etc/homegear/php.ini

mkdir -p /data/homegear-data/node-blue/node-red
cp /var/lib/homegear/node-blue/data/node-red/settings.js /data/homegear-data/node-blue/node-red/
chown -R homegear:homegear /data/homegear-data
sed -i 's/\/var\/lib\/homegear\/node-blue\/data\/node-red/\/data\/homegear-data\/node-blue\/node-red/g' /data/homegear-data/node-blue/node-red/settings.js

{
	echo ""
	echo "# Delete backuped db.sql."
	echo "[ -f /data/homegear-data/db.sql ] && [ -f /var/lib/homegear/db/db.sql ] && rm -f /data/homegear-data/db.sql"
	echo "exit 0"
} >> /etc/homegear/homegear-start.sh

{
	echo "[ -f /var/lib/homegear/db/db.sql ] && [ -d /data/homegear-data ] && cp -a /var/lib/homegear/db/db.sql /data/homegear-data/"
	echo "[ -d /data/homegear-data ] && chown homegear:homegear /data/homegear-data/*"
	echo "sync"
} >> /etc/homegear/homegear-stop.sh

chown -R homegear:homegear /var/lib/homegear/www

# Record completion NOW, while the root filesystem is still writable, and
# crucially BEFORE first-starting Homegear. homegear-management remounts /
# read-only as it comes up (its own read-only-appliance handling literally
# runs `mount -o remount,rw /` ... `sync; mount -o remount,ro /`), so a
# write to /etc after that point fails with EROFS - which is exactly how
# this script used to die on its final touch. The install is fully defined
# by the packages and config already in place here; the first start below
# is a separate step and needs no writable root (Homegear's own data lives
# on zram + /data).
touch "$DONE_FILE"
echo "==> Homegear installation complete."

# Create database and defaultPassword.txt on first start.
echo "==> Starting Homegear for the first time..."
systemctl restart homegear

logger -t rpi-firstboot-homegear "Homegear installed and configured"
