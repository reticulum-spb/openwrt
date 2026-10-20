include $(TOPDIR)/rules.mk

PKG_NAME:=xradio-firmware
PKG_VERSION:=2021.10.16
PKG_RELEASE:=1

# Distribution terms for these vendor blobs have not been confirmed.
PKG_LICENSE:=Proprietary

FIRMWARE_COMMIT:=5d685ad233b4dfd03a4d025fa0061f6b0f850cb3
FIRMWARE_URL:=https://raw.githubusercontent.com/armbian/firmware/$(FIRMWARE_COMMIT)/xr819

include $(INCLUDE_DIR)/package.mk

define Download/xradio-boot
  FILE:=$(PKG_NAME)-$(FIRMWARE_COMMIT)-boot_xr819.bin
  URL:=$(FIRMWARE_URL)
  URL_FILE:=boot_xr819.bin
  HASH:=6583350b3eb12f70fc6d6081426717bd0019b55c6558ffe820c1548f0702bb8c
endef
$(eval $(call Download,xradio-boot))

define Download/xradio-fw
  FILE:=$(PKG_NAME)-$(FIRMWARE_COMMIT)-fw_xr819.bin
  URL:=$(FIRMWARE_URL)
  URL_FILE:=fw_xr819.bin
  HASH:=fb81436ad7cc0876614a2a9c2a54c5a93a75315aee164e3a3afe3db80842a9e1
endef
$(eval $(call Download,xradio-fw))

define Download/xradio-sdd
  FILE:=$(PKG_NAME)-$(FIRMWARE_COMMIT)-sdd_xr819.bin
  URL:=$(FIRMWARE_URL)
  URL_FILE:=sdd_xr819.bin
  HASH:=84d3fb3ca8e5d25a0c113a5063bccbeb5b53da230a0afa236b5b625f37db5161
endef
$(eval $(call Download,xradio-sdd))

define Package/xradio-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=XR819 SDIO WiFi firmware
  URL:=https://github.com/armbian/firmware
  DEPENDS:=@(TARGET_sunxi&&TARGET_sunxi_cortexa7)
endef

define Package/xradio-firmware/description
  Firmware for the Xradio XR819 SDIO WiFi chip used on the Orange Pi Zero.
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/xradio-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/xr819
	$(INSTALL_DATA) $(DL_DIR)/$(PKG_NAME)-$(FIRMWARE_COMMIT)-boot_xr819.bin \
		$(1)/lib/firmware/xr819/boot_xr819.bin
	$(INSTALL_DATA) $(DL_DIR)/$(PKG_NAME)-$(FIRMWARE_COMMIT)-fw_xr819.bin \
		$(1)/lib/firmware/xr819/fw_xr819.bin
	$(INSTALL_DATA) $(DL_DIR)/$(PKG_NAME)-$(FIRMWARE_COMMIT)-sdd_xr819.bin \
		$(1)/lib/firmware/xr819/sdd_xr819.bin
endef

$(eval $(call BuildPackage,xradio-firmware))
