#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/tcl/selene_vzw

# The stock vendor (Android 13) was frozen at API 33. Do NOT leave this unset:
# PRODUCT_PACKAGES_SHIPPING_API_LEVEL_* lists (hwservicemanager, needed by the
# HIDL Gatekeeper / composer / camera HALs on stock vendor) are only installed
# for shipping levels at or below their threshold.
PRODUCT_SHIPPING_API_LEVEL := 33

PRODUCT_CHARACTERISTICS := tablet

# No kernel is built here, so the build cannot probe the kernel version for
# ART's userfaultfd GC. Stock GKI is 5.15 (>= 5.7 needed), so enable it.
PRODUCT_ENABLE_UFFD_GC := true

# Screen
TARGET_SCREEN_HEIGHT := 1340
TARGET_SCREEN_WIDTH := 800

PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := hdpi

# A/B
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=erofs \
    POSTINSTALL_OPTIONAL_system=true

PRODUCT_PACKAGES += \
    otapreopt_script \
    update_engine \
    update_engine_sideload \
    update_verifier

# Command-line A/B updates (adb shell update_engine_client) on test builds
ifneq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_PACKAGES += \
    update_engine_client
endif

PRODUCT_PACKAGES += \
    lpdump \
    snapshotctl

# Overlays: device configuration (brightness, power profile, cutout, status
# bar, refresh rate, ...) comes from the stock RROs in /vendor/overlay.
include $(LOCAL_PATH)/prebuilt/overlay/packages.mk

# Init scripts, fstabs, ueventd (stock)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.emmc:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.emmc \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6835:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6835 \
    $(LOCAL_PATH)/rootdir/etc/fstab.enableswap:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.enableswap \
    $(LOCAL_PATH)/rootdir/etc/ueventd.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc \
    $(foreach f,$(filter-out ueventd.rc init.selene.debug.rc init.selene.rc,$(notdir $(wildcard $(LOCAL_PATH)/rootdir/etc/*.rc))),\
        $(LOCAL_PATH)/rootdir/etc/$(f):$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/$(f))

# Without VNDK, vendor reaches libandroidicu (MTK camera, RenderScript blobs)
# only if it asks the i18n APEX for it.
PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS += $(LOCAL_PATH)/configs/vendor-linker.config.json

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.selene.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.selene.rc

# First-stage ramdisk (vendor_boot): fstabs and the stock first-stage kernel
# modules with their stock load lists (modules.load.recovery adds the panel and
# touch drivers for recovery).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6835:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt6835 \
    $(LOCAL_PATH)/rootdir/etc/fstab.emmc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.emmc \
    $(foreach f,$(notdir $(wildcard $(LOCAL_PATH)-kernel/vendor_ramdisk/lib/modules/*)),\
        $(LOCAL_PATH)-kernel/vendor_ramdisk/lib/modules/$(f):$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules/$(f))

# eSIM: the second SIM slot is an eUICC. Stock declares the feature on the
# system side (not shipped here). OpenEUICC (packages/apps/OpenEUICC, see
# .repo/local_manifests/selene_vzw.xml) is the privileged LPA.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.euicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.euicc.xml
PRODUCT_PACKAGES += \
    OpenEUICC

# Voice calls over VoLTE: MediaTek ImsService adapted to AOSP telephony
# (vendor/mediatek/ims, see .repo/local_manifests/selene_vzw.xml); the vendor
# IMS radio slots, mtkradioex and vtservice come from the stock blobs. The
# tablet telephony config has no dialer, and the stock RRO turns voice off
# (rro_overlays/FrameworksResOverlaySelene turns it back on).
$(call inherit-product, vendor/mediatek/ims/ims.mk)
PRODUCT_PACKAGES += \
    Dialer \
    CarrierConfigOverlaySelene \
    FrameworksResOverlaySelene

# Stock /oem files (bind-mounted on /oem by init.selene.rc)
PRODUCT_COPY_FILES += \
    $(foreach f,oem.prop skus.xml svn.bin svn.xml,\
        $(LOCAL_PATH)/configs/oem/$(f):$(TARGET_COPY_OUT_VENDOR)/etc/oem/$(f))

# Recovery
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.recovery.mt6835.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6835.rc

# Boot control: MediaTek's HAL (hal/boot), also in recovery (LineageOS
# recovery has none, and update_engine_sideload needs one). Switching slots
# also switches the eMMC boot area (preloader_a/b).
PRODUCT_PACKAGES += \
    android.hardware.boot-service.mediatek \
    android.hardware.boot-service.mediatek_recovery

# Health HAL for recovery (hal/health; battery level check before installs)
PRODUCT_PACKAGES += \
    android.hardware.health-service.mediatek-recovery

# Bring-up debugging: unthrottled kmsg + logcat to /metadata (userdebug)
ifneq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.selene.debug.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.selene.debug.rc
endif

# Stock /vendor/etc/mdota -> /mnt/vendor/mdota
PRODUCT_PACKAGES += \
    vendor_etc_mdota_symlink

# Vendor-side AOSP components the stock vendor shipped (excluded from the blob
# list, built from source here)
PRODUCT_PACKAGES += \
    vndservicemanager \
    vndservice


PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

# Proprietary blobs
$(call inherit-product, vendor/tcl/selene_vzw/selene_vzw-vendor.mk)
