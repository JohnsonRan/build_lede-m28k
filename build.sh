#!/bin/bash -e

group "download coolsnowwolf/lede"
git clone --depth=1 -b 8c11125e5e49b66b250ba6f229b12cfc911da87c https://github.com/coolsnowwolf/lede
endgroup