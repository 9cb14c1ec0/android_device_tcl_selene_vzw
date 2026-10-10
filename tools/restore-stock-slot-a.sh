#!/bin/bash
#
# Restore stock system_a, system_ext_a, product_a, vendor_a and vbmeta_a from the
# backups pulled from this device (TWRP, 2026-10-09). Run from TWRP.
#
set -euo pipefail
SERIAL=${SERIAL:?set SERIAL to the adb serial of the device}
STOCK=${STOCK:-/home/android/tcltab8attempt2/lineage/stock/live-mapper}
A="adb -s $SERIAL"
die() { echo "ERROR: $*" >&2; exit 1; }
[ "$($A get-state)" = recovery ] || { echo "not in recovery"; exit 1; }
[ "$($A shell getprop ro.boot.slot_suffix | tr -d '\r')" = _a ] || { echo "slot is not _a"; exit 1; }
( cd "$STOCK" && sha256sum -c SHA256SUMS )

write() {
    local img=$1 dev=$2 sz sha_h sha_d
    sz=$(stat -c %s "$img"); sha_h=$(sha256sum < "$img" | cut -d' ' -f1)
    echo "writing $(basename "$img") -> $dev"
    # adb exec-in can drop the tail of the stream; stage in TWRP's tmpfs instead
    $A push "$img" /tmp/flash.img >/dev/null
    [ "$($A shell sha256sum /tmp/flash.img | cut -d' ' -f1)" = "$sha_h" ] || die "push to /tmp corrupted"
    $A shell "dd if=/tmp/flash.img of=$dev bs=4M conv=fsync 2>/dev/null; rm -f /tmp/flash.img"
    $A shell sync
    sha_d=$($A shell "head -c $sz $dev | sha256sum" | cut -d' ' -f1)
    [ "$sha_h" = "$sha_d" ] || { echo "readback mismatch on $dev"; exit 1; }
    echo "  readback OK"
}
for p in system system_ext product vendor; do
    write "$STOCK/${p}_a.img" "/dev/block/mapper/${p}_a"
done
write "$STOCK/vbmeta_a.bin" /dev/block/by-name/vbmeta_a
echo "Stock system side restored."
