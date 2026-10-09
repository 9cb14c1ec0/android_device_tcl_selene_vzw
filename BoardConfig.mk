#
# Copyright (C) 2026 The TWRP Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#
# TCL TAB 8 NXTPAPER 5G (8189S / Selene_VZW), Verizon
# MediaTek MT6835, Android 15 system on an Android 13 (TP1A) vendor,
# android13-5.15 GKI kernel, A/B + Virtual A/B (compression), eMMC.
#
# All boot header values below were read from the stock vendor_boot_a /
# boot_a / init_boot_a images dumped from this device (see README.md).
#

DEVICE_PATH := device/tcl/selene_vzw

BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Architecture (2x Cortex-A76 + 6x Cortex-A55)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_SUPPORTS_64_BIT_APPS := true

# Platform
TARGET_BOARD_PLATFORM := mt6835
TARGET_BOOTLOADER_BOARD_NAME := mt6835
TARGET_NO_BOOTLOADER := true
BOARD_HAS_MTK_HARDWARE := true

# Kernel: stock GKI from boot_a (lz4). Only needed so the build system can
# assemble a vendor_boot; the flashable image is produced by
# repack-stock-vendor-boot.sh and never replaces the boot partition.
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt
BOARD_INCLUDE_DTB_IN_BOOTIMG := true

# Stock vendor_boot v4 header (unpack_bootimg --format=mkbootimg):
#   --pagesize 0x1000 --base 0 --kernel_offset 0x40000000
#   --ramdisk_offset 0x66f00000 --tags_offset 0x47c80000
#   --dtb_offset 0x47c80000 --vendor_cmdline bootopt=64S3,32N2,64N2
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00000000
BOARD_RAMDISK_OFFSET := 0x26f00000
BOARD_KERNEL_TAGS_OFFSET := 0x07c80000
BOARD_TAGS_OFFSET := 0x07c80000
BOARD_DTB_OFFSET := 0x07c80000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_RAMDISK_USE_LZ4 := true
BOARD_MKBOOTIMG_ARGS := \
    --header_version $(BOARD_BOOT_HEADER_VERSION) \
    --pagesize $(BOARD_KERNEL_PAGESIZE) \
    --base $(BOARD_KERNEL_BASE) \
    --kernel_offset $(BOARD_KERNEL_OFFSET) \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) \
    --dtb_offset $(BOARD_DTB_OFFSET)

# Partition sizes (from the GPT / dumped images)
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# Dynamic partitions: super = 10 GiB
BOARD_SUPER_PARTITION_SIZE := 10737418240
BOARD_SUPER_PARTITION_GROUPS := tcl_dynamic_partitions
BOARD_TCL_DYNAMIC_PARTITIONS_SIZE := 10735321088
BOARD_TCL_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    odm_dlkm \
    product \
    system \
    system_dlkm \
    system_ext \
    vendor \
    vendor_dlkm
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := false

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    dtbo \
    init_boot \
    odm_dlkm \
    product \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm
BOARD_USES_METADATA_PARTITION := true

# Recovery lives in vendor_boot (no recovery partition). Stock packs
# recovery + first_stage_ramdisk + /lib/modules as ONE unnamed platform
# fragment; repack-stock-vendor-boot.sh reproduces that layout.
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
TARGET_NO_RECOVERY := true
BOARD_USES_RECOVERY_AS_BOOT := false

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

# SELinux
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
# XBGR8888 scanout: MTK DRM honours per-pixel alpha with ARGB8888 (BGRA),
# which dropped anti-aliased glyph pixels (thin strokes vanished).
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
RECOVERY_SDCARD_ON_DATA := true
BOARD_SUPPRESS_SECURE_ERASE := true

# Stock recovery reports OS 13 / patch 2026-05-05 in prop.default.
# Matters once Trustonic keymaster/FBE decryption is attempted; it is
# stamped at ramdisk prepare time instead of touching PLATFORM_* here.
VENDOR_SECURITY_PATCH := 2026-05-05
BOOT_SECURITY_PATCH := 2026-05-05
BOARD_RECOVERY_IMAGE_PREPARE = $(DEVICE_PATH)/stamp-recovery-props.sh $(TARGET_RECOVERY_ROOT_OUT)

# TWRP: display 800x1340, density 240, MediaTek DRM
TW_THEME := portrait_hdpi
TARGET_SCREEN_WIDTH := 800
TARGET_SCREEN_HEIGHT := 1340
TW_FRAMERATE := 60
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
# Live sysfs max_brightness is 4095 (DT says 0x7ff; driver rescales).
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 2400
TW_NO_SCREEN_BLANK := true
TW_EXTRA_LANGUAGES := true
TW_DEVICE_VERSION := selene_vzw-8189S
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true

# Touch + panel drivers are loaded by first-stage init from the stock
# /lib/modules/modules.load.recovery (kept by the repack script), the same
# way stock recovery gets them. Do not duplicate them via TW_LOAD_VENDOR_MODULES.

TW_INCLUDE_FASTBOOTD := true
# configfs USB (incl. MTP) from recovery/root/init.recovery.usb.rc
TW_EXCLUDE_DEFAULT_USB_INIT := true
# Bring-up: binding ffs.mtp+ffs.adb drops USB entirely (sideload, adb-only,
# works). Keep adb reliable until MTP can be debugged over adb.
TW_EXCLUDE_MTP := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_LPTOOLS := true
TW_USE_TOOLBOX := true
TW_EXCLUDE_APEX := true
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone0/temp"
TW_BACKUP_EXCLUSIONS := /data/fonts

# Crypto: stock /data is FBE v2 + metadata encryption via Trustonic TEE
# (ro.hardware.kmsetkey/gatekeeper=trustonic). Off for the first boot
# milestone; enabling it needs the Trustonic mcDriverDaemon + keymint/
# keymaster HAL blobs from vendor (see README "Next steps").
TW_INCLUDE_CRYPTO := false

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TWRP_EVENT_LOGGING := false
