#
# Copyright (C) 2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/pearl

# Inherit from mt6895-common
include device/xiaomi/mt6895-common/BoardConfigCommon.mk

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := pearl

# Display
TARGET_SCREEN_DENSITY := 440

# Fastboot package
BOARD_BOOTLOADER_IN_UPDATE_PACKAGE := true
BOARD_SUPER_IMAGE_IN_UPDATE_PACKAGE := true

# 测试：关闭SElinux
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

# Use pearl's USB gadget configuration instead of the generic MediaTek rc.
SOONG_CONFIG_NAMESPACES += mediatek_gadget
SOONG_CONFIG_mediatek_gadget += use_custom_usb_gadget_rc
SOONG_CONFIG_mediatek_gadget_use_custom_usb_gadget_rc := true

# Kernel
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules/modules.load))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules/modules.load.recovery))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules/modules.load.vendor_boot))
BOOT_KERNEL_MODULES := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD) $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD)

# Properties
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Security Patch Level
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
VENDOR_SECURITY_PATCH := $(BOOT_SECURITY_PATCH)

# Framework Compatibility Matrix
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += $(DEVICE_PATH)/vintf/pearl_framework_compatibility_matrix.xml

# Inherit the proprietary files
include vendor/xiaomi/pearl/BoardConfigVendor.mk

# Inherit from proprietary files for miuicamera
include vendor/xiaomi/miuicamera-pearl/BoardConfig.mk
