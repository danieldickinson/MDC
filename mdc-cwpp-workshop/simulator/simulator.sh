#!/usr/bin/env bash
# =====================================================================
# MDC CWPP Workshop — Attack Simulator
# =====================================================================
# Usage:
#   ./simulator.sh <plan> <scenario>          # run one scenario
#   ./simulator.sh <plan> all                 # run every scenario in a plan
#   ./simulator.sh list                       # list all available scenarios
#   ./simulator.sh kill-chain                 # run the demo kill-chain sequence
#
# Plans: servers containers storage sql appservice keyvault arm dns dbs apis ai
#
# Examples:
#   ./simulator.sh servers 01                 # EICAR file on Windows + Linux
#   ./simulator.sh containers all             # all 10 K8s scenarios
#   ./simulator.sh kill-chain                 # demo flow
#
# ⚠️ SAFETY
#   - Only run in the PoC subscription deployed by infra/ or terraform/.
#   - Every artifact this script creates is tagged poc-mdc-simulator=true.
#   - Re-running a scenario first cleans up the previous artifact (idempotent).
# =====================================================================
set -euo pipefail

# Resolve script dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANS_DIR="$SCRIPT_DIR/plans"

# ----- env discovery -----------------------------------------------------
: "${ENV_TAG:=pc}"
: "${LOCATION:=westeurope}"
: "${RG_EDGE:=rg-mdc-${ENV_TAG}-edge}"
: "${RG_SERVERS:=rg-mdc-${ENV_TAG}-servers}"
: "${RG_DATA:=rg-mdc-${ENV_TAG}-data}"
: "${RG_APPS:=rg-mdc-${ENV_TAG}-apps}"
: "${WIN_VM:=vm-win-mdc}"
: "${LIN_VM:=vm-lin-mdc}"
: "${AKS_CLUSTER:=}"   # will discover
: "${STORAGE_ACC:=}"   # will discover
: "${SQL_SERVER:=}"    # will discover
: "${KEY_VAULT:=}"     # will discover
: "${APP_NAME:=}"      # will discover

export ENV_TAG LOCATION RG_EDGE RG_SERVERS RG_DATA RG_APPS \
       WIN_VM LIN_VM AKS_CLUSTER STORAGE_ACC SQL_SERVER KEY_VAULT APP_NAME

# ----- helpers -----------------------------------------------------------
C_RST=$'\033[0m'; C_BLU=$'\033[1;34m'; C_GRN=$'\033[1;32m'
C_YEL=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'

log()  { printf "%s[%s]%s %s\n" "$C_BLU" "$(date +%H:%M:%S)" "$C_RST" "$*"; }
ok()   { printf "%s ✔ %s%s\n" "$C_GRN" "$*" "$C_RST"; }
warn() { printf "%s ⚠ %s%s\n" "$C_YEL" "$*" "$C_RST"; }
err()  { printf "%s ✘ %s%s\n" "$C_RED" "$*" "$C_RST" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

require_az() {
  have az || { err "Azure CLI (az) is required."; exit 1; }
  az account show >/dev/null 2>&1 || { err "Run 'az login' first."; exit 1; }
}

discover() {
  log "Discovering deployed resources in subscription $(az account show --query name -o tsv)"
  if [[ -z "$AKS_CLUSTER" ]]; then
    AKS_CLUSTER=$(az aks list -g "$RG_SERVERS" --query "[0].name" -o tsv 2>/dev/null || echo "")
  fi
  if [[ -z "$STORAGE_ACC" ]]; then
    STORAGE_ACC=$(az storage account list -g "$RG_DATA" --query "[0].name" -o tsv 2>/dev/null || echo "")
  fi
  if [[ -z "$SQL_SERVER" ]]; then
    SQL_SERVER=$(az sql server list -g "$RG_DATA" --query "[0].name" -o tsv 2>/dev/null || echo "")
  fi
  if [[ -z "$KEY_VAULT" ]]; then
    KEY_VAULT=$(az keyvault list -g "$RG_EDGE" --query "[0].name" -o tsv 2>/dev/null || echo "")
  fi
  if [[ -z "$APP_NAME" ]]; then
    APP_NAME=$(az webapp list -g "$RG_APPS" --query "[0].name" -o tsv 2>/dev/null || echo "")
  fi
  ok "Discovered: aks=$AKS_CLUSTER  stor=$STORAGE_ACC  sql=$SQL_SERVER  kv=$KEY_VAULT  app=$APP_NAME"
  export AKS_CLUSTER STORAGE_ACC SQL_SERVER KEY_VAULT APP_NAME
}

usage() {
  cat <<EOF
Usage: $0 <plan> <scenario|all> | list | kill-chain

Plans:
  servers      — Defender for Servers (S-SRV-01..10)
  containers   — Defender for Containers (S-K8S-01..10)
  storage      — Defender for Storage (S-STO-01..10)
  sql          — Defender for SQL (S-SQL-01..10)
  appservice   — Defender for App Service (S-APP-01..10)
  keyvault     — Defender for Key Vault (S-KV-01..10)
  arm          — Defender for Resource Manager (S-ARM-01..10)
  dns          — Defender for DNS (S-DNS-01..10)
  dbs          — Open-source DBs & Cosmos (S-DB-01..10)
  apis         — Defender for APIs (S-API-01..10)
  ai           — Defender for AI Services (S-AI-01..10)

Examples:
  $0 servers 01              # EICAR test file
  $0 containers all
  $0 kill-chain              # Demo storyline
EOF
}

list_all() {
  for f in "$PLANS_DIR"/*.sh; do
    plan=$(basename "$f" .sh)
    echo "${C_BLU}=== $plan ===${C_RST}"
    grep -E '^# Scenario:' "$f" | sed 's/^# Scenario: /  /'
  done
}

# ----- dispatch ----------------------------------------------------------
[[ $# -lt 1 ]] && { usage; exit 1; }

case "$1" in
  list)
    list_all; exit 0 ;;
  kill-chain)
    require_az; discover
    log "${C_YEL}Running kill-chain demo (≈ 15 minutes)…${C_RST}"
    bash "$PLANS_DIR/apis.sh"       03 || true   # sqlmap UA on API
    bash "$PLANS_DIR/servers.sh"    02 || true   # encoded PS
    bash "$PLANS_DIR/servers.sh"    03 || true   # LSASS
    bash "$PLANS_DIR/arm.sh"        10 || true   # SP cred add
    bash "$PLANS_DIR/arm.sh"        04 || true   # wildcard custom role
    bash "$PLANS_DIR/containers.sh" 01 || true   # privileged pod
    bash "$PLANS_DIR/containers.sh" 06 || true   # SA token misuse
    bash "$PLANS_DIR/storage.sh"    05 || true   # mass extraction
    bash "$PLANS_DIR/arm.sh"        08 || true   # disable diagnostics
    bash "$PLANS_DIR/keyvault.sh"   08 || true   # purge secrets
    ok "Kill-chain finished. Allow 10-30 min for all alerts to surface."
    exit 0 ;;
  -h|--help|help)
    usage; exit 0 ;;
esac

plan="$1"; shift
scenario="${1:-all}"

script="$PLANS_DIR/${plan}.sh"
[[ -f "$script" ]] || { err "Unknown plan: $plan"; usage; exit 1; }

require_az
discover

if [[ "$scenario" == "all" ]]; then
  log "Running ALL scenarios for plan: $plan"
  for n in 01 02 03 04 05 06 07 08 09 10; do
    bash "$script" "$n" || warn "scenario $n failed; continuing"
  done
else
  bash "$script" "$scenario"
fi

ok "Done. Open MDC → Security alerts (allow 5-30 min for alerts to surface)."
