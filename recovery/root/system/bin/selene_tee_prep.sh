#!/system/bin/sh
# Prepare the Trustonic registry for mcDriverDaemon in recovery.
# persist is mounted READ-ONLY and its mcRegistry copied to tmpfs, so the
# daemon (stock args include --sfs-reformat) can never modify persist.
mkdir -p /mnt/vendor/persist /tmp/mcRegistry
mount -t ext4 -o ro,nosuid,nodev,noatime /dev/block/by-name/persist /mnt/vendor/persist ||
    echo "selene_tee_prep: persist mount failed" > /dev/kmsg
if [ -d /mnt/vendor/persist/mcRegistry ]; then
    cp -a /mnt/vendor/persist/mcRegistry/. /tmp/mcRegistry/
fi
chown -R system:system /tmp/mcRegistry
chmod 0771 /tmp/mcRegistry
echo "selene_tee_prep: registry $(ls /tmp/mcRegistry | wc -l) entries" > /dev/kmsg
