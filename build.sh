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

mkdir -p /builder
group "download coolsnowwolf/lede"
git clone -b master --depth=1 https://github.com/JohnsonRan/lede-m28k /builder/lede
cd /builder/lede
git reset --hard 8c11125e5e49b66b250ba6f229b12cfc911da87c
endgroup

group "custom package"
curl -skL https://github.com/JohnsonRan/lede-m28k/raw/main/openwrt/scripts/99-custom.sh | bash
endgroup

group "update feed"
./scripts/feeds update -a
./scripts/feeds install -a
endgroup

echo "build lede-m28k"
curl -skL https://github.com/JohnsonRan/lede-m28k/raw/main/openwrt/m28k.config > .config
make defconfig
make -j$(nproc)