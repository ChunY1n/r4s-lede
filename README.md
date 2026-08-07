# r4s-lede

NanoPi R4S DDR3 1GB 固件：以 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) 为基座，
集成 **xwan/mwan3plus 单线多拨** + **dae/daed（daede）透明代理**，仅使用 iptables/fw3 防火墙，
不含 nftables/fw4。

## 固件内容

- 基座：lede `master`（内核 6.12，rockchip armv8）
- 多拨：`luci-app-xwan` + `mwan3plus`（来自 x-wrt/com.x-wrt，iptables 系）
- 代理：`dae` + `daed` + `luci-app-daede`（来自 kenzok8/openwrt-daede，内核 BTF/BPF + netkit）
- 向导：`luci-app-wizard`（初始化向导，含“关闭 IPv6”开关）
- 分区：系统 rootfs **512MB** + 软件 overlay **1024MB**（首启自动创建，剩余空间为数据分区）
- 后台：**http://192.168.15.1**
- U-Boot：lede 自带 `rk3399_ddr_800MHz_v1.30.bin`，原生支持 R4S DDR3 1GB，无需替换

## 使用

在 GitHub Actions 页面手动触发 `Build Lede R4S DDR3 1GB (dae/daed + xwan)`，
或等待每周自动构建。产物为 squashfs / ext4 两种 `sysupgrade.img.gz`，直接写 SD 卡/eMMC。

## 本地包说明

| 目录 | 内容 |
|------|------|
| `packages/xwan/luci-app-xwan` | 多拨 LuCI 界面（原 x-wrt） |
| `packages/xwan/mwan3plus` | 多拨引擎，提供 mwan3（原 x-wrt） |
| `packages/wizard/luci-app-wizard` | 初始化向导（原 x-wrt） |
| `packages/r4s-layout` | 分区自动创建（1GB overlay）+ 默认 LAN 192.168.15.1 |

## 注意事项

- dae/daed 依赖内核 BTF 与 BPF 选项，工作流已硬校验，缺项会直接失败。
- mwan3plus 是 iptables 系，与 lede 的 fw3 原生搭配，固件内不启用 fw4/nftables。
- 在线升级 dae/daed 的软件源尚未配置，后续可加入 lede 对应的 opkg feed。
