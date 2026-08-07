#!/bin/bash
# replace-uboot.sh
# 把 immortalwrt 的 U-Boot 引导区（idbloader + uboot.img + trust.bin）替换到 lede 固件，
# 使 NanoPi R4S DDR3 1GB 版本可正常启动。
#
# 布局说明：
#   - 两个镜像都是 MBR，第一个分区从 sector 65536 (32MB) 开始；
#   - sector 64-32767 (16MB) 是引导保留区，替换它不影响分区表和文件系统。
#
# 用法: $0 <lede-image> <immortalwrt-image> [output-image]

set -e

LEDE_IMG="$1"
IMMWRT_IMG="$2"
OUT_IMG="${3:-${LEDE_IMG%.img}-ddr3.img}"

if [ -z "$LEDE_IMG" ] || [ -z "$IMMWRT_IMG" ]; then
    echo "用法: $0 <lede-image> <immortalwrt-image> [output-image]"
    exit 1
fi

BS=512
BOOT_START=64
BOOT_COUNT=$((32768 - BOOT_START))   # 32704 sectors = 16MB 引导区
FIRST_PART=65536                     # 第一个分区起始 sector (32MB)

echo "=== 替换 U-Boot 引导区 ==="
echo "lede 镜像:        $LEDE_IMG"
echo "immortalwrt 镜像: $IMMWRT_IMG"
echo "输出镜像:         $OUT_IMG"
echo ""

for f in "$LEDE_IMG" "$IMMWRT_IMG"; do
    [ -f "$f" ] || { echo "错误: 文件不存在: $f"; exit 1; }
done

mbr_part1() {
    dd if="$1" bs=1 skip=454 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n'
}

check_mbr() {
    local f="$1"
    local sig
    sig=$(dd if="$f" bs=1 skip=510 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$sig" = "55aa" ] || { echo "错误: $f 不是有效的 MBR 镜像"; exit 1; }
    [ "$(mbr_part1 "$f")" = "00000100" ] || {
        echo "错误: $f 第一个分区不在 sector $FIRST_PART (32MB)，布局与预期不符"; exit 1; }
}

check_magic() { # <file> <sector> <expected>
    local got
    got=$(dd if="$1" bs=$BS skip="$2" count=1 2>/dev/null | head -c "${#3}")
    [ "$got" = "$3" ] || { echo "错误: $1 的 sector $2 魔数不是 '$3' (实际: '$got')"; exit 1; }
}

check_mbr "$LEDE_IMG"
check_mbr "$IMMWRT_IMG"

if [ -z "$(dd if="$LEDE_IMG" bs=$BS skip=64 count=1 2>/dev/null | od -An -tx1 | tr -d ' 0\n')" ]; then
    echo "错误: lede 镜像 sector 64 没有引导数据"; exit 1
fi

# immortalwrt pine64-bin 布局: uboot.img @16384, trust.bin @24576
check_magic "$IMMWRT_IMG" 16384 "LOADER  "
check_magic "$IMMWRT_IMG" 24576 "BL3X"

cp -f "$LEDE_IMG" "$OUT_IMG"

echo ""
echo "从 immortalwrt 提取引导区 (sector $BOOT_START-$((BOOT_START + BOOT_COUNT - 1))) 并写入 $OUT_IMG ..."
dd if="$IMMWRT_IMG" of="$OUT_IMG" bs=$BS skip=$BOOT_START seek=$BOOT_START \
   count=$BOOT_COUNT conv=notrunc status=progress

check_magic "$OUT_IMG" 16384 "LOADER  "
check_magic "$OUT_IMG" 24576 "BL3X"
cmp -n $((BOOT_START * BS)) "$LEDE_IMG" "$OUT_IMG" || {
    echo "错误: 替换后前 $BOOT_START 个 sector 与原始 lede 镜像不一致（分区表被改动）"; exit 1; }

echo ""
echo "=== U-Boot 替换完成 ==="
echo "输出镜像: $OUT_IMG"
