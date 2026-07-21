#!/bin/bash
# Runs every boot, right after /var/lib/homegear/db (zram) has been
# mounted by setup-tmpfs.sh. Recreates the zram-backed directories
# Homegear needs and restores the sqlite db backed up to /data on the
# previous shutdown (see homegear-stop.sh).

chmod 770 /var/lib/homegear/db
chown homegear:homegear /var/lib/homegear/db

mkdir /var/log/homegear
mkdir /var/log/homegear-dc-connector
mkdir /var/log/homegear-influxdb
mkdir /var/log/homegear-webssh
mkdir /var/log/homegear-management
chown homegear:homegear /var/log/homegear*

touch /var/log/mosquitto.log
chown mosquitto:mosquitto /var/log/mosquitto.log

mkdir -p /var/tmp/homegear
chown homegear:homegear /var/tmp/homegear
chmod 770 /var/tmp/homegear

mkdir -p /var/tmp/homegear/php
chmod 770 /var/tmp/homegear/php
chown homegear:homegear -R /var/tmp/homegear/php

[ -d /data ] && [ ! -d /data/homegear-data ] && mkdir /data/homegear-data
[ -d /data/homegear-data ] && [ ! -d /data/homegear-data/node-blue ] && mkdir /data/homegear-data/node-blue
[ -d /data/homegear-data ] && [ ! -d /data/homegear-data/families ] && mkdir /data/homegear-data/families
[ -d /data/homegear-data ] && chown -R homegear:homegear /data/homegear-data/*
[ -f /data/homegear-data/db.sql ] && cp -a /data/homegear-data/db.sql /var/lib/homegear/db/ && rm -f /data/homegear-data/db.sql

exit 0
