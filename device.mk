#
# Copyright (C) 2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from mt6895-common
$(call inherit-product, device/xiaomi/mt6895-common/mt6895.mk)

# Call the MiuiCamera setup
# $(call inherit-product-if-exists, vendor/xiaomi/miuicamera-pearl/device.mk)

# Fastboot package
PRODUCT_BUILD_SUPER_PARTITION := true
PRODUCT_FASTBOOT_TEMPLATE_ZIP := $(LOCAL_PATH)/prebuilts/fastboot.zip
PRODUCT_FASTBOOT_IMAGES_PATH := images

# Keymint 
# 硬件Keymint-service.mitee是AIDL-V1接口的, 而Lineage23.2已经是AIDL-V4接口了, 强行改ELF NEEDED也是会出现未定义符号问题
# 于是选择一个default软件实例让Android正常开机得了, 就是安全系数不高就是了
# 关闭 StrongBox, 让 keystore2 只用 default 实例
PRODUCT_PROPERTY_OVERRIDES += ro.hardware.strongbox=0
# 打包软件实现的 default KeyMint 服务
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-service

# FM Radio
PRODUCT_PACKAGES += \
    FMRadio

# NFC
PRODUCT_PACKAGES += \
    com.android.nfc_extras \
    Tag

PRODUCT_PACKAGES += \
    android.hardware.nfc-service.nxp

# Overlay
PRODUCT_PACKAGES += \
    FrameworksResOverlayPearl \
    NfcOverlayPearl \
    SettingsProviderOverlayPearl \
    SystemUIResOverlayPearl \
    WifiResOverlayPearl
    
# Rootdir
PRODUCT_PACKAGES += \
    init.project.rc \
    init.pearl.rc

# Shipping API Level
PRODUCT_SHIPPING_API_LEVEL := 31

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Inherit the proprietary files
$(call inherit-product, vendor/xiaomi/pearl/pearl-vendor.mk)
