#!/bin/bash -e

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

mirror=https://raw.githubusercontent.com/JohnsonRan/opwrt_build_script/master

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
endgroup

group "add gcc-15 support"
mirror=https://github.com/JohnsonRan/opwrt_build_script/raw/master
curl -skL $mirror/openwrt/patch/generic-24.10/202-toolchain-gcc-add-support-for-GCC-15.patch | patch -p1
# fix gcc-15
# Mbedtls
curl -s $mirror/openwrt/patch/openwrt-6.x/gcc-15/mbedtls/901-tests-fix-string-initialization-error-on-gcc15.patch > package/libs/mbedtls/patches/901-tests-fix-string-initialization-error-on-gcc15.patch
sed -i '/TARGET_CFLAGS/ s/$/ -Wno-error=unterminated-string-initialization/' package/libs/mbedtls/Makefile
# elfutils
curl -s $mirror/openwrt/patch/openwrt-6.x/gcc-15/elfutils/901-backends-fix-string-initialization-error-on-gcc15.patch > package/libs/elfutils/patches/901-backends-fix-string-initialization-error-on-gcc15.patch
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
endgroup

echo "build lede-m28k"
curl -skL https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/m28k.config > .config
make defconfig
make -j$(nproc)