#!/bin/bash
set -e
cd /mnt/Fast/projects/xash-streaming/xash3d-fwgs
./waf build -j$(nproc) > /tmp/xash-build.log 2>&1 || { grep -iE "error" /tmp/xash-build.log | head -10; exit 1; }
./waf install --destdir=/mnt/Fast/projects/xash-streaming/install >> /tmp/xash-build.log 2>&1
echo BUILD-AND-INSTALL-OK
