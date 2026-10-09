#
# Copyright (C) 2026 The TWRP Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/tcl/selene_vzw/device.mk)

PRODUCT_DEVICE := selene_vzw
PRODUCT_NAME := twrp_selene_vzw
PRODUCT_BRAND := TCL
PRODUCT_MODEL := 8189S
PRODUCT_MANUFACTURER := TCL
PRODUCT_CHARACTERISTICS := tablet
PRODUCT_RELEASE_NAME := selene_vzw

PRODUCT_SHIPPING_API_LEVEL := 33
PRODUCT_USE_DYNAMIC_PARTITIONS := true
