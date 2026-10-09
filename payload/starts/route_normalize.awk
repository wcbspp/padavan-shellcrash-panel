# Canonical panel profiles store each top-level field on one line.
BEGIN {n=0}
/^"route":/ {
 n++
 if ($0 !~ /"rule_set"[ ]*:[ ]*\[[ ]*"cn"[ ]*\]/) {
  if ($0 ~ /"rules"[ ]*:[ ]*\[[ ]*\]/) sub(/"rules"[ ]*:[ ]*\[[ ]*\]/,"\"rules\":[{\"rule_set\":[\"cn\"],\"outbound\":\"direct\"}]")
  else sub(/"rules"[ ]*:[ ]*\[/,"\"rules\":[{\"rule_set\":[\"cn\"],\"outbound\":\"direct\"},")
 }
 if ($0 !~ /"tag"[ ]*:[ ]*"cn"/) {
  library="{\"type\":\"local\",\"tag\":\"cn\",\"format\":\"binary\",\"path\":\"/tmp/ShellCrash/ruleset/cn.srs\"}"
  if ($0 ~ /"rule_set"[ ]*:[ ]*\[[ ]*\]/) sub(/"rule_set"[ ]*:[ ]*\[[ ]*\]/,"\"rule_set\":["library"]")
  else if ($0 ~ /"rule_set"[ ]*:[ ]*\[[ ]*\{/) sub(/"rule_set"[ ]*:[ ]*\[[ ]*\{/,"\"rule_set\":["library",{")
  else sub(/^"route":[ ]*\{/,"\"route\":{\"rule_set\":["library"],")
 }
}
{print}
END {if(n!=1)exit 2}
