LOCAL_PATH := device/tcl/selene_vzw

PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.mt6835.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6835.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags

# Virtual A/B (compression, userspace snapshots) props and snapuserd come
# from virtual_ab_ota/compression.mk inherited in twrp_selene_vzw.mk.
