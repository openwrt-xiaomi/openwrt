# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2012-2015 OpenWrt.org
# Copyright (C) 2016-2017 LEDE project

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += NETGEAR_ENC_MODEL NETGEAR_ENC_REGION NETGEAR_ENC_HW_ID_LIST NETGEAR_ENC_MODEL_LIST

loadaddr-$(CONFIG_TARGET_mediatek_mt7622) := 0x44000000
loadaddr-$(CONFIG_TARGET_mediatek_mt7623) := 0x80008000
loadaddr-$(CONFIG_TARGET_mediatek_mt7629) := 0x40008000
loadaddr-$(CONFIG_TARGET_mediatek_filogic) := 0x48000000

# default all platform image(fit) build
define Device/Default
  PROFILES = Default $$(DEVICE_NAME)
  KERNEL_NAME := Image
  KERNEL = kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_INITRAMFS = kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd
  KERNEL_LOADADDR = $(loadaddr-y)
  FILESYSTEMS := squashfs
  DEVICE_DTS_DIR := $(DTS_DIR)
  NETGEAR_ENC_MODEL :=
  NETGEAR_ENC_REGION :=
  NETGEAR_ENC_HW_ID_LIST :=
  NETGEAR_ENC_MODEL_LIST :=
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := append-kernel | pad-to 128k | append-rootfs | \
	pad-rootfs | append-metadata
endef

define Build/asus-trx
	$(STAGING_DIR_HOST)/bin/asusuimage $(wordlist 1,$(words $(1)),$(1)) -i $@ -o $@.new
	mv $@.new $@
endef

include $(SUBTARGET).mk

define Image/Build
	$(call Image/Build/$(1),$(1))
endef

$(eval $(call BuildImage))

