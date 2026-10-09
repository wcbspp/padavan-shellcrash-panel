#!/bin/sh
CRASHDIR=/etc/storage/ShellCrash
export CRASHDIR
export GOMEMLIMIT=12MiB
export GOGC=25
"$CRASHDIR/starts/legacy_storage_guard.sh" || exit 1
# 8 MiB reserve starves the small DMA zone during management shell forks.
[ ! -w /proc/sys/vm/min_free_kbytes ] || echo 4096 > /proc/sys/vm/min_free_kbytes
# Old SSR rule updates use mtd_storage.sh save even when SSR is disabled.
if [ "$(/usr/sbin/nvram get ss_enable)" != 1 ] && crontab -l 2>/dev/null | grep -qE '/usr/bin/update_(chnroute|gfwlist)\.sh'; then
 crontab -l | grep -vE '/usr/bin/update_(chnroute|gfwlist)\.sh' > /tmp/sc-clean-cron
 crontab /tmp/sc-clean-cron; rm -f /tmp/sc-clean-cron
fi
sed -i '/^alias crash=/d; /^export CRASHDIR=/d' /etc/profile
echo 'alias crash="sh /etc/storage/ShellCrash/menu.sh"' >> /etc/profile
echo 'export CRASHDIR="/etc/storage/ShellCrash"' >> /etc/profile
"$CRASHDIR/starts/padavan_ui.sh"
# Boot honours the official switch; manual start and recovery remain available.
[ "$1" != boot ] || [ ! -f "$CRASHDIR/.dis_startup" ] || exit 0
[ -f "$CRASHDIR/configs/panel-disabled" ] && exit 0
if ! mkdir /tmp/shellcrash-bootstrap.lock 2>/dev/null; then
 owner=$(cat /tmp/shellcrash-bootstrap.lock/owner 2>/dev/null)
 [ -z "$owner" ] || { kill -0 "$owner" 2>/dev/null && exit 0; }
 rm -f /tmp/shellcrash-bootstrap.lock/owner
 rmdir /tmp/shellcrash-bootstrap.lock 2>/dev/null || exit 1
 mkdir /tmp/shellcrash-bootstrap.lock 2>/dev/null || exit 1
fi
echo $$ > /tmp/shellcrash-bootstrap.lock/owner
trap 'rm -f /tmp/shellcrash-bootstrap.lock/owner; rmdir /tmp/shellcrash-bootstrap.lock 2>/dev/null' EXIT
mkdir -p /tmp/ShellCrash
mount -t tmpfs -o remount,rw,size=45M tmpfs /tmp
"$CRASHDIR/starts/download_core.sh" || exit 1
[ -f "$CRASHDIR/configs/panel-disabled" ] && exit 0
. "$CRASHDIR/starts/panel_env.sh" || exit 1
if [ "$1" = boot ]; then SC_CONTROL_SOURCE=boot; else SC_CONTROL_SOURCE=${SC_CONTROL_SOURCE:-tool}; fi
export SC_CONTROL_SOURCE
C=$CRASHDIR
. "$C/starts/rules_path.sh"
rules_ensure || exit 1
ln -sf "$RULES_FILE" /tmp/ShellCrash/cn_ip.txt
native_result=0
"$CRASHDIR/start.sh" start || native_result=$?
[ "$native_result" != 0 ] || exit 0
# Some official trailing hooks return nonzero after a successful start.
# Accept only a live core with its authenticated API, not the exit code alone.
secret=$(sed -n 's/^secret=//p' "$CRASHDIR/configs/ShellCrash.cfg" | head -1)
for attempt in 1 2 3 4 5; do
 if [ -n "$(pidof CrashCore)" ] && curl --noproxy '*' -fsS --connect-timeout 1 --max-time 2 -H "Authorization: Bearer $secret" "http://${PANEL_LAN_IP}:9999/version" >/dev/null 2>&1; then exit 0; fi
 sleep 1
done
exit "$native_result"
