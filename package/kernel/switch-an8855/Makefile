include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=switch-an8855
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/$(PKG_NAME)
  SECTION:=kernel
  SUBMENU:=Other modules
  TITLE:=Airoha AN8855 Ethernet switch support
  FILES:=$(PKG_BUILD_DIR)/an8855-dsa.ko
  AUTOLOAD:=$(call AutoLoad,43,an8855-dsa,1)
endef

define KernelPackage/$(PKG_NAME)/description
  Airoha AN8855 Ethernet switch support
endef

define Build/Compile
	$(KERNEL_MAKE) M=$(PKG_BUILD_DIR) modules
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
