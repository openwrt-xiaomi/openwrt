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

define Build/x-uboot-bin
	cat $(STAGING_DIR_IMAGE)/$(1)-u-boot.bin >> $@
endef

define Build/x-append-hex
	echo -n " "$(1) | sed -r 's/ /\\x/g' | echo -ne $$(cat) >> $@
endef

define Build/x-append-uboot-size-le32
	$(eval imgname=$(word 1,$(1))-u-boot.bin)
	$(eval extend=$(word 2,$(1)))
	printf "%08X" $$(( $$(stat -c %s $(STAGING_DIR_IMAGE)/$(imgname)) + $(extend) )) | \
		sed -E 's/(..)(..)(..)(..)/\\x\4\\x\3\\x\2\\x\1/' | echo -ne $$(cat) >> $@
endef

define Build/x-uboot-with-arm64hdr
	rm -f $@
	$(call Build/x-append-hex,'1F 20 03 D5')             # code0: NOP
	$(call Build/x-append-hex,'0F 00 00 14')             # code1: B +60
	$(call Build/x-append-hex,'C0 FF 1F 00 00 00 00 00') # text_offset: 0x1FFFC0
	$(call Build/x-append-uboot-size-le32,$(1) 64)       # image_size: file_size + 64
	$(call Build/x-append-hex,'00 00 00 00')             # image_size: HIGHest 32-bits
	$(call Build/x-append-hex,'08 00 00 00 00 00 00 00') # flags: BIT(3)
	$(call Build/x-append-hex,'00 00 00 00 00 00 00 00') # res2: 0
	$(call Build/x-append-hex,'00 00 00 00 00 00 00 00') # res3: 0
	$(call Build/x-append-hex,'00 00 00 00 00 00 00 00') # res4: 0
	$(call Build/x-append-hex,'41 52 4D 64')             # magic: "ARMd" = LINUX_ARM64_IMAGE_MAGIC
	$(call Build/x-append-hex,'00 00 00 00')             # res5: 0
	$(call Build/x-uboot-bin,$(1))
endef

define Build/x-uboot-fit
	$(eval cmptype=$(word 1,$(1)))
	$(eval epaddr=$(word 2,$(1)))
	$(eval dtbimg=$(word 3,$(1)))
	$(TOPDIR)/scripts/mkits.sh \
		-D $(DEVICE_NAME) -o $@.its -k $@ \
		-C $(cmptype) \
		-a $(epaddr) -e $(epaddr) \
		-c "config-1" \
		$(if $(dtbimg),-d $(dtbimg), ) \
		-A $(LINUX_KARCH) -v u-boot
	PATH=$(LINUX_DIR)/scripts/dtc:$(PATH) mkimage -f $@.its $@.new
	@mv $@.new $@
endef

include $(SUBTARGET).mk

define Image/Build
	$(call Image/Build/$(1),$(1))
endef

$(eval $(call BuildImage))

