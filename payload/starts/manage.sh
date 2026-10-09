#!/bin/sh
# Padavan panel adaptation; configurable LAN address.
PANEL_HOME=${CRASHDIR:-/etc/storage/ShellCrash}
. "$PANEL_HOME/starts/panel_env.sh" || exit 1
# Runs on demand through Padavan's authenticated administration interface.
C=/etc/storage/ShellCrash
export GOMEMLIMIT=12MiB
export GOGC=25
D=/tmp/sc-admin
umask 077
mkdir -p "$D"
act=$1
id=$2
phase(){ printf '%s\n' "$1" > "$D/phase"; [ -z "$2" ] || printf '%s\n' "$2" > "$D/message"; }
event(){ printf '%s %s\n' "$(date '+%m-%d %H:%M:%S')" "$1" >> "$D/events.log"; }
owner_live(){ p=$(cat "$D/operation.lock/owner" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
lock(){
 if ! mkdir "$D/operation.lock" 2>/dev/null; then
  owner_live && return 1
  rm -f "$D/operation.lock/owner"; rmdir "$D/operation.lock" 2>/dev/null || return 1
  mkdir "$D/operation.lock" 2>/dev/null || return 1
 fi
 echo $$ > "$D/operation.lock/owner"
 trap 'if [ "$act" = dns ]; then rm -rf "$D/dns"; fi; if [ "$act" = rules ]; then rm -rf "$D/rules"; fi; if [ "$act" = fetch ]; then rm -f "$D/ca.pem"; fi; if [ "$act" = apply ]; then rm -f "$D/previous.json" "$D/candidate.json" "$D/bounds.gz" "$D/bounds.json" "$D/check.json" "$D/upload.b64" "$D/upload.parts"; fi; rm -f "$D/operation.lock/owner"; rmdir "$D/operation.lock" 2>/dev/null' EXIT
}
valid_id(){ printf '%s' "$1" | grep -Eq '^[a-f0-9]{8}$'; }
status(){
 . "$C/starts/resource_health.sh"
 resource_read
 pid=$(pidof CrashCore | awk '{print $1}'); running=false; [ -n "$pid" ] && running=true
 rss=0; [ -z "$pid" ] || rss=$(awk '/^VmRSS:/{print $2}' "/proc/$pid/status")
 mem=$(awk '/^MemFree:/{print $2}' /proc/meminfo)
 mode=true; [ -f "$C/configs/panel-disabled" ] && mode=false
 ph=$(cat "$D/phase" 2>/dev/null); [ -n "$ph" ] || ph=idle
 msg=$(cat "$D/message" 2>/dev/null | base64 | tr -d '\n')
 url=$(cat "$C/configs/subscription.url.b64" 2>/dev/null | tr -d '\n')
 nonce=$(cat "$D/id" 2>/dev/null)
 active=false; owner_live && active=true
 recoveries=$(cat "$D/recoveries" 2>/dev/null); case "$recoveries" in ''|*[!0-9]*) recoveries=0;; esac
 core_version=$(sed -n 's/^version=//p' "$C/configs/core-installed.info" 2>/dev/null)
 printf '%s' "$core_version" | grep -Eq '^1\.[0-9]{1,2}\.[0-9]{1,3}$' || core_version=unknown
 core_sha=$(sed -n 's/^sha256=//p' "$C/configs/core-installed.info" 2>/dev/null)
 printf '%s' "$core_sha" | grep -Eq '^[a-f0-9]{64}$' || core_sha=''
 core_blob=$(sed -n 's/^git_blob=//p' "$C/configs/core-installed.info" 2>/dev/null)
 printf '%s' "$core_blob" | grep -Eq '^[a-f0-9]{40}$' || core_blob=''
 . "$C/starts/mirror_lib.sh"
 mirror_base_b64=$(mirror_base | base64 | tr -d '\n')
 mirror_target_b64=$(mirror_get target | base64 | tr -d '\n')
 mirror_last_b64=$(cat "$C/configs/mirror.last" 2>/dev/null | base64 | tr -d '\n')
 mirror_check='{}'; [ ! -s "$D/mirror-check.json" ] || mirror_check=$(cat "$D/mirror-check.json")
 mirror_ready=false; [ ! -s "$C/configs/mirror_key" ] || mirror_ready=true
 core_check='{}'; [ ! -s "$D/core-check.json" ] || core_check=$(cat "$D/core-check.json")
 rules_count=$(head -1 "$C/configs/rules.meta" 2>/dev/null); case "$rules_count" in ''|*[!0-9]*) rules_count=4305;; esac
 dns_mode=$(sed -n 's/^dns_mod=//p' "$C/configs/ShellCrash.cfg" | head -1); case "$dns_mode" in mix|fake-ip|redir_host) :;; *) dns_mode=unknown;; esac
 rules_date=$(sed -n '2p' "$C/configs/rules.meta" 2>/dev/null | base64 | tr -d '\n')
 printf '{"mirror_base_b64":"%s","mirror_target_b64":"%s","mirror_last_b64":"%s","mirror_ready":%s,"mirror_check":%s,"dns_mode":"%s","rules_count":%s,"rules_date_b64":"%s","running":%s,"enabled":%s,"rss_kb":%s,"free_kb":%s,"recoveries":%s,"active":%s,"phase":"%s","message_b64":"%s","url_b64":"%s","id":"%s","core_version":"%s","core_sha":"%s","core_blob":"%s","core_check":%s,"available_kb":%s,"pressure":"%s","shmem_kb":%s,"slab_kb":%s,"tcp_kb":%s,"conntrack":%s}\n' "$mirror_base_b64" "$mirror_target_b64" "$mirror_last_b64" "$mirror_ready" "$mirror_check" "$dns_mode" "$rules_count" "$rules_date" "$running" "$mode" "${rss:-0}" "${mem:-0}" "$recoveries" "$active" "$ph" "$msg" "$url" "$nonce" "$core_version" "$core_sha" "$core_blob" "$core_check" "$rh_available" "$rh_pressure" "$rh_shmem" "$rh_slab" "$rh_tcp" "$rh_conn"
 trim_logs
}
trim_logs(){
# Bound transient diagnostic files without a new log daemon.
 for f in "$D/events.log" /tmp/ShellCrash/core.log; do
  [ -f "$f" ] || continue
  n=$(stat -c %s "$f" 2>/dev/null)
  if [ "${n:-0}" -gt 65536 ]; then tail -c 32768 "$f" > "$D/trim"; cat "$D/trim" > "$f"; rm -f "$D/trim"; fi
 done
}
stop_core(){
 old=$(pidof CrashCore)
 "$C/start.sh" stop >> "$D/worker.log" 2>&1
 tries=0
 while [ "$tries" -lt 20 ]; do
  live=false
  for p in $old; do kill -0 "$p" 2>/dev/null && live=true; done
  [ "$live" = true ] || return 0
  sleep 1; tries=$((tries+1))
 done
 return 1
}
start_core(){
 "$C/starts/panel_boot.sh" >> "$D/worker.log" 2>&1
 secret=$(sed -n 's/^secret=//p' "$C/configs/ShellCrash.cfg" | head -1)
 tries=0
 while [ "$tries" -lt 30 ]; do
  if [ -n "$(pidof CrashCore)" ] && curl -fsS --connect-timeout 1 --max-time 2 -H "Authorization: Bearer $secret" http://${PANEL_LAN_IP}:9999/version >/dev/null 2>&1; then return 0; fi
  sleep 1; tries=$((tries+1))
 done
 return 1
}
save_safe(){
 waited=0
 while [ -d /tmp/shellcrash-storage-save.lock ] && [ "$waited" -lt 75 ]; do sleep 1; waited=$((waited+1)); done
 "$C/starts/save_storage.sh" >> "$D/worker.log" 2>&1
}
fail(){ phase error "$1"; event "$1"; }
case "$act" in
 fetch|apply|rules|dns|coreupdate|mirrorsync|mirrorsave)
  . "$C/starts/resource_health.sh"; resource_read
  if [ "$rh_pressure" = protect ]; then
   owner_live && exit 1
   valid_id "$id" && echo "$id" > "$D/id"
   fail memory_protected; exit 1
  fi;;
esac
case "$act" in
 trim) trim_logs;;
 status) status;;
 incidents) [ ! -f "$D/incidents.log" ] || tail -100 "$D/incidents.log";;
 memory) [ ! -f "$D/memory.csv" ] || cat "$D/memory.csv";;
 mirrorsave|mirrorsync)
  valid_id "$id" || exit 1
  if [ "$act" = mirrorsave ]; then [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] || exit 1; fi
  lock || exit 1
  echo "$id" > "$D/id"
  . "$C/starts/mirror_update.sh";;
 corecheck|coreupdate)
  valid_id "$id" || exit 1
  lock || exit 1
  echo "$id" > "$D/id"
  : > "$D/worker.log"
  . "$C/starts/core_update.sh";;
 dns)
  valid_id "$id" && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && [ "$(cat "$D/kind")" = filter ] || exit 1
  lock || exit 1
  . "$C/starts/dns_update.sh";;
 rules)
  valid_id "$id" || exit 1
  lock || exit 1
  echo "$id" > "$D/id"
  . "$C/starts/rules_update.sh";;
 clear)
  lock || exit 1
  phase clearing clearing_logs
  # Keep system OOM evidence and the separate recovery counter.
  for f in "$D/events.log" /tmp/ShellCrash/core.log /tmp/ShellCrash/ShellCrash.log "$D/fetch-error" "$D/worker.log" "$D/logs.out"; do
   [ ! -f "$f" ] || : > "$f"
  done
  event 'Logs cleared'; phase done logs_cleared;;
 logs)
  printf '=== Management ===\n'; tail -40 "$D/events.log" 2>/dev/null
  printf '\n=== Resource pressure ===\n'; tail -20 "$D/pressure.log" 2>/dev/null
  printf '\n=== Proxy ===\n'; tail -65 /tmp/ShellCrash/core.log 2>/dev/null
  printf '\n=== ShellCrash ===\n'; tail -20 /tmp/ShellCrash/ShellCrash.log 2>/dev/null
  printf '\n=== Subscription download ===\n'; tail -5 "$D/fetch-error" 2>/dev/null
  printf '\n=== Last operation ===\n'; tail -20 "$D/worker.log" 2>/dev/null;;
 new)
  valid_id "$id" || exit 1
  owner_live && exit 1
  kind=$3; case "$kind" in source|bounds|filter|mirror) :;; *) exit 1;; esac
  [ "$(cat "$D/phase" 2>/dev/null)" = uploading ] && [ -f "$D/upload.parts" ] && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && [ "$kind" = "$(cat "$D/kind" 2>/dev/null)" ] && exit 0
  if [ "$kind" = bounds ]; then [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && [ -s "$D/candidate.url.b64" ] || exit 1; else
   rm -f "$D/sub.raw" "$D/candidate.url.b64" "$D/previous.json" "$D/candidate.json" "$D/bounds.gz" "$D/bounds.json" "$D/check.json"
   echo "$id" > "$D/id"
  fi
  : > "$D/upload.parts"; echo "$kind" > "$D/kind"; phase uploading upload_ready;;
 put)
  valid_id "$id" && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] || exit 1
  chunk=$3; printf '%s' "$chunk" | grep -Eq '^[a-f0-9]{4}[A-Za-z0-9+/=]{1,16}$' || exit 1
  [ "$(stat -c %s "$D/upload.parts")" -lt 400000 ] || exit 1
  seq=$(printf '%s' "$chunk" | cut -c 1-4); part=$(printf '%s' "$chunk" | cut -c 5-)
  # Short indexed records can be replayed safely; assembly discards duplicates.
  printf '%s %s\n' "$seq" "$part" >> "$D/upload.parts";;
 fetch)
  [ "$(cat "$D/phase" 2>/dev/null)" = downloaded ] && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && exit 0
  valid_id "$id" && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && [ "$(cat "$D/kind")" = source ] || exit 1
  lock || exit 1
  phase fetching downloading_subscription; : > "$D/worker.log"
  sort "$D/upload.parts" | awk '!seen[$1]++{printf "%s",$2}' > "$D/upload.b64"
  url=$(base64 -d "$D/upload.b64" 2>/dev/null)
  [ "${#url}" -le 2048 ] || { fail invalid_subscription_url; exit 1; }
  case "$url" in https://*|http://*) :;; *) fail invalid_subscription_url; exit 1;; esac
  printf '%s' "$url" | grep -q '[[:space:]]' && { fail invalid_subscription_url; exit 1; }
  printf '%s' "$url" | base64 | tr -d '\n' > "$D/candidate.url.b64"
  # TLS verification remains enabled; neither the URL nor credentials enter logs.
  cat /etc/ssl/certs/*.crt "$C/configs/subscription-ca.pem" > "$D/ca.pem"
  if ! curl -4 --cacert "$D/ca.pem" --noproxy '*' -fsS --connect-timeout 10 --max-time 25 --max-filesize 524288 "$url" -o "$D/sub.raw" 2> "$D/fetch-error"; then
   if [ -n "$(pidof CrashCore)" ]; then
    event 'Direct subscription download failed; retrying through active proxy'
    if ! curl -4 --cacert "$D/ca.pem" --noproxy '' --proxy http://${PANEL_LAN_IP}:7890 -fsS --connect-timeout 10 --max-time 60 --max-filesize 524288 "$url" -o "$D/sub.raw" 2>> "$D/fetch-error"; then
     fail subscription_download_failed; rm -f "$D/sub.raw"; exit 1
    fi
   else
    fail subscription_download_failed; rm -f "$D/sub.raw"; exit 1
   fi
  fi
  [ -s "$D/sub.raw" ] || { fail empty_subscription; exit 1; }
  phase downloaded subscription_downloaded; event 'Subscription downloaded; active configuration unchanged';;
 start|stop|restart)
  lock || exit 1
  : > "$D/worker.log"; phase "$act" service_operation; event "Service $act requested"
  if [ "$act" = stop ]; then
   echo 1 > "$C/configs/panel-disabled"
   stop_core || { fail service_stop_failed; exit 1; }
   if ! save_safe; then fail persistent_save_failed; exit 1; fi
  else
   rm -f "$C/configs/panel-disabled"
   if [ "$act" = restart ]; then stop_core || { fail service_stop_failed; exit 1; }; fi
   [ -n "$(pidof CrashCore)" ] || start_core || { fail service_start_failed; exit 1; }
   save_safe || { fail persistent_save_failed; exit 1; }
  fi
  phase done service_operation_complete; event "Service $act completed";;
 apply)
  [ "$(cat "$D/phase" 2>/dev/null)" = done ] && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && exit 0
  valid_id "$id" && [ "$id" = "$(cat "$D/id" 2>/dev/null)" ] && [ "$(cat "$D/kind")" = bounds ] || exit 1
  lock || exit 1
  : > "$D/worker.log"; phase applying validating_configuration
  sort "$D/upload.parts" | awk '!seen[$1]++{printf "%s",$2}' > "$D/upload.b64"
  if ! base64 -d "$D/upload.b64" > "$D/bounds.gz" 2>/dev/null; then fail invalid_upload; exit 1; fi
  magic=$(head -c 2 "$D/bounds.gz" | base64 | tr -d '\n')
  if [ "$magic" = H4s= ]; then gzip -dc "$D/bounds.gz" 2>/dev/null | head -c 160001 > "$D/bounds.json"; else head -c 160001 "$D/bounds.gz" > "$D/bounds.json"; fi
  [ "$(stat -c %s "$D/bounds.json")" -le 160000 ] && grep -q '^\[' "$D/bounds.json" || { fail invalid_upload; exit 1; }
  awk 'FNR==NR{b=$0;next} /^"outbounds":/{print "\"outbounds\":" b ",";next}{print}' "$D/bounds.json" "$C/jsons/config.json" > "$D/candidate.json"
  grep -q '^"outbounds":' "$C/jsons/config.json" || { fail configuration_template_missing; exit 1; }
  was_running=0; [ -z "$(pidof CrashCore)" ] || was_running=1
  cp "$C/jsons/config.json" "$D/previous.json"
  cp "$C/configs/subscription.url.b64" "$D/previous.url.b64" 2>/dev/null || : > "$D/previous.url.b64"
  if [ "$was_running" = 1 ]; then stop_core || { fail service_stop_failed; exit 1; }; fi
  if [ ! -s /tmp/ShellCrash/CrashCore.tar.gz ]; then "$C/starts/download_core.sh" >> "$D/worker.log" 2>&1 || { fail core_download_failed; exit 1; }; fi
  # Only outbounds change; avoid parsing the unchanged large DNS/CN tables twice.
  { printf '{"outbounds":'; cat "$D/bounds.json"; printf ',"route":{"final":"proxy-main"}}\n'; } > "$D/check.json"
  if ! tar -zxf /tmp/ShellCrash/CrashCore.tar.gz -C /tmp/ShellCrash || ! GOMEMLIMIT=12MiB GOGC=25 /tmp/ShellCrash/CrashCore check -c "$D/check.json" >> "$D/worker.log" 2>&1; then
   rm -f /tmp/ShellCrash/CrashCore; [ "$was_running" = 0 ] || start_core
   fail configuration_check_failed_previous_kept; exit 1
  fi
  cp "$D/candidate.json" "$C/jsons/config.json"; cp "$D/candidate.url.b64" "$C/configs/subscription.url.b64"
  if ! save_safe; then
   cp "$D/previous.json" "$C/jsons/config.json"; cp "$D/previous.url.b64" "$C/configs/subscription.url.b64"
   rm -f /tmp/ShellCrash/CrashCore; [ "$was_running" = 0 ] || start_core
   fail persistent_save_failed_previous_kept; exit 1
  fi
  if [ "$was_running" = 1 ] && ! start_core; then
   cp "$D/previous.json" "$C/jsons/config.json"; cp "$D/previous.url.b64" "$C/configs/subscription.url.b64"
   save_safe; start_core
   fail start_failed_previous_restored; exit 1
  fi
  [ "$was_running" = 1 ] || rm -f /tmp/ShellCrash/CrashCore
  phase done subscription_updated; event 'Subscription validated, saved and applied'
  rm -f "$D/previous.json" "$D/candidate.json" "$D/bounds.gz" "$D/bounds.json" "$D/upload.b64" "$D/upload.parts" "$D/check.json";;
 *) exit 1;;
esac
