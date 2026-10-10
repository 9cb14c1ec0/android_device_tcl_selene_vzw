#!/bin/bash
# Regenerate sepolicy/vendor/{stock_port.te,*_contexts} from the stock TCL
# vendor policy and a BASELINE policy built without this tree's own policy:
#   1. move sepolicy/vendor/* (keep stock_port_fixups.te aside), m selinux_policy
#   2. tools/sepolicy-port.sh
#   3. put stock_port_fixups.te back
# Running it against a policy that already contains the port finds nothing new.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT_PRODUCT=${OUT_PRODUCT:-$HERE/../../../../out/target/product/selene_vzw}
export OUT_PRODUCT PORT_TMP=${PORT_TMP:-/tmp/selene-sepolicy-port}
mkdir -p "$PORT_TMP"
S=$OUT_PRODUCT/system/etc/selinux; SE=$OUT_PRODUCT/system_ext/etc/selinux
P=$OUT_PRODUCT/product/etc/selinux; V=$OUT_PRODUCT/vendor/etc/selinux
decl() { # $1 = type|typeattribute, files...
    local kw=$1; shift
    cat "$@" 2>/dev/null | grep -oE "^\($kw [^ )]+" | awk '{print $2}' | sed -E 's/_202404$//' | sort -u
}
decl type $S/plat_sepolicy.cil $SE/system_ext_sepolicy.cil $P/product_sepolicy.cil $V/vendor_sepolicy.cil $V/plat_pub_versioned.cil > $PORT_TMP/all_types.txt
decl typeattribute $S/plat_sepolicy.cil $SE/system_ext_sepolicy.cil $P/product_sepolicy.cil $V/vendor_sepolicy.cil $V/plat_pub_versioned.cil > $PORT_TMP/all_attrs.txt
# Names the vendor policy may reference: public platform policy + vendor.
( decl type $V/plat_pub_versioned.cil $V/vendor_sepolicy.cil; decl typeattribute $V/plat_pub_versioned.cil $V/vendor_sepolicy.cil ) | sort -u > $PORT_TMP/vis_types.txt
wc -l $PORT_TMP/*.txt
PORT_DROP="$HERE/sepolicy-port-drop.txt" python3 "$HERE/sepolicy_port.py" "$HERE/../sepolicy/vendor"
python3 "$HERE/merge_stock_contexts.py" "${STOCK_SELINUX:-/home/android/tcltab8attempt2/lineage/stock/vendor/etc/selinux}" \
    "$HERE/../sepolicy/vendor" "$PORT_TMP" "$HERE/../../../.."
