#!/bin/sh
# Plain text settings, never evaluated as shell code.
mirror_get(){ sed -n "s/^$1=//p" "$C/configs/mirror.conf" 2>/dev/null | head -1; }
mirror_base(){ mirror_get base; }
mirror_core_url(){
 base=$(mirror_base); [ -n "$base" ] || return 1
 sha=$(release_get sha256 "$1"); blob=$(release_get git_blob "$1")
 if [ -n "$sha" ]; then printf '%s/core-%s.tar.gz\n' "$base" "$sha"; else printf '%s/blob-%s.tar.gz\n' "$base" "$blob"; fi
}
mirror_put(){
 kind=$1; file=$2
 base=$(mirror_base); target=$(mirror_get target)
 [ -n "$base" ] && [ -n "$target" ] || return 2
 printf '%s' "$target" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}@[A-Za-z0-9.-]+:[0-9]{1,5}$' || return 1
 peer=${target%:*}; port=${target##*:}
 [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || return 1
 key="$C/configs/mirror_key"; hosts="$C/configs/mirror_known_hosts"
 [ -s "$key" ] && [ -s "$hosts" ] || return 1
 # Dropbear reads ~/.ssh/known_hosts; restore a pinned host key after reboot.
 mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
 touch "$HOME/.ssh/known_hosts"; chmod 600 "$HOME/.ssh/known_hosts"
 while IFS= read -r line; do grep -Fxq "$line" "$HOME/.ssh/known_hosts" || printf '%s\n' "$line" >> "$HOME/.ssh/known_hosts"; done < "$hosts"
 digest=$(sha256sum "$file" | awk '{print $1}')
 # No password, agent, PTY or port forwards; the server key has a forced receiver.
 if ! ssh -T -I 45 -p "$port" -i "$key" "$peer" "$kind $digest" < "$file" > "$D/mirror-reply" 2>> "$D/worker.log"; then return 1; fi
 [ "$(cat "$D/mirror-reply")" = "$digest" ] || return 1
 suffix=txt; [ "$kind" != core ] || suffix=tar.gz; [ "$kind" != cn ] || suffix=srs
 # Verify the public download route too; success on SSH alone is insufficient.
 curl -4 --noproxy '*' -fsSL --connect-timeout 8 --max-time 120 --max-filesize "$(stat -c %s "$file")" "$base/$kind-$digest.$suffix" | sha256sum | grep -q "^$digest " || return 1
 printf '%s|%s|%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$kind" "$digest" > "$C/configs/mirror.last"
 event "Mirror synchronized and read-back verified: $kind $digest"
 return 0
}
mirror_required_put(){
 [ -n "$(mirror_get target)" ] || return 0
 phase syncing mirror_syncing
 mirror_put "$1" "$2"
}

mirror_probe(){
 base=$(mirror_base)
 [ -n "$base" ] || { printf '{"available":false,"configured":false}\n' > "$D/mirror-check.json"; return 0; }
 if curl -4 --noproxy '*' -fsSL --connect-timeout 5 --max-time 12 --max-filesize 2048 "$base/core-info.txt" -o "$D/mirror-check.info" && release_valid "$D/mirror-check.info"; then
  printf '{"available":true,"configured":true,"version":"%s","sha256":"%s","checked":%s}\n' "$(release_get version "$D/mirror-check.info")" "$(release_get sha256 "$D/mirror-check.info")" "$(date +%s)" > "$D/mirror-check.json"
 else printf '{"available":false,"configured":true,"checked":%s}\n' "$(date +%s)" > "$D/mirror-check.json"; fi
 rm -f "$D/mirror-check.info"
}
