#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# The stock (A13) OMX service and its libavservices_minijail are kept as
# vendor prebuilts. Android 16's generated vendor image does not honor their
# OVERRIDES, so keep base_vendor.mk from installing the AOSP builds as well.
# Must be set before base_vendor.mk is inherited.
TARGET_SUPPORTS_OMX_SERVICE := false

# 64-bit kernel/userspace with 32-bit app support (stock ro.zygote=zygote64_32).
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)

# Virtual A/B with compression (matches stock; affects system-side tooling only,
# the vendor ramdisk is not rebuilt).
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)

$(call inherit-product, device/tcl/selene_vzw/device.mk)

# Tablet with LTE/5G modem.
$(call inherit-product, vendor/lineage/config/common_full_tablet.mk)

PRODUCT_DEVICE := selene_vzw
PRODUCT_NAME := lineage_selene_vzw
PRODUCT_BRAND := TCL
PRODUCT_MODEL := 8189S
PRODUCT_MANUFACTURER := TCL

PRODUCT_GMS_CLIENTID_BASE := android-tcl

PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceName=Selene_VZW \
    DeviceProduct=8189S \
    BuildDesc="8189S-user 15 AP3A.240905.015.A2 4PEQ release-keys"

BUILD_FINGERPRINT := TCL/8189S/Selene_VZW:15/AP3A.240905.015.A2/4PEQ:user/release-keys
