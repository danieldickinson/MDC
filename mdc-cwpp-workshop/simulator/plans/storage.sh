#!/usr/bin/env bash
# Defender for Storage — scenarios S-STO-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

CONTAINER="tcon"

stor() { az storage "$@" --account-name "$STORAGE_ACC" --auth-mode login; }

ensure_container() {
  stor container create -n "$CONTAINER" --auth-mode login >/dev/null 2>&1 || true
}

# Scenario: 01 — Upload EICAR blob                          [T1204]
s01() {
  scenario_header S-STO-01 "Upload EICAR blob" T1204
  ensure_container
  local tmp; tmp=$(mktemp)
  printf 'X5O!P%%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$tmp"
  stor blob delete -c "$CONTAINER" -n eicar.com >/dev/null 2>&1 || true
  stor blob upload -c "$CONTAINER" -f "$tmp" -n eicar.com --overwrite
  rm -f "$tmp"
  ok "EICAR uploaded; malware scanner will quarantine."
}

# Scenario: 02 — Access from Tor                            [T1090.003]
s02() {
  scenario_header S-STO-02 "Access via Tor" T1090.003
  if ! have curl; then err "curl required"; return 1; fi
  if ! have torsocks; then warn "torsocks not installed — open the SAS URL manually in Tor Browser instead."; fi
  ensure_container
  local sas; sas=$(stor blob generate-sas -c "$CONTAINER" -n eicar.com --permissions r \
    --expiry "$(date -u -v+1H +%Y-%m-%dT%H:%MZ 2>/dev/null || date -u --date='+1 hour' +%Y-%m-%dT%H:%MZ)" \
    --as-user --auth-mode login -o tsv || echo "")
  local url="https://${STORAGE_ACC}.blob.core.windows.net/${CONTAINER}/eicar.com?${sas}"
  if have torsocks; then
    torsocks curl -s -o /dev/null -w "%{http_code}\n" "$url" || true
  else
    info "Open in Tor Browser: $url"
  fi
  ok "Access via Tor attempted."
}

# Scenario: 03 — Access from suspicious IP                  [T1078]
s03() {
  scenario_header S-STO-03 "Access from a TI / suspicious IP" T1078
  warn "Run this scenario from a VM in a low-reputation egress range."
  info "(Locally we just simulate by curling with a strange UA so something registers.)"
  curl -s -o /dev/null -w "%{http_code}\n" \
       -A "sqlmap/1.7 (suspicious-ua)" \
       "https://${STORAGE_ACC}.blob.core.windows.net/${CONTAINER}/eicar.com" || true
}

# Scenario: 04 — Anonymous public access                    [T1530]
s04() {
  scenario_header S-STO-04 "Set container public + anon read" T1530
  ensure_container
  az storage container set-permission --account-name "$STORAGE_ACC" -n "$CONTAINER" --public-access blob --auth-mode login >/dev/null
  curl -s -o /dev/null -w "anon-status: %{http_code}\n" "https://${STORAGE_ACC}.blob.core.windows.net/${CONTAINER}/eicar.com" || true
  az storage container set-permission --account-name "$STORAGE_ACC" -n "$CONTAINER" --public-access off --auth-mode login >/dev/null
  ok "Anon access generated; container restored to private."
}

# Scenario: 05 — Mass extraction                            [T1567]
s05() {
  scenario_header S-STO-05 "Mass extraction via azcopy" T1567
  ensure_container
  # Generate decoy blobs to extract
  local dir; dir=$(mktemp -d)
  for i in $(seq 1 50); do echo "$RANDOM" > "$dir/blob$i.txt"; done
  if have azcopy; then
    az storage blob upload-batch --destination "$CONTAINER" --source "$dir" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
    local dump; dump=$(mktemp -d)
    az storage blob download-batch -s "$CONTAINER" -d "$dump" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
    rm -rf "$dump"
  else
    az storage blob upload-batch --destination "$CONTAINER" --source "$dir" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
    info "azcopy not installed; using az CLI batch download instead."
    local dump; dump=$(mktemp -d)
    az storage blob download-batch -s "$CONTAINER" -d "$dump" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
    rm -rf "$dump"
  fi
  rm -rf "$dir"
  ok "Bulk read/write completed."
}

# Scenario: 06 — Phishing content                           [T1566]
s06() {
  scenario_header S-STO-06 "Upload phishing-look HTML" T1566
  ensure_container
  local tmp; tmp=$(mktemp --suffix=.html 2>/dev/null || mktemp /tmp/phish.XXXXXX.html)
  cat > "$tmp" <<'HTML'
<!DOCTYPE html><html><head><title>Sign in to your work or school account</title></head>
<body><h1>Microsoft</h1><p>This page is a workshop phishing demo. No data is collected.</p>
<form><input type="email" name="upn" placeholder="Email"><input type="password" placeholder="Password"></form></body></html>
HTML
  stor blob upload -c "$CONTAINER" -f "$tmp" -n login.html --overwrite >/dev/null
  rm -f "$tmp"
  ok "Phishing-look HTML uploaded."
}

# Scenario: 07 — SAS from new geo                           [T1078.004]
s07() {
  scenario_header S-STO-07 "Use SAS from a new location" T1078.004
  warn "Walk-through only — to truly trigger, switch VPN to another country and re-run this command:"
  local sas; sas=$(stor blob generate-sas -c "$CONTAINER" -n eicar.com --permissions r \
    --expiry "$(date -u -v+1H +%Y-%m-%dT%H:%MZ 2>/dev/null || date -u --date='+1 hour' +%Y-%m-%dT%H:%MZ)" \
    --as-user --auth-mode login -o tsv || echo "")
  echo "https://${STORAGE_ACC}.blob.core.windows.net/${CONTAINER}/eicar.com?${sas}"
}

# Scenario: 08 — Mass deletion                              [T1485]
s08() {
  scenario_header S-STO-08 "Mass deletion of blobs" T1485
  ensure_container
  # Make sure there's something to delete
  local dir; dir=$(mktemp -d)
  for i in $(seq 1 30); do echo "$RANDOM" > "$dir/d$i.txt"; done
  az storage blob upload-batch --destination "$CONTAINER" --source "$dir" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
  rm -rf "$dir"
  az storage blob delete-batch -s "$CONTAINER" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
  ok "Bulk deletion executed (recoverable via soft-delete)."
}

# Scenario: 09 — Container ACL → public                     [T1098]
s09() {
  scenario_header S-STO-09 "Change container ACL to public" T1098
  az storage container set-permission --account-name "$STORAGE_ACC" -n "$CONTAINER" --public-access container --auth-mode login >/dev/null
  warn "Reverting"
  az storage container set-permission --account-name "$STORAGE_ACC" -n "$CONTAINER" --public-access off --auth-mode login >/dev/null
  ok "ACL toggled."
}

# Scenario: 10 — Suspicious extension uploads               [T1105]
s10() {
  scenario_header S-STO-10 "Bulk suspicious-extension uploads" T1105
  ensure_container
  local dir; dir=$(mktemp -d)
  local exts=(ps1 bat exe hta js scr)
  for i in $(seq 1 30); do
    ext=${exts[$(( RANDOM % ${#exts[@]} ))]}
    echo "x" > "$dir/$(uuidgen 2>/dev/null || echo $RANDOM).$ext"
  done
  az storage blob upload-batch --destination "$CONTAINER" --source "$dir" --account-name "$STORAGE_ACC" --auth-mode login >/dev/null
  rm -rf "$dir"
  ok "Suspicious extensions uploaded."
}

dispatch "${1:?scenario number required (01..10)}"
