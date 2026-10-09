#!/bin/bash
# Write a vendor_boot image to vendor_boot_a via the mtkclient DA path
# (this carrier build has no usable fastboot). Device must be booted to
# Android; start this, then run `adb reboot bootloader` so the ~4 s
# preloader window is caught.
#
#   flash-vendor-boot-mtk.sh <image>        # flash
#   flash-vendor-boot-mtk.sh --restore      # flash stock vendor_boot_a.bin
#
# Only slot A is ever touched. Requires typing YES.
set -euo pipefail
STOCK=/home/android/tcltab8attempt2/dump/firmware/vendor_boot_a.bin
STOCK_SHA=b3fc1cd458712d97ff3765430a74eaddeadb4f16efb212cb479d9df9fcc6ff33
RUNNER=/home/android/tcltab8attempt2/exploit/run_heapbait_mtk.py
PY=/home/android/mtkclient_fresh/.venv/bin/python

img=${1:?usage: $0 <image>|--restore}
[ "$img" = --restore ] && img=$STOCK
test -f "$img"
size=$(stat -c %s "$img")
[ "$size" -eq 67108864 ] || { echo "refusing: $img is $size bytes, expected 67108864" >&2; exit 1; }
head -c 8 "$img" | grep -q VNDRBOOT || { echo "refusing: not a vendor_boot image" >&2; exit 1; }
echo "$STOCK_SHA  $STOCK" | sha256sum -c --quiet || { echo "stock backup missing/changed" >&2; exit 1; }

echo "About to write $img"
echo "  sha256 $(sha256sum "$img" | cut -d' ' -f1)"
echo "  -> vendor_boot_a (restore image: $STOCK)"
read -r -p "Type YES to continue: " ok
[ "$ok" = YES ] || exit 1
cd /home/android/mtkclient_fresh
exec "$PY" "$RUNNER" w vendor_boot_a "$img"
