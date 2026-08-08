#!/bin/bash
# 编译 lede (rockchip-armv8)：失败时先并行重试一次，仍失败再 V=s 完整重试

set -u

make -j"$1"
rc=$?

if [ "$rc" -ne 0 ]; then
    echo "首次编译失败 (rc=$rc)，并行重试一次..."
    if make -j"$1" >/tmp/lede-retry1.log 2>&1; then
        echo "并行重试成功"
        exit 0
    fi
    rc2=$?
    echo "并行重试仍失败 (rc=$rc2)，V=s 重试..."
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
