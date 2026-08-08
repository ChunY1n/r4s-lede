#!/bin/sh
# 防火墙选项定时兜底：LuCI/CLI 任何方式改 firewall 配置后，
# 每分钟把 tcpcca 和 fullcone 同步到系统（与 ucitrack 事件互补）。
/etc/init.d/r4s-tcpcca reload >/dev/null 2>&1
/etc/init.d/r4s-fullcone reload >/dev/null 2>&1
exit 0
