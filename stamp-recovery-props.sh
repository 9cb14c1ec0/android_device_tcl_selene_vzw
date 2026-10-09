#!/bin/sh
# Called from BOARD_RECOVERY_IMAGE_PREPARE after the recovery root is
# assembled and before mkbootfs. Stamp the stock recovery's reported OS
# version / security patch (prop.default of stock vendor_boot_a:
# release 13, patch 2026-05-05) so a future TEE keymaster sees the values
# it expects. Harmless while TW_INCLUDE_CRYPTO is off.
set -eu
root=${1:?}
prop=$root/prop.default
test -f "$prop"
sed -i \
    -e 's/^ro.build.version.release=.*/ro.build.version.release=13/' \
    -e 's/^ro.build.version.release_or_codename=.*/ro.build.version.release_or_codename=13/' \
    -e 's/^ro.build.version.security_patch=.*/ro.build.version.security_patch=2026-05-05/' \
    "$prop"
for p in ro.crypto.state=encrypted ro.crypto.type=file; do
    n=${p%%=*}
    if grep -q "^${n}=" "$prop"; then sed -i "s/^${n}=.*/${p}/" "$prop"; else printf '%s\n' "$p" >> "$prop"; fi
done
