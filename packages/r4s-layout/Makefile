include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=r4s-layout
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/r4s-layout
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=R4S partition layout (512MB rootfs + 1GB overlay) and defaults
  DEPENDS:=+busybox \
	+kmod-fs-ext4 \
	+tune2fs \
	+blkid \
	+fdisk \
	+gdisk \
	+partx-utils \
	+e2fsprogs
endef

define Package/r4s-layout/description
  On first boot, creates a 1GB ext4 overlay partition and a data
  partition from the remaining space (preinit 79_disk_ready).
  Also applies R4S defaults: LAN 192.168.15.1.
endef

define Build/Compile
endef

define Package/r4s-layout/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/fstab $(1)/etc/config/fstab
	$(INSTALL_DIR) $(1)/lib/preinit
	$(INSTALL_DATA) ./files/lib/preinit/79_disk_ready $(1)/lib/preinit/79_disk_ready
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/disk_ready_done $(1)/etc/init.d/disk_ready_done
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/diskv $(1)/usr/sbin/diskv
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-r4s-defaults $(1)/etc/uci-defaults/99-r4s-defaults
	$(INSTALL_DIR) $(1)/etc/sysctl.d
	$(INSTALL_DATA) ./files/etc/sysctl.d/90-tcp-bbr.conf $(1)/etc/sysctl.d/90-tcp-bbr.conf
endef

$(eval $(call BuildPackage,r4s-layout))
