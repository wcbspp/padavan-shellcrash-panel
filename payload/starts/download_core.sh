#!/bin/sh
C=/etc/storage/ShellCrash
D=/tmp/sc-admin
CRASHDIR=$C
mkdir -p /tmp/ShellCrash
 . "$C/starts/core_release.sh"
 release="$C/configs/core-installed.info"
 release_valid "$release" || { logger -t ShellCrash 'Installed core metadata invalid; refusing download'; exit 1; }
 if [ -s /tmp/ShellCrash/CrashCore.tar.gz ]; then
  printf '%s  %s\n' "$(release_get sha256 "$release")" /tmp/ShellCrash/CrashCore.tar.gz | sha256sum -c - >/dev/null 2>&1 && exit 0
  rm -f /tmp/ShellCrash/CrashCore.tar.gz
 fi
if [ ! -s /tmp/ShellCrash/CrashCore.tar.gz ]; then
 downloaded=0
 expected=$(release_get sha256 "$release")
 for u in $(sed '/^#/d; /^$/d' "$C/configs/core_mirrors.list"); do
  installed=$(release_get version "$release")
  u=$(printf '%s' "$u" | sed "s/singbox-mini-[0-9][0-9.]*-mipsle/singbox-mini-$installed-mipsle/")
  # Preserve the user-configured mirror priority; never accept a different program.
  if curl -4 --noproxy '*' -fsSL --connect-timeout 8 --max-time 90 --max-filesize "$(release_get archive_size "$release")" "$u" -o /tmp/ShellCrash/core-download.tgz && printf '%s  %s\n' "$expected" /tmp/ShellCrash/core-download.tgz | sha256sum -c - >/dev/null 2>&1; then downloaded=1; break; fi
  rm -f /tmp/ShellCrash/core-download.tgz
 done
 if [ "$downloaded" = 1 ] || release_download "$release" /tmp/ShellCrash/core-download.tgz; then
  mv /tmp/ShellCrash/core-download.tgz /tmp/ShellCrash/CrashCore.tar.gz
  logger -t ShellCrash 'Core downloaded and verified; configured mirrors first, public fallback'
 else
  rm -f /tmp/ShellCrash/core-download.tgz
  logger -t ShellCrash 'Core download failed; ordinary routing remains available'
  exit 1
 fi
fi
