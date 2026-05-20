#!/usr/bin/env bash
# Defender for Key Vault — S-KV-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

[[ -n "$KEY_VAULT" ]] || { err "KEY_VAULT not discovered"; exit 1; }

# Helper: ensure demo secrets exist
ensure_secrets() {
  for n in demo-db-password demo-api-key demo-storage-key; do
    az keyvault secret show --vault-name "$KEY_VAULT" -n "$n" >/dev/null 2>&1 \
      || az keyvault secret set --vault-name "$KEY_VAULT" -n "$n" --value "rotate-me-$RANDOM" >/dev/null
  done
}

s01() { scenario_header S-KV-01 "Mass secret enumeration" T1087
  ensure_secrets
  for n in $(az keyvault secret list --vault-name "$KEY_VAULT" --query "[].name" -o tsv); do
    az keyvault secret show --vault-name "$KEY_VAULT" -n "$n" >/dev/null
  done
  ok "Enumerated secrets in $KEY_VAULT."
}

s02() { scenario_header S-KV-02 "Access from unfamiliar IP (walk-through)" T1078
  info "Run an enumeration from a new geo / VPN exit."
  az keyvault secret list --vault-name "$KEY_VAULT" --query "length(@)"
}

s03() { scenario_header S-KV-03 "Access from Tor" T1090.003
  if have torsocks; then
    torsocks az keyvault secret list --vault-name "$KEY_VAULT" --query "length(@)" || true
  else
    warn "torsocks not installed; run via Tor SOCKS manually."
  fi
}

s04() { scenario_header S-KV-04 "Denied-access spike" T1087
  warn "This requires a principal WITHOUT permissions. Set KV_LOWPRIV_TOKEN or run from a different identity."
  for i in $(seq 1 30); do
    az keyvault secret show --vault-name "$KEY_VAULT" -n "doesnotexist-$i" >/dev/null 2>&1 || true
  done
}

s05() { scenario_header S-KV-05 "New application access" T1087
  info "Create a fresh SP and let it list secrets — walk-through."
  az ad sp list --display-name "kv-mdc-newapp" --query "[].appId" -o tsv
}

s06() { scenario_header S-KV-06 "Unusual access pattern" T1078
  ensure_secrets
  az keyvault secret list --vault-name "$KEY_VAULT" -o table | head
}

s07() { scenario_header S-KV-07 "Policy change + bulk read" T1098
  warn "Toggling 'enabled-for-deployment' to surface a vault-policy change event."
  az keyvault update --name "$KEY_VAULT" --enabled-for-deployment true >/dev/null
  az keyvault secret list --vault-name "$KEY_VAULT" >/dev/null
  az keyvault update --name "$KEY_VAULT" --enabled-for-deployment false >/dev/null
  ok "Policy toggled twice."
}

s08() { scenario_header S-KV-08 "Bulk delete + recover" T1485
  ensure_secrets
  for n in $(az keyvault secret list --vault-name "$KEY_VAULT" --query "[].name" -o tsv); do
    az keyvault secret delete --vault-name "$KEY_VAULT" -n "$n" >/dev/null
  done
  warn "Recovering soft-deleted secrets"
  sleep 10
  for n in $(az keyvault secret list-deleted --vault-name "$KEY_VAULT" --query "[].name" -o tsv); do
    az keyvault secret recover --vault-name "$KEY_VAULT" -n "$n" >/dev/null || true
  done
  ok "Bulk delete + recover completed."
}

s09() { scenario_header S-KV-09 "Access from TI IP (walk-through)" T1078
  info "Run a 'secret show' from a known low-rep egress."
}

s10() { scenario_header S-KV-10 "Disable purge protection (will fail by design)" T1562
  az keyvault update --name "$KEY_VAULT" --enable-purge-protection false 2>&1 | tail -3 || true
  ok "Attempt logged."
}

dispatch "${1:?scenario number required (01..10)}"
