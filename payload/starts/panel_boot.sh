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
ln -sf /etc/storage/chinadns/chnroute.txt /tmp/ShellCrash/cn_ip.txt
"$CRASHDIR/start.sh" start
