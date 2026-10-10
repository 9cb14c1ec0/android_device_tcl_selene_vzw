#!/bin/bash
# Full stock-policy port cycle: baseline build without this tree's vendor
# policy -> port -> restore hand-written fixups -> build the final policy.
set -e
HERE=$(cd "$(dirname "$0")" && pwd); TOP=$(cd "$HERE/../../../.." && pwd)
SEP=$HERE/../sepolicy/vendor; KEEP=$(mktemp -d)
cp "$SEP"/stock_port_fixups.te "$KEEP"/
rm -f "$SEP"/*
build() { (cd "$TOP" && source build/envsetup.sh >/dev/null 2>&1 && \
    lunch lineage_selene_vzw-bp1a-userdebug >/dev/null 2>&1 && m selinux_policy "$@"); }
trap 'cp -n "$KEEP"/stock_port_fixups.te "$SEP"/' EXIT
build > "${LOG_DIR:-/tmp}/sepolicy-baseline.log" 2>&1 || { echo "baseline build failed"; exit 1; }
"$HERE/sepolicy-port.sh"
cp "$KEEP"/stock_port_fixups.te "$SEP"/
build > "${LOG_DIR:-/tmp}/sepolicy-final.log" 2>&1 && echo "policy OK" || { echo "policy build failed: ${LOG_DIR:-/tmp}/sepolicy-final.log"; exit 1; }
