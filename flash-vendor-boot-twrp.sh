#!/bin/bash
# Flash a vendor_boot image to vendor_boot_a from a running TWRP over adb
# (root shell, no authorization needed), verify it by reading it back,
# then reboot to recovery.
#
#   flash-vendor-boot-twrp.sh <image> [adb serial]
set -euo pipefail
img=${1:?usage: $0 <image> [serial]}
adb=(adb); [ -n "${2:-}" ] && adb=(adb -s "$2")
size=$(stat -c %s "$img")
[ "$size" -eq 67108864 ] || { echo "refusing: $img is $size bytes, expected 67108864" >&2; exit 1; }
head -c 8 "$img" | grep -q VNDRBOOT || { echo "refusing: not a vendor_boot image" >&2; exit 1; }
[ "$("${adb[@]}" get-state)" = recovery ] || { echo "device is not in recovery" >&2; exit 1; }
[ "$("${adb[@]}" shell getprop ro.product.device | tr -d '\r')" = selene_vzw ] || {
    echo "refusing: device is not selene_vzw" >&2; exit 1; }

sha=$(sha256sum "$img" | cut -d' ' -f1)
"${adb[@]}" push "$img" /tmp/vb.img
"${adb[@]}" shell "set -e
    dev=\$(readlink -f /dev/block/by-name/vendor_boot_a)
    echo '$sha  /tmp/vb.img' | sha256sum -c -
    dd if=/tmp/vb.img of=\$dev bs=1M conv=fsync
    sync
    [ \"\$(sha256sum \$dev | cut -d' ' -f1)\" = '$sha' ] && echo 'readback OK'
    rm /tmp/vb.img"
# Reboot from an enforcing TWRP hangs (misc write denied); harmless if permissive.
"${adb[@]}" shell 'setenforce 0; reboot recovery' || true
