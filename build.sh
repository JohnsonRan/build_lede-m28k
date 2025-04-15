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
# openssl - quictls
pushd package/libs/openssl/patches
    curl -sO $mirror/openwrt/patch/openssl/quic/0001-QUIC-Add-support-for-BoringSSL-QUIC-APIs.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0002-QUIC-New-method-to-get-QUIC-secret-length.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0003-QUIC-Make-temp-secret-names-less-confusing.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0004-QUIC-Move-QUIC-transport-params-to-encrypted-extensi.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0005-QUIC-Use-proper-secrets-for-handshake.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0006-QUIC-Handle-partial-handshake-messages.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0007-QUIC-Fix-quic_transport-constructors-parsers.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0008-QUIC-Reset-init-state-in-SSL_process_quic_post_hands.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0009-QUIC-Don-t-process-an-incomplete-message.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0010-QUIC-Quick-fix-s2c-to-c2s-for-early-secret.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0011-QUIC-Add-client-early-traffic-secret-storage.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0012-QUIC-Add-OPENSSL_NO_QUIC-wrapper.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0013-QUIC-Correctly-disable-middlebox-compat.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0014-QUIC-Move-QUIC-code-out-of-tls13_change_cipher_state.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0015-QUIC-Tweeks-to-quic_change_cipher_state.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0016-QUIC-Add-support-for-more-secrets.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0017-QUIC-Fix-resumption-secret.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0018-QUIC-Handle-EndOfEarlyData-and-MaxEarlyData.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0019-QUIC-Fall-through-for-0RTT.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0020-QUIC-Some-cleanup-for-the-main-QUIC-changes.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0021-QUIC-Prevent-KeyUpdate-for-QUIC.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0022-QUIC-Test-KeyUpdate-rejection.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0023-QUIC-Buffer-all-provided-quic-data.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0024-QUIC-Enforce-consistent-encryption-level-for-handsha.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0025-QUIC-add-v1-quic_transport_parameters.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0026-QUIC-return-success-when-no-post-handshake-data.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0027-QUIC-__owur-makes-no-sense-for-void-return-values.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0028-QUIC-remove-SSL_R_BAD_DATA_LENGTH-unused.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0029-QUIC-SSLerr-ERR_raise-ERR_LIB_SSL.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0030-QUIC-Add-compile-run-time-checking-for-QUIC.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0031-QUIC-Add-early-data-support.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0032-QUIC-Make-SSL_provide_quic_data-accept-0-length-data.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0033-QUIC-Process-multiple-post-handshake-messages-in-a-s.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0034-QUIC-Fix-CI.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0035-QUIC-Break-up-header-body-processing.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0036-QUIC-Don-t-muck-with-FIPS-checksums.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0037-QUIC-Update-RFC-references.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0038-QUIC-revert-white-space-change.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0039-QUIC-use-SSL_IS_QUIC-in-more-places.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0040-QUIC-Error-when-non-empty-session_id-in-CH.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0041-QUIC-Update-SSL_clear-to-clear-quic-data.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0042-QUIC-Better-SSL_clear.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0043-QUIC-Fix-extension-test.patch
    curl -sO $mirror/openwrt/patch/openssl/quic/0044-QUIC-Update-metadata-version.patch
popd
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
endgroup

group "add gcc-15 support"
curl -skL $mirror/openwrt/patch/generic-24.10/202-toolchain-gcc-add-support-for-GCC-15.patch | patch -p1
# fix gcc-15
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
