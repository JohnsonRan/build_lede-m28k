#!/bin/bash -e

mkdir -p /builder
group "download coolsnowwolf/lede"
git clone -b master https://github.com/coolsnowwolf/lede /builder/lede
cd /builder/lede
git reset --hard 8c11125e5e49b66b250ba6f229b12cfc911da87c
endgroup

group "update feed"
./scripts/feeds update -a
./scripts/feeds install -a
endgroup

group "patch lede"
curl -skL https://github.com/JohnsonRan/lede-m28k/raw/main/openwrt/patchs/m28k_mold+lto.patch | patch -p1
endgroup

group "custom package"
curl -skL https://github.com/JohnsonRan/lede-m28k/raw/main/openwrt/scripts/99-custom.sh | bash
endgroup

echo "build lede-m28k"
curl -skL https://github.com/JohnsonRan/lede-m28k/raw/main/openwrt/m28k.config > .config
make defconfig
make -j$(nproc)