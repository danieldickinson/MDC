#!/usr/bin/env bash
# Defender for Resource Manager — S-ARM-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

SUB=$(az account show --query id -o tsv)

s01() { scenario_header S-ARM-01 "ARM from Tor (walk-through)" T1090.003
  info "Run 'az' commands over a Tor SOCKS proxy from a clean VM."
}

s02() { scenario_header S-ARM-02 "ARM from suspicious IP (walk-through)" T1078
  info "Run from a TI-listed VM IP."
}

s03() { scenario_header S-ARM-03 "Risky sign-in + ARM (walk-through)" T1078
  info "Trigger Entra Identity Protection risk on a user, then do az group list."
}

s04() { scenario_header S-ARM-04 "Wildcard custom role" T1098
  local rolename="pwn-cwpp-$(date +%s)"
  cat > /tmp/role.json <<EOF
{ "Name": "$rolename", "IsCustom": true,
  "Description": "PoC workshop wildcard role - DO NOT USE",
  "Actions": ["*"], "AssignableScopes": ["/subscriptions/$SUB"] }
EOF
  az role definition create --role-definition /tmp/role.json
  warn "Removing role"
  az role definition delete --name "$rolename" || true
  rm -f /tmp/role.json
  ok "Role created & deleted."
}

s05() { scenario_header S-ARM-05 "Bulk VM deployment" T1496
  local rg="rg-mdc-${ENV_TAG}-spam-$(date +%s)"
  az group create -n "$rg" -l "$LOCATION" --tags env=poc-mdc poc-mdc-simulator=true >/dev/null
  for i in $(seq 1 5); do
    az vm create -g "$rg" -n vmspam$i \
      --image Ubuntu2204 --size Standard_B1s \
      --admin-username adminuser --generate-ssh-keys \
      --public-ip-sku Standard --tags env=poc-mdc poc-mdc-simulator=true \
      --no-wait >/dev/null
  done
  warn "Cleanup runs in background"
  az group delete -n "$rg" --yes --no-wait
  ok "Bulk deploy issued (5 VMs)."
}

s06() { scenario_header S-ARM-06 "Mass deletion (test RGs only)" T1485
  warn "Deletes any RG with tag poc-mdc-simulator=true that is NOT one of the lab RGs."
  for rg in $(az group list --tag poc-mdc-simulator=true --query "[].name" -o tsv); do
    case "$rg" in
      "$RG_EDGE"|"$RG_SERVERS"|"$RG_DATA"|"$RG_APPS") info "skip $rg" ;;
      *) az group delete -n "$rg" --yes --no-wait ;;
    esac
  done
}

s07() { scenario_header S-ARM-07 "Run-command misuse" T1059
  az vm run-command invoke -g "$RG_SERVERS" -n "$LIN_VM" \
    --command-id RunShellScript --scripts "whoami; uname -a; curl -s https://example.com | head -c 200" \
    --query "value[0].message" -o tsv | head -10 || true
  ok "Run-command issued."
}

s08() { scenario_header S-ARM-08 "Disable diagnostic settings" T1562
  local kv_id
  kv_id=$(az keyvault show -n "$KEY_VAULT" --query id -o tsv)
  local diag
  diag=$(az monitor diagnostic-settings list --resource "$kv_id" --query "[0].name" -o tsv)
  if [[ -n "$diag" && "$diag" != "null" ]]; then
    az monitor diagnostic-settings delete --resource "$kv_id" -n "$diag"
    warn "Recreating diag with placeholder LAW"
    local law_id
    law_id=$(az monitor log-analytics workspace list -g "$RG_EDGE" --query "[0].id" -o tsv)
    az monitor diagnostic-settings create --resource "$kv_id" -n "$diag" \
      --workspace "$law_id" --logs '[{"category":"AuditEvent","enabled":true}]' >/dev/null
    ok "Diagnostic setting cycled."
  else
    info "No diag setting present to delete."
  fi
}

s09() { scenario_header S-ARM-09 "Bulk template export" T1213
  local out; out=$(mktemp -d)
  for rg in "$RG_EDGE" "$RG_SERVERS" "$RG_DATA" "$RG_APPS"; do
    az group export -n "$rg" > "$out/$rg.json" 2>/dev/null || warn "skip $rg"
  done
  rm -rf "$out"
  ok "Templates exported to a temp dir (and deleted)."
}

s10() { scenario_header S-ARM-10 "Service principal credential add" T1098
  local sp_name="sp-mdc-cwpp-poc"
  local app_id
  app_id=$(az ad sp list --display-name "$sp_name" --query "[0].appId" -o tsv)
  if [[ -z "$app_id" ]]; then
    info "Creating throwaway SP $sp_name"
    app_id=$(az ad sp create-for-rbac --name "$sp_name" --role Reader --scopes "/subscriptions/$SUB" --query appId -o tsv)
  fi
  az ad sp credential reset --id "$app_id" --append --query "{appId:appId,end:endDateTime}" -o table || true
  ok "SP credential appended."
}

dispatch "${1:?scenario number required (01..10)}"
