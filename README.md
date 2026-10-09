# TWRP 14.1 device tree — TCL Tab 8 NxtPaper 5G (8189S / selene_vzw)

Verizon TCL TAB 8 NXTPAPER 5G, MediaTek MT6835, eMMC, A/B + Virtual A/B
(compression, userspace snapshots), dynamic partitions (super = 10 GiB).
Android 15 system on an Android 13 (TP1A, `4PEN`) vendor with an
**android13-5.15** GKI kernel (vermagic `5.15.180-android13-8`).

Status: **bring-up scaffold** — not yet booted on hardware.

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

```bash
cd /home/android/tcltab8attempt2/twrp-14.1
device/tcl/selene_vzw/apply-patches.sh      # once
export ALLOW_MISSING_DEPENDENCIES=true
. build/envsetup.sh
lunch twrp_selene_vzw-ap2a-eng
m vendorbootimage -j$(nproc)
device/tcl/selene_vzw/repack-stock-vendor-boot.sh
# -> out/target/product/selene_vzw/vendor_boot-twrp-selene_vzw.img
```

`m vendorbootimage` alone is not the flashable image.

## Flash (slot A only, via mtkclient — no fastboot on this build)

```bash
device/tcl/selene_vzw/flash-vendor-boot-mtk.sh out/target/product/selene_vzw/vendor_boot-twrp-selene_vzw.img
# restore:
device/tcl/selene_vzw/flash-vendor-boot-mtk.sh --restore
```

Start the script with the device in Android, then `adb reboot bootloader`
so the ~4 s preloader window is caught. Afterwards force-reboot
(Power+VolUp ~12 s), then `adb reboot recovery`.

The vendor_boot digest in `vbmeta_a` will not match. With the bootloader
unlocked (orange state) LK should warn and continue; if it refuses, the next
step is a vbmeta with verification disabled.

Suggested order on hardware:
1. flash `vendor_boot-stock-roundtrip.img` (== stock) — trivially safe, proves the flashing path;
2. flash the TWRP image, confirm **normal Android still boots**;
3. `adb reboot recovery`.

## Next steps / known gaps

- Confirm `lcd-backlight` `max_brightness` and pixel format (BGRA_8888 is a guess from another MTK DRM port).
- Decryption: `/data` is FBE v2 + metadata encryption on a **Trustonic** TEE
  (`ro.hardware.kmsetkey/gatekeeper=trustonic`). Needs `mcDriverDaemon`,
  the Trustonic keymaster/keymint + gatekeeper HALs and TAs from the vendor
  partition in `super`, then `TW_INCLUDE_CRYPTO := true`.
- SELinux: recovery domain is permissive via `sepolicy/recovery.te`.
  `repack-stock-vendor-boot.sh --permissive` also adds
  `androidboot.selinux=permissive` as vendor bootconfig.
