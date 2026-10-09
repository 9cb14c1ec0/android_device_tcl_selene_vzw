#!/bin/sh
# Called from BOARD_RECOVERY_IMAGE_PREPARE after the recovery root is
# assembled and before mkbootfs. Report the same OS version / patch level
# as the installed Android (system build.prop: release 15, patch
# 2026-05-05) so the Trustonic KeyMint TA accepts the existing key blobs
# without trying to upgrade them.
set -eu
root=${1:?}
prop=$root/prop.default
test -f "$prop"
sed -i \
    -e 's/^ro.build.version.release=.*/ro.build.version.release=15/' \
    -e 's/^ro.build.version.release_or_codename=.*/ro.build.version.release_or_codename=15/' \
    -e 's/^ro.build.version.security_patch=.*/ro.build.version.security_patch=2026-05-05/' \
    "$prop"
# Bring-up: adb without RSA authorization, as root, from early boot.
for p in ro.crypto.state=encrypted ro.crypto.type=file ro.adb.secure=0 persist.sys.usb.config=adb \
         ro.hardware.gatekeeper=trustonic ro.hardware.kmsetkey=trustonic \
         ro.vendor.build.security_patch=2026-05-05 ro.vendor.mtk_trustonic_tee_support=1; do
    n=${p%%=*}
    if grep -q "^${n}=" "$prop"; then sed -i "s/^${n}=.*/${p}/" "$prop"; else printf '%s\n' "$p" >> "$prop"; fi
done
