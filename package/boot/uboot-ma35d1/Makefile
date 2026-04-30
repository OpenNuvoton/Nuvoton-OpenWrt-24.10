#
# Copyright (C) 2013-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

#PKG_NAME:=uboot
PKG_VERSION:=2020.07
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/OpenNuvoton/MA35D1_u-boot-v2020.07.git
PKG_SOURCE_DATE:=2025-11-06
PKG_SOURCE_VERSION:=d39f0d5442637b1e94123382fd2000ca11736f52
PKG_MIRROR_HASH:=3937110da45154308a4867f3a1b69aa61e9f81db7802560df91a2f2d39e0d07b

PKG_CPE_ID:=cpe:/a:denx:u-boot

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/image.mk

define U-Boot/Default
  BUILD_TARGET:=$(BOARD)
  UBOOT_IMAGE:=u-boot.bin
  DEPENDS:=@(TARGET_ma35d1||TARGET_ma35d0||TARGET_ma35h0)
endef

define U-Boot/ma35d1
  NAME:=MA35 board
ifneq ($(findstring spinand,$(PROFILE)),)
  UBOOT_CONFIG:=$(BOARD)_spinand
else ifneq ($(findstring sdcard0,$(PROFILE)),)
  UBOOT_CONFIG:=$(BOARD)_sdcard0
else ifneq ($(findstring sdcard1,$(PROFILE)),)
  UBOOT_CONFIG:=$(BOARD)_sdcard1
else
  UBOOT_CONFIG:=$(BOARD)_nand
endif
endef

UBOOT_TARGETS:=ma35d1

$(info PROFILE = $(PROFILE))

define Build/InstallDev
	touch /tmp/openwrt.boot
	sed -i /^UBOOT_/d /tmp/openwrt.boot
	echo UBOOT_CONFIG=$(UBOOT_CONFIG) >> /tmp/openwrt.boot
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(foreach img,$(UBOOT_IMAGE), \
		$(CP) $(PKG_BUILD_DIR)/$(img) $(STAGING_DIR_IMAGE)/$(img); \
	)
endef

$(eval $(call BuildPackage/U-Boot))
