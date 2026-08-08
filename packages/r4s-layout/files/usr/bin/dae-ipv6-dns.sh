#!/bin/sh
# 联动 daed DNS/global 定制：
# 常规模式：仅当 (IPv6 关闭) 且 (daede 服务运行) 且 (核心运行) 时保持
# AAAA 拒绝 / localdns / subnode / 本机 bootstrap 定制，否则还原。
# start 模式（daed 启动钩子）：IPv6 关闭就立即应用，IPv6 开启就还原，不等核心。
# 面板账号从 /etc/daed/auth 读取（格式 username:password，权限 600），不进固件。
set -u

DB=/etc/daed/wing.db
AUTH=/etc/daed/auth
[ -f "$DB" ] || exit 0
command -v sqlite3 >/dev/null 2>&1 || exit 0

mode=${1:-auto}
v6=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo 0)
[ "$v6" = "1" ] || [ "$v6" = "0" ] || exit 0

daed_run=0
pgrep -f '/usr/bin/daed run' >/dev/null 2>&1 && daed_run=1
core_run=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT running FROM systems WHERE id=1;" 2>/dev/null | head -1)
[ "${core_run:-0}" = "1" ] || core_run=0

want_apply=0
if [ "$mode" = "start" ]; then
	[ "$v6" = "1" ] && want_apply=1
else
	[ "$v6" = "1" ] && [ "$daed_run" = "1" ] && [ "$core_run" = "1" ] && want_apply=1
fi

changed=0
if [ "$want_apply" = "1" ]; then
	# ---------- 应用定制 ----------
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM dns WHERE selected=1 AND instr(dns,'qtype(aaaa) -> reject')>0;" 2>/dev/null)
	[ "${has:-0}" -gt 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE dns SET dns=replace(dns,'qname(geosite:cn) -> alidns','qtype(aaaa) -> reject'||char(10)||'      qname(geosite:cn) -> alidns') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM dns WHERE selected=1 AND instr(dns,'localdns: ''udp://127.0.0.1:53''')>0;" 2>/dev/null)
	[ "${has:-0}" -gt 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE dns SET dns=replace(dns,'upstream {','upstream {'||char(10)||'  localdns: ''udp://127.0.0.1:53''') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM dns WHERE selected=1 AND instr(dns,'subnode(subtag_regex: .*) -> localdns')>0;" 2>/dev/null)
	[ "${has:-0}" -gt 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE dns SET dns=replace(dns,'fallback: cloudflare','subnode(subtag_regex: .*) -> localdns'||char(10)||'    fallback: cloudflare') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM configs WHERE selected=1 AND instr(global,'bootstrap_resolver:\"127.0.0.1:53\"')>0;" 2>/dev/null)
	[ "${has:-0}" -gt 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE configs SET global=replace(replace(global,'bootstrap_resolver:\"127.0.0.1\"','bootstrap_resolver:\"127.0.0.1:53\"'),'bootstrap_resolver:\"223.5.5.5:53\"','bootstrap_resolver:\"127.0.0.1:53\"') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	# 节点连通性检测字段去掉 IPv6 字面量（纯 hex+冒号 条目）
	for _f in udp_check_dns tcp_check_url; do
		_old=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT global FROM configs WHERE selected=1;" 2>/dev/null | sed -n "s/.*${_f}:\"\([^\"]*\)\".*/\1/p")
		[ -n "$_old" ] || continue
		_new=$(printf '%s' "$_old" | awk -F, '{o=""; for(i=1;i<=NF;i++){if($i ~ /^[0-9a-fA-F:]+$/ && $i ~ /:/) continue; o=o (o==""?"":",") $i} printf "%s", o}')
		[ "$_new" = "$_old" ] && continue
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE configs SET global=replace(global,'${_f}:\"${_old}\"','${_f}:\"${_new}\"') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	done
else
	# ---------- 还原 ----------
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM dns WHERE selected=1 AND instr(dns,'qtype(aaaa) -> reject')>0;" 2>/dev/null)
	[ "${has:-0}" -eq 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE dns SET dns=replace(replace(dns,'qtype(aaaa) -> reject'||char(10),''),'    '||char(10),'') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM dns WHERE selected=1 AND instr(dns,'localdns: ''udp://127.0.0.1:53''')>0;" 2>/dev/null)
	[ "${has:-0}" -eq 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE dns SET dns=replace(replace(dns,'  localdns: ''udp://127.0.0.1:53'''||char(13)||char(10),''),'  localdns: ''udp://127.0.0.1:53'''||char(10),'') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM dns WHERE selected=1 AND instr(dns,'subnode(subtag_regex: .*) -> localdns')>0;" 2>/dev/null)
	[ "${has:-0}" -eq 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE dns SET dns=replace(replace(dns,'subnode(subtag_regex: .*) -> localdns'||char(13)||char(10)||'    ',''),'subnode(subtag_regex: .*) -> localdns'||char(10)||'    ','') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	has=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT COUNT(*) FROM configs WHERE selected=1 AND instr(global,'bootstrap_resolver:\"127.0.0.1\"')>0;" 2>/dev/null)
	[ "${has:-0}" -eq 0 ] || {
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE configs SET global=replace(replace(global,'bootstrap_resolver:\"127.0.0.1:53\"','bootstrap_resolver:\"223.5.5.5:53\"'),'bootstrap_resolver:\"127.0.0.1\"','bootstrap_resolver:\"223.5.5.5:53\"') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	}
	# 节点连通性检测字段补回默认 IPv6 条目
	for _f in udp_check_dns tcp_check_url; do
		_def="2001:4860:4860::8888"
		[ "$_f" = "tcp_check_url" ] && _def="2606:4700:4700::1111"
		_old=$(sqlite3 -cmd '.timeout 8000' "$DB" "SELECT global FROM configs WHERE selected=1;" 2>/dev/null | sed -n "s/.*${_f}:\"\([^\"]*\)\".*/\1/p")
		[ -n "$_old" ] || continue
		case ",$_old," in
			*",$_def,"*) continue ;;
		esac
		_new="$_old,$_def"
		n=$(sqlite3 -cmd '.timeout 8000' "$DB" "UPDATE configs SET global=replace(global,'${_f}:\"${_old}\"','${_f}:\"${_new}\"') WHERE selected=1; SELECT changes();" 2>/dev/null | tail -1)
		[ "${n:-0}" -gt 0 ] && changed=1
	done
fi

[ "$changed" = "1" ] || exit 0

# 核心在跑：通过 daed API 热加载，避免停核心；账号从 AUTH 文件读取
if [ "$daed_run" = "1" ] && [ "$core_run" = "1" ] && [ -r "$AUTH" ]; then
	_username=$(sed -n '1s/:.*//p' "$AUTH")
	_password=$(sed -n '1s/^[^:]*://p' "$AUTH")
	[ -n "$_username" ] || exit 0
	TOKEN=$(curl -s -m 8 -H 'Content-Type: application/json' --data "{\"query\":\"query Login(\$username:String!,\$password:String!){token(username:\$username,password:\$password)}\",\"variables\":{\"username\":\"$_username\",\"password\":\"$_password\"}}" http://127.0.0.1:2023/graphql | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
	[ -n "$TOKEN" ] && curl -s -m 30 -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" --data '{"query":"mutation Run($dry:Boolean!){run(dry:$dry)}","variables":{"dry":false}}' http://127.0.0.1:2023/graphql >/dev/null 2>&1
	logger -t dae-ipv6-dns "daed config changed, reloaded via API"
fi
