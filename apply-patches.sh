#!/bin/sh
# Apply the small generic platform fixes used by this port (taken from the
# TB305FU clove_row_wifi TWRP 14.1 port; device-specific crypto hunks dropped).
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
apply_one bootable/recovery bootable_recovery.patch
# build/make: do not rsync a host vendor/ over the recovery ramdisk vendor dir.
apply_one build/make build_make.patch
echo "all patches applied"
