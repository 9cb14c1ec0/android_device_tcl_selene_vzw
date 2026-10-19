#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# LineageOS 23.2 (Android 16) for the Verizon TCL Tab 8 NxtPaper 5G
# (8189S / selene_vzw), MediaTek MT6835.
#
# Builds the whole A/B OTA set except the firmware: boot (stock GKI kernel),
# init_boot, vendor_boot (stock first-stage modules + LineageOS recovery),
# dtbo, vbmeta*, the stock dlkm images (prebuilt, re-footered) and
# system/system_ext/product/vendor. The vendor image is rebuilt from the stock
# Android 13 (TP1A, API 33) blobs in vendor/tcl/selene_vzw. See README.md.
#

DEVICE_PATH := device/tcl/selene_vzw

# Architecture (MT6835: 2x Cortex-A78 + 6x Cortex-A55; stock builds for a55)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a55
TARGET_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a55
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_SUPPORTS_64_BIT_APPS := true

# Platform
TARGET_BOARD_PLATFORM := mt6835
TARGET_BOOTLOADER_BOARD_NAME := selene_vzw
TARGET_NO_BOOTLOADER := true

# Stock vendor is frozen at API 33 (ro.board.first_api_level=33, VNDK 33).
BOARD_SHIPPING_API_LEVEL := 33

# Kernel: stock (Google GKI android13-5.15 from boot_a), with the stock DTB,
# DTBO, first-stage modules and dlkm images; all prebuilt in
# device/tcl/selene_vzw-kernel (see its README).
KERNEL_PATH := $(DEVICE_PATH)-kernel
TARGET_NO_KERNEL := false
TARGET_PREBUILT_KERNEL := $(KERNEL_PATH)/Image.lz4
# boot.img is the stock boot_a (kernel only), AVB footer stripped; the build
# adds ours. Its header keeps the stock (unset) OS version and patch level,
# which the bootloader hands to KeyMint, so both slots present the same values.
BOARD_PREBUILT_BOOTIMAGE := $(KERNEL_PATH)/boot.img
BOARD_PREBUILT_DTBIMAGE_DIR := $(KERNEL_PATH)/dtb
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_PATH)/dtbo.img
BOARD_PREBUILT_VENDOR_DLKMIMAGE := $(KERNEL_PATH)/images/vendor_dlkm.img
BOARD_PREBUILT_ODM_DLKMIMAGE := $(KERNEL_PATH)/images/odm_dlkm.img
BOARD_PREBUILT_SYSTEM_DLKMIMAGE := $(KERNEL_PATH)/images/system_dlkm.img

# Stock boot image geometry (header v4, 4 KiB pages; addresses from the stock
# vendor_boot: kernel 0x40000000, ramdisk 0x66f00000, tags/DTB 0x47c80000).
BOARD_BOOT_HEADER_VERSION := 4
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00000000
BOARD_RAMDISK_OFFSET := 0x26f00000
BOARD_KERNEL_TAGS_OFFSET := 0x07c80000
BOARD_DTB_OFFSET := 0x07c80000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)
BOARD_RAMDISK_USE_LZ4 := true

# Static partition sizes (stock GPT; both slots are equal). LK loads boot,
# init_boot and vendor_boot at full partition size.
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_FLASH_BLOCK_SIZE := 262144

# Recovery: LineageOS recovery in vendor_boot, as stock (the stock vendor
# ramdisk is recovery root + first_stage_ramdisk + lib/modules).
TARGET_NO_RECOVERY := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# A/B with Virtual A/B (stock). The firmware (preloader, lk, tee, md1img, ...)
# is not in the OTA: both slots must carry the same stock 4PEN firmware.
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm

# Dynamic partitions. Same group name as stock slot metadata ("main").
BOARD_SUPER_PARTITION_SIZE := 10737418240
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 10735321088
BOARD_MAIN_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := false

# Filesystems: stock uses EROFS for every read-only logical partition.
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_EROFS_COMPRESSOR := lz4hc,9
BOARD_EROFS_PCLUSTER_SIZE := 65536

TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product

TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs

# The dlkm partitions are the stock images (BOARD_PREBUILT_*_DLKMIMAGE). They
# must be declared so that the system image root contains real mount-point
# directories for them (an undeclared partition becomes a symlink, and
# first-stage init cannot mount onto a symlink -> kernel panic). Declaring
# vendor_dlkm also makes the build create /vendor/lib/modules ->
# /vendor_dlkm/lib/modules, as on stock.
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_USES_ODM_DLKMIMAGE := true
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
# No odm partition on this device: /odm/* are symlinks into /vendor/odm (AOSP
# default when TARGET_COPY_OUT_ODM is unset), same as stock.

# Extra stock root mount points: /preload (TCL preload, erofs logical) and
# /otapkg (TCL OTA package partition, mounted by vendor init).
BOARD_ROOT_EXTRA_FOLDERS := preload otapkg

# The stock oem and preload logical partitions are not shipped (an OTA drops
# them from the slot it writes): /preload holds TCL's apps (nofail), and the
# few /oem files are bind-mounted from /vendor/etc/oem (init.selene.rc).

BOARD_USES_METADATA_PARTITION := true

# Verified boot. The bootloader is unlocked (orange state): LK boots a vbmeta
# signed with any key and checks the hashes of the images it loads. The build
# self-signs with the AVB test keys.
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA2048
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2

BOARD_AVB_VBMETA_VENDOR := vendor
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 4

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Recovery fstab
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.emmc

# SELinux: LineageOS MediaTek vendor policy + the rest of the stock policy
# ported in sepolicy/vendor (stock_port.te). The A13 blobs use pre-namespace
# vendor property names (sys.*, persist.sys.*, ro.tct.*, ...). sepolicy_vndr
# dropped its legacy mode on 23.2, so allow them here.
BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true
include device/mediatek/sepolicy_vndr/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += \
    $(DEVICE_PATH)/sepolicy/vendor \
    $(DEVICE_PATH)/sepolicy/device

# VINTF (stock manifest + the stock per-HAL fragments, merged; stock matrix)
DEVICE_MANIFEST_FILE := \
    $(DEVICE_PATH)/configs/vintf/manifest.xml \
    $(sort $(wildcard $(DEVICE_PATH)/configs/vintf/manifest/*.xml))
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/configs/vintf/compatibility_matrix.xml
# Framework side of the vendor-specific HALs: stock system's device matrix
# (MediaTek device_framework_matrix.xml), so the A/B OTA's VINTF check passes.
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/configs/vintf/framework_compatibility_matrix.xml

# Stock per-SKU ODM manifests (radio slots); LK passes
# androidboot.product.hardware.sku=8189SVZW-1Svzw_dsds on this unit.
ODM_MANIFEST_SKUS := 8189SVZW-1Svzw_dsds 8189SVZW-1Svzw_ss dsds qsqs ss tsts
$(foreach sku,$(ODM_MANIFEST_SKUS),\
    $(eval ODM_MANIFEST_$(call to-upper,$(sku))_FILES := $(DEVICE_PATH)/configs/vintf/odm/manifest_$(sku).xml))

# Stock A13 blobs
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true

# Security patch levels (stock vendor; stock boot, so KeyMint's boot patch
# level does not change)
VENDOR_SECURITY_PATCH := 2026-05-05
BOOT_SECURITY_PATCH := 2024-05-05

BUILD_BROKEN_DUP_RULES := true

include vendor/tcl/selene_vzw/BoardConfigVendor.mk
