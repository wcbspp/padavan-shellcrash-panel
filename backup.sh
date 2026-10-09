#!/bin/sh
# Capture only the files the installer may change, including absence markers.
set -eu
umask 077
out=${1:--}
D=$(mktemp -d /tmp/sc-panel-backup.XXXXXX)
trap 'rm -f "$D/_panel_backup_state"; rmdir "$D" 2>/dev/null || :' EXIT
set -- started_script.sh
{
 if [ -e /etc/storage/ShellCrash ]; then echo shellcrash=present; else echo shellcrash=absent; fi
 if [ -e /etc/storage/chinadns/chnroute.txt ]; then echo cnroute=present; else echo cnroute=absent; fi
 if [ -d /etc/storage/chinadns ]; then echo cndir=present; else echo cndir=absent; fi
} > "$D/_panel_backup_state"
[ ! -e /etc/storage/ShellCrash ] || set -- "$@" ShellCrash
[ ! -e /etc/storage/chinadns/chnroute.txt ] || set -- "$@" chinadns/chnroute.txt
tar -czf "$out" -C /etc/storage "$@" -C "$D" _panel_backup_state
