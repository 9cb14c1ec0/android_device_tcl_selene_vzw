#!/bin/bash
# Build a flashable vendor_boot for selene_vzw that mirrors the stock layout:
# header v4, stock DTB / offsets / cmdline, and ONE unnamed platform ramdisk
# fragment (legacy lz4) containing
#   - the TWRP recovery root (replaces stock recovery), plus
#   - stock first_stage_ramdisk/  (normal Android first stage: fstab, snapuserd)
#   - stock lib/modules/          (modules.load + modules.load.recovery: panel,
#                                  touch, etc. loaded by first-stage init)
# Normal boot therefore keeps working with this image flashed.
#
# Usage (from the tree root, after `m vendorbootimage`):
#   device/tcl/selene_vzw/repack-stock-vendor-boot.sh            # TWRP image
#   device/tcl/selene_vzw/repack-stock-vendor-boot.sh --stock    # round-trip
#        the unmodified stock ramdisk through this pipeline (validates that
#        LK accepts our mkbootimg/avbtool output before risking TWRP)
#   --enforcing    omit the default bring-up androidboot.selinux=permissive
#                  on the vendor cmdline (only honoured by TWRP's eng init;
#                  stock user init in normal boot ignores it). LK drops the
#                  vendor bootconfig section, so the cmdline is used.
set -euo pipefail

mode=twrp
permissive=1
for arg in "$@"; do
    case $arg in
        --stock) mode=stock ;;
        --permissive) permissive=1 ;;
        --enforcing) permissive=0 ;;
        *) echo "unknown arg $arg" >&2; exit 2 ;;
    esac
done

if [ -n "${ANDROID_BUILD_TOP:-}" ]; then
    top=$ANDROID_BUILD_TOP
else
    top=$(cd "$(dirname "$0")/../../.." && pwd)
fi
device=$top/device/tcl/selene_vzw
product=$top/out/target/product/selene_vzw
work=$product/selene-repack
rm -rf "$work"; mkdir -p "$work"

mkbootimg="python3 $top/system/tools/mkbootimg/mkbootimg.py"
avbtool="python3 $top/external/avb/avbtool.py"

lz4 -dc "$device/prebuilt/stock_vendor_ramdisk.cpio.lz4" > "$work/stock.cpio"

if [ "$mode" = stock ]; then
    cp "$work/stock.cpio" "$work/merged.cpio"
    output=$product/vendor_boot-stock-roundtrip.img
else
    twrp_frag=$product/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4
    if [ -f "$twrp_frag" ]; then
        lz4 -dc "$twrp_frag" > "$work/twrp.cpio"
    else
        # Fall back to packing the assembled recovery root ourselves.
        test -d "$product/recovery/root"
        "$top/out/host/linux-x86/bin/mkbootfs" "$product/recovery/root" > "$work/twrp.cpio"
    fi
    python3 "$device/merge-cpio.py" "$work/merged.cpio" "$work/stock.cpio" \
        --keep first_stage_ramdisk --keep lib "$work/twrp.cpio"
    output=$product/vendor_boot-twrp-selene_vzw.img
fi

if [ "$mode" = stock ]; then
    # Byte-identical stock ramdisk: output should equal vendor_boot_a.bin.
    cp "$device/prebuilt/stock_vendor_ramdisk.cpio.lz4" "$work/ramdisk.lz4"
else
    # The kernel's initramfs unpacker only understands legacy-frame lz4.
    lz4 -l -12 --favor-decSpeed -f "$work/merged.cpio" "$work/ramdisk.lz4" >/dev/null
fi

vendor_cmdline='bootopt=64S3,32N2,64N2'
if [ "$permissive" = 1 ] && [ "$mode" != stock ]; then
    vendor_cmdline="$vendor_cmdline androidboot.selinux=permissive"
fi

# Values from unpack_bootimg --format=mkbootimg on stock vendor_boot_a.
$mkbootimg \
    --header_version 4 \
    --pagesize 0x00001000 \
    --base 0x00000000 \
    --kernel_offset 0x40000000 \
    --ramdisk_offset 0x66f00000 \
    --tags_offset 0x47c80000 \
    --dtb_offset 0x0000000047c80000 \
    --vendor_cmdline "$vendor_cmdline" \
    --board '' \
    --dtb "$device/prebuilt/dtb.img" \
    --ramdisk_type 1 --ramdisk_name '' \
    --vendor_ramdisk_fragment "$work/ramdisk.lz4" \
    --vendor_boot "$work/vendor_boot-unsigned.img"

cp "$work/vendor_boot-unsigned.img" "$output"
# Same salt/prop as stock. The digest will not match vbmeta_a; with the
# bootloader unlocked (orange) LK warns but continues.
$avbtool add_hash_footer \
    --image "$output" \
    --partition_name vendor_boot \
    --partition_size 67108864 \
    --internal_release_string 'avbtool 1.2.0' \
    --hash_algorithm sha256 \
    --salt e23b1210c5e8b6ec460eed4c728d50060d0b6dc46c370bf7aaec4d1431903d89 \
    --prop 'com.android.build.vendor_boot.fingerprint:alps/hal_mgvi_64_armv82/mgvi_64_armv82:13/TP1A.220624.014/4PEN:user/release-keys'

ls -l "$output"
sha256sum "$output"
