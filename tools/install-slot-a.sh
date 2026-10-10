#!/bin/bash
#
# Install the LineageOS images to slot A from TWRP (root adb).
#
#   install-slot-a.sh            preflight only (no writes)
#   install-slot-a.sh --flash    write system_a, system_ext_a, product_a, vendor_a and a
#                                verification-disabled copy of stock vbmeta_a
#
# Never touches slot B, super metadata, the dlkm partitions, boot, init_boot,
# vendor_boot, dtbo or /data. Restore: restore-stock-slot-a.sh.
#
set -euo pipefail

SERIAL=${SERIAL:?set SERIAL to the adb serial of the device}
OUT=${OUT:-/home/android/tb305fu/lineage-22.2/out/target/product/selene_vzw}
STOCK=${STOCK:-/home/android/tcltab8attempt2/lineage/stock/live-mapper}
HERE=$(cd "$(dirname "$0")" && pwd)
A="adb -s $SERIAL"
FLASH=0; [ "${1:-}" = "--flash" ] && FLASH=1

die() { echo "ERROR: $*" >&2; exit 1; }

[ "$($A get-state 2>/dev/null)" = recovery ] || die "$SERIAL is not in recovery"
[ "$($A shell getprop ro.product.device | tr -d '\r')" = selene_vzw ] || die "not selene_vzw TWRP"
[ "$($A shell getprop ro.boot.slot_suffix | tr -d '\r')" = _a ] || die "active slot is not _a"
[ "$($A shell id -u | tr -d '\r')" = 0 ] || die "adb is not root"

# Stock vbmeta_a must still be the stock one (or our patched copy of it).
sha_dev_vbmeta=$($A shell "dd if=/dev/block/by-name/vbmeta_a bs=1M 2>/dev/null | sha256sum" | cut -d' ' -f1)
sha_stock_vbmeta=$(sha256sum < "$STOCK/vbmeta_a.bin" | cut -d' ' -f1)
python3 "$HERE/patch-vbmeta-disable-verification.py" "$STOCK/vbmeta_a.bin" /tmp/selene-vbmeta_a-noverify.img >/dev/null
sha_patched_vbmeta=$(sha256sum < /tmp/selene-vbmeta_a-noverify.img | cut -d' ' -f1)
case "$sha_dev_vbmeta" in
  "$sha_stock_vbmeta") echo "vbmeta_a: stock" ;;
  "$sha_patched_vbmeta") echo "vbmeta_a: already verification-disabled" ;;
  *) die "vbmeta_a is neither stock nor our patched copy ($sha_dev_vbmeta)" ;;
esac

for p in system system_ext product vendor; do
    img="$OUT/$p.img"
    [ -f "$img" ] || die "missing $img"
    file -b "$img" | grep -qi "sparse" && die "$img is sparse; expected raw erofs"
    isz=$(stat -c %s "$img")
    dsz=$($A shell "blockdev --getsize64 /dev/block/mapper/${p}_a" | tr -d '\r')
    mnt=$($A shell "grep -c /dev/block/$(basename "$($A shell readlink -f /dev/block/mapper/${p}_a | tr -d '\r')") /proc/mounts" | tr -d '\r' || true)
    printf "%-11s image %11d  partition %11d  %s\n" "$p" "$isz" "$dsz" \
        "$([ "$isz" -le "$dsz" ] && echo fits || echo 'DOES NOT FIT')"
    [ "$isz" -le "$dsz" ] || die "${p}_a too small; resize needed (see README)"
    [ "${mnt:-0}" = 0 ] || die "${p}_a is mounted in recovery; unmount it first"
done

[ $FLASH = 1 ] || { echo "Preflight OK. Re-run with --flash to write."; exit 0; }

write() { # $1 image, $2 device node
    local img=$1 dev=$2 sz sha_h sha_d
    sz=$(stat -c %s "$img"); sha_h=$(sha256sum < "$img" | cut -d' ' -f1)
    echo "writing $(basename "$img") -> $dev ($sz bytes)"
    # adb exec-in can drop the tail of the stream; stage in TWRP's tmpfs instead
    $A push "$img" /tmp/flash.img >/dev/null
    [ "$($A shell sha256sum /tmp/flash.img | cut -d' ' -f1)" = "$sha_h" ] || die "push to /tmp corrupted"
    $A shell "dd if=/tmp/flash.img of=$dev bs=4M conv=fsync 2>/dev/null; rm -f /tmp/flash.img"
    $A shell sync
    sha_d=$($A shell "head -c $sz $dev | sha256sum" | cut -d' ' -f1)
    [ "$sha_h" = "$sha_d" ] || die "readback mismatch on $dev ($sha_d != $sha_h)"
    echo "  readback OK $sha_h"
}

for p in system system_ext product vendor; do
    write "$OUT/$p.img" "/dev/block/mapper/${p}_a"
done
write /tmp/selene-vbmeta_a-noverify.img /dev/block/by-name/vbmeta_a
echo "Done. /data was not touched."
