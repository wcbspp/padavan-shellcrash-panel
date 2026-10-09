#!/bin/sh
# Padavan panel adaptation; configurable LAN address.
PANEL_HOME=${CRASHDIR:-/etc/storage/ShellCrash}
. "$PANEL_HOME/starts/panel_env.sh" || exit 1
C=/etc/storage/ShellCrash
P=/tmp/panel-dns
mkdir -p "$P" /tmp/ShellCrash/ruleset || exit 1
hash=3b83cff9903602f27c3a6737c775f742253a24a60165ff4d9b9ef28ac22bc140
if ! echo "$hash  /tmp/ShellCrash/ruleset/cn.srs" | sha256sum -c - >/dev/null 2>&1; then
 { for cert in /etc/ssl/certs/*.crt; do [ ! -f "$cert" ] || cat "$cert"; done; cat "$C/configs/subscription-ca.pem"; } > "$P/ca.pem"
 found=0
 for u in ${PANEL_CN_MIRROR:-} https://raw.githubusercontent.com/DustinWin/ruleset_geodata/877462de3ab7fe81ad4b8bd0f7d4a8fd9df363fe/cn.srs https://testingcf.jsdelivr.net/gh/DustinWin/ruleset_geodata@877462de3ab7fe81ad4b8bd0f7d4a8fd9df363fe/cn.srs; do
  if curl --cacert "$P/ca.pem" --noproxy '*' -fsSL --connect-timeout 10 --max-time 40 --max-filesize 1048576 "$u" -o "$P/cn.new" && echo "$hash  $P/cn.new" | sha256sum -c - >/dev/null 2>&1; then mv "$P/cn.new" /tmp/ShellCrash/ruleset/cn.srs; found=1; break; fi
 done
 rm -f "$P/cn.new" "$P/ca.pem"
 [ "$found" = 1 ] || { logger -t ShellCrash 'CN domain rules unavailable; proxy start cancelled'; exit 1; }
fi
awk -f "$C/starts/filter_compile.awk" "$C/configs/fake_ip_filter.list" > "$P/filter.json" || exit 1
# Preserve LAN-only administration and warning-level bounded logs.
for key in log experimental; do
 awk -v k="$key" '$0 ~ "^\"" k "\":" {sub(/,$/,"");print "{" $0 "}"}' "$C/jsons/config.json" > "$P/$key.json"
 ln -sf "$P/$key.json" "$C/jsons/$key.json"
done
mode=$(sed -n 's/^dns_mod=//p' "$C/configs/ShellCrash.cfg" | head -1)
case "$mode" in mix|fake-ip|redir_host) :;; *) mode=mix;; esac
{
 printf '{"dns":{"servers":[{"type":"udp","tag":"dns-direct","server":"223.5.5.5"},{"type":"tcp","tag":"dns-proxy","server":"8.8.8.8","detour":"proxy-main"},{"type":"udp","tag":"dns_resolver","server":"223.5.5.5"}'
 [ "$mode" = redir_host ] || printf ',{"type":"fakeip","tag":"dns-fake","inet4_range":"198.18.0.0/15"}'
 printf '],"rules":[{"domain":["localhost"],"domain_suffix":["lan","local","localdomain","home.arpa"],"server":"dns-direct"},'
 [ "$mode" = fake-ip ] || printf '{"rule_set":["cn"],"server":"dns-direct"},'
 if [ "$mode" != redir_host ]; then
  if [ "$(cat "$P/filter.json")" != '{"domain":[],"domain_suffix":[],"domain_regex":[]}' ]; then sed 's/}$/,"server":"dns-proxy"},/' "$P/filter.json"; fi
  printf '{"query_type":["A"],"server":"dns-fake","rewrite_ttl":1},'
 fi
 printf '{"query_type":["AAAA"],"action":"reject"}],"final":"dns-proxy","strategy":"ipv4_only"}}\n'
} > "$P/dns.json"
ln -sf "$P/dns.json" "$C/jsons/dns.json"
