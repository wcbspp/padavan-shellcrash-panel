#!/bin/sh
# Sourced by existing sampler/status/actions; no resident monitor.
resource_read(){
 set -- $(awk '/^MemFree:/{f=$2}/^MemAvailable:/{a=$2}/^AnonPages:/{n=$2}/^Shmem:/{h=$2}/^Slab:/{s=$2}/^SUnreclaim:/{u=$2}END{print f+0,a+0,n+0,h+0,s+0,u+0}' /proc/meminfo)
 rh_free=$1; rh_available=$2; rh_anon=$3; rh_shmem=$4; rh_slab=$5; rh_unreclaim=$6
 rh_pressure=normal
 [ "$rh_available" -ge 16384 ] || rh_pressure=warning
 [ "$rh_available" -ge 12288 ] || rh_pressure=protect
 set -- $(awk '/^TCP:/{for(i=1;i<=NF;i++){if($i=="mem")t=$(i+1)*4;if($i=="alloc")a=$(i+1)}}/^UDP:/{for(i=1;i<=NF;i++)if($i=="mem")u=$(i+1)*4}END{print t+0,u+0,a+0}' /proc/net/sockstat)
 rh_tcp=$1; rh_udp=$2; rh_sockets=$3
 rh_conn=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null); case "$rh_conn" in ''|*[!0-9]*) rh_conn=0;; esac
}
resource_cleanup(){
 # Only unreferenced, reproducible legacy runtime data; keep the SSR plugin/config.
 if [ "$(/usr/sbin/nvram get ss_enable)" != 1 ] && ! grep -qE 'dnsmasq\.dom|gfwlist|conf-dir=' /etc/dnsmasq.conf /etc/storage/dnsmasq/dnsmasq.conf && ! grep -q 'conf-file=' /etc/storage/dnsmasq/dnsmasq.conf; then
  rm -f /tmp/dnsmasq.dom/gfwlist_list.conf
 fi
 # Startup removes the program cache; update jobs own any temporary archive.
 rh_owner=$(cat /tmp/sc-admin/operation.lock/owner 2>/dev/null)
 if [ -n "$(pidof CrashCore)" ] && { [ -z "$rh_owner" ] || ! kill -0 "$rh_owner" 2>/dev/null; } && [ ! -d /tmp/shellcrash-bootstrap.lock ]; then
  rm -f /tmp/ShellCrash/CrashCore.tar.gz
 fi
}
resource_snapshot(){
 resource_read
 rh_zone=$(awk '/Node 0, zone/{z=$4}/pages free/{if(z=="DMA")d=$3*4;else if(z=="Normal")n=$3*4}END{print d+0 "," n+0}' /proc/zoneinfo)
 printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$now" "$up" "${pid:-0}" "${rss:-0}" "$rh_available" "$rh_anon" "$rh_shmem" "$rh_slab" "$rh_unreclaim" "$rh_tcp" "$rh_udp" "$rh_sockets" "$rh_conn" "$rh_zone" >> "$D/resources.csv"
 awk -F, -v min="$((up-86400))" 'NF==15 && $2>=min' "$D/resources.csv" | tail -1441 > "$D/resources.next"; mv "$D/resources.next" "$D/resources.csv"
 old_pressure=$(cat "$D/pressure" 2>/dev/null)
 if [ "$old_pressure" != "$rh_pressure" ]; then
  printf '%s pressure=%s available_kb=%s rss_kb=%s shmem_kb=%s slab_kb=%s tcp_kb=%s conntrack=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$rh_pressure" "$rh_available" "${rss:-0}" "$rh_shmem" "$rh_slab" "$rh_tcp" "$rh_conn" >> "$D/pressure.log"
  tail -100 "$D/pressure.log" > "$D/pressure.next"; mv "$D/pressure.next" "$D/pressure.log"
 fi
 printf '%s\n' "$rh_pressure" > "$D/pressure"
}
