include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

define Device/Default
	PROFILES := Default
	KERNEL_LOADADDR := 0x41000000
	DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
	DEVICE_DTS_CONFIG := config@1
	DEVICE_DTS_DIR := $(DTS_DIR)/qcom
	IMAGES := sysupgrade.bin
	IMAGE/sysupgrade.bin = sysupgrade-tar | append-metadata
	IMAGE/sysupgrade.bin/squashfs :=
endef

define Device/FitImage
	KERNEL_SUFFIX := -uImage.itb
	KERNEL = kernel-bin | libdeflate-gzip | fit gzip $$(KDIR)/image-$$(DEVICE_DTS).dtb
	KERNEL_NAME := Image
endef

define Device/FitImageLzma
	KERNEL_SUFFIX := -uImage.itb
	KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	KERNEL_NAME := Image
endef

define Device/EmmcImage
	IMAGES += factory.bin
	IMAGE/factory.bin := append-rootfs | pad-rootfs | pad-to 64k
	IMAGE/sysupgrade.bin/squashfs := append-rootfs | pad-to 64k | sysupgrade-tar rootfs=$$$$@ | append-metadata
endef

define Device/UbiFit
	KERNEL_IN_UBI := 1
	IMAGES += factory.ubi
	IMAGE/factory.ubi := append-ubi
endef

define Build/append-vmlinux
	dd if=$(KERNEL_BUILD_DIR)/vmlinux >> $@
endef

define Build/append-vmlinux-initramfs
	dd if=$(KERNEL_BUILD_DIR)/vmlinux-initramfs >> $@
endef

define Build/save-to
	mv $@ $@.$(word 1,$(1))
endef

define Build/remove-file
	$(eval filename=$@.$(word 1,$(1)))
	[ -f $(filename) ] && rm $(filename)
endef

define Build/remove-file-f
	$(eval filename=$@.$(word 1,$(1)))
	[ -f $(filename) ] && rm -f $(filename)
endef

define Build/uImageAdv
	$(eval imgtype=$(word 1,$(1)))
	$(eval cmptype=$(word 2,$(1)))
	$(eval imgfile=$(word 3,$(1)))
	$(if $(UIMAGE_TIME),SOURCE_DATE_EPOCH="$(UIMAGE_TIME)") \
	mkimage \
		-A $(LINUX_KARCH) \
		-O linux \
		-T $(imgtype) \
		-C $(cmptype) \
		-a $(KERNEL_LOADADDR) \
		-e $(if $(KERNEL_ENTRY),$(KERNEL_ENTRY),$(KERNEL_LOADADDR)) \
		-n '$(if $(UIMAGE_NAME),$(UIMAGE_NAME),$(call toupper,$(LINUX_KARCH)) $(VERSION_DIST) Linux-$(LINUX_VERSION))' \
		$(if $(UIMAGE_MAGIC),-M $(UIMAGE_MAGIC)) \
		-d $(if $(imgfile),$@.$(subst :,:$@.,$(imgfile)),$@) \
		$(wordlist 4,$(words $(1)),$(1)) \
		$@.new
	mv $@.new $@
endef

define Build/append-fake-rootfs
	$(eval comp=$(word 1,$(1)))
	$(eval filepath=$(word 2,$(1)))
	$(eval filecont=$(word 3,$(1)))
	rm -rf $@.fakefs $@.fakehsqs
	mkdir -p $@.fakefs/$$(dirname $(filepath))
	echo '$(filecont)' > $@.fakefs/$(filepath)
	$(STAGING_DIR_HOST)/bin/mksquashfs4 $@.fakefs $@.fakehsqs -comp $(comp) \
		-b 4096 -no-exports -no-sparse -no-xattrs -all-root -noappend \
		$(wordlist 4,$(words $(1)),$(1))
	cat $@.fakehsqs >> $@
	$(if $@,rm -rf $@.fakefs $@.fakehsqs)
endef

define Build/asus-trx
	$(STAGING_DIR_HOST)/bin/mkasustrx $(wordlist 1,$(words $(1)),$(1)) -i $@ -o $@.new
	mv $@.new $@
endef

define Build/append-fake-ramdisk
	$(eval kernel_img=$@.$(word 1,$(1)))
	let ksize="$$(stat -c%s $(kernel_img))"; \
	let psize="( ksize % 8 )"; \
	[ $$psize -ge 1 ] && [ $$psize -le 4 ] && { \
		dd if=/dev/zero bs=28 count=1 >> $@; \
	} || { \
		dd if=/dev/zero bs=32 count=1 >> $@; \
	}
endef

define Device/LegacyImage
	KERNEL_NAME := vmlinux
	KERNEL = kernel-bin
	KERNEL_SUFFIX :=
	IMAGES += sysupgrade.bin
	IMAGE/sysupgrade.bin := \
		append-vmlinux | gzip | check-size 16380k | save-to img_kernel | \
		append-fake-ramdisk img_kernel | save-to img_fakerd | \
		append-dtb | save-to img_dtb | \
		uImageAdv multi gzip img_kernel:img_fakerd:img_dtb | \
		remove-file img_kernel | remove-file img_fakerd | remove-file img_dtb | \
		sysupgrade-tar kernel=$$$$@ | append-metadata
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
