# Shared helpers sourced by plan scripts. Not executable on its own.

C_RST=$'\033[0m'; C_BLU=$'\033[1;34m'; C_GRN=$'\033[1;32m'
C_YEL=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'

scenario_header() {
  local id="$1" name="$2" mitre="$3"
  printf "\n%s──────────────────────────────────────────────────%s\n" "$C_BLU" "$C_RST"
  printf "%s[%s]%s %s   %s(%s)%s\n" "$C_BLU" "$id" "$C_RST" "$name" "$C_DIM" "$mitre" "$C_RST"
  printf "%s──────────────────────────────────────────────────%s\n" "$C_BLU" "$C_RST"
}

ok()   { printf "%s ✔ %s%s\n" "$C_GRN" "$*" "$C_RST"; }
warn() { printf "%s ⚠ %s%s\n" "$C_YEL" "$*" "$C_RST"; }
err()  { printf "%s ✘ %s%s\n" "$C_RED" "$*" "$C_RST" >&2; }
info() { printf "%s · %s%s\n" "$C_DIM" "$*" "$C_RST"; }

confirm_safe() {
  if [[ "${ENV_TAG:-}" != "pc" && "${FORCE_UNSAFE:-0}" != "1" ]]; then
    err "ENV_TAG is not 'pc' — set FORCE_UNSAFE=1 to override."
    exit 1
  fi
  local sub_name
  sub_name="$(az account show --query name -o tsv 2>/dev/null || echo unknown)"
  if [[ "$sub_name" != *"poc"* && "$sub_name" != *"PoC"* && "$sub_name" != *"sandbox"* && "${FORCE_UNSAFE:-0}" != "1" ]]; then
    warn "Subscription name '$sub_name' does not contain 'poc/PoC/sandbox'. Set FORCE_UNSAFE=1 to proceed."
    exit 1
  fi
}

run_on_vm() {
  local vm="$1"; shift
  local rg="${1:-$RG_SERVERS}"; shift || true
  local script="$1"; shift
  az vm run-command invoke -g "$rg" -n "$vm" \
    --command-id RunShellScript --scripts "$script" --query "value[0].message" -o tsv
}

run_on_winvm() {
  local vm="$1"; shift
  local rg="${1:-$RG_SERVERS}"; shift || true
  local script="$1"; shift
  az vm run-command invoke -g "$rg" -n "$vm" \
    --command-id RunPowerShellScript --scripts "$script" --query "value[0].message" -o tsv
}

dispatch() {
  # $1 = scenario number; functions must be named s01, s02, …
  local n="$1"; shift || true
  if declare -F "s${n}" >/dev/null; then
    "s${n}" "$@"
  else
    err "Scenario $n not implemented for $(basename "$0" .sh)"
    exit 2
  fi
}
