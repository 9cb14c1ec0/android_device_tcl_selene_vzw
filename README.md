# LineageOS 23.2 for the TCL Tab 8 NxtPaper 5G (Verizon, 8189S / selene_vzw)

Unofficial LineageOS 23.2 (Android 16) device tree for the Verizon TCL Tab 8
NxtPaper 5G, model `8189S`, codename `Selene_VZW`, MediaTek MT6835.

**Status: daily-usable userdebug build, A/B OTA updates work. 2026-10-19.**

| Area | State |
| --- | --- |
| Boot, FBE + metadata encryption, Trustonic KeyMint/keystore2 | works |
| Display, touch, lights, vibrator | works |
| Wi-Fi (2.4/5 GHz, WPA3-SAE) | works |
| Bluetooth: pairing, A2DP media, HFP calls | works |
| Camera: rear 8 MP / front 5 MP photo, video recording | works (Aperture) |
| Hardware video encode/decode (MTK Codec2, AVC/HEVC) | works |
| Audio: playback, mic recording | works |
| Telephony: VoLTE calls, SMS, mobile data | works (Verizon network, US Mobile SIM in slot 1) |
| eSIM (slot 2 is an eUICC) | detected by OpenEUICC ("eSIM Manager"); profile download not tested |
| Sensors (accelerometer, light, proximity, ...) | works |
| GNSS | HAL starts; outdoor fix not tested |
| A/B OTA (`update_engine`), LineageOS recovery, `adb sideload` | works, both slot directions |
| Face unlock (TCL vendor APEX) | disabled (`configs/vintf/README`) |
| SELinux | enforcing |
| Built-in Updater | no update server configured |

Known issues:

* Cancelling an outgoing call while it is still ringing can take several
  seconds: the modem waits for the network to confirm the cancel, Telecom
  shows "Calling" again after its 5 s timeout, and a second press releases the
  call locally. Answered calls hang up immediately.
* The controller loses the link when a Bluetooth peer that is the link
  central puts it in long sniff intervals (seen with a Yealink WH66, 1.28 s
  sniff, 5 s supervision timeout). Workaround on the device: add the peer to
  `INTEROP_DISABLE_SNIFF` in `/data/misc/bluedroid/interop_database_dynamic.conf`
  while Bluetooth is off.

## What is built

The stock firmware has an Android 15 system (`AP3A.240905.015.A2`) on an
Android 13 vendor (`TP1A.220624.014`, `ro.board.first_api_level=33`, FCM
target level 7) and an android13-5.15 GKI kernel.

The build produces the whole A/B OTA set except the firmware:

| Partition | Source |
| --- | --- |
| `system`, `system_ext`, `product` | this build |
| `vendor` (includes `/vendor/odm`) | this build: stock blobs from [`vendor/tcl/selene_vzw`](https://github.com/9cb14c1ec0/android_vendor_tcl_selene_vzw) plus LineageOS-built vendor modules, sepolicy, VINTF, init and props |
| `boot` (GKI kernel), `dtbo`, `vendor_dlkm`, `odm_dlkm`, `system_dlkm` | stock prebuilts from [`device/tcl/selene_vzw-kernel`](https://github.com/9cb14c1ec0/android_device_tcl_selene_vzw-kernel), re-footered |
| `init_boot` | this build |
| `vendor_boot` | this build: stock first-stage modules and LineageOS recovery (`recovery` ramdisk fragment) |
| `vbmeta`, `vbmeta_system`, `vbmeta_vendor` | this build, signed with the AVB test keys |
| firmware (`preloader`, `lk`, `tee`, `md1img`, `scp`, ...) | stock, **not** in the OTA: both slots must carry the same stock `4PEN` firmware |

The bootloader is unlocked (orange state), so LK boots a `vbmeta` signed with
any key.

Android 16 has no VNDK. The vendor image gets Android 16 vendor variants of
libbase, libutils, libhidlbase and others. The Android 13 blobs link against
those, so ABI breaks have to be handled with `blob_fixups`, for example the
`-v33` libraries from `hardware/lineage/compat` or this tree's `compat/`.
`tools/check-vendor-symbols.py` finds them offline after a build.

## Sources

Besides LineageOS 23.2, `.repo/local_manifests/selene_vzw.xml` adds:

* `device/mediatek/sepolicy_vndr`, `hardware/mediatek` (LineageOS)
* `vendor/mediatek/ims`: MediaTek ImsService adapted to AOSP telephony
* `packages/apps/OpenEUICC` with `lpac`, `cJSON` and `prebuilts/openeuicc-deps`

This tree, `device/tcl/selene_vzw-kernel` and `vendor/tcl/selene_vzw` are
cloned by hand (branch `lineage-23.2`):

```bash
git clone -b lineage-23.2 https://github.com/9cb14c1ec0/android_device_tcl_selene_vzw device/tcl/selene_vzw
git clone -b lineage-23.2 https://github.com/9cb14c1ec0/android_device_tcl_selene_vzw-kernel device/tcl/selene_vzw-kernel
git clone -b lineage-23.2 https://github.com/9cb14c1ec0/android_vendor_tcl_selene_vzw vendor/tcl/selene_vzw
```

## Device-specific pieces

* **Telephony.** MediaTek's `mtkfusionrild` is the RIL (AOSP `rild` is
  disabled in `init.selene.rc`). The tablet telephony config has no dialer
  and the stock RRO turns voice off; `Dialer` and
  `rro_overlays/FrameworksResOverlaySelene` turn calls back on.
  `rro_overlays/CarrierConfigOverlaySelene` drops Verizon's VoLTE provisioning
  requirement (MCC/MNC 311/480 and carrier ID 1839), because the MediaTek
  ImsService reports VoLTE as not provisioned and calls would fall back to CS.
* **Mobile data.** The modem's data policy refuses every PDN except IMS with
  `VZW_DATA_NOT_ALLOWED` until it is told that mobile data is on. Stock does
  that from MediaTek's framework (`IMtkRadioExData::syncDataSettingsToMd`);
  `datasettings/` (`mtk_data_settings`) sends it when rild starts and when a
  SIM card or eSIM profile appears.
* **eSIM.** OpenEUICC is the privileged LPA for the eUICC in slot 2.
* **Bluetooth audio.** The AOSP Bluetooth stack starts A2DP sessions in AOSP's
  `libbluetooth_audio_session_aidl`, but the stock `audio.bluetooth.default`
  waits on MediaTek's copy (stock pairs it with MediaTek's Bluetooth stack).
  The AOSP provider (`android.hardware.bluetooth.audio-impl`, loaded by the
  stock audio service by name), the AOSP A2DP HAL and the session libraries
  are built from source instead of extracted.
* **Recovery and A/B.** MediaTek's AIDL boot HAL and a health HAL live in
  `hal/` (also used in recovery). Switching slots also switches the eMMC boot
  area (`preloader_a`/`preloader_b`).
* **`/oem`.** The `oem` partition is not built (fsgen rejects the name); its
  files ship in `/vendor/etc/oem` and are bind-mounted on `/oem`.

## Blob handling (`proprietary-files.txt`)

`proprietary-files.txt` is generated by `tools/gen-proprietary-files.py` from
an extracted stock vendor:

* **Everything** in stock `/vendor` is a blob, except what the build provides:
  * sepolicy, VINTF, `build.prop`, fs_config, passwd/group;
  * toybox, sh, vndservicemanager;
  * init rc, fstab and ueventd files (stock copies live in `rootdir/etc`);
  * the RRO APKs (`prebuilt/overlay`, installed as `prebuilt_overlay`
    modules, since APKs are not allowed in `PRODUCT_COPY_FILES`).
* `tools/exclude-libs.txt` lists stock libraries the build provides itself:
  * AOSP HIDL/AIDL interface libraries (stable ABI);
  * generic AOSP modules that `base_vendor.mk` / `handheld_vendor.mk` install
    anyway (soundfx, `*.default` HALs, libril, clearkey plugins, ...);
  * the Bluetooth audio provider, A2DP HAL and session libraries (see above).
* `tools/copy-only-libs.txt` lists stock blobs that share a name with an AOSP
  source module but must stay stock. Examples: implementation libraries such
  as libcodec2_*, libaudiofoundation, the unstable `*-aidl-cpp` libraries,
  MTK's `libwifi-hal`, hostapd and wpa_supplicant. They become
  `<name>_vendor` prebuilts (`MODULE_SUFFIX`, same file name on device), and
  `lib_fixups` in `extract-files.py` points blob dependencies at them.
* Stock HAL services whose AOSP namesakes would install to the same path are
  renamed `-v33` (`RENAME` in `tools/gen-proprietary-files.py`).

ABI fixups (`extract-files.py`, from on-device `CANNOT LINK` errors and
`tools/check-vendor-symbols.py`):

* `libstagefright_foundation-v33` for every stock blob linking
  libstagefright_foundation (A15 changed the AHandler ABI; MTK venc deadlocked)
* codec2 `-v33` compat libraries and the codec2 seccomp policy (`uname`,
  `sysinfo`)
* `libtinyxml2-v34` for the power and audio HALs (Android 16 changed the
  tinyxml2 layout)
* `libui_shim` (old GraphicBufferMapper::lock/unlock) for codec2/OMX libs
* `libcrypto_shim_selene` (this tree: `sk_dup`, `CBS_init`) for
  wpa_supplicant/hostapd/hs20-osu-client
* `libbase_shim`, `libprocessgroup_shim`, keymint + `rkp-V2-ndk`
* `vendor-linker.config.json` requires libandroidicu (camera/RenderScript)

`blob_fixups`: blobs that use `android.hardware.graphics.common-V3` or
`graphics.allocator-V1` are moved to V6 / V2, because a process may only link
one version of an AIDL interface and the platform libui uses V6.

Extract:

```bash
# stock vendor: dd /dev/block/mapper/vendor_a (stock), then
fsck.erofs --extract=<dump>/vendor vendor_a.img
python3 tools/gen-proprietary-files.py <dump> > proprietary-files.txt
./extract-files.py <dump>
```

Re-extracting touches every blob, so the next build is close to a full
rebuild.

## VINTF

`configs/vintf` holds the stock device manifest and fragments, minus HALs that
the build provides with its own fragments (duplicates leave servicemanager
without a device manifest and the device hangs at the boot logo).
`tools/check-vintf.sh` validates the packed `vendor.img` offline; always check
the image, not `out/` staging, which can hold stale fragments
(`m installclean` clears them).

## SELinux

The policy is LineageOS `device/mediatek/sepolicy_vndr` (legacy mode, because
the A13 blobs use non-namespaced vendor properties) plus the rest of the stock
TCL vendor policy:

* `sepolicy/vendor/stock_port.te` and the stock contexts are generated by
  `tools/regen-sepolicy.sh`. It builds a baseline policy, runs
  `tools/sepolicy_port.py` (stock types are versioned `_33_0`), and merges
  every stock context line whose type exists and whose path is not already
  labeled (`tools/merge_stock_contexts.py`). This brings in, for example, the
  `hal_keymint_default_exec` label for
  `android.hardware.security.keymint@2.0-service.trustonic`, which
  sepolicy_vndr lacks.
* Where sepolicy_vndr already labels something differently
  (`persist.vendor.powerhal.`), its label wins and the stock rules are
  mirrored onto it.
* `tools/sepolicy-port-drop.txt` holds stock rules that violate platform
  neverallows. `sepolicy/vendor/stock_port_fixups.te` has hand-written
  replacements.

## Building

```bash
source build/envsetup.sh
lunch lineage_selene_vzw-bp4a-userdebug
m bacon
```

Output: `out/target/product/selene_vzw/lineage-23.2-<date>-UNOFFICIAL-selene_vzw.zip`
(A/B OTA package, also usable with `adb sideload`).

## Installing and updating

The device has no usable fastboot.

**Updating a running build** (writes the inactive slot; the current slot stays
as the fallback):

* from LineageOS recovery: `adb reboot sideload`, then
  `adb sideload lineage-23.2-*.zip`;
* or from Android on userdebug builds, with root adb:

  ```bash
  adb push lineage-23.2-*.zip /data/ota_package/update.zip
  # offset/size of payload.bin inside the zip; headers = payload_properties.txt
  adb shell update_engine_client --update --follow \
      --payload=file:///data/ota_package/update.zip \
      --offset=<offset> --size=<size> --headers="<payload_properties.txt>"
  adb reboot
  ```

**First install from stock** needs a way to write `vendor_boot` (the
[TWRP port](https://github.com/9cb14c1ec0/android_device_tcl_selene_vzw) or a
MediaTek DA tool): write this build's `vendor_boot.img` to the active slot,
boot to recovery, `adb sideload` the zip and format data. (This exact
sequence from stock has not been tested end to end; this device was moved
over from an earlier TWRP-installed build.) Stock and LineageOS
keys are not compatible: after the first boot of this build KeyMint upgrades
its keys, so a stock slot can no longer decrypt `/data`.

Keep full stock backups (all `_a`/`_b` physical partitions, the eMMC boot
areas, `super`) before the first install. `tools/install-slot-a.sh` and
`tools/restore-stock-slot-a.sh` are from the Android 15 TWRP-based install and
are obsolete: they write a patched stock `vbmeta_a` over this build's.

## Notes

* **Stale Virtual A/B COW partitions.** The stock slot-A super metadata still
  listed `*_a-cow` partitions from a stock OTA, but `/metadata/ota` had no
  snapshot state (it was wiped at bootloader unlock). Raw-extent dumps of
  `super` taken around that OTA are **not** usable for
  system/system_ext/product; back up from `/dev/block/mapper/*_a` instead.
* `ro.boot.product.hardware.sku=8189SVZW-1Svzw_dsds` selects the per-SKU ODM
  VINTF manifest (radio slots).
* After a live carrier config change, the MediaTek IMS stack needs a radio
  cycle (airplane mode) to re-register with voice.
