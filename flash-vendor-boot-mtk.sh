#!/bin/bash
# Write a vendor_boot image to vendor_boot_a via the mtkclient DA path
# (this carrier build has no usable fastboot). Device must be booted to
# Android; start this, then run `adb reboot bootloader` so the ~4 s
# preloader window is caught.
#
#   flash-vendor-boot-mtk.sh <image>        # flash
#   flash-vendor-boot-mtk.sh --restore      # flash stock vendor_boot_a.bin
#
# Configuration (environment):
#   STOCK      stock vendor_boot_a.bin dump (restore image; required)
#   STOCK_SHA  expected sha256 of $STOCK (default: the 4PEN dump below)
#   MTKCLIENT  mtkclient checkout (default: ~/mtkclient)
#   PY         python with mtkclient installed (default: $MTKCLIENT/.venv/bin/python)
#   RUNNER     mtkclient entry point; must accept `w <partition> <file>`.
#              Default: $MTKCLIENT/mtk.py. On this SoC the DA needs an SLA
#              bypass; point RUNNER at a wrapper that applies it.
#
# Only slot A is ever touched. Requires typing YES. If TWRP is already
# running, flashing from it is simpler: see README ("Flash from TWRP").
set -euo pipefail
: "${STOCK:?set STOCK to your stock vendor_boot_a.bin dump}"
STOCK_SHA=${STOCK_SHA:-b3fc1cd458712d97ff3765430a74eaddeadb4f16efb212cb479d9df9fcc6ff33}
MTKCLIENT=${MTKCLIENT:-$HOME/mtkclient}
PY=${PY:-$MTKCLIENT/.venv/bin/python}
RUNNER=${RUNNER:-$MTKCLIENT/mtk.py}

img=${1:?usage: $0 <image>|--restore}
[ "$img" = --restore ] && img=$STOCK
test -f "$img"
img=$(realpath "$img")   # runner cds into mtkclient
size=$(stat -c %s "$img")
[ "$size" -eq 67108864 ] || { echo "refusing: $img is $size bytes, expected 67108864" >&2; exit 1; }
head -c 8 "$img" | grep -q VNDRBOOT || { echo "refusing: not a vendor_boot image" >&2; exit 1; }
echo "$STOCK_SHA  $STOCK" | sha256sum -c --quiet || { echo "stock backup missing/changed" >&2; exit 1; }

echo "About to write $img"
echo "  sha256 $(sha256sum "$img" | cut -d' ' -f1)"
echo "  -> vendor_boot_a (restore image: $STOCK)"
read -r -p "Type YES to continue: " ok
[ "$ok" = YES ] || exit 1
cd "$MTKCLIENT"
exec "$PY" "$RUNNER" w vendor_boot_a "$img"
