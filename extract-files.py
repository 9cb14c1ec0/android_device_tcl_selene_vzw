#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Extracts proprietary blobs for selene_vzw into vendor/tcl/selene_vzw.
#
# Source: a directory holding the extracted stock vendor partition
# (<dump>/vendor/...), made with
#   fsck.erofs --extract=<dump>/vendor vendor_a.img
# from /dev/block/mapper/vendor_a pulled in TWRP. Then:
#   ./extract-files.py <dump>
#

import os

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.fixups_lib import (
    lib_fixups,
    lib_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'device/tcl/selene_vzw',
]

# Stock blobs that share a name with an AOSP source module are kept as
# prebuilts named <lib>_vendor (tools/copy-only-libs.txt, MODULE_SUFFIX in
# proprietary-files.txt); point blob dependencies at those, so the build does
# not also install its own Android 15 builds of them.
with open(os.path.join(os.path.dirname(__file__), 'tools', 'copy-only-libs.txt')) as f:
    copy_only_libs = tuple(f.read().split())


def lib_fixup_vendor_suffix(lib: str, partition: str, *args, **kwargs):
    return f'{lib}_{partition}' if partition == 'vendor' else None


lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
    copy_only_libs: lib_fixup_vendor_suffix,
}

blob_fixups: blob_fixups_user_type = {
    # libui (Android 16) uses android.hardware.graphics.common-V7; a process
    # may only link one version of an AIDL interface. V7 is a superset of V3.
    (
        'vendor/lib/vendor.mediatek.hardware.pq_aidl-V1-ndk.so',
        'vendor/lib64/vendor.mediatek.hardware.pq_aidl-V1-ndk.so',
    ): blob_fixup()
        .replace_needed('android.hardware.graphics.common-V3-ndk.so', 'android.hardware.graphics.common-V7-ndk.so'),
    (
        'vendor/lib64/libcodec2_vpp_AIMEMC_plugin.so',
        'vendor/lib64/libcodec2_vpp_AISR_plugin.so',
    ): blob_fixup()
        .replace_needed('android.hardware.graphics.common-V3-ndk.so', 'android.hardware.graphics.common-V7-ndk.so')
        .replace_needed('android.hardware.graphics.allocator-V1-ndk.so', 'android.hardware.graphics.allocator-V2-ndk.so')
        .replace_needed('libstagefright_foundation.so', 'libstagefright_foundation-v33.so'),
    # host_init_verifier rejects `interface` lines for MediaTek HIDL
    # interfaces that are not defined in this source tree; they only matter
    # for lazy (on-demand) starts, and these services start by class.
    (
        'vendor/etc/init/atcid.rc',
        'vendor/etc/init/dmc_core.rc',
        'vendor/etc/init/loghidlvendorservice.rc',
        'vendor/etc/init/md_monitor.rc',
        'vendor/etc/init/vendor.mediatek.hardware.aee@1.1-service.rc',
        'vendor/etc/init/vendor.mediatek.hardware.mmagent@1.1-service.rc',
        'vendor/etc/init/vendor.mediatek.hardware.mms@1.7-service.rc',
    ): blob_fixup()
        .regex_replace(r'\n\s*interface vendor\.mediatek\.hardware\.[^\n]*', ''),
    # Android 15 libbase dropped Trim(const std::string&) (now string_view).
    (
        'vendor/bin/dmabuf_dump',
        'vendor/bin/hw/android.hardware.health-service.example',
        'vendor/bin/hw/android.hardware.usb-aidl-service.mediatekv1.0',
        'vendor/lib/hw/android.hardware.boot@1.0-impl-1.2-mtkimpl.so',
        'vendor/lib64/hw/android.hardware.boot@1.0-impl-1.2-mtkimpl.so',
        'vendor/lib/libnvram.so',
        'vendor/lib64/libnvram.so',
    ): blob_fixup()
        .add_needed('libbase_shim.so'),
    # Android 15 libprocessgroup changed the SetTaskProfiles signature.
    'vendor/lib64/hw/hwcomposer.mtk_common.so': blob_fixup()
        .add_needed('libprocessgroup_shim.so'),
    # IRemotelyProvisionedComponent moved from keymint to the rkp interface;
    # rkp V2 is the RKP version keymint V2 shipped with.
    'vendor/bin/hw/android.hardware.security.keymint@2.0-service.trustonic': blob_fixup()
        .add_needed('android.hardware.security.rkp-V2-ndk.so'),
    # Android 15 BoringSSL: sk_dup -> OPENSSL_sk_dup, CBS_init inline.
    (
        'vendor/bin/hw/wpa_supplicant',
        'vendor/bin/hw/hostapd',
        'vendor/bin/hs20-osu-client',
    ): blob_fixup()
        .add_needed('libcrypto_shim_selene.so'),
    # Android 15 libui dropped the GraphicBufferMapper::lock/unlock overloads
    # the A13 codec2/OMX libraries use.
    (
        'vendor/lib/libcodec2_vndk.so',
        'vendor/lib64/libcodec2_vndk.so',
        'vendor/lib/libstagefright_softomx.so',
        'vendor/lib64/libstagefright_softomx.so',
    ): blob_fixup()
        .add_needed('libui_shim.so')
        .replace_needed('libstagefright_foundation.so', 'libstagefright_foundation-v33.so'),
    # Android 15 libstagefright_foundation changed the AHandler/ALooper ABI
    # (MTK venc deadlocks in AHandler::deliverMessage); stock blobs use the
    # Android 13 build from hardware/lineage/compat.
    (
        'vendor/lib64/hw/sensors.mediatek.V2.0.so',
        'vendor/lib64/libaudioclient_aidl_conversion.so',
        'vendor/lib64/libcamera2ndk_vendor.so',
        'vendor/lib64/libcodec2_mtk_c2store.so',
        'vendor/lib64/libcodec2_mtk_vdec.so',
        'vendor/lib64/libcodec2_mtk_venc.so',
        'vendor/lib64/libcodec2_soft_common.so',
        'vendor/lib64/libcodec2_soft_mtk_alacdec.so',
        'vendor/lib64/libcodec2_soft_mtk_imaadpcmdec.so',
        'vendor/lib64/libcodec2_soft_mtk_mp3dec.so',
        'vendor/lib64/libcodec2_soft_mtk_msadpcmdec.so',
        'vendor/lib64/libcodec2_vpp_mi_plugin.so',
        'vendor/lib64/libcodec2_vpp_qt_plugin.so',
        'vendor/lib64/libcodec2_vpp_rs_plugin.so',
        'vendor/lib64/libsfplugin_ccodec_utils.so',
        'vendor/lib/libaudioclient_aidl_conversion.so',
        'vendor/lib/libcodec2_mtk_c2store.so',
        'vendor/lib/libcodec2_mtk_vdec.so',
        'vendor/lib/libcodec2_mtk_venc.so',
        'vendor/lib/libcodec2_soft_common.so',
        'vendor/lib/libcodec2_soft_mtk_alacdec.so',
        'vendor/lib/libcodec2_soft_mtk_imaadpcmdec.so',
        'vendor/lib/libcodec2_soft_mtk_mp3dec.so',
        'vendor/lib/libcodec2_soft_mtk_msadpcmdec.so',
        'vendor/lib/libcodec2_vpp_mi_plugin.so',
        'vendor/lib/libcodec2_vpp_qt_plugin.so',
        'vendor/lib/libcodec2_vpp_rs_plugin.so',
        'vendor/lib/libsfplugin_ccodec_utils.so',
        'vendor/lib/libstagefright_soft_aacdec.so',
        'vendor/lib/libstagefright_soft_aacenc.so',
        'vendor/lib/libstagefright_soft_amrdec.so',
        'vendor/lib/libstagefright_soft_amrnbenc.so',
        'vendor/lib/libstagefright_soft_amrwbenc.so',
        'vendor/lib/libstagefright_soft_avcdec.so',
        'vendor/lib/libstagefright_soft_avcenc.so',
        'vendor/lib/libstagefright_soft_flacdec.so',
        'vendor/lib/libstagefright_soft_flacenc.so',
        'vendor/lib/libstagefright_soft_g711dec.so',
        'vendor/lib/libstagefright_soft_gsmdec.so',
        'vendor/lib/libstagefright_soft_hevcdec.so',
        'vendor/lib/libstagefright_soft_mp3dec.so',
        'vendor/lib/libstagefright_soft_mpeg2dec.so',
        'vendor/lib/libstagefright_soft_mpeg4dec.so',
        'vendor/lib/libstagefright_soft_mpeg4enc.so',
        'vendor/lib/libstagefright_softomx_plugin.so',
        'vendor/lib/libstagefright_soft_opusdec.so',
        'vendor/lib/libstagefright_soft_rawdec.so',
        'vendor/lib/libstagefright_soft_vorbisdec.so',
        'vendor/lib/libstagefright_soft_vpxdec.so',
        'vendor/lib/libstagefright_soft_vpxenc.so',
    ): blob_fixup()
        .replace_needed('libstagefright_foundation.so', 'libstagefright_foundation-v33.so'),
}  # fmt: skip

module = ExtractUtilsModule(
    'selene_vzw',
    'tcl',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
)

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()
