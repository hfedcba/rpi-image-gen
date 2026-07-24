#!/bin/bash
#
# Keeps root read-write across every boot until first-boot bootstrapping
# (partitioning, hostname, optional Homegear install) has fully finished,
# mirroring pi-gen's firstStart.sh, which stayed rw for its entire guided
# setup. Without this, none of those steps - nor an admin's forced
# password change over SSH - could write to the (normally read-only)
# root filesystem.

set -eu

log() { logger -t rpi-firstboot-rw "$*"; echo "rpi-firstboot-rw: $*"; }

# No "|| true" here: if this remount fails, every step downstream (data
# partition setup, hostname, Homegear install, the forced SSH password
# change) will also fail to write, but silently, since they assume root
# is already rw by the time they run. Let this fail loudly instead - the
# services that Requires= this one (see their .service units) will then
# correctly refuse to start rather than failing individually later with
# confusing, seemingly-unrelated read-only errors.
mount -o remount,rw /
log "root remounted read-write"
