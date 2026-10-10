#!/bin/bash
# Offline VINTF check of the built images (same libvintf as the device).
T=$(cd "$(dirname "$0")/../../../.." && pwd); O=$T/out/target/product/selene_vzw
# Check the packed image, not the staging dir (stale files there mislead).
V=$(mktemp -d); trap "rm -rf $V" EXIT; fsck.erofs --extract=$V $O/vendor.img >/dev/null
"$T/out/host/linux-x86/bin/checkvintf" --check-compat \
    --dirmap /system:$O/system --dirmap /system_ext:$O/system_ext \
    --dirmap /product:$O/product --dirmap /vendor:$V --dirmap /odm:$V/odm \
    --dirmap /apex:/nonexistent \
    --property ro.product.first_api_level=33 \
    --property ro.boot.product.hardware.sku=8189SVZW-1Svzw_dsds 2>&1 |
    grep -E "error|ERROR|Conflict|INCOMPATIBLE|COMPATIBLE|cannot|Cannot" | sort -u
