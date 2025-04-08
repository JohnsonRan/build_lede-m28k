#!/bin/bash

# extra packages
git clone https://github.com/JohnsonRan/packages_net_speedtest-ex package/new/speedtest-ex
git clone https://github.com/JohnsonRan/packages_utils_boltbrowser package/new/boltbrowser
git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/new/nikki --depth=1
git clone https://github.com/asvow/luci-app-tailscale package/new/luci-app-tailscale --depth=1
git clone https://github.com/JohnsonRan/InfinityDuck package/new/duck --depth=1
rm -rf package/feeds/packages/v2ray-geodata
git clone https://github.com/JohnsonRan/packages_net_v2ray-geodata package/new/v2ray-geodata --depth=1
rm -rf feeds/packages/net/curl
git clone https://github.com/sbwml/feeds_packages_net_curl package/new/curl
git clone https://github.com/sbwml/package_kernel_tcp-brutal package/new/brutal
git clone https://github.com/sbwml/package_libs_ngtcp2 package/new/ngtcp2
git clone https://github.com/sbwml/package_libs_nghttp3 package/new/nghttp3
rm -rf feeds/packages/lang/golang/golang
git clone https://github.com/JohnsonRan/packages_lang_golang feeds/packages/lang/golang/golang
    
# sysupgrade keep files
mkdir -p files/etc
echo "/etc/hotplug.d/iface/*.sh" >>files/etc/sysupgrade.conf
echo "/etc/nikki/run/cache.db" >>files/etc/sysupgrade.conf

# make sure mihomo is always latest
git clone -b Alpha --depth=1 https://github.com/metacubex/mihomo --depth=1
mihomo_sha=$(git -C mihomo rev-parse HEAD)
mihomo_short_sha=$(git -C mihomo rev-parse --short HEAD)
git -C mihomo config tar.xz.command "xz -c"
git -C mihomo archive --output=mihomo.tar.xz HEAD
mihomo_checksum=$(sha256sum mihomo/mihomo.tar.xz | cut -d ' ' -f 1)
sed -i "s/PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=$(date -u -d yesterday -I)/" package/new/nikki/nikki/Makefile
sed -i "s/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$mihomo_sha/" package/new/nikki/nikki/Makefile
sed -i "s/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=$mihomo_checksum/" package/new/nikki/nikki/Makefile
sed -i "s/PKG_BUILD_VERSION:=.*/PKG_BUILD_VERSION:=alpha-$mihomo_short_sha/" package/new/nikki/nikki/Makefile

# configure tailscale
#sed -i "s/$(INSTALL_DATA) ./files//tailscale.conf $(1)/etc/config/tailscale//g" package/feeds/packages/tailscale/Makefile
#sed -i "s/$(INSTALL_BIN) ./files//tailscale.init $(1)/etc/init.d/tailscale//g" package/feeds/packages/tailscale/Makefile
mkdir -p files/etc/hotplug.d/iface
curl -skLo files/etc/hotplug.d/iface/99-tailscale-needs https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/files/etc/hotplug.d/iface/99-tailscale-needs
# make sure tailscale is always latest
ts_version=$(curl -s https://api.github.com/repos/tailscale/tailscale/releases/latest | grep -oP '(?<="tag_name": ")[^"]*' | sed 's/^v//')
ts_tarball="tailscale-${ts_version}.tar.gz"
curl -skLo "${ts_tarball}" "https://codeload.github.com/tailscale/tailscale/tar.gz/v${ts_version}"
ts_hash=$(sha256sum "${ts_tarball}" | awk '{print $1}')
rm -rf "${ts_tarball}"
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=${ts_version}/" package/feeds/packages/tailscale/Makefile
sed -i "s/PKG_HASH:=.*/PKG_HASH:=${ts_hash}/" package/feeds/packages/tailscale/Makefile

# add UE-DDNS
mkdir -p files/usr/bin
curl -skLo files/usr/bin/ue-ddns ddns.03k.org
chmod +x files/usr/bin/ue-ddns

# defaults
mkdir -p files/etc/uci-defaults
curl -skLo files/etc/uci-defaults/99-zram https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/files/etc/uci-defaults/99-zram
curl -skLo files/etc/uci-defaults/99-kmod https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/files/etc/uci-defaults/99-kmod