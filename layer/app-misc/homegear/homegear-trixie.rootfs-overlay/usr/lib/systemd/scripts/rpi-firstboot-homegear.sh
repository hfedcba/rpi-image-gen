#!/bin/bash
#
# Non-interactive replacement for pi-gen's firstStartCustom.sh. Runs once,
# after the /data partition (see layer data-partition) is mounted, since
# Homegear's postinst script detects and uses /data/homegear-data if it
# already exists at install time.

set -eu

STATE_DIR=/etc/rpi-image-gen
DONE_FILE="$STATE_DIR/homegear-install.done"

[ -f "$DONE_FILE" ] && exit 0

mkdir -p "$STATE_DIR"
mount -o remount,rw / 2>/dev/null || true

# Create Homegear data directory before installing Homegear so it can be
# detected in Homegear's postinst script.
mkdir -p /data/homegear-data
chown homegear:homegear /data/homegear-data

apt-get update

apt-get -y install \
	homegear homegear-management homegear-webssh homegear-adminui \
	homegear-nodes-core homegear-nodes-extra homegear-homematicbidcos \
	homegear-homematicwired homegear-insteon homegear-max \
	homegear-philipshue homegear-sonos homegear-kodi homegear-beckhoff \
	homegear-knx homegear-enocean homegear-intertechno homegear-ccu \
	homegear-nanoleaf || apt-get -y -f install

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

# Create database and defaultPassword.txt while file system is writeable
systemctl restart homegear

touch "$DONE_FILE"
mount -o remount,ro / 2>/dev/null || true

logger -t rpi-firstboot-homegear "Homegear installed and configured"
