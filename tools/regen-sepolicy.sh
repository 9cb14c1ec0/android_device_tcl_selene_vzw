#!/bin/bash
# Full stock-policy port cycle: baseline build without this tree's vendor
# policy -> port -> restore hand-written fixups -> build the final policy.
set -e
HERE=$(cd "$(dirname "$0")" && pwd); TOP=$(cd "$HERE/../../../.." && pwd)
SEP=$HERE/../sepolicy/vendor; DEV=$HERE/../sepolicy/device; KEEP=$(mktemp -d)
cp "$SEP"/stock_port_fixups.te "$KEEP"/
rm -f "$SEP"/*
# Hand-written device policy references ported types; park it for the baseline.
mv "$DEV" "$KEEP"/device
build() { (cd "$TOP" && source build/envsetup.sh >/dev/null 2>&1 && \
    lunch lineage_selene_vzw-bp4a-userdebug >/dev/null 2>&1 && m selinux_policy "$@"); }
trap 'cp -n "$KEEP"/stock_port_fixups.te "$SEP"/; [ -d "$DEV" ] || mv "$KEEP"/device "$DEV"' EXIT
build > "${LOG_DIR:-/tmp}/sepolicy-baseline.log" 2>&1 || { echo "baseline build failed"; exit 1; }
"$HERE/sepolicy-port.sh"
cp "$KEEP"/stock_port_fixups.te "$SEP"/
mv "$KEEP"/device "$DEV"
build > "${LOG_DIR:-/tmp}/sepolicy-final.log" 2>&1 && echo "policy OK" || { echo "policy build failed: ${LOG_DIR:-/tmp}/sepolicy-final.log"; exit 1; }
