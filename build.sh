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
find package/new/custom -mindepth 1 -maxdepth 1 -not -name "bash-completion" -not -name "luci-app-diskman" -not -name "luci-app-netspeedtest"  -not -name "speedtest-cli" -exec rm -rf {} +
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
git clone https://git.cooluc.com/sbwml/luci-app-sqm feeds/luci/applications/luci-app-sqm
# fix kmod-zram
curl -skL https://github.com/JohnsonRan/build_lede-m28k/raw/main/openwrt/patchs/fix-zram.patch | patch -p1
endgroup

group "patch fw4"
# util-linux
rm -rf package/utils/util-linux
git clone https://github.com/sbwml/package_utils_util-linux -b openwrt-24.10 package/utils/util-linux

# Shortcut Forwarding Engine
git clone https://git.cooluc.com/sbwml/shortcut-fe package/new/shortcut-fe

# Patch FireWall 4
if [ "$version" = "dev" ] || [ "$version" = "rc2" ]; then
    # firewall4
    sed -i 's|$(PROJECT_GIT)/project|https://github.com/openwrt|g' package/network/config/firewall4/Makefile
    mkdir -p package/network/config/firewall4/patches
    # fix ct status dnat
    curl -s $mirror/openwrt/patch/firewall4/firewall4_patches/990-unconditionally-allow-ct-status-dnat.patch > package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
    # fullcone
    curl -s $mirror/openwrt/patch/firewall4/firewall4_patches/999-01-firewall4-add-fullcone-support.patch > package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
    # bcm fullcone
    curl -s $mirror/openwrt/patch/firewall4/firewall4_patches/999-02-firewall4-add-bcm-fullconenat-support.patch > package/network/config/firewall4/patches/999-02-firewall4-add-bcm-fullconenat-support.patch
    # kernel version
    curl -s $mirror/openwrt/patch/firewall4/firewall4_patches/002-fix-fw4.uc-adept-kernel-version-type-of-x.x.patch > package/network/config/firewall4/patches/002-fix-fw4.uc-adept-kernel-version-type-of-x.x.patch
    # fix flow offload
    curl -s $mirror/openwrt/patch/firewall4/firewall4_patches/001-fix-fw4-flow-offload.patch > package/network/config/firewall4/patches/001-fix-fw4-flow-offload.patch
    # add custom nft command support
    curl -s $mirror/openwrt/patch/firewall4/100-openwrt-firewall4-add-custom-nft-command-support.patch | patch -p1
    # libnftnl
    mkdir -p package/libs/libnftnl/patches
    curl -s $mirror/openwrt/patch/firewall4/libnftnl/0001-libnftnl-add-fullcone-expression-support.patch > package/libs/libnftnl/patches/0001-libnftnl-add-fullcone-expression-support.patch
    curl -s $mirror/openwrt/patch/firewall4/libnftnl/0002-libnftnl-add-brcm-fullcone-support.patch > package/libs/libnftnl/patches/0002-libnftnl-add-brcm-fullcone-support.patch
    # nftables
    mkdir -p package/network/utils/nftables/patches
    curl -s $mirror/openwrt/patch/firewall4/nftables/0001-nftables-add-fullcone-expression-support.patch > package/network/utils/nftables/patches/0001-nftables-add-fullcone-expression-support.patch
    curl -s $mirror/openwrt/patch/firewall4/nftables/0002-nftables-add-brcm-fullconenat-support.patch > package/network/utils/nftables/patches/0002-nftables-add-brcm-fullconenat-support.patch
    curl -s $mirror/openwrt/patch/firewall4/nftables/0003-drop-rej-file.patch > package/network/utils/nftables/patches/0003-drop-rej-file.patch
fi

# FullCone module
git clone https://git.cooluc.com/sbwml/nft-fullcone package/new/nft-fullcone

# IPv6 NAT
git clone https://github.com/sbwml/packages_new_nat6 package/new/nat6

# Patch Luci add nft_fullcone/bcm_fullcone & shortcut-fe & natflow & ipv6-nat & custom nft command option
pushd feeds/luci
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0001-luci-app-firewall-add-nft-fullcone-and-bcm-fullcone-.patch | patch -p1
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0002-luci-app-firewall-add-shortcut-fe-option.patch | patch -p1
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0003-luci-app-firewall-add-ipv6-nat-option.patch | patch -p1
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0004-luci-add-firewall-add-custom-nft-rule-support.patch | patch -p1
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0005-luci-app-firewall-add-natflow-offload-support.patch | patch -p1
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0006-luci-app-firewall-enable-hardware-offload-only-on-de.patch | patch -p1
    curl -s $mirror/openwrt/patch/firewall4/luci-24.10/0007-luci-app-firewall-add-fullcone6-option-for-nftables-.patch | patch -p1
popd
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

group "luci patches"
pushd feeds/luci
    curl -s $mirror/openwrt/patch/luci/0001-luci-mod-system-add-modal-overlay-dialog-to-reboot.patch | patch -p1
    curl -s $mirror/openwrt/patch/luci/0002-luci-mod-status-displays-actual-process-memory-usage.patch | patch -p1
    curl -s $mirror/openwrt/patch/luci/0003-luci-mod-status-storage-index-applicable-only-to-val.patch | patch -p1
    curl -s $mirror/openwrt/patch/luci/0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch | patch -p1
    curl -s $mirror/openwrt/patch/luci/0005-luci-mod-system-add-refresh-interval-setting.patch | patch -p1
    curl -s $mirror/openwrt/patch/luci/0007-luci-mod-system-add-ucitrack-luci-mod-system-zram.js.patch | patch -p1
popd
endgroup

group "kernel patches"
# build with clang
curl -s $mirror/openwrt/patch/generic-24.10/0005-kernel-Add-support-for-llvm-clang-compiler.patch | patch -p1
# out of tree Kconfig(LRNG/CLANG core)
curl -s $mirror/openwrt/patch/generic-24.10/0006-build-kernel-add-out-of-tree-kernel-config.patch | patch -p1
# kenrel Vermagic
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH include/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic
# kernel modules
pushd package/kernel/linux/modules
    rm -f [a-z]*.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/block.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/can.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/crypto.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/firewire.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/fs.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/gpio.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/hwmon.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/i2c.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/iio.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/input.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/leds.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/lib.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/multiplexer.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/netdevices.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/netfilter.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/netsupport.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/nls.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/other.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/pcmcia.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/rtc.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/sound.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/spi.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/usb.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/video.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/virt.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/w1.mk
    curl -Os $mirror/openwrt/patch/openwrt-6.x/modules/wpan.mk
popd
# BBRv3 - linux-6.12
pushd target/linux/generic/backport-6.12
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0001-net-tcp_bbr-broaden-app-limited-rate-sample-detectio.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0002-net-tcp_bbr-v2-shrink-delivered_mstamp-first_tx_msta.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0003-net-tcp_bbr-v2-snapshot-packets-in-flight-at-transmi.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0004-net-tcp_bbr-v2-count-packets-lost-over-TCP-rate-samp.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0005-net-tcp_bbr-v2-export-FLAG_ECE-in-rate_sample.is_ece.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0006-net-tcp_bbr-v2-introduce-ca_ops-skb_marked_lost-CC-m.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0007-net-tcp_bbr-v2-adjust-skb-tx.in_flight-upon-merge-in.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0008-net-tcp_bbr-v2-adjust-skb-tx.in_flight-upon-split-in.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0009-net-tcp-add-new-ca-opts-flag-TCP_CONG_WANTS_CE_EVENT.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0010-net-tcp-re-generalize-TSO-sizing-in-TCP-CC-module-AP.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0011-net-tcp-add-fast_ack_mode-1-skip-rwin-check-in-tcp_f.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0012-net-tcp_bbr-v2-record-app-limited-status-of-TLP-repa.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0013-net-tcp_bbr-v2-inform-CC-module-of-losses-repaired-b.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0014-net-tcp_bbr-v2-introduce-is_acking_tlp_retrans_seq-i.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0015-tcp-introduce-per-route-feature-RTAX_FEATURE_ECN_LOW.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0016-net-tcp_bbr-v3-update-TCP-bbr-congestion-control-mod.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0017-net-tcp_bbr-v3-ensure-ECN-enabled-BBR-flows-set-ECT-.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0018-tcp-export-TCPI_OPT_ECN_LOW-in-tcp_info-tcpi_options.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0019-x86-cfi-bpf-Add-tso_segs-and-skb_marked_lost-to-bpf_.patch
    #curl -Os $mirror/openwrt/patch/kernel-6.12/bbr3/010-bbr3-0020-net-tcp_bbr-v3-silence-Wconstant-logical-operand.patch
popd

# LRNG - 6.12
pushd target/linux/generic/hack-6.12
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0001-LRNG-Entropy-Source-and-DRNG-Manager.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0002-LRNG-allocate-one-DRNG-instance-per-NUMA-node.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0003-LRNG-proc-interface.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0004-LRNG-add-switchable-DRNG-support.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0005-LRNG-add-common-generic-hash-support.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0006-crypto-DRBG-externalize-DRBG-functions-for-LRNG.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0007-LRNG-add-SP800-90A-DRBG-extension.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0008-LRNG-add-kernel-crypto-API-PRNG-extension.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0009-LRNG-add-atomic-DRNG-implementation.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0010-LRNG-add-common-timer-based-entropy-source-code.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0011-LRNG-add-interrupt-entropy-source.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0012-scheduler-add-entropy-sampling-hook.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0013-LRNG-add-scheduler-based-entropy-source.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0014-LRNG-add-SP800-90B-compliant-health-tests.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0015-LRNG-add-random.c-entropy-source-support.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0016-LRNG-CPU-entropy-source.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0017-LRNG-add-Jitter-RNG-fast-noise-source.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0018-LRNG-add-option-to-enable-runtime-entropy-rate-confi.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0019-LRNG-add-interface-for-gathering-of-raw-entropy.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0020-LRNG-add-power-on-and-runtime-self-tests.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0021-LRNG-sysctls-and-proc-interface.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0022-LRMG-add-drop-in-replacement-random-4-API.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0023-LRNG-add-kernel-crypto-API-interface.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0024-LRNG-add-dev-lrng-device-file-support.patch
    curl -Os $mirror/openwrt/patch/kernel-6.12/lrng/011-LRNG-0025-LRNG-add-hwrand-framework-interface.patch
popd

# iproute2 - bbr3
curl -s $mirror/openwrt/patch/iproute2/900-ss-output-TCP-BBRv3-diag-information.patch > package/network/utils/iproute2/patches/900-ss-output-TCP-BBRv3-diag-information.patch
curl -s $mirror/openwrt/patch/iproute2/901-ip-introduce-the-ecn_low-per-route-feature.patch > package/network/utils/iproute2/patches/901-ip-introduce-the-ecn_low-per-route-feature.patch
curl -s $mirror/openwrt/patch/iproute2/902-ss-display-ecn_low-if-tcp_info-tcpi_options-TCPI_OPT.patch > package/network/utils/iproute2/patches/902-ss-display-ecn_low-if-tcp_info-tcpi_options-TCPI_OPT.patch

# kernel patch
# btf: silence btf module warning messages
curl -s $mirror/openwrt/patch/kernel-6.12/btf/990-btf-silence-btf-module-warning-messages.patch > target/linux/generic/hack-6.12/990-btf-silence-btf-module-warning-messages.patch
# cpu model
curl -s $mirror/openwrt/patch/kernel-6.12/arm64/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch > target/linux/generic/hack-6.12/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
## fullcone
#curl -s $mirror/openwrt/patch/kernel-6.12/net/952-net-conntrack-events-support-multiple-registrant.patch > target/linux/generic/hack-6.12/952-net-conntrack-events-support-multiple-registrant.patch
# bcm-fullcone
#curl -s $mirror/openwrt/patch/kernel-6.12/net/982-add-bcm-fullcone-support.patch > target/linux/generic/hack-6.12/982-add-bcm-fullcone-support.patch
#curl -s $mirror/openwrt/patch/kernel-6.12/net/983-add-bcm-fullcone-nft_masq-support.patch > target/linux/generic/hack-6.12/983-add-bcm-fullcone-nft_masq-support.patch
# shortcut-fe
curl -s $mirror/openwrt/patch/kernel-6.12/net/601-netfilter-export-udp_get_timeouts-function.patch > target/linux/generic/hack-6.12/601-netfilter-export-udp_get_timeouts-function.patch
curl -s $mirror/openwrt/patch/kernel-6.12/net/953-net-patch-linux-kernel-to-support-shortcut-fe.patch > target/linux/generic/hack-6.12/953-net-patch-linux-kernel-to-support-shortcut-fe.patch

# mac80211 - 6.15
rm -rf package/kernel/mac80211
git clone https://github.com/sbwml/package_kernel_mac80211 package/kernel/mac80211 -b openwrt-24.10
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
