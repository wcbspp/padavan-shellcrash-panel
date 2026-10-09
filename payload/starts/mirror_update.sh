#!/bin/sh
# Sourced by the authenticated manager under its operation lock.
. "$C/starts/mirror_lib.sh"
if [ "$act" = mirrorsave ]; then
 [ "$(cat "$D/kind")" = mirror ] || { fail invalid_upload; exit 1; }
 sort "$D/upload.parts" | awk '!seen[$1]++{printf "%s",$2}' > "$D/upload.b64"
 base64 -d "$D/upload.b64" > "$D/mirror.new" 2>/dev/null || { fail invalid_upload; exit 1; }
 [ "$(wc -c < "$D/mirror.new")" -le 2048 ] || { fail mirror_invalid; exit 1; }
 [ "$(wc -l < "$D/mirror.new")" -eq 2 ] || { fail mirror_invalid; exit 1; }
 base=$(sed -n 's/^base=//p' "$D/mirror.new"); target=$(sed -n 's/^target=//p' "$D/mirror.new")
 if [ -n "$base" ]; then
  printf '%s' "$base" | grep -Eq '^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~-]+)*$' || { fail mirror_invalid; exit 1; }
  printf '%s' "$base" | grep -q '/\.\.' && { fail mirror_invalid; exit 1; }
 fi
 if [ -n "$target" ]; then
  [ -n "$base" ] && printf '%s' "$target" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}@[A-Za-z0-9.-]+:[0-9]{1,5}$' || { fail mirror_invalid; exit 1; }
  port=${target##*:}; [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || { fail mirror_invalid; exit 1; }
  [ -s "$C/configs/mirror_key" ] && [ -s "$C/configs/mirror_known_hosts" ] || { fail mirror_key_missing; exit 1; }
 fi
 phase saving mirror_saving
 previous="$D/mirror.previous"; existed=0
 [ ! -f "$C/configs/mirror.conf" ] || { existed=1; cp "$C/configs/mirror.conf" "$previous"; }
 printf 'base=%s\ntarget=%s\n' "$base" "$target" > "$C/configs/mirror.conf"
 chmod 600 "$C/configs/mirror.conf"
 if ! save_safe; then
  if [ "$existed" = 1 ]; then cp "$previous" "$C/configs/mirror.conf"; else rm -f "$C/configs/mirror.conf"; fi
  fail persistent_save_failed_previous_kept; exit 1
 fi
 rm -f "$previous" "$D/mirror.new" "$D/upload.b64" "$D/upload.parts"
 phase done mirror_saved; event 'Mirror settings saved'; exit 0
fi
[ -n "$(mirror_get target)" ] || { fail mirror_key_missing; exit 1; }
. "$C/starts/core_release.sh"
mirror_probe
current_sha=$(release_get sha256 "$C/configs/core-installed.info")
base=$(mirror_base)
phase syncing mirror_syncing
# A current mirror needs no archive staged in the router's RAM.
if curl -4 --noproxy '*' -fsSL --connect-timeout 8 --max-time 120 --max-filesize "$(release_get archive_size "$C/configs/core-installed.info")" "$base/core-$current_sha.tar.gz" | sha256sum | grep -q "^$current_sha "; then
 core_present=1
else core_present=0; fi
if [ "$core_present" = 0 ]; then
 . "$C/starts/resource_health.sh"; resource_read
 packed=$(release_get archive_size "$C/configs/core-installed.info")
 [ "$rh_available" -ge "$((packed/1024+16384))" ] || { fail mirror_memory_insufficient; exit 1; }
 "$C/starts/download_core.sh" >> "$D/worker.log" 2>&1 || { fail core_download_failed; exit 1; }
 mirror_put core /tmp/ShellCrash/CrashCore.tar.gz || { rm -f /tmp/ShellCrash/CrashCore.tar.gz; fail mirror_sync_failed; exit 1; }
fi
. "$C/starts/rules_path.sh"
rules_ensure || { fail rules_invalid_previous_kept; exit 1; }
mirror_put info "$C/configs/core-installed.info" && mirror_put rules "$RULES_FILE" && mirror_put cn /tmp/ShellCrash/ruleset/cn.srs || { fail mirror_sync_failed; rm -f /tmp/ShellCrash/CrashCore.tar.gz; exit 1; }
# Boot no longer needs the compressed archive once the executable is mapped.
[ -z "$(pidof CrashCore)" ] || rm -f /tmp/ShellCrash/CrashCore.tar.gz
save_safe || { fail persistent_save_failed; exit 1; }
mirror_probe
rm -f "$C/configs/mirror.pending"
phase done mirror_synced
