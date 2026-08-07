#!/bin/bash
# 编译 lede (rockchip-armv8)，失败时用 V=s 完整重试一次

set -u

make -j"$1"
rc=$?

if [ "$rc" -ne 0 ]; then
    echo "首次编译失败 (rc=$rc)，V=s 重试..."
    if make V=s >/tmp/lede-retry.log 2>&1; then
        echo "V=s 重试成功"
        tail -100 /tmp/lede-retry.log
        exit 0
    else
        echo "V=s 重试仍失败"
        tail -300 /tmp/lede-retry.log
        exit 1
    fi
fi

exit 0
