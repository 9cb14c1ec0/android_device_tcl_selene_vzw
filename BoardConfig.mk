#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# LineageOS 22.2 (Android 15) for the Verizon TCL Tab 8 NxtPaper 5G
# (8189S / selene_vzw), MediaTek MT6835.
#
# Builds system, system_ext, product and vendor. The vendor image is rebuilt
# from the stock Android 13 (TP1A, API 33) blobs in vendor/tcl/selene_vzw.
# vendor_dlkm / odm_dlkm / system_dlkm, the GKI 5.15 boot, init_boot, dtbo
# and the firmware stay stock. See README.md.
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

# Kernel / boot images are NOT built: the stock GKI boot_a, init_boot_a,
# dtbo_a and the stock vendor_dlkm/odm_dlkm/system_dlkm are kept, and
# vendor_boot_a carries TWRP (or stock).
TARGET_NO_KERNEL := true
TARGET_NO_RECOVERY := true
BOARD_BOOT_HEADER_VERSION := 4

# A/B with Virtual A/B (stock)
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    system \
    system_ext \
    product \
    vendor

# Dynamic partitions. Same group name as stock slot metadata ("main").
BOARD_SUPER_PARTITION_SIZE := 10737418240
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 10735321088
BOARD_MAIN_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor
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

# The stock dlkm partitions below are NOT built, but they must be declared so
# that the system image root contains real mount-point directories for them
# (an undeclared partition becomes a symlink, and first-stage init cannot
# mount onto a symlink -> kernel panic). Declaring vendor_dlkm also makes the
# build create /vendor/lib/modules -> /vendor_dlkm/lib/modules, as on stock.
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

BOARD_USES_METADATA_PARTITION := true

# Verified boot. Stock vbmeta_a chains vbmeta_system to TCL's key, so the
# install flips the verification-disabled flag in vbmeta_a (see README). The
# images still carry hashtree footers signed with the AOSP test key.
BOARD_AVB_ENABLE := true
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

# Recovery fstab (only used for update tooling; recovery is TWRP)
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.emmc

# SELinux: LineageOS MediaTek vendor policy + the rest of the stock policy
# ported in sepolicy/vendor (stock_port.te). The A13 blobs use pre-namespace
# vendor property names, hence the legacy mode.
BOARD_MTK_SEPOLICY_IS_LEGACY := true
include device/mediatek/sepolicy_vndr/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# VINTF (stock manifest + the stock per-HAL fragments, merged; stock matrix)
DEVICE_MANIFEST_FILE := \
    $(DEVICE_PATH)/configs/vintf/manifest.xml \
    $(sort $(wildcard $(DEVICE_PATH)/configs/vintf/manifest/*.xml))
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/configs/vintf/compatibility_matrix.xml

# Stock per-SKU ODM manifests (radio slots); LK passes
# androidboot.product.hardware.sku=8189SVZW-1Svzw_dsds on this unit.
ODM_MANIFEST_SKUS := 8189SVZW-1Svzw_dsds 8189SVZW-1Svzw_ss dsds qsqs ss tsts
$(foreach sku,$(ODM_MANIFEST_SKUS),\
    $(eval ODM_MANIFEST_$(call to-upper,$(sku))_FILES := $(DEVICE_PATH)/configs/vintf/odm/manifest_$(sku).xml))

# Stock A13 blobs
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true

# Security patch level (stock vendor)
VENDOR_SECURITY_PATCH := 2026-05-05

BUILD_BROKEN_DUP_RULES := true

include vendor/tcl/selene_vzw/BoardConfigVendor.mk
