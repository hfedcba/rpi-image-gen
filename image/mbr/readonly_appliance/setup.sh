#!/bin/bash

set -eu

LABEL="$1"

case $LABEL in
   ROOT)
      cat << EOF > $IMAGEMOUNTPATH/etc/fstab
proc            /proc                       proc            defaults                                                            0       0
EOF
      case $IGconf_image_rootfs_type in
         ext4)
            cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
/dev/disk/by-slot/system  /  ext4 noatime,ro,errors=remount-ro 0 1
EOF
            ;;
         btrfs)
            cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
/dev/disk/by-slot/system  /  btrfs noatime,ro 0 0
EOF
            ;;
         *)
            ;;
      esac

      # /data (BTRFS) is intentionally absent here: it does not exist yet
      # at build time and is appended by layer data-partition on first
      # boot, once the physical disk's actual size is known.
      cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
/dev/disk/by-slot/boot  /boot/firmware  vfat defaults,noatime,ro 0 2
tmpfs           /run                        tmpfs           defaults,nosuid,mode=1777,size=50M                                  0       0
tmpfs           /dev/shm                    tmpfs           defaults,size=32m                                                   0       0
tmpfs           /sys/fs/cgroup              tmpfs           defaults                                                            0       0
EOF
      ;;
   BOOT)
      sed -i "s|root=\([^ ]*\)|root=/dev/disk/by-slot/system|" $IMAGEMOUNTPATH/cmdline.txt
      ;;
   *)
      ;;
esac
