#!/bin/bash

# extra packages
git clone https://github.com/JohnsonRan/packages_net_speedtest-ex package/new/speedtest-ex
git clone https://github.com/JohnsonRan/packages_utils_boltbrowser package/new/boltbrowser
git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/new/nikki --depth=1
git clone https://github.com/asvow/luci-app-tailscale package/new/luci-app-tailscale --depth=1
git clone https://github.com/JohnsonRan/InfinityDuck package/new/duck --depth=1
rm -rf package/feeds/packages/v2ray-geodata
git clone https://github.com/JohnsonRan/packages_net_v2ray-geodata package/new/v2ray-geodata --depth=1
# curl
rm -rf feeds/packages/net/curl
git clone https://github.com/sbwml/feeds_packages_net_curl package/new/curl
git clone https://github.com/sbwml/package_libs_ngtcp2 package/new/ngtcp2
git clone https://github.com/sbwml/package_libs_nghttp3 package/new/nghttp3
# tcp-brutal
git clone https://github.com/sbwml/package_kernel_tcp-brutal package/new/brutal
# latest golang version
rm -rf feeds/packages/lang/golang/golang
git clone https://github.com/JohnsonRan/packages_lang_golang feeds/packages/lang/golang/golang

# sysupgrade keep files
mkdir -p files/etc
echo "/etc/hotplug.d/iface/*.sh" >>files/etc/sysupgrade.conf
echo "/etc/nikki/run/cache.db" >>files/etc/sysupgrade.conf
git clone https://github.com/morytyann/OpenWrt-nikki package/new/openwrt-nikki --depth=1
mkdir -p files/etc/opkg/keys
curl -skL https://github.com/nikkinikki-org/OpenWrt-nikki/raw/gh-pages/key-build.pub >files/etc/opkg/keys/ab017c88aab7a08b
echo "src/gz nikki https://nikkinikki.pages.dev/openwrt-24.10/aarch64_generic/nikki" >>files/etc/opkg/customfeeds.conf
mkdir -p files/etc/nikki/run/ui
curl -skLo files/etc/nikki/run/Country.mmdb https://github.com/NobyDa/geoip/raw/release/Private-GeoIP-CN.mmdb
curl -skLo files/etc/nikki/run/GeoIP.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat
curl -skLo files/etc/nikki/run/GeoSite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat
curl -skLo gh-pages.zip https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip
unzip -q gh-pages.zip
mv zashboard-gh-pages files/etc/nikki/run/ui/zashboard
rm -rf gh-pages.zip
# make sure nikki is always latest
git clone -b Alpha --depth=1 https://github.com/metacubex/mihomo --depth=1 nikki
nikki_sha=$(git -C nikki rev-parse HEAD)
nikki_short_sha=$(git -C nikki rev-parse --short HEAD)
git -C nikki config tar.xz.command "xz -c"
git -C nikki archive --output=nikki.tar.xz HEAD
nikki_checksum=$(sha256sum nikki/nikki.tar.xz | cut -d ' ' -f 1)
sed -i "s/PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=$(git -C nikki log -n 1 --format=%cs)/" package/new/openwrt-nikki/nikki/Makefile
sed -i "s/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$nikki_sha/" package/new/openwrt-nikki/nikki/Makefile
sed -i "s/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=$nikki_checksum/" package/new/openwrt-nikki/nikki/Makefile
sed -i "s/PKG_BUILD_VERSION:=.*/PKG_BUILD_VERSION:=alpha-$nikki_short_sha/" package/new/openwrt-nikki/nikki/Makefile
rm -rf nikki

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
curl -skLo files/etc/uci-defaults/99-opkg https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/files/etc/uci-defaults/99-defaults
curl -skLo files/etc/uci-defaults/99-nikki https://github.com/JohnsonRan/opwrt_build_script/raw/master/openwrt/files/etc/uci-defaults/99-nikki
curl -skLo files/etc/uci-defaults/99-dae https://github.com/JohnsonRan/opwrt_build_script/raw/master/openwrt/files/etc/uci-defaults/99-dae

# custom feed
curl -skL https://opkg.ihtw.moe/key-build.pub >files/etc/opkg/keys/351925c1f1557850
echo "src/gz infsubs https://opkg.ihtw.moe/openwrt-24.10/aarch64_generic/InfinitySubstance" >>files/etc/opkg/customfeeds.conf

# default LAN IP
sed -i "s/192.168.1.1/172.20.10.1/g" package/base-files/luci2/bin/config_generate