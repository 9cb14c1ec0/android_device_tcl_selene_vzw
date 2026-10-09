# TWRP 14.1 device tree — TCL Tab 8 NxtPaper 5G (8189S / selene_vzw)

Verizon TCL TAB 8 NXTPAPER 5G, MediaTek MT6835, eMMC, A/B + Virtual A/B
(compression, userspace snapshots), dynamic partitions (super = 10 GiB).
Android 15 system on an Android 13 (TP1A, `4PEN`) vendor with an
**android13-5.15** GKI kernel (vermagic `5.15.180-android13-8`).

Status: **boots on hardware** (vendor_boot_a). Working: display (DRM,
XBGR8888), touch, early unauthenticated root adb, Trustonic TEE + KeyMint 2
+ Gatekeeper + keystore2, **automatic FBE v2 + metadata decryption** (no
lock screen; PIN/pattern untested). MTP is disabled for bring-up. SELinux is
permissive in recovery via the vendor cmdline (Android stays enforcing).

## Boot layout (read from the dumped stock images)

| Image | Notes |
| --- | --- |
| `boot_a` | v4, GKI kernel only (lz4), no ramdisk |
| `init_boot_a` | v4, generic ramdisk: `/init`, `snapuserd`, ramdisk `build.prop` |
| `vendor_boot_a` | v4, DTB, cmdline `bootopt=64S3,32N2,64N2`, **one** unnamed platform ramdisk (legacy lz4) |

There is no recovery partition. The single vendor ramdisk is the stock
recovery root plus `first_stage_ramdisk/` (normal-boot fstab, snapuserd,
fsck tools) and `lib/modules/` (219 modules; `modules.load.recovery` already
lists the panel drivers and the Novatek/Chipone/ICNL9951C/GT9896S touch
drivers). LK appends the `init_boot` ramdisk after it. Recovery vs normal
boot is decided by first-stage init (`force_normal_boot`).

`repack-stock-vendor-boot.sh` keeps that exact layout and swaps only the
recovery root for TWRP's. Normal Android boot keeps working with the TWRP
image flashed, and TWRP gets display + touch from stock first-stage module
loading.

Pipeline check: `repack-stock-vendor-boot.sh --stock` rebuilds
`vendor_boot_a.bin` **byte-for-byte** (same header, DTB, AVB footer), so the
mkbootimg/avbtool parameters are exactly stock.

## Build

Uses the minimal TWRP 14.1 manifest. ~150 GB free disk recommended.

```bash
mkdir twrp-14.1 && cd twrp-14.1
repo init --depth=1 \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git \
  -b twrp-14.1
repo sync -c -j$(nproc)
git clone https://github.com/9cb14c1ec0/android_device_tcl_selene_vzw.git \
  device/tcl/selene_vzw

device/tcl/selene_vzw/apply-patches.sh      # once (bootable/recovery, vold, logd, keystore2, build)
export ALLOW_MISSING_DEPENDENCIES=true
. build/envsetup.sh
lunch twrp_selene_vzw-ap2a-eng              # do not pipe lunch; the env is lost
m vendorbootimage -j$(nproc)
device/tcl/selene_vzw/repack-stock-vendor-boot.sh
# -> out/target/product/selene_vzw/vendor_boot-twrp-selene_vzw.img
```

`m vendorbootimage` alone is not the flashable image; the repack script
merges TWRP's recovery root into the stock vendor ramdisk layout, packs it
with the stock header/DTB/cmdline and adds the stock-format AVB footer.
`--enforcing` omits the bring-up `androidboot.selinux=permissive` cmdline.

If you change libraries that TWRP copies into the recovery root (e.g. the
pixel format in `libminuitwrp`), delete
`out/target/product/selene_vzw/recovery/root/relink_*-timestamp` first;
TWRP's copy step does not track library changes.

## Flash

**Slot A only.** The bootloader must be unlocked (orange state). Keep a
dump of your stock `vendor_boot_a` (and ideally `vbmeta_a`) before
flashing anything. The vendor_boot digest in `vbmeta_a` will not match;
unlocked LK warns and continues.

### From a running TWRP (simplest)

```bash
device/tcl/selene_vzw/flash-vendor-boot-twrp.sh \
  out/target/product/selene_vzw/vendor_boot-twrp-selene_vzw.img
```

Pushes the image, writes `vendor_boot_a` with `dd`, verifies it by reading
it back, and reboots to recovery.

### First install (no TWRP yet): mtkclient

This carrier build has no usable fastboot. `flash-vendor-boot-mtk.sh`
writes `vendor_boot_a` through mtkclient's DA. On this SoC the DA requires
an SLA bypass; set `RUNNER` to a wrapper that applies it (see the script
header for `STOCK`, `MTKCLIENT`, `PY`, `RUNNER`).

```bash
STOCK=/path/to/vendor_boot_a.bin \
  device/tcl/selene_vzw/flash-vendor-boot-mtk.sh out/target/product/selene_vzw/vendor_boot-twrp-selene_vzw.img
# restore stock:
STOCK=/path/to/vendor_boot_a.bin device/tcl/selene_vzw/flash-vendor-boot-mtk.sh --restore
```

Start the script with the device in Android, then `adb reboot bootloader`
so the ~4 s preloader window is caught. Afterwards force-reboot
(Power+VolUp ~12 s), confirm Android still boots, then `adb reboot recovery`.

ADB in recovery is root and unauthenticated from early boot (~14 s), so it
works even if the UI does not.

## Decryption notes

- Runtime fstab is vendor `fstab.emmc` (`ro.boot.fstab_suffix=emmc`):
  `fileencryption=aes-256-xts:aes-256-cts:v2` (policy flags 0x2). The
  first-stage `fstab.mt6835` says `+inlinecrypt_optimized`; using that makes
  `EnsurePolicy` fail on `/data/system_de/0`.
- `TW_SKIP_ADDITIONAL_FSTAB` is required: TWRP passes the additional fstab
  path to vold as the *zoned device*, moving the metadata key lookup to
  `metadata_encryption/default/key`.
- `prop.default` must report OS 15 / 2026-05-05 (stamp-recovery-props.sh).
- TEE: `/dev/mobicore*` ownership is set in init (no vendor ueventd in
  recovery); mcDriverDaemon uses a tmpfs copy of `persist/mcRegistry`
  (persist is mounted read-only).
- Base `vendor/etc/vintf/manifest.xml` and `system/etc/vintf/manifest.xml`
  must exist or the manifest fragments are ignored.
- TWRP's vold writes "upgraded" key blobs only to `/tmp`; on-disk blobs are
  never rewritten.
- Rebooting with SELinux enforcing hangs (misc write denied); the image is
  permissive so this no longer happens.

## Do not

- Format `/data` or `/metadata` from this TWRP unless you mean to lose
  everything; decryption depends on the existing keys.
- Flash `vendor_boot_b`; slot B is the stock fallback.

## Next steps / known gaps

- Re-enable MTP (ffs.mtp + ffs.adb bind dropped USB).
- PIN/pattern decryption (gatekeeper path) untested.
- Write real sepolicy and drop the permissive cmdline.

## License

See `LICENSE`. Makefiles, scripts, init files and patches are Apache-2.0.
The prebuilt kernel/DTB/vendor ramdisk and the Trustonic/MediaTek/TCL
blobs are proprietary files extracted from stock firmware, redistributed
only so this recovery can be reproduced.

## Credits

Crypto/vold/keystore2/logd patches and the vendor_boot repack approach are
adapted from the TB305FU port
([android_device_lenovo_clove_row_wifi](https://github.com/9cb14c1ec0/android_device_lenovo_clove_row_wifi)).
