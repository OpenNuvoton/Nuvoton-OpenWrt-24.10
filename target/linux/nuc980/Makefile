# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

ARCH:=arm
BOARD:=nuc980
BOARDNAME:=Nuvoton NUC980
FEATURES:=gpio usb squashfs targz nand ubifs boot-part rootfs-part jffs2
CPU_TYPE:=arm926ej-s
SUBTARGETS:=evb chili iot iotg2 iotg2d server

KERNEL_PATCHVER:=6.6

define Target/Description
        Build firmware images for Nuvoton NUC980 SoC family routers.
endef

include $(INCLUDE_DIR)/target.mk

KERNELNAME:=zImage dtbs

DEFAULT_PACKAGES += libopenssl

# The NUC980 kernel (arch/arm/boot/Makefile) copies the raw kernel Image to
# ../image/980image, which resolves to $(KERNEL_BUILD_DIR)/image/980image.
# Mirror the Buildroot linux.mk behaviour (mkdir -p $(@D)/../image) and make
# sure that directory exists before the kernel is built.
define Kernel/Configure
	$(call Kernel/Configure/Default)
	mkdir -p $(KERNEL_BUILD_DIR)/image
endef

$(eval $(call BuildTarget))
