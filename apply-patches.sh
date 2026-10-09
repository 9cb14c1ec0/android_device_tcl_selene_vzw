#!/bin/sh
# Apply the small generic platform fixes used by this port (taken from the
# TB305FU clove_row_wifi TWRP 14.1 port; its Beanpod-specific sepolicy dropped).
set -eu
top=${ANDROID_BUILD_TOP:-$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)}
patchdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/patches

apply_one() {
    proj=$1; patch=$2
    if git -C "$top/$proj" apply --check "$patchdir/$patch" 2>/dev/null; then
        git -C "$top/$proj" apply "$patchdir/$patch"; echo "applied $patch -> $proj"
    elif git -C "$top/$proj" apply --reverse --check "$patchdir/$patch" 2>/dev/null; then
        echo "already applied $patch"
    else
        echo "FAILED to apply $patch onto $proj" >&2; exit 1
    fi
}

# libpixelflinger: ashmem-backed PROT_EXEC mapping fails on modern kernels.
# minuitwrp/events: keep type-B touch release state.
# Crypto build fixes (ndk lib names, keystore2/keymint-V3 libs, bootstrap
# linker symlink), /dev/block/mapper/userdata fallback, FBE-only paths.
apply_one bootable/recovery bootable_recovery.patch
# vold: AIDL gatekeeper, safe keystore DB copy, FBE-DE diagnostics.
apply_one system/vold system_vold.patch
# logd: do not abort on restart in recovery.
apply_one system/logging system_logging.patch
# keystore2 km_compat: use hwbinder default manager (no VINTF wait).
apply_one system/security system_security.patch
# build/make: do not rsync a host vendor/ over the recovery ramdisk vendor dir.
apply_one build/make build_make.patch
echo "all patches applied"
