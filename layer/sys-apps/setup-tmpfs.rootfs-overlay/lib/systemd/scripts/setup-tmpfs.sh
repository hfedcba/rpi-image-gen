#!/bin/bash

if [ ! -z /data/fake-hwclock.data ]; then
    date -u -s "$(cat /data/fake-hwclock.data)"
fi

# Other layers may claim additional zram devices (e.g. a database
# directory) by dropping a SIZE=/MOUNTPOINT=[/POSTMOUNT=] conf file here,
# instead of patching this script. zram's device count is fixed at
# modprobe time, so it must be known up front.
EXTRA_DIR=/etc/setup-tmpfs-extra.d
extra_confs=""
if [ -d "$EXTRA_DIR" ]; then
    extra_confs=$(find "$EXTRA_DIR" -maxdepth 1 -name '*.conf' | sort)
fi
extra_count=0
[ -n "$extra_confs" ] && extra_count=$(printf '%s\n' "$extra_confs" | wc -l)

modprobe zram num_devices=$((2 + extra_count))

echo 134217728 > /sys/block/zram0/disksize
echo 134217728 > /sys/block/zram1/disksize

mkfs.ext4 /dev/zram0
mkfs.ext4 /dev/zram1

mount /dev/zram0 /var/log
mount /dev/zram1 /tmp

chmod 775 /var/log
chmod 777 /tmp

mkdir /var/tmp/lock
chmod 777 /var/tmp/lock
mkdir /var/tmp/dhcp
chmod 755 /var/tmp/dhcp
mkdir /var/tmp/spool
chmod 755 /var/tmp/spool
mkdir /var/tmp/systemd
chmod 755 /var/tmp/systemd
touch /var/tmp/systemd/random-seed
chmod 600 /var/tmp/systemd/random-seed
mkdir -p /var/spool/cron/crontabs
chmod 731 /var/spool/cron/crontabs
chmod +t /var/spool/cron/crontabs
mkdir -p /var/spool/cron/atjobs
chown daemon:daemon /var/spool/cron/atjobs
mkdir -p /var/spool/cron/atspool
chown daemon:daemon /var/spool/cron/atspool
mkdir -p /var/spool/rsyslog
chmod 700 /var/spool/rsyslog
mkdir /var/tmp/dhcpcd5
chmod 755 /var/tmp/dhcpcd5

if [ -n "$extra_confs" ]; then
    n=2
    printf '%s\n' "$extra_confs" | while IFS= read -r conf; do
        SIZE=""; MOUNTPOINT=""; POSTMOUNT=""
        . "$conf"
        if [ -z "$SIZE" ] || [ -z "$MOUNTPOINT" ]; then
            n=$((n + 1))
            continue
        fi
        echo "$SIZE" > "/sys/block/zram${n}/disksize"
        mkfs.ext4 "/dev/zram${n}"
        mkdir -p "$MOUNTPOINT"
        mount "/dev/zram${n}" "$MOUNTPOINT"
        [ -n "$POSTMOUNT" ] && [ -x "$POSTMOUNT" ] && "$POSTMOUNT"
        n=$((n + 1))
    done
fi

exit 0
