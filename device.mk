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
