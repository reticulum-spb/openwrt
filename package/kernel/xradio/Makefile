include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=xradio
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=43992a7e7ed95ff815cf6d8ba81cef1085e50ab9
PKG_SOURCE_DATE:=2025-10-10
PKG_SOURCE_URL:=https://codeload.github.com/fifteenhex/xradio/tar.gz
PKG_SOURCE_URL_FILE:=$(PKG_SOURCE_VERSION)
PKG_SOURCE:=xradio-$(PKG_SOURCE_VERSION).tar.gz
PKG_HASH:=fce2819322e18d80abba84fa420a55ec6ccea61240fc1a3268880eb84584bea5
PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/xradio-$(PKG_SOURCE_VERSION)
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

STAMP_CONFIGURED_DEPENDS := $(STAGING_DIR)/usr/include/mac80211-backport/backport/autoconf.h

NOSTDINC_FLAGS := \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-include backport/backport.h

define KernelPackage/xradio
  SUBMENU:=Wireless Drivers
  TITLE:=XRADIO XR819 SDIO wireless driver
  URL:=https://github.com/fifteenhex/xradio
  DEPENDS:=@(TARGET_sunxi&&TARGET_sunxi_cortexa7) +kmod-mmc +kmod-cfg80211 +kmod-mac80211 +xradio-firmware
  FILES:=$(PKG_BUILD_DIR)/xradio_wlan.ko
  AUTOLOAD:=$(call AutoProbe,xradio_wlan)
endef

define KernelPackage/xradio/description
  Driver for the Xradio XR819 SDIO WiFi chip used on the Orange Pi Zero,
  adapted for OpenWrt's mac80211 backports.
endef

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) \
		CONFIG_XRADIO_MAC80211_BACKPORTS=y \
		M="$(PKG_BUILD_DIR)" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		modules
endef

$(eval $(call KernelPackage,xradio))
