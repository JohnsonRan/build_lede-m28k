#!/bin/bash -e

mirror=https://raw.githubusercontent.com/JohnsonRan/opwrt_build_script/master

GROUP=
group() {
    endgroup
    echo "::group::  $1"
    GROUP=1
}
endgroup() {
    if [ -n "$GROUP" ]; then
        echo "::endgroup::"
    fi
    GROUP=
}

if [ "$(whoami)" = "runner" ]; then
    BUILD_DIR="/builder"
    mkdir -p $BUILD_DIR
else
    BUILD_DIR=$(pwd)
fi

group "fetch coolsnowwolf/lede"
git clone -b master --depth=1 https://github.com/JohnsonRan/lede-m28k $BUILD_DIR/lede
cd $BUILD_DIR/lede
endgroup

group "update feed"
./scripts/feeds update -a
./scripts/feeds install -a
endgroup

group "custom package"
curl -skL https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/scripts/99-custom.sh | bash
# bash
sed -i 's#ash#bash#g' package/base-files/files/etc/passwd
sed -i '\#export ENV=/etc/shinit#a export HISTCONTROL=ignoredups' package/base-files/files/etc/profile
mkdir -p files/root
curl -so files/root/.bash_profile $mirror/openwrt/files/root/.bash_profile
curl -so files/root/.bashrc $mirror/openwrt/files/root/.bashrc
# rpcd - fix timeout
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js
# openssl-lto
sed -i "s/ no-lto//g" package/libs/openssl/Makefile
sed -i "/TARGET_CFLAGS +=/ s/\$/ -ffat-lto-objects/" package/libs/openssl/Makefile
# openssl urandom
sed -i "/-openwrt/iOPENSSL_OPTIONS += enable-ktls '-DDEVRANDOM=\"\\\\\"/dev/urandom\\\\\"\"\'\n" package/libs/openssl/Makefile
# sbwml/openwrt_pkgs
rm -rf package/{qat,qca,wwan}
git clone https://github.com/sbwml/openwrt_pkgs package/new/custom --depth=1
find package/new/custom -mindepth 1 -maxdepth 1 -not -name "bash-completion" -not -name "luci-app-diskman" -exec rm -rf {} +
# sbwml/autocore-arm
rm -rf package/lean
git clone https://github.com/sbwml/autocore-arm package/new/autocore-arm --depth=1
# imm cpufreq
git clone https://github.com/immortalwrt/immortalwrt --depth=1
cp -r immortalwrt/package/emortal/cpufreq package/new/cpufreq
rm -rf immortalwrt
# vnstat2
git clone https://github.com/openwrt/luci --depth=1
cp -r luci/applications/luci-app-vnstat2 package/new/vnstat2
rm -rf luci
# miniupnpd 2.3.9
rm -rf feeds/{packages/net/miniupnpd,luci/applications/luci-app-upnp}
git clone https://git.cooluc.com/sbwml/miniupnpd feeds/packages/net/miniupnpd -b v2.3.9
git clone https://git.cooluc.com/sbwml/luci-app-upnp feeds/luci/applications/luci-app-upnp -b openwrt-24.10
# luci-app-sqm
rm -rf feeds/luci/applications/luci-app-sqm
git clone https://$gitea/sbwml/luci-app-sqm feeds/luci/applications/luci-app-sqm
endgroup

group "add gcc-15 support"
curl -skL $mirror/openwrt/patch/generic-24.10/202-toolchain-gcc-add-support-for-GCC-15.patch | patch -p1
# fix gcc-15
curl -skL https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/patchs/fix-GCC15.patch | patch -p1
# Mbedtls
sed -i '/TARGET_CFLAGS/ s/$/ -Wno-error=unterminated-string-initialization/' package/libs/mbedtls/Makefile
# elfutils
curl -s $mirror/openwrt/patch/openwrt-6.x/gcc-15/elfutils/901-backends-fix-string-initialization-error-on-gcc15.patch >package/libs/elfutils/patches/901-backends-fix-string-initialization-error-on-gcc15.patch
# lsof
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' feeds/packages/utils/lsof/Makefile
# ppp
sed -i '/CONFIGURE_ARGS/i \\nTARGET_CFLAGS += -std=gnu17\n' package/network/services/ppp/Makefile
# mtd
sed -i '/target=/i TARGET_CFLAGS += -std=gnu17\n' package/system/mtd/Makefile
# dnsmasq
sed -i '/MAKE_FLAGS/i TARGET_CFLAGS += -std=gnu17\n' package/network/services/dnsmasq/Makefile
# bash
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' feeds/packages/utils/bash/Makefile
# e2fsprogs
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' package/utils/e2fsprogs/Makefile
# f2fs-tools
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' package/utils/f2fs-tools/Makefile
# jq
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' feeds/packages/utils/jq/Makefile
# libsepol
sed -i '/HOST_MAKE_FLAGS/i TARGET_CFLAGS += -std=gnu17\n' package/libs/libsepol/Makefile
# parted
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' feeds/packages/utils/parted/Makefile
# gmp
sed -i '/CONFIGURE_ARGS/i TARGET_CFLAGS += -std=gnu17\n' package/libs/gmp/Makefile
# linux-atm
rm -rf package/network/utils/linux-atm
git clone https://github.com/sbwml/package_network_utils_linux-atm package/network/utils/linux-atm
endgroup

group "lede-m28k defconfig"
curl -skL https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/m28k.config >.config
# ccache
if [ "$CCACHE" != "false" ]; then
    echo -e "\nCONFIG_CCACHE=y" >> .config
    echo "CONFIG_CCACHE_DIR=\"$BUILD_DIR/lede/.ccache\"" >> .config
fi
make defconfig &>/dev/null
endgroup
